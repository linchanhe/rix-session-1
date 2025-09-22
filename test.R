library(dplyr)

iris %>%
  group_by(Species) %>%
  summarise(mean_sepal_length = mean(Sepal.Length))
add new file
