library(ggplot2)
library(dplyr)

df <- read.csv("/home/fenn/data/atd-estimation/csv/components.csv")


df.loc <- df %>% group_by(project) %>%
  summarise(LinesOfCode = sum(LinesOfCode))

df <- df %>% group_by(project) %>%
  mutate(group = cut(sum(LinesOfCode), 
                     include.lowest = T,
                     breaks = quantile(df.loc$LinesOfCode, seq(0, 1, 1/12)),
                     labels = c("tiny", "very-small", "small", "medium-small", "medium", 
                                "medium-large", "large", "very-large", "huge", "gigantic",
                                "immense", "gargantuan")))

ggplot(df, aes(project, LinesOfCode, color = project)) + 
  geom_boxplot() + 
  theme(legend.position = "none", axis.text.x = element_text(angle = 45, hjust = 1)) + 
  facet_wrap(.~group, scales = "free") +
  labs(x = "", y = "Lines of Code (LOC)", title = "Projects' LOC distribution grouped by project size (sum of LOC)")

df.artefacts <- df %>% group_by(project, group, componentType) %>% tally()

ggplot(df.artefacts, aes(project, n, fill = componentType)) + 
  geom_col() + 
  facet_wrap(~group, scales="free") +
  theme(legend.position = "none", axis.text.x = element_text(angle = 45, hjust = 1)) + 
  labs(x = "", y = "Lines of Code (LOC)", title = "Projects' LOC distribution grouped by project size (sum of LOC)")
