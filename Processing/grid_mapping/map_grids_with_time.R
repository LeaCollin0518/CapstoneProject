# setwd("/Users/hammaadadam/Desktop/Columbia/Courses/Capstone/CapstoneProject/Processing/grid_mapping")
#setwd("C:/Users/leac7/Documents/Columbia/Capstone/CapstoneProject")
.libPaths(c("/rigel/dsi/users/lc3362/rpackages/", .libPaths()))
setwd("/rigel/dsi/projects/bne/")

#library(extracat)
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
    print (i)
    ref_sub <- ref %>% select(time, x, y) %>% 
                filter(between(x, other_coords$x[i] - big_res_lon/2, other_coords$x[i] + big_res_lon/2),
                       between(y, other_coords$y[i] - big_res_lat/2, other_coords$y[i] + big_res_lat/2)) 
    other_sub <- other %>% filter(x==other_coords$x[i], y==other_coords$y[i]) %>% select(time, pm25)
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
years <- seq(2010, 2016)

args <- commandArgs(trailingOnly = TRUE)
index <- as.numeric(args[1])
curr_year <- years[index]

dal_name <- 'Data/nationwide/AV_'
dal_name <- paste0(dal_name, curr_year)
dal_name <- paste0(dal_name, '_align.csv')

print (dal_name)


# Use Dalhousie as the reference grid. Put into the right structure for the combine_data function
dal <- read.csv(dal_name)
names(dal) <- c('x', 'y', 'pm25')
dal$time <- curr_year
dal <- dal %>% select(time, x, y)
print (nrow(dal))

# Map GBD
gbd <- read.csv('Data/GBD/gbd_2000_2016.csv')
gbd$X <- NULL
names(gbd) <- c('x', 'y', 'pm25', 'time')
gbd_year <- gbd %>% filter(time == curr_year)
gbd_year <- gbd_year %>% group_by(time, x, y) %>% summarise(pm25 = mean(pm25)) %>% data.frame()

new_file <- 'Data/nationwide/GBD_'
new_file <- paste0(new_file, curr_year)
new_file <- paste0(new_file, '_align.csv')
print (new_file)

start_time <- Sys.time()
combine_data(dal, gbd_year, 0.1, 0.1, new_file)
end_time <- Sys.time()

print (end_time - start_time)