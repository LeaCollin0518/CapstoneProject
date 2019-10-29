require(RColorBrewer); require(ggplot2)
require(mapdata); require(maptools)
require("plyr"); require(dplyr)
library(tidyverse)
library(raster)
library(rgdal)
library(sp)
library(automap)
library(leaflet)
library(leaflet.extras)
library(lubridate)

setwd("C:/Users/leac7/Documents/Columbia/Capstone/CapstoneProject")

# getting ground truth for palette
ground_truth <- readRDS('Data/epa_data/pm25_observed_2000_2016.rds')
ca_2010 <- ground_truth %>% filter(State.Code == '06' & year(Date) == '2010')

ca_epa <- ca_2010  %>% dplyr::select(uid, Latitude, Longitude, pm25_obs)
ca_avg <- data.frame(aggregate(ca_epa$pm25_obs, list(ca_epa$Latitude, ca_epa$Longitude), mean))
names(ca_avg) <- c('Latitude','Longitude', 'mean_pm2.5')
coordinates(ca_avg) <- ~ Longitude + Latitude

pal <- colorNumeric(rev(brewer.pal(n=11, name = "RdYlGn")), ca_avg$mean_pm2.5,
                    na.color = "transparent")

convert_to_spatial <- function(locations, crs_string) {
  coordinates(locations) =~lon+lat
  return (rasterFromXYZ(xyz=model_pred, crs=crs_string))
}

plot_pred <- function(spatial_preds, true_preds, palette){
 
  return (plot)
}

# Dalhousie
av_pred <- read.csv('Cali_Example/example/data/AV_2010_align.csv', header = TRUE)
av_pred <- av_pred %>% dplyr::select(lat, lon, pm25)

coordinates(av_pred) =~lon+lat
av_r <- rasterFromXYZ(xyz=av_pred, crs="+init=epsg:4326 +proj=longlat +datum=WGS84 +no_defs +ellps=WGS84 +towgs84=0,0,0")

av_plot <-leaflet() %>% addProviderTiles(providers$Stamen.TonerLite) %>%
  addRasterImage(av_r, colors = pal, opacity = 0.5) %>%
  addLegend(pal = pal, values = ca_avg$mean_pm2.5,
            title = "PM2.5") %>%
  fitBounds(-125.0, 37.10732, -121.46928, 42.1)
av_plot

# GM
gm_pred <- read.csv('Cali_Example/example/data/GM_2010_align.csv', header = TRUE)
gm_pred <- gm_pred %>% dplyr::select(lat, lon, pm25)

coordinates(gm_pred) =~lon+lat
gm_r <- rasterFromXYZ(xyz=gm_pred, crs="+init=epsg:4326 +proj=longlat +datum=WGS84 +no_defs +ellps=WGS84 +towgs84=0,0,0")

gm_plot <- leaflet() %>% addProviderTiles(providers$Stamen.TonerLite) %>%
  addRasterImage(gm_r, colors = pal, opacity = 0.5) %>%
  addLegend(pal = pal, values = ca_avg$mean_pm2.5,
            title = "PM2.5") %>%
  fitBounds(-125.0, 37.10732, -121.46928, 42.1)
gm_plot

# GS
# GM
gs_pred <- read.csv('Cali_Example/example/data/GS_2010_align.csv', header = TRUE)
gs_pred <- gs_pred %>% dplyr::select(lat, lon, pm25)

coordinates(gs_pred) =~lon+lat
gs_r <- rasterFromXYZ(xyz=gs_pred, crs="+init=epsg:4326 +proj=longlat +datum=WGS84 +no_defs +ellps=WGS84 +towgs84=0,0,0")

gs_plot <- leaflet() %>% addProviderTiles(providers$Stamen.TonerLite) %>%
  addRasterImage(gs_r, colors = pal, opacity = 0.5) %>%
  addLegend(pal = pal, values = ca_avg$mean_pm2.5,
            title = "PM2.5") %>%
  fitBounds(-125.0, 37.10732, -121.46928, 42.1)
gs_plot
