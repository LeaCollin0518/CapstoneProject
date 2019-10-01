setwd("/Users/hammaadadam/Desktop/Columbia/Courses/Capstone/CapstoneProject/Data/")
library(tidyverse)
library(lubridate)
library(extracat)


years <- c(2000:2001)

filename <- paste0("epa_data/Deduped/epa_deduped_",year, ".rds")
epa_combined <- readRDS(filename)
for(year in years[2:length(years)]){
  filename <- paste0("epa_data/Deduped/epa_deduped_",year, ".rds")
  epa_year <- readRDS(filename)
  epa_combined <- 
}
  
