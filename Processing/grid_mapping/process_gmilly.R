library(chron)
library(RColorBrewer)
library(lattice)
library(ncdf4)
library(lubridate)
  
parse_nc <- function(ncname, dname){
  
  ncfname <- paste(ncname, ".nc", sep = "")
  ncin <- nc_open(ncfname)
  lon <- ncvar_get(ncin, "lon")
  lat <- ncvar_get(ncin, "lat", verbose = F)
  t <- ncvar_get(ncin, "time")
  
  tunits <- ncatt_get(ncin, "time", "units")
  nt <- dim(t)
  
  tmp.array <- ncvar_get(ncin, dname)
  fillvalue <- ncatt_get(ncin, dname, "_FillValue")
  
  nc_close(ncin)
  tmp.array[tmp.array == fillvalue$value] <- NA
  
  tmp.vec.long <- as.vector(tmp.array)
  tmp.mat <- matrix(tmp.vec.long, nrow = dim(lon) * dim(lat), ncol = nt)
  
  lonlat <- expand.grid(lon, lat)
  tmp.df02 <- data.frame(cbind(lonlat, tmp.mat))
  names(tmp.df02) <- c("lon", "lat", min(t) -1 + seq(1:365))
  tmp.df02 <- tmp.df02 %>% gather(key=day, value=pm25, -lon, -lat)
  tmp.df02$date <- as.numeric(tmp.df02$day)
  tmp.df02$date <- as.character(chron(tmp.df02$date, origin = c(1, 0, 2000)))
  
  year_df <- tmp.df02 %>% select(date, lon, lat, pm25) %>% data.frame()
  return(year_df)
}

year <- 2004
ncname <- paste0("PM25_2004-2011_USA/PM25_24hr_",year,"_Base_USA")
dname <- "PM25_24hr"  # note: tmp means temperature (not temporary)
gmilly_combined <- parse_nc(ncname, dname)

for(year in 2005:2011){
  ncname <- paste0("PM25_2004-2011_USA/PM25_24hr_",year,"_Base_USA")
  new_year <- parse_nc(ncname, dname)
  gmilly_combined <- rbind(gmilly_combined , new_year)
}

gmilly_combined$date <- as.Date(gmilly_combined$date, "%m/%d/%y")
saveRDS(gmilly_combined, "gmilly.rds")

