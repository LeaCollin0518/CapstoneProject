setwd("~/Desktop/Columbia/Courses/Capstone/CapstoneProject/Data/grid_mapping/clean_models/")
library(dplyr)
library(purrr)
sw_initial <- read.csv("USA, Regression, Xception, z13+16.csv")
sw <- sw_initial %>% rename(x=longitude, y=latitude, pm25=Predicted) %>% select(x, y, pm25)
sw_time <- sw
sw_time$time <- 2010

years <- c(2011:2016)
for(year in years){
  sw_year <- sw
  sw_year$time <- year
  sw_time <- rbind(sw_time, sw_year)
}
sw_time <- sw_time %>% select(time, x, y, pm25)

write.csv(sw_time, "sw_2010_2016.csv")
