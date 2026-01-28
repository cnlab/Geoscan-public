# intakeSummary.R

# A function to create a table of basic summary statistics by
# participant upon intake of geotracking data
# Designed to run AFTER stay events have been calculated

# Parameters - dataSet - a dataframe of geotracking observations created by uploadGeodata

# Outputs a dataframe to the global environment with summary stats

intakeSummary <- function(dataSet){
  
  require(tidyverse)
  require(lubridate)
  
 # myData = dataSet
  
  #intakeSummary <<- 
    #myData %>% 
  summary <- dataSet %>% 
  as.data.frame() %>%
  ungroup() %>%
  group_by(filename) %>% 
  summarize(n = n(), #n
            na_datetime = sum(is.na(datetime)), # number of NA datetime
            na_lat_lon = (sum(is.na(lat))), # number of NA lat/lon
            begin_datetime = min(datetime),
            end_datetime = max(datetime),
            stayEvents = n_distinct(stayeventgroup)) 

  #return(dataSet)
  return(summary)
  
  }

# Vignette

# cleanData %>% intakeSummary(.)