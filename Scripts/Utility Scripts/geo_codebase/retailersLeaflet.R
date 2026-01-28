# retailersLeaflet.R

# Visualizes tobacco retailers observations
# Parameters - dataSet (a csv of retailers with lat/lon observations)
# Outputs a leaflet map with retailers depicted according to
# active licensure

retailersLeaflet <- function(dataSet){

active <- dataSet %>%
  filter(expired_y_n == "ACTIVE")

expired <- dataSet %>%
  filter(expired_y_n != "ACTIVE")

m4 <- leaflet() %>%
  setView(lng = -77.475127, lat = 40.726604, zoom = 07) %>%
  addProviderTiles(providers$Esri.WorldTopoMap) %>%
  addCircleMarkers(lng= as.numeric(active$lon), 
                   lat= as.numeric(active$lat), 
                   radius = 1,
                   fillOpacity = 1,
                   color= "red",
                   label = paste(active$trade_name, "|",
                                 active$address_full),
                   group = "Active Retailers") %>%
  addCircleMarkers(lng= as.numeric(expired$lon), 
                   lat= as.numeric(expired$lat), 
                   radius = 0.5,
                   fillOpacity = 1,
                   color= "blue",
                   label = paste(expired$trade_name, "|",
                                 expired$address_full),
                   group = "Expired Retailers") %>%
  addLayersControl(
    overlayGroups = c("Active Retailers", 
                      "Expired Retailers"),
    options = layersControlOptions(collapsed = TRUE)) %>%
  addLegend(color = "blue", 
            labels = "Expired Retailers",
            group = "Expired Retailers",
            position = "topright") %>%
  addLegend(color = "red", 
            labels = "Active Retailers",
            group = "Active Retailers",
            position = "topright")  %>% 
  hideGroup(c("Expired Retailers")) %>%
  addScaleBar(position = "topleft")

m4 # Print the map
}

# Vignette

# retailersLeaflet(retailers)