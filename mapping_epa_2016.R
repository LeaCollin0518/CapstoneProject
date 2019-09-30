library(tidyverse)
require(RColorBrewer); require(ggplot2)
require(mapdata); require(maptools)
library(raster); library(zipcode) 
library(choroplethr)
library(rgdal)
library(ggmap)
library(sp)
require("plyr"); require(dplyr)
library(tgp)
library(mgcv)
library(gstat)
library(automap)
library(raster) 
library(dismo)
library(ggplot2)
library(maps)
library(mapdata)
library(sp)
library(gstat)
library(automap)
require(dplyr); require(RColorBrewer); require(ggplot2)
require(mapdata); require(maptools)
library(raster) 
library(dismo)

library(data.table)

setwd("C:/Users/leac7/Documents/Columbia/Capstone/CapstoneProject/Data")

# EXPLORATORY ANALYSIS - CAN PROBABLY IGNORE
improve <- read.delim("improve_data/improve_2000_2016.txt", sep = ",", header = TRUE, stringsAsFactors = FALSE)
improve <- as.data.table(read.csv('improve_data/improve_2000_2016.txt', header = TRUE, sep = ',', colClasses = rep("character", ncol(improve))))

improve$POC <- as.numeric(improve$POC)
improve$Date <- as.Date(improve$Date, "%Y/%m/%d") 
improve$Latitude <- as.numeric(improve$Latitude)
improve$Longitude <- as.numeric(improve$Longitude)
improve$MF.Value <- as.numeric(improve$MF.Value)

daily_2016 <- read.csv('epa_data/daily_88101_2016.csv', header = TRUE, stringsAsFactors = FALSE)
daily_2015 <- read.csv('epa_data/daily_88101_2015.csv', header = TRUE)
daily_2006 <- read.csv('epa_data/daily_88101_2006.csv', header = TRUE)


daily_2006 <- read.csv('epa_data/daily_88101_2006.csv', header = TRUE)

daily_2006 <- read.csv('epa_data/daily_88101_2006.csv', header = TRUE)

improve <- improve[POC == 1, ]

# finding no duplicates
improve <- improve[, has.multiple.records := .N > 1, by = list(State, CountyFIPS, SiteCode, Date)]
num_dups <- improve[has.multiple.records == TRUE, .N]

num_missing_pm <- improve[MF.Value == -999, .N]

improve <- as.data.frame(improve)
improve$has.multiple.records <- NULL


# EXAMPLE MAPPING
fips_codes <- read.csv('fips_codes.csv', header = TRUE, stringsAsFactors = FALSE)
fips_codes <- read.csv('fips_codes.csv', header = TRUE, colClasses = rep('character', ncol(fips_codes)))
names(fips_codes) <- c('Summary.Level', 'State.Code', 'County.Code', 'County.Subdivision.Code', 'Place.Code.Fips', 'Consolidated.City.Code', 'Area.Name')

epa_2016 <- read.csv('epa_data/epa_deduped_2016.csv', header = TRUE, stringsAsFactors = FALSE)
epa_2016 <- read.csv('epa_data/epa_deduped_2016.csv', header = TRUE, colClasses = rep('character', ncol(epa_2016)))
epa_2016$X <- NULL # delete dummy index column
epa_2016$Date.Local <- as.Date(epa_2016$Date.Local)
num.columns <- c('POC', 'Latitude', 'Longitude', 'Arithmetic.Mean')
epa_2016[num.columns] <- sapply(epa_2016[num.columns], as.numeric)

### MAPPING ONLY CA COUNTIES (JAN 2016)

ca_2016 <- epa_2016 %>% filter(State.Code == '06')
ca_fips <- fips_codes %>% filter(State.Code == '06')
ca_fips$Area.Name <- sapply(ca_fips$Area.Name, tolower)
ca_fips <- ca_fips %>% filter(County.Code != '000')

