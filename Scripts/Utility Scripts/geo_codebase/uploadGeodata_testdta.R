# uploadGeodata.R

# A function to load geolocation json data from a folder location and
# clean it.

# Parameters: filePath - a text string denoting the location of a folder containing json files

# Dependencies: tidyverse, jsonlite

uploadGeodata_testdta <- function(filePath){
  
  require(tidyverse)
  require(jsonlite)

loadJSON <- function(jsonFilename){fromJSON(jsonFilename, 
                                            simplifyDataFrame = TRUE, 
                                            flatten = TRUE)%>%
    .[1] %>% 
    as.data.frame() %>%
    mutate(lat = locations.latitudeE7 / 1e7, # put the decimal in the right place for the lat
           lon = locations.longitudeE7 / 1e7, # put the decimal in the right place for the lat
           datetime = as.POSIXct(as.numeric(locations.timestampMs)/1000, # go from unix time to POSIXct date time
                                 origin = "1970-01-01")) %>%
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
