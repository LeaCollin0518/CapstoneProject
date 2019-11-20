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
ca_2010 <- ground_truth %>% filter(State.Code == '06' & year(Date) == '2010' & month(Date) == '1')

ca_epa <- ca_2010  %>% dplyr::select(uid, Latitude, Longitude, pm25_obs)
ca_avg <- data.frame(aggregate(ca_epa$pm25_obs, list(ca_epa$Latitude, ca_epa$Longitude), mean))
names(ca_avg) <- c('Latitude','Longitude', 'mean_pm2.5')
pm_pal_vals <- ca_avg$mean_pm2.5

pal <- colorNumeric(rev(brewer.pal(n=11, name = "RdYlGn")), pm_pal_vals,
                    na.color = "transparent")

make_plot <- function(r_object, color_pal, pal_vals){
  r_object <- r_object
  color_pal <- color_pal
  pal_vals <- pal_vals
  shape_plot <- leaflet() %>% addProviderTiles(providers$Stamen.TonerLite) %>%
    addRasterImage(r_object, colors = color_pal, opacity = 0.5) %>%
    addLegend(pal = color_pal, values = pal_vals,
              title = "PM2.5") %>%
    fitBounds(-125.0, 37.10732, -121.46928, 42.1)
  return (shape_plot)
}

make_spatial_object <- function(r_data){
  r_data <- r_data
  r_data <- r_data %>% dplyr::select(lat, lon, pm25)
  coordinates(r_data) = ~lon+lat
  r_data <- rasterFromXYZ(xyz=r_data, crs="+init=epsg:4326 +proj=longlat +datum=WGS84 +no_defs +ellps=WGS84 +towgs84=0,0,0")
  return (r_data)
}

## BNE predictions - Jan 2010

# mean overall
bne_pred <- read.csv('Data/cali_pred_data_2010_monthly_subsets/cali_2010_Jan_32_mean_overall.csv', header = TRUE)
bne_pred_overall <- make_spatial_object(bne_pred)
bne_overall_plot <- make_plot(bne_pred_overall, pal, pm_pal_vals)
bne_overall_plot

# mean mean

bne_pred <- read.csv('Data/cali_pred_data_2010_monthly_subsets/cali_2010_Jan_32_mean_mean.csv', header = TRUE)
bne_pred_mean <- make_spatial_object(bne_pred)
bne_mean_plot <- make_plot(bne_pred_mean, pal, pm_pal_vals)
bne_mean_plot

## AV predictions - Jan 2010

av_pred <- read.csv('Data/cali_pred_data_2010_monthly/AV_clean_20101_align.csv', header = TRUE)
av_pred <- make_spatial_object(av_pred)
av_plot <- make_plot(av_pred, pal, pm_pal_vals)
av_plot

## GM predictions - Jan 2010
gm_pred <- read.csv('Data/cali_pred_data_2010_monthly/GM_clean_20101_align.csv', header = TRUE)
gm_pred <- make_spatial_object(gm_pred)
gm_plot <- make_plot(gm_pred, pal, pm_pal_vals)
gm_plot

## GS predictions - Jan 2010
gs_pred <- read.csv('Data/cali_pred_data_2010_monthly/GS_clean_20101_align.csv', header = TRUE)
gs_pred <- make_spatial_object(gs_pred)
gs_plot <- make_plot(gs_pred, pal, pm_pal_vals)
gs_plot

#coordinates(ca_avg) <- ~ Longitude + Latitude

av_sub1 <- read.csv('Data/cali_pred_data_2010_monthly_overlap_subsets/AV_clean_20101_align.11.csv', header = TRUE)
av_sub1 <- av_sub1 %>% dplyr::select(lon, lat, pm25)
pm_vals <- av_sub1$pm25

pal <- colorNumeric(rev(brewer.pal(n=11, name = "RdYlGn")), pm_vals,
                    na.color = "transparent")

coordinates(av_sub1) =~lon+lat
av_r <- rasterFromXYZ(xyz=av_sub1, crs="+init=epsg:4326 +proj=longlat +datum=WGS84 +no_defs +ellps=WGS84 +towgs84=0,0,0")

av_plot <-leaflet() %>% addProviderTiles(providers$Stamen.TonerLite) %>%
  addRasterImage(av_r, colors = pal, opacity = 0.5) %>%
  addLegend(pal = pal, values = pm_vals,
            title = "PM2.5") %>%
  fitBounds(-125.0, 37.10732, -121.46928, 42.1)
av_plot

# TEST SUBSET

av_sub1 <- read.csv('Data/cali_pred_data_2010_monthly/coordinates_10.csv', header = TRUE)
av_sub1 <- av_sub1 %>% dplyr::select(x, y, pm25)
pm_vals <- av_sub1$pm25

pal <- colorNumeric(rev(brewer.pal(n=11, name = "RdYlGn")), pm_vals,
                    na.color = "transparent")

coordinates(av_sub1) =~x+y
av_r <- rasterFromXYZ(xyz=av_sub1, crs="+init=epsg:4326 +proj=longlat +datum=WGS84 +no_defs +ellps=WGS84 +towgs84=0,0,0")

av_plot <-leaflet() %>% addProviderTiles(providers$Stamen.TonerLite) %>%
  addRasterImage(av_r, colors = pal, opacity = 0.5) %>%
  addLegend(pal = pal, values = pm_vals,
            title = "PM2.5") %>%
  fitBounds(-125.0, 37.10732, -121.46928, 42.1)
av_plot

# Dalhousie
av_pred <- read.csv('Data/cali_pred_data_2010_monthly/AV_clean_20106_align.csv', header = TRUE)
av_pred <- av_pred %>% dplyr::select(lat, lon, pm25)
av_pred <- av_pred[order (av_pred$lon, av_pred$lat),]
pm_vals <- av_pred$pm25

pal <- colorNumeric(rev(brewer.pal(n=11, name = "RdYlGn")), av_pred$pm25,
                    na.color = "transparent")

coordinates(av_pred) =~lon+lat
av_r <- rasterFromXYZ(xyz=av_pred, crs="+init=epsg:4326 +proj=longlat +datum=WGS84 +no_defs +ellps=WGS84 +towgs84=0,0,0")

av_plot2 <-leaflet() %>% addProviderTiles(providers$Stamen.TonerLite) %>%
  addRasterImage(av_r, colors = pal, opacity = 0.5) %>%
  addLegend(pal = pal, values = pm_vals,
            title = "PM2.5") %>%
  fitBounds(-125.0, 37.10732, -121.46928, 42.1)
av_plot2

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
