require(RColorBrewer); require(ggplot2)
require(mapdata); require(maptools)
require("plyr"); require(dplyr)
library(tidyverse)
library(raster)
library(zipcode) 
library(choroplethr)
library(rgdal)
library(ggmap)
library(sp)
library(tgp)
library(mgcv)
library(gstat)
library(automap)
library(dismo)
library(maps)
library(mapdata)
library(gstat)
library(leaflet)
library(rgeos)
library(leaflet.extras)
library(rgdal)
library(mapview)
library(webshot)
library(lubridate)

setwd("C:/Users/leac7/Documents/Columbia/Capstone/CapstoneProject/Data")

# MAPPING GROUND TRUTH FOR CALIFORNIA 2010

model_pred <- read.csv('cali_example/model_predictions.csv', header = TRUE)
model_pred_mean <- model_pred %>% dplyr::select(lon, lat, mean_mean)
model_pred_overall <- model_pred %>% dplyr::select(lon, lat, mean_overall)

coordinates(model_pred_mean) <- ~ lon + lat
coordinates(model_pred_overall) <- ~ lon + lat

ground_truth <- readRDS('epa_data/pm25_observed_2000_2016.rds')
ca_2010 <- ground_truth %>% filter(State.Code == '06' & year(Date) == '2010')

ca_epa <- ca_2010  %>% dplyr::select(uid, Latitude, Longitude, pm25_obs)
ca_avg <- data.frame(aggregate(ca_epa$pm25_obs, list(ca_epa$Latitude, ca_epa$Longitude), mean))
names(ca_avg) <- c('Latitude','Longitude', 'mean_pm2.5')
coordinates(ca_avg) <- ~ Longitude + Latitude

pal <- colorNumeric(rev(brewer.pal(n=11, name = "RdYlGn")), ca_avg$mean_pm2.5,
                    na.color = "transparent")

cal_mean_plot <- leaflet() %>% addProviderTiles(providers$Stamen.TonerLite) %>%
  addLegend(pal = pal, values = ca_avg$mean_pm2.5,
            title = "PM2.5") %>%
  addCircleMarkers(lng = model_pred_mean$lon, # we feed the longitude coordinates 
                   lat = model_pred_mean$lat,
                   radius = 1, 
                   stroke = FALSE, 
                   fillOpacity = 1, 
                   color = pal(model_pred_mean$mean_mean)) %>%
  fitBounds(-125.0, 34.0, -115.0, 43.0)

cal_mean_plot

cal_overall_plot <- leaflet() %>% addProviderTiles(providers$Stamen.TonerLite) %>%
  addLegend(pal = pal, values = ca_avg$mean_pm2.5,
            title = "PM2.5") %>%
  addCircleMarkers(lng = model_pred_overall$lon, # we feed the longitude coordinates 
                   lat = model_pred_overall$lat,
                   radius = 1, 
                   stroke = FALSE, 
                   fillOpacity = 1, 
                   color = pal(model_pred_overall$mean_overall)) %>%
  fitBounds(-125.0, 34.0, -115.0, 43.0)

cal_overall_plot
