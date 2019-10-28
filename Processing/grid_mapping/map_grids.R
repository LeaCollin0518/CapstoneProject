setwd("Desktop/Columbia/Courses/Capstone/CapstoneProject/Data/grid_mapping/")
library(extracat)
library(tidyverse)

combine_data <- function(ref, other, big_res_lon, big_res_lat, other_name){
  lat_range     <- range(ref$y)
  lat_range[1]  <- lat_range[1] - big_res_lat
  lat_range[2]  <- lat_range[2] + big_res_lat
  
  long_range  <- range(ref$x)
  long_range[1]  <- long_range[1] - big_res_lon
  long_range[2]  <- long_range[2] + big_res_lon
  
  other <- other %>% filter(between(x, long_range[1], long_range[2]), 
                            between(y, lat_range[1], lat_range[2]))
  
  result <- matrix(NA, nrow(ref), 3)
  counter <- 1
  
  for(i in 1:nrow(other)){
    ref_sub <- ref %>% select(x,y) %>% 
                   filter(between(x, other$x[i] - big_res_lon/2, other$x[i] + big_res_lon/2),
                          between(y, other$y[i] - big_res_lat/2, other$y[i] + big_res_lat/2)) %>% 
                      mutate(other = other$PM25[i])
    if(nrow(ref_sub)>0){
      result[counter:(counter - 1 + nrow(ref_sub)),] <- as.matrix(ref_sub)
      counter <- counter + nrow(ref_sub)
    }
  }
  
  result <- data.frame(result)
  names(result) <- c("x", "y", "other")
  result <- result %>% filter(!is.na(x))
  combined <- ref %>% left_join(result)
  
  names(combined) <- c(names(ref), paste0(other_name, "_pm25"))
  return(combined)
}

dal <- read.csv("clean_models/dh_ca_annual_2010.csv")
gbd <- read.csv("clean_models/gbd_2010.csv")
gbd <- gbd %>% select(-X)
names(gbd) <- names(dal)
combine <- combine_data(dal, gbd, 0.1, 0.1, "gbd")

gmilly <- readRDS("clean_models/gmilly.rds")
gmilly$year <- year(gmilly$date)
gmilly <- gmilly %>% filter(year==2010)
gmilly <- gmilly %>% group_by(lat, lon) %>% 
            summarise(pm25 = mean(pm25))
gmilly <- gmilly %>% select(lon, lat, pm25) %>% rename(x=lon, y=lat) %>% data.frame()
gmilly$x <- gmilly$x - 360
names(gmilly) <- names(dal)

combine <- combine_data(combine, gmilly, 2.5, 2, "gmilly")

# library(censusr)
# dal_tracts <- append_geoid(dal %>% select(x,y) %>% rename(lat=y, lon=x), 'tr')

saveRDS(combine, "predictions_annual_2010.rds")
 
