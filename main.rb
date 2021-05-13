#!/bin/ruby

require 'daru'
require 'concurrent'

JAVA = ENV["arcan_java"].nil? ? "java" : ENV["arcan_java"]
ARCAN_JAR = ENV["arcan_jar"] # Change the value of this variable to the path to your jar, or set the env variable "arcan_jar" in your shell using export
ARCAN_MEM = ENV["arcan_mem"].nil? ? "3G" : ENV["arcan_mem"]


def run_arcan_CPP(project_name, input_dir, output_dir, filters_dir, includes_dir, log_file, disable_csv_output = false)
    branch = "HEAD"
    filters_file = "#{filters_dir}/#{project_name}.yaml"
    filters_file = "#{filters_dir}/all-projects.yaml" unless File.exist? filters_file
    arcan_command = "#{JAVA} -Xmx#{ARCAN_MEM} -jar #{ARCAN_JAR} analyse -p #{project_name} -i #{input_dir} -o #{output_dir} -l CPP --branch #{branch} --filtersFile #{filters_file} --auxiliaryPaths #{includes_dir} --all -v output.dependencyGraph=true"
    `echo "#{arcan_command}" > #{log_file}`
    return `#{arcan_command} 2>&1 >> #{log_file}`
end

def run_arcan_JAVA(project_name, input_dir, output_dir, filters_dir, branch, log_file, disable_csv_output = false)
    metrics = "AffectedClassesRatio,AffectedComponentType,AfferentAffectedRatio,CentreComponent,Shape,EfferentAffectedRatio,InstabilityGap,LOCDensity,NumberOfEdges,Size,PageRankWeighted,Strength,Support,TotalNumberOfChanges"
    metrics = "all"
    filters_file = "#{filters_dir}/#{project_name}.yaml"
    filters_file = "#{filters_dir}/all-projects.yaml" unless File.exist? filters_file
    #arcan_command = "java -jar #{ARCAN_JAR} analyse -p #{project_name} -i #{input_dir} -o #{output_dir} -l JAVA --branch #{branch} --filtersFile #{filters_file} --all -v output.dependencyGraph=true metrics.smells=#{metrics}"
    disable_csv_output_str = "output.metrics=false output.membership=false output.characteristics=false output.affected=false" if disable_csv_output
    arcan_command = "#{JAVA} -Xmx#{ARCAN_MEM} -jar #{ARCAN_JAR} analyse -p #{project_name} -i #{input_dir} -o #{output_dir} -l JAVA --branch #{branch} --filtersFile #{filters_file} --all -v output.dependencyGraph=true metrics.smells=#{metrics} -e --startDate 1-1-1 --endDate 2021-12-12 --intervalDays 0 #{disable_csv_output}"
    `echo "#{arcan_command}" > #{log_file}`
    return `#{arcan_command} 2>&1 >> #{log_file}`
end

def git_clone(link, project_dir, log_file, shallow)
    shallow_str = "--depth 1" if shallow
    shallow_str = "" unless shallow
    return `git clone --progress #{shallow_str} #{link} #{project_dir} 2> #{log_file}`
end

if ARGV.length <= 5
    puts "Usage <projects-file> <repos-dir> <output-dir> <filters-dir> <includes-dir> [--runArcan] [--runGit] [--not-shallow] [--CPP] [--disable-csv-output]"
    exit 0
else
    projects_file = ARGV[0]
    projects_dir = ARGV[1]
    output_dir = ARGV[2]
    filters_dir = ARGV[3]
    includes_dir = ARGV[4]
    run_arcan = ARGV.include? "--runArcan";
    run_git = ARGV.include? "--runGit";
    is_cpp = ARGV.include? "--CPP";
    shallow = !ARGV.include?("--not-shallow");
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
        else
            puts "Git repo already cloned #{project_dir}"
        end
        
        if Dir.exists? project_dir and Dir["#{output_dir}/arcanOutput/#{folder_name}"].empty? and run_arcan
            puts "Running Arcan on #{project_dir}"
            log_file = "#{output_dir}/#{folder_name}.arcan.log"

            default_branch = `git branch -vv | grep -Po "^[\s\*]*\K[^\s]*(?=.*$(git branch -r | grep -Po "HEAD -> \K.*$").*)"`
            default_branch.strip!
            default_branch = "master" if default_branch.empty?
            if is_cpp
                run_arcan_CPP(folder_name, project_dir, output_dir, filters_dir, includes_dir, log_file)           
            else
                run_arcan_JAVA(folder_name, project_dir, output_dir, filters_dir, default_branch, log_file, disable_csv_output)
            end

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
        else
            puts "Project #{folder_name} was already analysed"
            already_analysed << folder_name
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
    f.puts(partial)
end