setwd("/Users/hammaadadam/Desktop/Columbia/Courses/Capstone/CapstoneProject/Data/")
library(tidyverse)
library(lubridate)
library(extracat)

# Read in Improve and clean
improve <- read.delim("improve_data/improve_all.txt", sep = ",", header = TRUE, stringsAsFactors = FALSE)
improve <- read.delim("improve_data/improve_all.txt", sep = ",", header = TRUE, 
                      colClasses = rep("character", ncol(improve)), na.strings = c("-999", "NA"))
improve$POC <- as.numeric(improve$POC)
improve$Date <- as.Date(improve$Date, "%Y/%m/%d") 
improve$Latitude <- as.numeric(improve$Latitude)
improve$Longitude <- as.numeric(improve$Longitude)
improve$MF.Value <- as.numeric(improve$MF.Value)
improve_clean <- improve %>% filter(POC == 1) %>% 
                  filter(Date > ymd("1999-12-31"), Date < ymd("2017-01-01")) %>% 
                    rename(pm25_obs = MF.Value) %>% 
                      filter(!is.na(pm25_obs))

if(!(nrow(improve_clean %>% select(SiteCode, Date) %>% unique())==nrow(improve_clean))){
  print("Error: Not duduped")
}

site_identify <- (improve_clean %>% group_by(EPACode) %>%
                    summarise(n=n_distinct(SiteCode)) %>% filter(n > 1, !is.na(EPACode)))$EPACode

improve_clean$uid <- improve_clean$EPACode
improve_clean$uid[is.na(improve_clean$EPACode)] <- improve_clean$SiteCode[is.na(improve_clean$EPACode)]
improve_clean$uid[improve_clean$EPACode %in% site_identify] <- improve_clean$SiteCode[improve_clean$EPACode %in% site_identify]

saveRDS(improve_clean, file="improve_data/improve_clean.rds")
