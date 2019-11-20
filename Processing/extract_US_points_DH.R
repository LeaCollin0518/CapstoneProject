# Script for Extracting Points from ASCII Grid File
library(dplyr)
library(tidyr)
library(raster)
library(rgdal)
library(stringr)
library(tigris)
setwd("C:/Users/leac7/Documents/Columbia/Capstone/CapstoneProject")

asc_file <- "annual/GWRwSPEC_PM25_NA_201001_201012-RH35-NoNegs.asc/GWRwSPEC_PM25_NA_201001_201012-RH35-NoNegs.asc"
asc_file_dir <- paste0("Data/dalhousie_v2/", asc_file)
raster_file <- raster(asc_file_dir)
geo_proj <- crs(raster_file)

all_us <- states(cb = FALSE, resolution = "500k")
# exclude Alaska and Hawaii
all_us <- all_us[all_us$STUSPS != "AK",]
all_us <- all_us[all_us$STUSPS != 'HI',]
all_us <- spTransform(all_us, geo_proj)

files <- list.files(path="Data/dalhousie_v2/annual/", pattern="*.asc", full.names=TRUE, recursive=FALSE)

year_pattern <- ".*20(\\d{2}).*"
asc_pattern <- ".*\\/(.*\\.asc)"
years <- str_pad(as.character(seq(from = 4, to = 16)), 2, pad = '0')

for (file in files){
  asc_file <- str_match(file, asc_pattern)[,2]
  asc_file_dir <- paste0(file, '/')
  asc_file_dir <- paste0(asc_file_dir, asc_file)
  
  curr_year <- str_match(file, year_pattern)[,2]
  
  if (curr_year %in% years){
    print (asc_file_dir)
    print(curr_year)
    
    raster_file <- raster(asc_file_dir)
    # Crop raster to tract
    cropped_raster <- crop(raster_file, all_us)
    cropped_raster.NA <- reclassify(cropped_raster, cbind(NA, -999.99)) 
    
    dh.mask <- raster::mask(x=cropped_raster.NA, mask=all_us)
    
    point_values <- raster::extract(dh.mask, # the raster that you wish to extract values from a point, or polygon spatial object
                                    coordinates(dh.mask))
    point_df <- data.frame(coordinates(dh.mask), point_values)
    
    # drop na PM 2.5 values (these are the masked values)
    
    names(point_df) <- c("lon", "lat", "pm25")
    all_dh <- point_df %>% drop_na(pm25)
    
    file_name <- "Data/nationwide/AV_20"
    file_name <- paste0(file_name, curr_year)
    file_name <- paste0(file_name, '_align.csv')
    print (file_name)
    write.csv(all_dh,
              file = file_name,
              row.names=FALSE)
  }
}