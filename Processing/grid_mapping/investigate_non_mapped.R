setwd("../../Data/grid_mapping/mapped/2010_mapped_data/")
library(dplyr)
library(extracat)
library(ggmap)

dal <- read.csv("AV_2010_align.csv")
gbd <- read.csv("GBD_2010_align.csv")
sw  <- read.csv("test_scott_2010_align.csv")

gbd <- gbd %>% filter(time==2010) %>% select(-X, -time)
sw  <- sw  %>% filter(time==2010) %>% select(-X, -time)

ref <- dal %>% left_join(gbd, c("lon", "lat"), suffix=c("_av", "_gb"))
ref <- ref %>% left_join(sw, c("lon", "lat"), suffix=c("", "_sw"))
ref <- ref %>% rename(pm25_sw = pm25)

visna(ref)

gb_na <- ref %>% filter(is.na(pm25_gb)) %>% 
          select(lon, lat)

sw_na <- ref %>% filter(is.na(pm25_sw)) %>% 
          select(lon, lat)


library(rworldmap)
newmap <- getMap(resolution = "low")
plot(newmap, xlim = c(-172, -66), ylim = c(18, 72), asp = 1)
points(sw_na$lon, sw_na$lat, col = "red", cex = .2)

library(rworldmap)
newmap <- getMap(resolution = "low")
plot(newmap, xlim = c(-172, -66), ylim = c(18, 72), asp = 1)
points(gb_na$lon, gb_na$lat, col = "red", cex = .2)
