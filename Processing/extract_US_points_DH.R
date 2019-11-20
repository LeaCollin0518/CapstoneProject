# Script for Extracting Points from ASCII Grid File
require(RColorBrewer)
library(lubridate)
library(dplyr)
library(tidyr)
library(raster)
library(rgdal)
library(stringr)
library(tigris)
library(leaflet)
library(leaflet.extras)

setwd("C:/Users/leac7/Documents/Columbia/Capstone/CapstoneProject")

# files <- list.files(path="Data/dalhousie_v2/annual/", pattern="*.asc", full.names=TRUE, recursive=FALSE)

asc_file <- "annual/GWRwSPEC_PM25_NA_201001_201012-RH35-NoNegs.asc/GWRwSPEC_PM25_NA_201001_201012-RH35-NoNegs.asc"
asc_file_dir <- paste0("Data/dalhousie_v2/", asc_file)
raster_file <- raster(asc_file_dir)
geo_proj <- crs(raster_file)

all_us <- states(cb = TRUE)
all_us <- all_us[all_us$STUSPS != "AK",]
all_us <- all_us[all_us$STUSPS != 'HI',]
#all_us <- all_us[all_us$STUSPS == 'TX',]
#all_us <- all_us[all_us$STUSPS != 'WA',]

all_us <- spTransform(all_us, geo_proj)

cropped_raster <- crop(raster_file, all_us)
#cropped_raster[is.na(cropped_raster$GWRwSPEC_PM25_NA_201001_201012.RH35.NoNegs),]
cropped_raster.NA <- reclassify(cropped_raster, cbind(NA, -999.99)) 

dh.mask <- raster::mask(x=cropped_raster.NA, mask=all_us)

point_values <- raster::extract(dh.mask, # the raster that you wish to extract values from
                                coordinates(dh.mask) # a point, or polygon spatial object
)
point_df <- data.frame(coordinates(dh.mask), point_values)

# drop na PM 2.5 values (these are the masked values)

names(point_df) <- c("lon", "lat", "pm25")
all_dh <- point_df %>% drop_na(pm25)

file_name <- "Data/nationwide/AV_2010_align.csv"
write.csv(all_dh,
          file = file_name,
          row.names=FALSE)

plot(dh.mask)

# look at plot
leaflet(all_us) %>%
  addProviderTiles("CartoDB.Positron") %>%
  addPolygons(fillColor = "white",
              color = "black",
              weight = 0.5) %>%
  setView(-98.5795, 39.8282, zoom=3)

ground_truth <- readRDS('Data/epa_data/pm25_observed_2000_2016.rds')
us_2010 <- ground_truth %>% filter(year(Date) == '2010')

us_epa <- us_2010  %>% dplyr::select(uid, Latitude, Longitude, pm25_obs)
us_avg <- data.frame(aggregate(us_epa$pm25_obs, list(us_epa$Latitude, us_epa$Longitude), mean))
names(us_avg) <- c('Latitude','Longitude', 'mean_pm2.5')
pm_pal_vals <- us_avg$mean_pm2.5

pal <- colorNumeric(rev(brewer.pal(n=11, name = "RdYlGn")), pm_pal_vals,
                    na.color = "transparent")

#check crop
m1 <- leaflet() %>% addProviderTiles(providers$Stamen.TonerLite) %>%
  addRasterImage(cropped_raster, colors = pal, opacity = 0.5) %>%
  addLegend(pal = pal, values = pm_pal_vals,
            title = "PM2.5") %>%
  setView(-98.5795, 39.8282, zoom=3)
m1

point_values <- raster::extract(cropped_raster, # the raster that you wish to extract values from
                                coordinates(cropped_raster) # a point, or polygon spatial object
)

point_df <- data.frame(coordinates(cropped_raster), point_values)
names(point_df) <- c("x", "y", "PM25")

file_name <- "Data/cali_example/dh_us_annual_2010.csv"
write.csv(point_df,
          file = file_name,
          row.names=FALSE)

dh_us <- read.csv(file_name, header = TRUE)

coordinates(dh_us) = ~x+y
r_data <- rasterFromXYZ(xyz=dh_us, crs="+init=epsg:4326 +proj=longlat +datum=WGS84 +no_defs +ellps=WGS84 +towgs84=0,0,0")

shape_plot <- leaflet() %>% addProviderTiles(providers$Stamen.TonerLite) %>%
  addRasterImage(r_data, colors = pal, opacity = 0.5) %>%
  addLegend(pal = pal, values = pm_pal_vals,
            title = "PM2.5") %>%
  setView(-98.5795, 39.8282, zoom=3)
shape_plot

pattern <- ".*20(\\d{2}).*"

# Shape file of tract you want to look at
# Currently: California
shape_file <- "gz_2010_06_140_00_500k"
shape_file_dir <- paste0("Data/plotting/", shape_file)
raw_tract <- readOGR(dsn = shape_file_dir, layer = shape_file)


for (file in files){
  print (file)
  raster_file <- raster(file)
  cropped_raster <- raster(asc_file)
  # Crop raster to tract
  cropped_raster <- crop(raster_file, raw_tract)
  
  # Extract point values from raster and specified coordinates
  point_values <- raster::extract(cropped_raster, # the raster that you wish to extract values from
                                  coordinates(cropped_raster)) # a point, or polygon spatial object
  
  # Create dataframe of coordinates and extracted point values
  point_df <- data.frame(coordinates(cropped_raster), point_values)
  names(point_df) <- c("x", "y", "PM25")
  curr_year <- str_match(file, pattern)[,2]
  file_name <- "Data/cali_example/AV_20"
  file_name <- paste0(file_name, curr_year)
  file_name <- paste0(file_name, '_align.csv')
  print (file_name)
  write.csv(point_df,
            file = file_name,
            row.names=FALSE)
  
}
