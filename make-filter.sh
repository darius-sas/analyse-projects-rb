#!/bin/bash

arcan(){
    java -jar /home/fenn/git/arcan-2/arcan-cli/target/Arcan2-cli-2.0.8-beta-jar-with-dependencies.jar $@
}

project=$1
arcan generate filter filters/${project}.yaml && nano filters/${project}.yaml
arcan analyse -p ${project} -i /home/fenn/data/atd-estimation/repos/${project} -o /home/fenn/data/atd-estimation -l JAVA --all --filtersFile filters/${project}.yaml --fail

# analyse(){arcan analyse -p $1 -i /home/fenn/data/atd-estimation/repos/$1 -o /home/fenn/data/atd-estimation --all --fail -v -l JAVA --filtersFile filters/$1.yaml}