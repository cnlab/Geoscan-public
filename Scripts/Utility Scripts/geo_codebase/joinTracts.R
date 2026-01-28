# joinTracts.R

# Spatially join geotracking data to their respective Census Tracts
# so they can be associated with demographic and economic data as needed

# Parameters

# geotracking point data - an sf object
# year - year for which tracts are requested
# lat, lon - maybe need these if using a csv with lat/lon

# Returns an sf object with tract GEOID
# Defaults to 2010-2019 Tracts if year is not specified

joinTracts <- function(pointData, year){
  
  require(tidyverse)
  require(tigris)
  require(sf)
  
  ifelse(class(pointData) %>% as.list() %>% .[1] != "sf", print("pointData is not an sf object and must be converted. "),
         "pointData is an sf object")
  
  options(tigris_class = "sf")
  
  # Load all states using tigris
  
  allStates <- states(year = year)%>%
    st_as_sf() %>%
    st_transform(crs=4326)
  
  # Spatial join to determine which states need to be called
  # for tract spatial data, return only unique State GEOIDs

  myStates <- st_join(pointData %>%
            st_transform(crs = 4326), 
            allStates %>%
            dplyr::select(GEOID) %>%
            st_transform(crs = 4326), 
          join = st_intersects, 
          left = TRUE) %>%
          as.data.frame() %>% 
          dplyr::select(GEOID) %>% 
    unique() %>% 
    na.omit()
  
  # lapply the tracts function from tigris to each unique GEOID,
  # bind_rows to create a single sf object
  
  stateTracts <- lapply(myStates$GEOID, tracts) %>%
    bind_rows(.)
  
  # Join points to tracts, return points with only
  # the tract GEOID and NAMELSAD attached.
  
  pointData_Tracts <- st_join(pointData %>%
                                     st_transform(crs = 4326), 
                                   stateTracts %>%
                                     dplyr::select(GEOID, NAMELSAD) %>%
                                     st_transform(crs = 4326), 
                                   join = st_intersects, 
                                   left = TRUE)
  
  return(pointData_Tracts)
    
}

# how it works:
# load all states
# spatial join to determine states in data set
# load tracts from those states only
# spatial join again
# select out columns you don't need
# return csv with lat/lon

# Create vignette