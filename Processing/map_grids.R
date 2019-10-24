library(extracat)
library(tidyverse)

combine_data <- function(ref, other, big_res, small_res, other_name){
  lat_range     <- range(ref$y)
  lat_range[1]  <- lat_range[1] - big_res
  lat_range[2]  <- lat_range[2] + big_res
  
  long_range  <- range(ref$x)
  long_range[1]  <- long_range[1] - big_res
  long_range[2]  <- long_range[2] + big_res
  
  other <- other %>% filter(between(x, long_range[1], long_range[2]), 
                            between(y, lat_range[1], lat_range[2]))
  
  result <- matrix(NA, nrow(ref), 3)
  counter <- 1
  
  for(i in 1:nrow(other)){
    ref_sub <- ref %>% select(x,y) %>% 
                   filter(between(x, other$x[i] - big_res/2, other$x[i] + big_res/2),
                          between(y, other$y[i] - big_res/2, other$y[i] + big_res/2)) %>% 
                      mutate(other = other$PM25[i])
    if(nrow(ref_sub)>0){
      result[counter:(counter - 1 + nrow(ref_sub)),] <- as.matrix(ref_sub)
      counter <- counter + nrow(ref_sub)
    }
  }
  
  result <- data.frame(result)
  names(result) <- c("x", "y", "other")
  result <- result %>% filter(!is.na(x))
  
  not_rep <- anti_join(ref[1:2], result[,1:2])
  
  res <- big_res + small_res*2
  result_2 <- matrix(NA, nrow(not_rep), 3)
  counter <- 1
  for(i in 1:nrow(other)){
    ref_sub <- not_rep %>% filter(between(x, other$x[i] - res/2, other$x[i] + res/2),
                                  between(y, other$y[i] - res/2, other$y[i] + res/2)) %>% 
                mutate(other = other$PM25[i])
    if(nrow(ref_sub)>0){
      result_2[counter:(counter - 1 + nrow(ref_sub)),] <- as.matrix(ref_sub)
      counter <- counter + nrow(ref_sub)
    }
  }
  
  result_2 <- data.frame(result_2)
  names(result_2) <- c("x", "y", "other")
  
  result_2 <- result_2 %>% filter(!is.na(x)) %>% group_by(x, y) %>% 
                summarise_all(mean) %>% ungroup() %>% data.frame()
  
  result <- rbind(result, result_2)
  combined <- ref %>% left_join(result)
  
  names(combined) <- c(names(ref), paste0(other_name, "_pm25"))
  return(combined)
}

dal <- read.csv("dh_ca_points.csv")
gbd <- read.csv("gbd_2016.csv")
gbd <- gbd %>% select(-X)
names(gbd) <- names(dal)
combine <- combine_data(dal, gbd, 0.1, 0.01, "gbd")

