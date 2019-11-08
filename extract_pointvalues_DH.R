# Script for Extracting Points from ASCII Grid File
library(raster)
library(rgdal)

setwd("C:/Users/leac7/Documents/Columbia/Capstone/CapstoneProject")

# Read in .asc file and raster it
asc_file <- "annual/GWRwSPEC_PM25_NA_201001_201012-RH35-NoNegs.asc"
asc_file_dir <- paste0("Data/dalhousie_v2/", asc_file)
raster_file <- raster(asc_file_dir)

# Shape file of tract you want to look at
# Currently: California
shape_file <- "gz_2010_06_140_00_500k"
shape_file_dir <- paste0("Data/plotting/", shape_file)
raw_tract <- readOGR(dsn = shape_file_dir, layer = shape_file)

# Crop raster to tract
cropped_raster <- crop(raster_file, raw_tract)

# Extract point values from raster and specified coordinates
point_values <- raster::extract(cropped_raster, # the raster that you wish to extract values from
                                coordinates(cropped_raster) # a point, or polygon spatial object
                                )

# Create dataframe of coordinates and extracted point values
point_df <- data.frame(coordinates(cropped_raster), point_values)
names(point_df) <- c("x", "y", "PM25")
file_name <- "Data/cali_example/dh_ca_annual_2010.csv"
write.csv(point_df,
          file = file_name,
          row.names=FALSE)

dh <- read.csv(file_name, header = TRUE)
