library(tidyverse)
library(lubridate)
observed_all <- readRDS("../Data/pm25_observed_2000_2016.rds")

years <- c(2010:2016)
for(year in years){
  observed <- observed_all %>% filter(year(Date)==year)
  
  observed$interval <- NA
  observed <- observed %>% arrange(uid, Date)
  
  for(i in 2:nrow(observed)){
    if(i%%10000==0){
      print(i)
    }
    if(observed$uid[i-1]==observed$uid[i]){
      observed$interval[i] <- observed$Date[i]-observed$Date[i-1]
    }
  }
  
  intervals <- observed %>% group_by(uid) %>% summarise(interval = median(interval, na.rm=TRUE), 
                                                        observations = n()) %>%
    mutate(presence = observations / floor(365/interval))
  
  monitors_include <- intervals$uid[intervals$presence>0.75]
  observed <- observed %>% filter(uid %in% monitors_include)
  observed <- observed %>% group_by(Longitude, Latitude) %>% summarise(pm25_obs = mean(pm25_obs))
  observed <- observed %>% rename(x=Longitude, y=Latitude) %>% data.frame()
  observed$time <- year
  observed <- observed %>% select(time, x, y, pm25_obs) %>% data.frame()
  filename <- paste0("../Data/filtered_monitors/pm25_observed_", year, ".csv")
  write.csv(observed, filename, row.names = FALSE)
}