setwd("/Users/hammaadadam/Desktop/Columbia/Courses/Capstone/CapstoneProject/Processing/grid_mapping")
library(extracat)
library(tidyverse)
library(lubridate)

pred_obs_map <- function(obs, pred, res_lon, res_lat, file_name){
  
  # obs is the observed data and must have 4 columns with names: time, x, y, pm25_obs 
  # other is the model being mapped to the reference grid. Must have columns time, x, and y, plus each model's predictions
  # res_lon is the resolution in longitude of the reference grid (i.e. 0.01)
  # res_lat is the resolution in latitude of the reference grid (i.e. 0.01)
  
  obs <- observed
  pred <- predictions
  res_lon <- 0.01
  res_lat <- 0.01
  
  long_range  <- range(pred$x)
  long_range[1]  <- long_range[1] - res_lon
  long_range[2]  <- long_range[2] + res_lon
  
  lat_range     <- range(pred$y)
  lat_range[1]  <- lat_range[1] - res_lat
  lat_range[2]  <- lat_range[2] + res_lat
  
  obs <- obs %>% filter(between(x, long_range[1], long_range[2]), 
                              between(y, lat_range[1], lat_range[2]))
  
  result <- as.data.frame(matrix(NA, nrow(obs), ncol(pred)+1))
  names(result) <- c(names(obs)[1:4], names(pred[4:ncol(pred)]))
  
  obs_coords <- obs %>% select(x, y) %>% unique() %>% na.omit()
  counter <- 1
  
  for(i in 1:nrow(obs_coords)){
    pred_sub <- pred %>% filter(between(x, obs_coords$x[i] - res_lon/2, obs_coords$x[i] + res_lon/2),
                                between(y, obs_coords$y[i] - res_lat/2, obs_coords$y[i] + res_lat/2))
    if(nrow(pred_sub)!=1){
      print(paste0('Check Row ', i))
    }
    obs_sub <- obs %>% filter(x==obs_coords$x[i], y==obs_coords$y[i])
    obs_sub <- obs_sub %>% left_join(pred_sub %>% select(-x, -y), c("time")) 
    
    if(nrow(obs_sub > 0)){
      result[(counter:(counter+nrow(obs_sub)-1)), ] <- obs_sub
      counter <- counter + nrow(obs_sub)
    }
  }
  result <- result %>% arrange(time, x, y) %>% rename(lon=x, lat=y) %>% data.frame()
  write.csv(result, file_name)
}

#### Example

years=c(2010)
observed <- readRDS("../../Data/pm25_observed_2000_2016.rds")
observed <- observed %>% filter(year(Date) %in% years)
# TODO: Remove all monitors for which we don't have at least 75% of observations
observed$time <- year(observed$Date)
observed <- observed %>% group_by(time, Longitude, Latitude) %>% summarise(pm25_obs = mean(pm25_obs))
observed <- observed %>% rename(x=Longitude, y=Latitude) %>% data.frame()

# TODO: will need to generate prediction file from individually mapped predictions
predictions <- readRDS("../../Data/grid_mapping/predictions_annual_2010.rds")
predictions$time <- 2010 # Ideally, the prediction file itself will have a date, but in this case, mine didn't
predictions <- predictions %>% select(6,1:5) # Reordering columns for function
names_pred <- c("time", "x", "y", "pred_AV", "pred_GS", "pred_GM")
names(predictions) <- names_pred

pred_obs_map(observed, predictions, 0.01, 0.01, "test_monitor_map.csv")
