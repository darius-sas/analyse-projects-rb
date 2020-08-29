require 'daru'
require 'concurrent'


ARCAN_JAR = "/home/p284098/jars/Arcan2-cli-2.0.8-beta-jar-with-dependencies.jar"

def run_arcan(project_name, input_dir, output_dir, filters_dir, log_file)
    branch = "HEAD"
    filters_file = "#{filters_dir}/#{project_name}.yaml"
    filters_file = "#{filters_dir}/all-projects.yaml" unless File.exist? filters_file
    arcan_command = "java -jar #{ARCAN_JAR} analyse -p #{project_name} -i #{input_dir} -o #{output_dir} -l JAVA --branch #{branch} --filtersFile #{filters_file} --all -v"
    `echo "#{arcan_command}" > #{log_file}`
    return `#{arcan_command} &>> #{log_file}`
end

def git_clone(link, project_dir, log_file)
    return `git clone --progress --depth 1 #{link} #{project_dir} 2> #{log_file}`
end

if ARGV.length != 4
    puts "Usage <projects-file> <repos-dir> <output-dir> <filters-dir>"
    exit 0
else
    projects_file = ARGV[0]
    projects_dir = ARGV[1]
    output_dir = ARGV[2]
    filters_dir = ARGV[3]
end

pool = Concurrent::FixedThreadPool.new([2, Concurrent.processor_count].max)
puts "Thread pool size: #{pool.length}"
projects = Daru::DataFrame.from_csv(projects_file)
git_projects = projects.filter_rows { |r| r['link.git'] == "true" }

success = Concurrent::Array.new
failed = Concurrent::Array.new
n_projects = git_projects.length

git_projects.each_row do |p|
    puts "Queuing for analysis project '#{p['project.name']}'"
    pool.post do 
        link = p['project.link']
        folder_name = link.chomp("/")[/[\w\d\-\.]+$/]
        project_dir = "#{projects_dir}/#{folder_name}"

        if not Dir.exist? project_dir
            puts "Cloning #{link}"
            log_file = "#{output_dir}/#{folder_name}.git.log"
            git_clone(link, project_dir, log_file)
            puts "Git successfully cloned #{link}" if $?.success?
            puts "Git failed to clone #{link}" if not $?.success?
        else
            puts "Git repo already cloned #{project_dir}"
        end
        
        if Dir.exists? project_dir and Dir["#{output_dir}/arcanOutput/#{folder_name}"].empty?
            puts "Running Arcan on #{project_dir}"
            log_file = "#{output_dir}/#{folder_name}.arcan.log"
            #branch = p['project.branch']
            run_arcan(folder_name, project_dir, output_dir, filters_dir, log_file)

            if $?.success?
                puts "Arcan successfully analysed #{folder_name}"
                `mv #{log_file} #{output_dir}/success/#{folder_name}.arcan.log`
                success << folder_name
            else
                puts "Arcan failed to analyse #{folder_name}"
                `rm -rf #{output_dir}/arcanOutput/#{folder_name}`
                `mv #{log_file} #{output_dir}/failed/#{folder_name}.arcan.log`
                failed << folder_name
            end
        else
            puts "Project #{folder_name} was already analysed"
        end
        puts "Progress: #{success.length + failed.length}/#{n_projects}"
    end
end

pool.shutdown
pool.wait_for_termination


puts "Summary: \nSuccessful: #{success.length}\nFailed: #{failed.length}\nTotal:#{n_projects}"