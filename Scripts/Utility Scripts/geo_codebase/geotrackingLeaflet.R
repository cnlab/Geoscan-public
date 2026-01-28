# geotrackingLeaflet.R

# Visualizes geotracking observations subdivided by subject
# Parameters - dataSet, stayEvents
# If stayEvents is TRUE, the map outputs stay events
# otherwise it shows all geotracking observations

geotrackingLeaflet <- function(dataSet, stayEvents = FALSE){

require(tidyverse)
require(leaflet)
require(leaflet.providers)
require(leaflet.extras)
  
  stayeventgroup <- filter(dataSet,
                       is.na(stayeventgroup) == FALSE)
  
  if(stayEvents == TRUE) {dataSet.df = split(stayeventgroup %>% as.data.frame(), stayeventgroup$filename)}
  if(stayEvents == FALSE) {dataSet.df = split(dataSet %>% as.data.frame(), dataSet$filename)}


#stayEvents <- cleanData %>%
#  filter(is.na(stayeventgroup) == FALSE)

l <- leaflet() %>% 
  addProviderTiles(providers$Esri.WorldTopoMap) %>%
  setView(lng = mean(dataSet$lon, na.rm = TRUE), mean(dataSet$lat, na.rm = TRUE), zoom = 07) %>%
  addScaleBar(position = "topleft")
  

  names(dataSet.df) %>%
    purrr::walk( function(df) {
      l <<- l %>%
        addCircleMarkers(data=dataSet.df[[df]],
                   lng=~lon, 
                   lat=~lat,
                   radius =~ 1, 
                   fillOpacity =~ 1,
                   color =~ "blue",
                   label=~paste("datetime:", datetime, ", rg_hr:", rg_hr ),
                   group = df)
    })
  
  l %>%
    addLayersControl(
      overlayGroups = names(dataSet.df),
      options = layersControlOptions(collapsed = FALSE))
}
   
# Vignette

# geotrackingLeaflet(cleanData, FALSE)