setwd("/Users/hammaadadam/Desktop/Columbia/Courses/Capstone/CapstoneProject/Data/")
library(tidyverse)
library(lubridate)
library(extracat)

years <- c(2000:2016)

for(year in years){
  filename <- paste0("epa_data/daily_88101_",year, ".csv")
  epa <- read.csv(filename, stringsAsFactors = FALSE)
  epa <- read.csv(filename, colClasses = rep("character", ncol(epa)))
  
  epa_clean <- epa %>% select(State.Code, County.Code, Site.Num, POC, 
                              Latitude, Longitude, Date.Local, Sample.Duration, Observation.Count, 
                              Observation.Percent, Arithmetic.Mean, Event.Type)
  
  epa_clean$uid <- paste(epa_clean$State.Code, epa_clean$County.Code, epa_clean$Site.Num, sep="")
  epa_clean$POC <- as.numeric(epa_clean$POC)
  epa_clean$Latitude <- as.numeric(epa_clean$Latitude)
  epa_clean$Longitude <- as.numeric(epa_clean$Longitude)
  epa_clean$Date.Local <- as.Date(epa_clean$Date.Local, "%Y-%m-%d")
  epa_clean$Observation.Count <- as.numeric(epa_clean$Observation.Count)
  epa_clean$Observation.Percent <- as.numeric(epa_clean$Observation.Percent)
  epa_clean$Arithmetic.Mean <- as.numeric(epa_clean$Arithmetic.Mean)
  
  epa <- epa_clean
  
  epa_clean <- epa_clean %>% filter(POC==1)
  epa_clean <- epa_clean %>% filter(Sample.Duration %in% c("24 HOUR", "1 HOUR"))
  
  # Remove measurements that don't meet time treshold
  dq_treshold <- 0.75
  epa_clean <- epa_clean %>% filter(Sample.Duration=="24 HOUR" | Observation.Count >= dq_treshold*24)
  epa_deduped <- epa_clean %>% select(uid, State.Code, County.Code, Site.Num, POC, Latitude, Longitude, Date.Local) %>% unique()
  
  # Dedupe event type
  epa_event_dd <- epa_clean %>% select(uid, Date.Local, Sample.Duration, Event.Type, Arithmetic.Mean) %>% 
    spread(key = Event.Type, value = Arithmetic.Mean)
  
  epa_event_dd$Arithmetic.Mean <- NA
  epa_event_dd$Arithmetic.Mean[!is.na(epa_event_dd$None)] <- epa_event_dd$None[!is.na(epa_event_dd$None)]
  epa_event_dd$Arithmetic.Mean[is.na(epa_event_dd$Arithmetic.Mean)] <- epa_event_dd$Included[is.na(epa_event_dd$Arithmetic.Mean)]
  epa_event_dd <- epa_event_dd %>% select(uid, Date.Local, Sample.Duration, Arithmetic.Mean)
  
  epa_deduped <- epa_deduped %>% inner_join(epa_event_dd)
  epa_deduped$source <- "EPA"
  if(!(nrow(epa_deduped)==nrow(epa_deduped %>% select(uid, Date.Local) %>% unique()))){
    print("Not Deduped")
  }
  epa_deduped <- epa_deduped %>% rename(Date = Date.Local, pm25_obs = Arithmetic.Mean) %>% data.frame()
  save_filename = paste0("epa_data/Deduped/epa_deduped_", year, ".rds")
  saveRDS(epa_deduped, save_filename)
}