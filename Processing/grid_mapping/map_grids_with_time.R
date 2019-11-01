setwd("/Users/hammaadadam/Desktop/Columbia/Courses/Capstone/CapstoneProject/Processing/grid_mapping")
library(extracat)
library(tidyverse)
library(lubridate)

combine_data <- function(ref, other, big_res_lon, big_res_lat, file_name){
  
  # ref is the reference grid and must have 3 columns with names: time, x, y (in that order)
  # other is the model being mapped to the reference grid. Must have 4 columns with names: time, x, y, PM25 (in that order)
  # big_res_lon is the resolution in longitude of the model being mapped (i.e. other model). So for gmilly, this is 2.5, for GBD, 0.1
  # big_res_lon is the resolution in latitude of the model being mapped (i.e. other model). So for gmilly, this is 2, for GBD, 0.1
  
  long_range  <- range(ref$x)
  long_range[1]  <- long_range[1] - big_res_lon
  long_range[2]  <- long_range[2] + big_res_lon

  lat_range     <- range(ref$y)
  lat_range[1]  <- lat_range[1] - big_res_lat
  lat_range[2]  <- lat_range[2] + big_res_lat
  
  other <- other %>% filter(between(x, long_range[1], long_range[2]), 
                            between(y, lat_range[1], lat_range[2]))

  result <- matrix(NA, nrow(ref), 4)
  counter <- 1
  
  other_coords <- other %>% select(x, y) %>% unique()
  
  for(i in 1:nrow(other_coords)){
    ref_sub <- ref %>% select(time, x, y) %>% 
                filter(between(x, other_coords$x[i] - big_res_lon/2, other_coords$x[i] + big_res_lon/2),
                       between(y, other_coords$y[i] - big_res_lat/2, other_coords$y[i] + big_res_lat/2)) 
    other_sub <- other %>% filter(x==other_coords$x[i], y==other_coords$y[i]) %>% select(time, PM25)
    ref_sub <- ref_sub %>% left_join(other_sub, c("time"="time"))
    
    if(nrow(ref_sub)>0){
      result[counter:(counter - 1 + nrow(ref_sub)),] <- as.matrix(ref_sub)
      counter <- counter + nrow(ref_sub)
    }
  }
  
  result <- data.frame(result)
  names(result) <- c("time", "lon", "lat", "pm25")
  result <- result %>% filter(!is.na(lon))
  result <- result %>% select(time, lat, lon, pm25) %>% data.frame()
  
  write.csv(result, file_name)
}

#### Example

# Use Dalhousie as the reference grid. Put into the right structure for the combine_data function
dal <- read.csv("../../Data/grid_mapping/clean_models/dh_ca_annual_2010.csv")
dal$time <- 2010
dal <- dal %>% select(time, x, y)

# Use GM as the other model. Put into the right form
gmilly <- na.omit(readRDS("../../Data/grid_mapping/clean_models/gmilly.rds"))
gmilly$time <- year(gmilly$date)
gmilly <- gmilly %>% group_by(time, x, y) %>% 
            summarise(PM25 = mean(PM25)) %>% data.frame()

combine_data(dal, gmilly, 2.5, 2, "GM_align_fake.csv")