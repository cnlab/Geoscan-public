# uploadGeodata.R

# A function to load geolocation json data from a folder location and
# clean it.

# Parameters: filePath - a text string denoting the location of a folder containing json files

# Dependencies: tidyverse, jsonlite
#Updated March 2023 to work for participant data 

uploadGeodata <- function(filePath){
  
  require(tidyverse)
  require(jsonlite)
  

  
  loadJSON <- function(jsonFilename){
      df <- fromJSON(jsonFilename, 
      simplifyDataFrame = TRUE, 
      flatten = TRUE)   %>%
      .[1] %>% 
      as.data.frame()

      mutate(df, lat = locations.latitudeE7 / 1e7, # put the decimal in the right place for the lat
             lon = locations.longitudeE7 / 1e7, # put the decimal in the right place for the lat
             datetime = as.POSIXct(locations.deviceTimestamp, format="%Y-%m-%dT%H:%M:%OSZ") # convert to POSIXct date time
                                   ) %>%
      select(datetime, lat, lon, locations.altitude,
            locations.velocity, locations.accuracy) # select only what you need
    
  }
  
  paths <- dir(filePath, pattern = "\\.json$", full.names = TRUE)
  names(paths) <- basename(paths)
  myData <- map_dfr(paths, loadJSON, .id = "filename")
  
  return(myData)
}

# Vignette

# Using the test data from the geoscanning github repo:

# test <- uploadGeodata("Data/Geotracking/multi_json_test")
