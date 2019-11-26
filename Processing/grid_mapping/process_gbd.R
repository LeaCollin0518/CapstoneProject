library(dplyr)
load("../../Data/grid_mapping/clean_models/pre_clean/GBD2016_PREDPOP_FINAL")


mydata2 <- mydata2 %>% filter(Country=="USA") %>% rename(x=Longitude, y=Latitude)
gbd <- mydata2 %>% select(x,y,paste0("Mean_PM2.5_2000")) %>% rename(pm25=`Mean_PM2.5_2000`)
gbd$year <- 2000

years <- c(2005, 2010:2016)

for(year in years){
  gbd_year <- mydata2 %>% select(x,y,paste0("Mean_PM2.5_", year))
  gbd_year$year <- year
  names(gbd_year) <- names(gbd)
  gbd <- rbind(gbd, gbd_year)
}

write.csv(gbd, paste0("../../Data/grid_mapping/clean_models/gbd_2000_2016.csv"))