county_pattern <- '(.+)\\s(county|city)'
ca_fips$match.area.name <- str_match(ca_fips$Area.Name, county_pattern)[,2]
null_cols <- c('Summary.Level', 'State.Code', 'County.Subdivision.Code', 'Place.Code.Fips', 'Consolidated.City.Code', 'Area.Name')
ca_fips[null_cols] <- NULL

usa <- map_data("usa")
w2hr <- map_data("world2")

states <- map_data("state")
ca_df <- subset(states, region == "california")
counties <- map_data("county")
ca_county <- subset(counties, region == "california")

ca_base <- ggplot(data = ca_df, mapping = aes(x = long, y = lat, group = group)) + 
  coord_fixed(1.3) + 
  geom_polygon(color = "black", fill = "gray")
ca_base

ca_base + 
  geom_polygon(data = ca_county, fill = NA, color = "white") +
  geom_polygon(color = "black", fill = NA)


ca_epa <- merge(x=ca_2016,y=ca_fips,by="County.Code")
ca_epa$subregion <- ca_epa$match.area.name
ca_epa$match.area.name <- NULL

ca_epa_jan <- ca_epa %>% filter(month(Date.Local) == '1') %>% dplyr::select(Site.Num, Latitude, Longitude, Arithmetic.Mean, subregion)
ca_epa_jan <- data.frame(aggregate(ca_epa_jan$Arithmetic.Mean, list(ca_epa_jan$subregion), mean))
names(ca_epa_jan) <- c('subregion', 'mean_pm2.5')
ca_pm25 <- inner_join(ca_county, ca_epa_jan, by = "subregion")

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

### TRYING MORE STUFF
ca.jan.01.2016 <- ca_epa %>% filter(Date.Local == '2016-01-01')
coordinates(ca.jan.01.2016) <- ~ Longitude + Latitude

states <- rgdal::readOGR("plotting/tl_2017_us_state/tl_2017_us_state.shp")
states <- states[states$STUSPS %in% c('CA'),] 
bbox(ca.jan.01.2016)

mycol.palette <- colorRampPalette(c("blue", "green","yellow",  "orange", "red"), space = "rgb")

ca.jan.01.2016 %>% as.data.frame %>% 
  ggplot() + geom_polygon(data = states, 
                          aes(x=long, y = lat, group = group), 
                          fill = "white", 
                          color="black") +
  coord_fixed(xlim = c(-124.18, -115.49),  ylim = c(32.64, 41.73), ratio = 1.1) +
  geom_point(aes(x = Longitude, y = Latitude, color=Arithmetic.Mean), size = 3, alpha=3/4) + 
  scale_colour_gradientn(colours = terrain.colors(20)) +
  ggtitle("True PM 2.5") + coord_equal() + theme_bw()

ca_epa_jan <- ca_epa %>% filter(month(Date.Local) == '1') %>% dplyr::select(Site.Num, Latitude, Longitude, Arithmetic.Mean, subregion)
ca_epa_jan <- data.frame(aggregate(ca_epa_jan$Arithmetic.Mean, list(ca_epa_jan$Latitude, ca_epa_jan$Longitude), mean))
names(ca_epa_jan) <- c('Latitude', 'Longitude', 'PM2.5')
coordinates(ca_epa_jan) <- ~ Longitude + Latitude

ca_epa_jan %>% as.data.frame %>% 
  ggplot() + geom_polygon(data = states, 
                          aes(x=long, y = lat, group = group), 
                          fill = "white", 
                          color="black") +
  coord_fixed(xlim = c(-124.18, -115.49),  ylim = c(32.64, 41.73), ratio = 1.1) +
  geom_point(aes(x = Longitude, y = Latitude, color=PM2.5), size = 3, alpha=3/4) +
  scale_colour_gradientn(colours = terrain.colors(20)) +
  ggtitle("True PM 2.5 - Jan 2016") + coord_equal() + theme_bw()
