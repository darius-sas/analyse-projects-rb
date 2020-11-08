#!/bin/bash

arcan(){
    java -jar /home/fenn/git/arcan-2/arcan-cli/target/Arcan2-cli-2.0.9-beta-jar-with-dependencies.jar $@
}

project=$1
find /home/fenn/data/atd-estimation/cpp-repos/${project} -type f -name "Makefile" -print -exec grep -o -e "-I.*" {} \;
read -p "Press enter to continue " var
arcan generate includes cpp-includes/${project}.yaml && nano cpp-includes/${project}.yaml
exit
arcan analyse -p ${project} -i /home/fenn/data/atd-estimation/repos/${project} -o /home/fenn/data/atd-estimation -l CPP --all --filtersFile cpp-filters/cpp-project-filter.yaml --fail

# analyse(){arcan analyse -p $1 -i /home/fenn/data/atd-estimation/repos/$1 -o /home/fenn/data/atd-estimation --all --fail -v -l JAVA --includePaths cpp-includes/$1.yaml --filtersFile cpp-filters/cpp-project-filter.yaml}
