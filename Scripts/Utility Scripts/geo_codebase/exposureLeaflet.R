# exposureLeaflet.R

# Visualizes a random 5% sample of geotracking observations subdivided by subject
# With stay events visualized by size and exposures in red
# Parameters - dataSet, mph_thresh
# dataSet needs to have gone through retailer spatial join
# mph_thresh is a numeric value in mph that helps determine exposure status

exposureLeaflet <- function(dataSet, mph_thresh){
  
  require(tidyverse)
  require(leaflet)
  require(leaflet.providers)
  require(leaflet.extras)
  
  getmode <- function(v) {
    uniqv <- na.omit(unique(v))
    uniqv[which.max(tabulate(match(v, uniqv)))]
  }
  
  dataSet <- dataSet %>% 
    as.data.frame() %>% ungroup() %>%
    mutate(filename = as.factor(filename))
  dataSet.df <- dataSet %>% 
    filter(is.na(trade_name) == FALSE & lagmph < mph_thresh) %>% 
    group_by(filename, lat, lon, datetime) %>% 
    slice(1) %>% 
    ungroup() %>% 
    mutate(is_stay_event = ifelse(grepl("NA", stayeventgroup) == FALSE, 1, 0),
           likely_active_exposure = ifelse(datetime < expiration_date, 1, 0)) %>%
    rbind(., dataSet %>%
            filter(is.na(trade_name)== TRUE) %>%
            mutate(is_stay_event = ifelse(grepl("NA", stayeventgroup) == FALSE, 1, 0),
                   likely_active_exposure = 0)) %>%
    group_by(filename) %>%
    slice_sample(prop = .05) %>% # For large datasets, trim down to a more workable number of observations.
    ungroup()
  
  l <- leaflet() %>% 
    addProviderTiles(providers$Esri.WorldTopoMap) %>%
    setView(lng = getmode(dataSet.df$lon), lat = getmode(dataSet.df$lat), zoom = 11) %>%
    addScaleBar(position = "topleft")
  dataSet.df2 = split(dataSet.df, dataSet.df$filename)

  names(dataSet.df2) %>%
    purrr::walk( function(df) {
      
      pal <- colorFactor(c("navy", "red"), domain = c(1, 0))
      
      l <<- l %>%
        addCircleMarkers(data=dataSet.df2[[df]],
                         lng=~lon, 
                         lat=~lat,
                         radius = ~ifelse(is_stay_event == 1, 8, 3), 
                         fillOpacity =~ .5,
                         color =~pal(likely_active_exposure),
                         label=~paste("datetime:", datetime, ", Active (0/1)", likely_active_exposure, trade_name ),
                         group = df)
    })
  
  l %>%
    addLayersControl(
      overlayGroups = names(dataSet.df2),
      options = layersControlOptions(collapsed = TRUE)) %>%
    hideGroup(names(dataSet.df2))
}

# Vignette

# exposureLeaflet(cleanData_Retailers_Tracts, mph_thresh)