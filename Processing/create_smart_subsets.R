library(tidyverse)
library(raster)
library(rgdal)
library(sp)
library(automap)
library(leaflet)
library(leaflet.extras)
library(lubridate)
library(SpaDES)

setwd("C:/Users/leac7/Documents/Columbia/Capstone/CapstoneProject")

av_pred <- read.csv('Data/cali_pred_data_2010_monthly/AV_clean_20101_align.csv', header = TRUE)
av_pred <- av_pred %>% dplyr::select(lat, lon, pm25)
av_pred <- av_pred[order (av_pred$lon, av_pred$lat),]

coordinates(av_pred) =~lon+lat
av_r <- rasterFromXYZ(xyz=av_pred, crs="+init=epsg:4326 +proj=longlat +datum=WGS84 +no_defs +ellps=WGS84 +towgs84=0,0,0")

av_splits <- splitRaster(av_r, 6, 6)

for (i in seq(1:length(av_splits))){
  file_name <- paste0('Data/cali_pred_data_2010_monthly/coordinates_', i)
  file_name <- paste0(file_name, '.csv')
  av_sub <- av_splits[[i]]
  av_sub <- data.frame(coordinates(av_splits[[i]]))
  av_sub$pm25 <- rep(1, nrow(av_sub))
  write.csv(av_sub,
            file = file_name,
            row.names=FALSE)
}
