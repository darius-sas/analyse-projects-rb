library(methods) # avoid silly warnings from Rscript
library(dplyr)

args <- commandArgs(TRUE)

if (length(args) < 2) {
  write("Usage: Rscript merge-results.r <projects-dir> <output-dir> [--components] [--smells] [--affected] [--sizes]", stdout())
  quit()
}

merge.results <- function(dir, pattern){
  projectDirs <- list.files(dir, recursive = T, pattern = pattern)
  df <- data.frame()
  
  for (entry in projectDirs) {
    project <- strsplit(entry, "/")[[1]][1]
    df.pr <- read.table(paste(dir, entry, sep = "/"), header = T, sep = ",")
    df.pr$project <- project
    
    df <- rbind(df, df.pr)
  }
  df$project <- as.factor(df$project)
  df <- df %>% select(project, everything())
  return(df)
}

consecOnly = TRUE
components = FALSE
smells = FALSE
affected = FALSE
sizes = FALSE

if ("--components" %in% args) {
  components = TRUE
}

if ("--smells" %in% args) {
  smells = TRUE
}

if ("--affected" %in% args) {
  affected = TRUE
}

if ("--sizes" %in% args) {
  sizes = TRUE
}

results.dir <- args[1]
output.dir <- args[2]

# Create paths to output files
sc.dataset = file.path(output.dir, "smells.csv")
ps.dataset = file.path(output.dir, "projects.csv")
cc.dataset = file.path(output.dir, "components.csv")
af.dataset = file.path(output.dir, "affected.csv")

pattern = ".csv"

# Invoke merging and do postprocessing
if(smells){
  df <- merge.results(results.dir, paste("*smell-characteristics", pattern, sep=""))
  write.csv(df, file = sc.dataset, row.names = F)
}
if(sizes){
  df.projects <- merge.results(results.dir, paste("*project-sizes", pattern, sep=""))
  write.csv(df.projects, file = ps.dataset, row.names = F)
}
if(components){
  df.components <- merge.results(results.dir, paste("*component-metrics", pattern, sep = ""))
  write.csv(df.components, file = cc.dataset, row.names = F)
}
if(affected){
  df.affected <- merge.results(results.dir, paste("*affected-components", pattern, sep = ""))
  write.csv(df.affected, file = af.dataset, row.names = F)
}

