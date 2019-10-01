setwd("/Users/hammaadadam/Desktop/Columbia/Courses/Capstone/CapstoneProject/Data/")
library(tidyverse)
library(lubridate)
library(extracat)

# Read in Improve and clean
improve <- readRDS("improve_data/improve_clean.rds")

# Combine one year
years <- 2000:2016
for(year in years){
  epa_year <- readRDS(paste0("epa_data/Deduped/epa_deduped_", year, ".rds"))
  improve_year <- improve %>% filter(year(Date) == year)
  
  epa_year_data <- epa_year %>% select(uid, Date, pm25_obs)
  improve_year_data <- improve_year %>% select(uid, Date, pm25_obs)
  combined_data <- epa_year_data %>% full_join(improve_year_data, 
                                               c("uid"="uid", "Date"="Date"), 
                                               suffix = c("_epa", "_improve"))
  
  combined_data$source <- ""
  combined_data$source[!is.na(combined_data$pm25_obs_epa) & !is.na(combined_data$pm25_obs_improve)] <- "Both"
  combined_data$source[!is.na(combined_data$pm25_obs_epa) & is.na(combined_data$pm25_obs_improve)] <- "EPA"
  combined_data$source[is.na(combined_data$pm25_obs_epa) & !is.na(combined_data$pm25_obs_improve)] <- "Improve"
  
  
  combined_data <- combined_data %>% mutate(pm25_obs = rowMeans(combined_data[,3:4], na.rm = TRUE))
  combined_data <- combined_data %>% select(Date, uid, source, pm25_obs)
  
  epa_info <- epa_year %>% select(uid, Latitude, Longitude, State.Code, County.Code) %>% unique() %>% mutate(source="EPA")
  improve_info <- improve_year %>% select(uid, Latitude, Longitude, CountyFIPS) %>% 
    mutate(State.Code = substr(CountyFIPS, 1, 2), County.Code = substr(CountyFIPS, 3, 5)) %>% 
    select(-CountyFIPS) %>% unique() %>% mutate(source="Improve")
  
  
  combined_info <- rbind(epa_info, improve_info)
  combined_info <- combined_info %>% arrange(uid, source) 
  combined_info <- combined_info %>% distinct(uid, .keep_all = TRUE) %>% select(-source)
  
  combined_year <- combined_data %>% left_join(combined_info, c("uid"="uid"))
  if(!(nrow(combined_year %>% select(uid, Date) %>% unique())==nrow(combined_year))){
    print("Not unique")
  }
  
  combined_year <- combined_year %>% arrange(uid, Date)
  
  savefile = paste0("combined/epa_improve_", year, ".rds")
  saveRDS(combined_year, file=savefile)
}

     