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

pal <- leaflet::colorNumeric(rev(brewer.pal(n=11, name = "RdYlGn")), ca_pm25$mean_pm2.5,
                    na.color = "transparent")

elbow_room1 <- ca_base + 
  geom_polygon(data = ca_pm25, aes(fill = mean_pm2.5), color = "white") +
  geom_polygon(color = "black", fill = NA) +
  scale_fill_gradientn(colours = terrain.colors(10)) +
  theme_bw() +
  ditch_the_axes

elbow_room1

### CHICAGO

r = raster("plotting/GWR_PM25_NA_200501_200712-RH35-NoNegs.asc/GWR_PM25_NA_200501_200712-RH35-NoNegs.asc")
r

class(r)
dim(r)

shape_file <- "gz_2010_17_140_00_500k"
shape_file_dir <- paste0("plotting/", shape_file)
raw_tract <- readOGR(dsn = shape_file_dir, layer = shape_file)

pmdat <- projectRaster(r, crs = crs(raw_tract))
# crop the data
pmdat <- crop(pmdat, raw_tract)

class(pmdat)
pmdat
head(coordinates(pmdat)) # x = longitude, y = latitude
head(values(pmdat))
summary(values(pmdat))
summary(values(pmdat)[which(values(pmdat)>0)])

pmdat2 <- raster::extract(pmdat, # the raster that you wish to extract values from
                          raw_tract, # a point, or polygon spatial object
                          buffer = .1, # specify a .5 degree radius
                          fun = mean, # extract the MEAN value from each plot
                          sp = TRUE) # create spatial object
class(pmdat2)
pmdat2@data %>% glimpse
summary(pmdat2)
names(pmdat2)[8] <- "pm25"
pmdat2$pm25      <- ifelse(pmdat2$pm25 < -10, NA, pmdat2$pm25)

spplot(pmdat2, "pm25")

### CALIFORNIA

shape_file <- "gz_2010_06_140_00_500k"
shape_file_dir <- paste0("plotting/", shape_file)
raw_tract <- readOGR(dsn = shape_file_dir, layer = shape_file)

# pmdat <- projectRaster(r, crs = crs(raw_tract))
# crop the data
pmdat <- crop(r, raw_tract)

class(pmdat)
pmdat
head(coordinates(pmdat))
tail(coordinates(pmdat))
head(values(pmdat))
summary(values(pmdat))
summary(values(pmdat)[which(values(pmdat)>0)])

pmdat2 <- raster::extract(pmdat, # the raster that you wish to extract values from
                          raw_tract, # a point, or polygon spatial object
                          buffer = .1, # specify a .5 degree radius
                          fun = mean, # extract the MEAN value from each plot
                          sp = TRUE) # create spatial object
class(pmdat2)
pmdat2@data %>% glimpse
summary(pmdat2)
names(pmdat2)[8] <- "pm25"
pmdat2$pm25      <- ifelse(pmdat2$pm25 < 0, NA, pmdat2$pm25)

spplot(pmdat2, "pm25")

######################### CALIFORNIA (more)

states <- readShapePoly("plotting/tl_2017_us_state/tl_2017_us_state.shp")
names(states)
states@data %>% glimpse

states.ca <- states[states$STATE_ABBR == "CA",]
bbox(states.ca)

e <- as(extent(-179.23, 179.86, -14.6, 71.44), 'SpatialPolygons')
# extent format (xmin,xmax,ymin,ymax)

pmdat.ca <- crop(r, e)
pmdat.ca

pmdat.ca[pmdat.ca < 0] <- NA

library(leaflet); library(rgeos)
library(leaflet.extras)
library(rgdal)
library(mapview); library(webshot)


load("plotting/annual_USA_072717.RData")
dtam.2006 <- na.omit(annual.allobs[which(annual.allobs$year == 2006 & annual.allobs$state.code == "06"), 
                                   c("latitude", "longitude", "year", "measured")])
# coordinates(dtam.2006) <- ~ longitude + latitude
# proj4string(dtam.2006) <- CRS(proj4string(pmdat.ca))
rm(annual.allobs)

pal <- colorNumeric(rev(brewer.pal(n=11, name = "RdYlGn")), values(pmdat.ca),
                    na.color = "transparent")

names(providers)

m1 <- leaflet() %>% addProviderTiles(providers$Stamen.TonerLite) %>%
  addRasterImage(pmdat.ca, colors = pal, opacity = 0.5) %>%
  addLegend(pal = pal, values = values(pmdat.ca),
            title = "PM2.5") %>%
  addCircleMarkers(lng = dtam.2006$longitude, # we feed the longitude coordinates 
                   lat = dtam.2006$latitude,
                   radius = 3, 
                   stroke = FALSE, 
                   fillOpacity = 0.9, 
                   color = pal(dtam.2006$measured)) %>%
  fitBounds(-180.0, 180.0, -15.0, 72.0)

m1

mapshot(m1, file = "mapPM25_CA_new.png")

m2 <- leaflet() %>% addProviderTiles(providers$Stamen.TonerLite) %>%
  # addRasterImage(pmdat.ca, colors = pal, opacity = 0.3) %>%
  addLegend(pal = pal, values = values(pmdat.ca),
            title = "PM2.5") %>%
  addCircleMarkers(lng = dtam.2006$longitude, # we feed the longitude coordinates 
                   lat = dtam.2006$latitude,
                   radius = 4, 
                   stroke = FALSE, 
                   fillOpacity = 1, 
                   color = pal(dtam.2006$measured)) %>%
  fitBounds(-123.02407, 37.10732, -121.46928, 38.32121)

m2

mapshot(m2, file = "mapPM25_CA_OnlyMonitors.png")


## make sure this is the CA raw_tract (i was too lazy to change names...)
pmdat.ca2 <- raster::extract(pmdat.ca, # the raster that you wish to extract values from
                             raw_tract, # a point, or polygon spatial object
                             buffer = .1, # specify a .5 degree radius
                             fun = mean, # extract the MEAN value from each plot
                             sp = TRUE) # create spatial object
class(pmdat.ca2)
pmdat.ca2@data %>% glimpse
summary(pmdat.ca2)
names(pmdat.ca2)[8] <- "pm25"
pmdat.ca2$pm25      <- ifelse(pmdat.ca2$pm25 < -10, NA, pmdat.ca2$pm25)
spplot(pmdat.ca2, "pm25")

save(pmdat.ca2, file="PM_Data_CAb.RData")

