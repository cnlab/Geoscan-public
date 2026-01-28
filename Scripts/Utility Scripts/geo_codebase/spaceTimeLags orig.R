# Space Time Indicators
# After you do stay events and radius of gyration
# You do this

# requirements: lat/lon in 4326, grouping called filename, date called datetime (these can be parameterized)
# Parameter myCRS should be in feet. Go to spatialreference.org to find a 4 digit CRS for your study
# area if you are doing this outside of Southern PA (the code should work for data nearby but will
# distort if a large or faraway area is used)

spaceTimeLags <- function(dataframe, myCRS){

require(tidyverse)
require(sf)
require(lubridate)

  # Check for poorly arranged data
  sortdata <- dataframe %>% arrange(filename, datetime)
  if (sum(dataframe$datetime!=sortdata$datetime)>0) {
    message("Data were not sorted first by participant ID and then by date/time. spaceTimeLags has now sorted the data accordingly.")
    dataframe <- dataframe %>% arrange(filename, datetime)
  }
  
  # Convert data frame to sf
  dataframe <- dataframe %>%
    filter(is.na(lat) == FALSE & is.na(lon) == FALSE) %>%
    st_as_sf(., coords = c("lon", "lat"), crs = 4326, remove = FALSE) %>%
      ungroup() %>%
      st_transform(crs = myCRS) %>%
      mutate(y_ft=map_dbl(geometry, ~st_centroid(.x)[[1]]),
             x_ft=map_dbl(geometry, ~st_centroid(.x)[[2]])) %>%
      group_by(filename) %>%
      mutate(lagDist_ft = sqrt(((lag(x_ft) - x_ft)^2) + ((lag(y_ft) - y_ft)^2)),
             lagTime = abs(datetime - lag(datetime)), 
             lagmph = (lagDist_ft/5280) / (as.numeric(lagTime) / (60*60)),
             leadDist_ft = sqrt(((lead(x_ft) - x_ft)^2) + ((lead(y_ft) - y_ft)^2)),
             leadTime = abs(datetime - lead(datetime)), 
             leadmph = (leadDist_ft/5280) / (as.numeric(leadTime) / (60*60)),
             lead_lag_avg_mph = (leadmph + lagmph)/2,
             mean_3_lagDist_ft = (lag(lagDist_ft, 1) + lag(lagDist_ft, 2) + lag(lagDist_ft, 3))/3) %>%
      dplyr::select(-c(x_ft, y_ft, leadDist_ft, leadmph)) %>%
    ungroup()

return(dataframe)
}

# test <- spaceTimeLags(cleanData, 2272)
