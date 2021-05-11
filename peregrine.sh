#!/bin/bash
#SBATCH --job-name=run-arcan-astracker
#SBATCH --mail-type=END
#SBATCH --time=168:00:00
#SBATCH --mail-user=d.d.sas@rug.nl
#SBATCH --output=job-%j.log
#SBATCH --partition=regular
#SBATCH --nodes=1
#SBATCH --ntasks=28
#SBATCH --mem=64000

module restore trackas

export arcan_java=/home/p284098/jars/jdk-14/bin/java
export arcan_jar=/home/p284098/jars/Arcan2-cli-2.2.0-beta-jar-with-dependencies.jar

ruby main.rb ~/dataset/java-projects-mini.csv ~/data/repos ~/data/output ~/data/filters ~/data --runGit --runArcan --not-shallow