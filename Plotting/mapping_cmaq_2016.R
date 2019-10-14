require(RColorBrewer); 
require(ggplot2)
require(mapdata); 
require(maptools)
require("plyr"); 
require(dplyr)
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
library(leaflet)
library(rgeos)
library(leaflet.extras)
library(rgdal)
library(mapview)
library(webshot)

library(data.table)

# EXAMPLE MAPPING
fips_codes <- read.csv('fips_codes.csv', header = TRUE, stringsAsFactors = FALSE)
fips_codes <- read.csv('fips_codes.csv', header = TRUE, colClasses = rep('character', ncol(fips_codes)))
names(fips_codes) <- c('Summary.Level', 'State.Code', 'County.Code', 'County.Subdivision.Code', 'Place.Code.Fips', 'Consolidated.City.Code', 'Area.Name')

fips_codes$FIPS <- paste(fips_codes$State.Code, fips_codes$County.Code, sep = "")

output_2016 <- read.csv('outputs/2016_pm25_daily_average 2.txt', header = TRUE, stringsAsFactors = FALSE)

output_2016$Date <- as.Date(output_2016$Date, format='%b-%d-%Y')
output_2016$FIPS <- as.character(output_2016$Loc_Label1)
output_2016$FIPS <- substr(output_2016$FIPS, 1, nchar(output_2016$FIPS)-6)

output_2016$FIPS[nchar(output_2016$FIPS)==4] <- paste0("0", output_2016$FIPS[nchar(output_2016$FIPS)==4])

### MAPPING ONLY CA COUNTIES (JAN 2016)

ca_fips <- fips_codes %>% filter(State.Code == '06')
ca_fips <- ca_fips %>% filter(County.Code != '000')

ca_output_2016 <- output_2016 %>% filter(FIPS %in% ca_fips$FIPS)
ca_fips$Area.Name <- sapply(ca_fips$Area.Name, tolower)


county_pattern <- '(.+)\\s(county|city)'
ca_fips$match.area.name <- str_match(ca_fips$Area.Name, county_pattern)[,2]
null_cols <- c('Summary.Level', 'State.Code', 'County.Subdivision.Code','Place.Code.Fips',  'Consolidated.City.Code', 'Area.Name')
ca_fips[null_cols] <- NULL

counties <- map_data("county")
ca_county <- subset(counties, region == "california")

ca_base <- ggplot(data = ca_county, mapping = aes(x = long, y = lat, group = group)) + 
  coord_fixed(1.3) + 
  geom_polygon(color = "black", fill = "gray") + 
  geom_polygon(data = ca_county, fill = NA, color = "white") +
  geom_polygon(color = "black", fill = NA)


ca_cmaq <- merge(x=ca_output_2016,y=ca_fips,by='FIPS')
ca_cmaq$subregion <- ca_cmaq$match.area.name
ca_cmaq$match.area.name <- NULL

ca_cmaq_jan <- ca_cmaq %>% filter(month(Date) == '1') %>% dplyr::select(Loc_Label1, Latitude, Longitude, Prediction, subregion)

ca_cmaq_jan <- data.frame(aggregate(ca_cmaq_jan$Prediction, list(ca_cmaq_jan$subregion), mean))
names(ca_cmaq_jan) <- c('subregion', 'mean_pm2.5')

ca_pm25 <- inner_join(ca_county, ca_cmaq_jan, by = "subregion")

ditch_the_axes <- theme(
  axis.text = element_blank(),
  axis.line = element_blank(),
  axis.ticks = element_blank(),
  panel.border = element_blank(),
  panel.grid = element_blank(),
  axis.title = element_blank()
)

elbow_room1 <- ca_base + 
  geom_polygon(data = ca_pm25, aes(fill = mean_pm2.5), color = "white") +
  geom_polygon(color = "black", fill = NA) +
  scale_fill_gradientn(colours = terrain.colors(20)) +
  theme_bw() +
  ditch_the_axes

elbow_room1
