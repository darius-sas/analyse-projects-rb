library(methods) # avoid silly warnings from Rscript
library(dplyr)

args <- commandArgs(TRUE)

if (length(args) < 2) {
  write("Usage: Rscript merge-results.r <projects-dir> <output-dir> [--components] [--smells] [--affected] [--sizes] [--entity]", stdout())
  quit()
}

merge.results <- function(dir, pattern){
  projectDirs <- list.files(dir, recursive = T, pattern = pattern)
  df <- data.frame()
  for (entry in projectDirs) {
    print(paste0("Reading ", entry))
    df.pr <- read.table(paste(dir, entry, sep = "/"), header = T, sep = ",")
    df <- rbind(df, df.pr)
  }
  return(df)
}

file.remove0<-function(file) {
  if (file.exists(file)) {
    file.remove(file)
  }
}

components = FALSE
smells = FALSE
affected = FALSE
sizes = FALSE
entity = FALSE

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

if ("--entity" %in% args) {
  entity = TRUE
}

results.dir <- args[1]
output.dir <- args[2]

# Create paths to output files
sc.dataset = file.path(output.dir, "smell-characteristics.csv")
ps.dataset = file.path(output.dir, "projects.csv")
cc.dataset = file.path(output.dir, "component-metrics.csv")
af.dataset = file.path(output.dir, "smell-affects.csv")
en.dataset = file.path(output.dir, "entity-tracking.csv")

# Invoke merging
if(smells){
  file.remove0(sc.dataset)
  df <- merge.results(results.dir, "*smell-characteristics.csv")
  write.csv(df, file = sc.dataset, row.names = F)
}
if(sizes){
  file.remove0(ps.dataset)
  df.projects <- merge.results(results.dir, "*project-sizes.csv")
  write.csv(df.projects, file = ps.dataset, row.names = F)
}
if(components){
  file.remove0(cc.dataset)
  df.components <- merge.results(results.dir, "*component-metrics.csv")
  write.csv(df.components, file = cc.dataset, row.names = F)
}
if(affected){
  file.remove0(af.dataset)
  df.affected <- merge.results(results.dir, "*smell-affects.csv")
  write.csv(df.affected, file = af.dataset, row.names = F)
}
if(entity){
  file.remove0(en.dataset)
  df.entity <- merge.results(results.dir, "*entity-tracking.csv")
  write.csv(df.entity, file = en.dataset, row.names = F)
}

