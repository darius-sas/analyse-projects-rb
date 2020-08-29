#!/bin/bash
#SBATCH --job-name=run-arcan-astracker
#SBATCH --mail-type=END
#SBATCH --time=5:00:00
#SBATCH --mail-user=d.d.sas@rug.nl
#SBATCH --output=job-%j.log
#SBATCH --partition=regular
#SBATCH --nodes=1
#SBATCH --ntasks=16
#SBATCH --mem=64000

module restore trackas
ruby main.rb ~/data/java-projects.csv ~/data/repos ~/data/output ~/data/filters