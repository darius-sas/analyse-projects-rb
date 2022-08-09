#!/bin/ruby

require 'daru'
require 'concurrent'

ARCAN_COMMAND = '/home/fenn/git/arcan-2/arcan-cli/target/arcan.sh'
ARCAN_MEMORY='3G'

def call_arcan(project_name, input_dir, output_dir, filters_dir, branch, language, log_file)
    filters_file = "#{filters_dir}/#{project_name}.yaml"
    filters_file = "#{filters_dir}/all-projects.yaml" unless File.exist? filters_file
    output = "output.writeSmellCharacteristics=true output.writeComponentMetrics=true output.writeAffected=false output.writeEntities=true output.writeProjectMetrics=true"
    arcan_command = "export JAVA_MEMORY=#{ARCAN_MEMORY} && #{ARCAN_COMMAND} analyse -p #{project_name} -i #{input_dir} -o #{output_dir} -l #{language} --branch #{branch} --filtersFile #{filters_file} --all -e --startDate 1-1-1 --endDate 2022-12-12 --intervalDays 180 -t #{output}"
    `echo "#{arcan_command}" > #{log_file}`
    return `#{arcan_command} 2>&1 >> #{log_file}`
end

def git_clone(link, project_dir, log_file, shallow)
    shallow_str = "--depth 1" if shallow
    shallow_str = "" unless shallow
    return `git clone --progress #{shallow_str} #{link} #{project_dir} 2> #{log_file}`
end

if ARGV.length <= 4
    puts "Usage <projects-file> <repos-dir> <output-dir> <filters-dir> [--runArcan] [--runGit] [--not-shallow] [--delete-repos]"
    exit 0
else
    projects_file = ARGV[0]
    projects_dir = ARGV[1]
    output_dir = ARGV[2]
    filters_dir = ARGV[3]
    run_arcan = ARGV.include? "--runArcan";
    run_git = ARGV.include? "--runGit";
    shallow = !ARGV.include?("--not-shallow");
    delete_repos = ARGV.include? "--delete-repos"
    disable_csv_output = ARGV.include? "--disable-csv-output"
end


thread_pool_size = [2, Concurrent.processor_count - 1].max
pool = Concurrent::FixedThreadPool.new(thread_pool_size)
puts "Thread pool size: #{thread_pool_size}"

projects = Daru::DataFrame.from_csv(projects_file)
git_projects = projects.filter_rows { |r| 
    r['project.link'].match? /(github.com)|(bitbucket.org)|(gitlab.com)|(gitbox.apache.org)/ 
}

success = Concurrent::Array.new
partial_failure = Concurrent::Array.new
failed = Concurrent::Array.new
already_analysed = Concurrent::Array.new

n_projects = git_projects.size
logs_dir = "#{output_dir}/logs"
logs_dir_fail = "#{logs_dir}/failed"
logs_dir_succ = "#{logs_dir}/success"
`rm -rf #{logs_dir}`
`mkdir -p #{logs_dir_succ}`
`mkdir -p #{logs_dir_fail}`

git_projects.each_row do |p|
    puts "Queuing for analysis project '#{p['project.name']}'"
    pool.post do 
        link = p['project.link']
        folder_name = link.chomp("/")[/[\w\d\-\.]+$/].chomp(".git")
        project_dir = "#{projects_dir}/#{folder_name}"

        if not Dir.exist? project_dir and run_git
            puts "Cloning #{link}"
            log_file = "#{logs_dir}/#{folder_name}.git.log"
            git_clone(link, project_dir, log_file, shallow)
            puts "Git successfully cloned #{link}" if $?.success?
            puts "Git failed to clone #{link}" if not $?.success?
        elsif Dir.exist? project_dir and run_git
            puts "Git repo already cloned: #{project_dir}"
        end
        
        partial_failure = []
        if Dir.exists? "#{output_dir}/arcanOutput/#{folder_name}" and !Dir["#{output_dir}/arcanOutput/#{folder_name}"].empty?
            puts "Project #{folder_name} was already analysed"
            already_analysed << folder_name
        elsif Dir.exists? project_dir and run_arcan
            log_file = "#{output_dir}/#{folder_name}.arcan.log"
            language = p['language']
            default_branch = p['project.branch']
            puts "Running Arcan on #{project_dir} (#{language}, #{default_branch})"
            call_arcan(folder_name, project_dir, output_dir, filters_dir, default_branch, language, log_file)
            
            complete_success = $?.success?
            if complete_success
                puts "Arcan successfully analysed #{folder_name}"
                `mv #{log_file} #{logs_dir_succ}/#{folder_name}.arcan.log`
                success << folder_name
            else
                puts "Arcan failed to analyse #{folder_name} (exit code: #{$?.exitstatus})"
                `rm -rf #{output_dir}/arcanOutput/#{folder_name}`
                `mv #{log_file} #{logs_dir_fail}/#{folder_name}.arcan.log`
                if $?.exitstatus != 255
                    partial_failure << folder_name
                end
                failed << folder_name
            end
        end
        if delete_repos
            puts "Deleting project's directory #{project_dir}"
            `rm -rf #{project_dir}`
        end
        puts "Progress: #{success.length + failed.length + already_analysed.length}/#{n_projects}"
    end
end

pool.shutdown
pool.wait_for_termination

puts "-------------------"
puts "Summary:" 
puts " - Successful: #{success.length}"
puts " - Failed: #{failed.length} (of which #{partial_failure.length} were partial)"
puts " - Already analysed: #{already_analysed.length}"
puts "-------------------"
puts "=> Analysed corpus: #{success.length + already_analysed.length}"
puts "=> Total projects: #{n_projects}"

File.open("#{logs_dir}/failed.log", "w+") do |f| 
    f.puts(failed)
end

File.open("#{logs_dir}/successful.log", "w+") do |f| 
    f.puts(success)
end

File.open("#{logs_dir}/partial.log", "w+") do |f| 
    f.puts(partial_failure)
end