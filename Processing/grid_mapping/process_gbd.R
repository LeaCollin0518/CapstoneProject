library(dplyr)
load("clean_models/pre_clean/GBD2016_PREDPOP_FINAL")

year = 2010
gbd_year <- mydata2 %>% filter(Country=="USA") %>% rename(x=Longitude, y=Latitude) %>% 
            select(x,y,paste0("Mean_PM2.5_", year))
write.csv(gbd_year, paste0("clean_models/gbd_", year, ".csv"))

