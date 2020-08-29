#!/bin/bash

arcan(){
    java -jar /home/fenn/git/arcan-2/arcan-cli/target/Arcan2-cli-2.0.8-beta-jar-with-dependencies.jar $@
}

project=$1
arcan generate filter filters/${project}.yaml && nano filters/${project}.yaml
arcan analyse -p ${project} -i repos/${project} -o . -l JAVA --all --filtersFile filters/${project}.yaml --fail
