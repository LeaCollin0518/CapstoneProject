setwd("/Users/hammaadadam/Desktop/Columbia/Courses/Capstone/CapstoneProject/Data/")
library(tidyverse)
library(lubridate)
library(extracat)

years <- 2000:2016

data_all <- readRDS(paste0("combined/epa_improve_",years[1],".rds"))
for(year in years[2:length(years)]){
  year_data <- readRDS(paste0("combined/epa_improve_",year,".rds"))
  data_all <- rbind(data_all, year_data)
}

nrow(data_all)==nrow(data_all %>% select(uid, Date) %>% unique())
saveRDS(data_all, file="pm25_observed_2000_2016.rds")
