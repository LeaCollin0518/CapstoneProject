setwd("~/Desktop/Columbia/Courses/Capstone/calibre/example/data/CA_monthly_training_data/")
library(dplyr)
library(lubridate)

files <- sort(list.files())

file <- files[1]
data <- read.csv(file)

for(file in files[2:length(files)]){
  data_month <- read.csv(file)
  data <- rbind(data, data_month)
}

data <- data %>% select(-X) %>% arrange(time, lon, lat)

data$date <- ymd("2010-01-01")
month(data$date) <- month(data$date) + (data$time-1)
data$time <- as.numeric(data$date - ymd("2009-12-31"))

data <- data %>% select(-date) %>% data.frame()
write.csv(data, "training_data_2010_monthly.csv")

X <- data.frame(matrix(0, nrow = 1000, ncol=3))
names(X) <- c("x1", "x2", "y")
X$x1 <- 2
X$x2 <- rnorm(1000)

summary(lm(y~x1+x2, X))
