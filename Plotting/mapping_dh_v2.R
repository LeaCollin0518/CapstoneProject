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

setwd("C:/Users/leac7/Documents/Columbia/Capstone/CapstoneProject/Data")

### MAPPING PREDICTIONS FOR CALIFORNIA
r = raster("dalhousie_v2/GWRwSPEC_PM25_NA_200010_200010-RH35-NoNegs.asc")

states <- rgdal::readOGR("plotting/tl_2017_us_state/tl_2017_us_state.shp")
states <- states[states$STUSPS %in% c('CA'),] 
bbox(states)

e <- as(extent(-124.5, -114.2, 32.6, 42.1), 'SpatialPolygons')
# extent format (xmin,xmax,ymin,ymax)

pmdat.ca <- crop(r, e)
pmdat.ca[pmdat.ca < 0] <- NA

# getting ground truth for palette
ground_truth <- readRDS('epa_data/pm25_observed_2000_2016.rds')
ca_2010 <- ground_truth %>% filter(State.Code == '06' & year(Date) == '2010')

ca_epa <- ca_2010  %>% dplyr::select(uid, Latitude, Longitude, pm25_obs)
ca_avg <- data.frame(aggregate(ca_epa$pm25_obs, list(ca_epa$Latitude, ca_epa$Longitude), mean))
names(ca_avg) <- c('Latitude','Longitude', 'mean_pm2.5')
coordinates(ca_avg) <- ~ Longitude + Latitude

pal <- colorNumeric(rev(brewer.pal(n=11, name = "RdYlGn")), ca_avg$mean_pm2.5,
                    na.color = "transparent")


m1 <- leaflet() %>% addProviderTiles(providers$Stamen.TonerLite) %>%
  addRasterImage(pmdat.ca, colors = pal, opacity = 0.5) %>%
  addLegend(pal = pal, values = ca_avg$mean_pm2.5,
            title = "PM2.5") %>%
  addCircleMarkers(lng = ca_avg$Longitude, # we feed the longitude coordinates 
                   lat = ca_avg$Latitude,
                   radius = 3, 
                   stroke = FALSE, 
                   fillOpacity = 0.9, 
                   color = pal(ca_avg$mean_pm2.5)) %>%
  fitBounds(-125.0, 37.10732, -121.46928, 42.1)

m1
