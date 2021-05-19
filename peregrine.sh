#!/bin/bash
#SBATCH --job-name=mega-dataset
#SBATCH --mail-type=END
#SBATCH --time=5-00:00:00
#SBATCH --mail-user=d.d.sas@rug.nl
#SBATCH --output=job-%j.log
#SBATCH --partition=regular
#SBATCH --nodes=1
#SBATCH --ntasks=15
#SBATCH --mem=128000

module restore trackas

export arcan_java=/home/p284098/jars/jdk-14/bin/java
export arcan_jar=/home/p284098/jars/Arcan2-cli-2.2.0-beta-jar-with-dependencies.jar
export arcan_mem=8G

ruby main.rb ./dataset/java-projects.csv ~/data/repos ~/data/jseip ./java-filters ~/data/jseip --runGit --runArcan --not-shallow --disable-csv-output
