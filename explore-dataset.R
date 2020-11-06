library(ggplot2)
library(dplyr)

df <- read.csv("/home/fenn/data/atd-estimation/csv/components.csv")


df.loc <- df %>% 
  filter(componentType == "unit") %>%
  group_by(project) %>%
  summarise(LinesOfCode = sum(LinesOfCode), NumOfUnits = n())

df <- df %>% group_by(project) %>%
  mutate(group = cut(sum(LinesOfCode), 
                     include.lowest = T,
                     breaks = quantile(df.loc$LinesOfCode, seq(0, 1, 1/12)),
                     labels = c("tiny", "very-small", "small", "medium-small", "medium", 
                                "medium-large", "large", "very-large", "huge", "gigantic",
                                "immense", "gargantuan")))

df.loc.cut <- df.loc %>%
  mutate(group = cut(LinesOfCode, 
                     include.lowest = T,
                     breaks = quantile(df.loc$LinesOfCode, seq(0, 1, 1/12)),
                     labels = c("tiny", "very-small", "small", "medium-small", "medium", 
                                "medium-large", "large", "very-large", "huge", "gigantic",
                                "immense", "gargantuan")))

ggplot(df.loc.cut, aes(project, LinesOfCode, fill = group)) +
  geom_col(color = "black") + 
  facet_wrap(.~group, scales = "free") +
  theme(legend.position = "none", axis.text.x = element_text(angle = 45, hjust = 1))

ggplot(df.loc.cut, aes(LinesOfCode)) +
  geom_density(fill = "cyan", color = "black", alpha = 0.3) +
  xlim(0, 1e6)

ggplot(df.loc.cut, aes(project, LinesOfCode, fill = group, size = NumOfUnits)) +
  geom_point(alpha = 0.5) + 
  facet_wrap(.~group, scales = "free") +
  theme(legend.position = "none", axis.text.x = element_text(angle = 45, hjust = 1))

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

df.todDep = df %>% filter(componentType == "unit" & FanIn+FanOut > 0)
ggplot(df.todDep, aes(FanIn+FanOut, y = group, fill = group)) + 
  ggridges::geom_density_ridges(alpha = .5, color = "black") + 
  scale_x_log10(breaks = c(1:10, 10^2, 10^3))

ggplot(df.todDep, aes(FanIn+FanOut, fill = group)) + 
  geom_histogram() + 
  facet_wrap(~group, scales="free") +
  xlim(0,50)
  scale_x_log10(breaks = c(1:10, 10^2, 10^3))
