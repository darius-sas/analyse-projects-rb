
job_file = "/home/fenn/data/job-13355797.log"
failed = `cat #{job_file} | grep "Arcan failed"`.split("\n")
failed = failed.map {|s| s.delete_prefix "Arcan failed to analyse "}

logs = Dir["/home/fenn/data/logs/*"].each do |a|
    puts a
    next if Dir.exist? a
    name = a[a.rindex("/")+1, a.index(".") - a.rindex("/") - 1]
    `cp #{a} /home/fenn/data/logs/failed` if failed.include? name
end