library(tidyverse)
library(lubridate)
year=2010
observed <- readRDS("../pm25_observed_2000_2016.rds")
observed <- observed %>% filter(year(Date)==year)
 
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

predictions <- readRDS(paste0("predictions_annual_", year, ".rds"))

pred_obs_map <- function(obs, pred, res_lon, res_lat){
  
  long_range  <- range(pred$x)
  long_range[1]  <- long_range[1] - res_lon
  long_range[2]  <- long_range[2] + res_lon
  
  lat_range     <- range(pred$y)
  lat_range[1]  <- lat_range[1] - res_lat
  lat_range[2]  <- lat_range[2] + res_lat
  
  obs <- obs %>% filter(between(x, long_range[1], long_range[2]), 
                              between(y, lat_range[1], lat_range[2]))
  
  result <- as.data.frame(matrix(NA, nrow(obs), ncol(pred)))
  names(result) <- c("x", "y", names(pred[,-c(1:2)]))
  result$x <- obs$x
  result$y <- obs$y
  
  for(i in 1:nrow(obs)){
    pred_sub <- pred %>% filter(between(x, obs$x[i] - res_lon/2, obs$x[i] + res_lon/2),
                                between(y, obs$y[i] - res_lat/2, obs$y[i] + res_lat/2))
    if(nrow(pred_sub)!=1){
      print(paste0('Check Row ', i))
    }
    result[i, (3:ncol(result))] <- pred_sub[,(3:ncol(pred_sub))]
  }
  
  result <- obs %>% left_join(result)
  return(result)
}

train <- pred_obs_map(observed, predictions, 0.01, 0.01)

names_pred <- c("lon", "lat", "pred_AV", "pred_GS", "pred_GM")
names_train <- c("lon", "lat", "pm25_obs", "pred_AV", "pred_GS", "pred_GM")
names(train) <- names_train
names(predictions) <- names_pred

write.csv(train, "Model_Input/training_data_CA_2010.csv")

for(column in names(predictions)[3:length(predictions)]){
  filename <- paste0("Model_Input/", substr(column,6,8),"_", year, "_CA_align.csv")
  file <- predictions %>% select(lat, lon, column)
  names(file) <- c("lat", "lon", "pm25")
  write.csv(file, filename)
}