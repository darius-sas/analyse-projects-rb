#!/bin/bash
#SBATCH --job-name=run-arcan-astracker
#SBATCH --mail-type=END
#SBATCH --time=20:00:00
#SBATCH --mail-user=d.d.sas@rug.nl
#SBATCH --output=job-%j.log
#SBATCH --partition=regular
#SBATCH --nodes=1
#SBATCH --ntasks=8
#SBATCH --mem=32000

module restore trackas
ruby main.rb ~/data/java-projects.csv ~/data/repos ~/data/output