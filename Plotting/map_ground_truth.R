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

epa_2016 <- read.csv('epa_data/epa_deduped_2016.csv', header = TRUE, stringsAsFactors = FALSE)
epa_2016 <- read.csv('epa_data/epa_deduped_2016.csv', header = TRUE, colClasses = rep('character', ncol(epa_2016)))
epa_2016$X <- NULL # delete dummy index column
epa_2016$Date.Local <- as.Date(epa_2016$Date.Local)
num.columns <- c('POC', 'Latitude', 'Longitude', 'Arithmetic.Mean')
epa_2016[num.columns] <- sapply(epa_2016[num.columns], as.numeric)

ca_2016 <- epa_2016 %>% filter(State.Code == '06')

ca_epa_jan <- ca_2016 %>% filter(month(Date.Local) == '1') %>% dplyr::select(Site.Num, Latitude, Longitude, Arithmetic.Mean)
ca_jan_avg <- data.frame(aggregate(ca_epa_jan$Arithmetic.Mean, list(ca_epa_jan$Latitude, ca_epa_jan$Longitude), mean))
names(ca_jan_avg) <- c('Latitude','Longitude', 'mean_pm2.5')
coordinates(ca_jan_avg) <- ~ Longitude + Latitude

# MAY NEED TO CHANGE COLOR PALETTE SCALE - need to ask Marianthi
pal <- colorNumeric(rev(brewer.pal(n=11, name = "RdYlGn")), ca_jan_avg$mean_pm2.5,
                     na.color = "transparent")

states <- rgdal::readOGR("plotting/tl_2017_us_state/tl_2017_us_state.shp")
states <- states[states$STUSPS %in% c('CA'),] 
bbox(states)


cal_plot <- leaflet() %>% addProviderTiles(providers$Stamen.TonerLite) %>%
  addLegend(pal = pal, values = ca_jan_avg$mean_pm2.5,
            title = "PM2.5") %>%
  addCircleMarkers(lng = ca_jan_avg$Longitude, # we feed the longitude coordinates 
                   lat = ca_jan_avg$Latitude,
                   radius = 5, 
                   stroke = FALSE, 
                   fillOpacity = 1, 
                   color = pal(ca_jan_avg$mean_pm2.5)) %>%
  fitBounds(-125.0, 34.0, -115.0, 43.0)

cal_plot
