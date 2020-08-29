require 'daru'
require 'concurrent'


ARCAN_JAR = "/home/fenn/git/arcan-2/arcan-cli/target/Arcan2-cli-2.0.8-beta-jar-with-dependencies.jar"

def run_arcan(project_name, input_dir, output_dir, filters_dir, log_file)
    branch = "HEAD"
    filters_file = "#{filters_dir}/#{project_name}.yaml"
    filters_file = "#{filters_dir}/all-projects.yaml" unless File.exist? filters_file
    arcan_command = "java -jar #{ARCAN_JAR} analyse -p #{project_name} -i #{input_dir} -o #{output_dir} -l JAVA --branch #{branch} --filtersFile #{filters_file} --all -v"
    `echo "#{arcan_command}" > #{log_file}`
    return `#{arcan_command} 2>&1 >> #{log_file}`
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

thread_pool_size = [2, Concurrent.processor_count].max
pool = Concurrent::FixedThreadPool.new(thread_pool_size)
puts "Thread pool size: #{thread_pool_size}"

projects = Daru::DataFrame.from_csv(projects_file)
git_projects = projects.filter_rows { |r| r['link.git'] == "true" }

success = Concurrent::Array.new
failed = Concurrent::Array.new
already_analysed = Concurrent::Array.new

n_projects = git_projects.size
logs_dir = "#{output_dir}/logs"
logs_dir_fail = "#{logs_dir}/failed"
logs_dir_succ = "#{logs_dir}/success"
`mkdir -p #{logs_dir_succ}`
`mkdir -p #{logs_dir_fail}`

`rm #{logs_dir_fail}/*`

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

            run_arcan(folder_name, project_dir, output_dir, filters_dir, log_file)
            complete_success = $?.success?
            if complete_success
                puts "Arcan successfully analysed #{folder_name}"
                `mv #{log_file} #{logs_dir_succ}/#{folder_name}.arcan.log`
                success << folder_name
            else
                puts "Arcan failed to analyse #{folder_name}"
                `rm -rf #{output_dir}/arcanOutput/#{folder_name}`
                `mv #{log_file} #{logs_dir_fail}/#{folder_name}.arcan.log`
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
puts " - Failed: #{failed.length}"
puts " - Already analysed: #{already_analysed.length}"
puts "-------------------"
puts "=> Total:#{n_projects}"