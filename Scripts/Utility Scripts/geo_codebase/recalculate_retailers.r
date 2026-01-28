library(ggmap)
library(ratelimitr)
haversine_distance_feet <- function(lat1, lon1, lat2, lon2) {
  # Radius of the Earth in kilometers
  R <- 6371
  
  # Convert latitude and longitude from degrees to radians
  lat1 <- lat1 * pi / 180
  lon1 <- lon1 * pi / 180
  lat2 <- lat2 * pi / 180
  lon2 <- lon2 * pi / 180
  
  # Differences between latitudes and longitudes
  dlat <- lat2 - lat1
  dlon <- lon2 - lon1
  
  # Haversine formula
  a <- sin(dlat/2)^2 + cos(lat1) * cos(lat2) * sin(dlon/2)^2
  c <- 2 * atan2(sqrt(a), sqrt(1 - a))
  distance_km <- R * c
  
  # Convert kilometers to feet (1 kilometer = 3280.84 feet)
  distance_feet <- distance_km * 3280.84
  
  return(distance_feet)
}
source("/Volumes/cnlab/GeoRemote/Scripts/Utility Scripts/geo_codebase/intakeRetailers.R")
retailers <- intakeRetailers("/Volumes/cnlab/GeoRemote/Data/Retailers/all_Retailers_aug_2023_DissVersion.csv")

retailers = retailers %>%
  mutate(old_lat = lat,
         old_lon = lon,
         lat = NA,
         lon = NA)

rate = rate(n = 3000, period = 180)
geocode_ratelimit = limit_rate(geocode, rate)

for (idx in 1:nrow(retailers)) {
  if (retailers$geo_diff[idx] > 1500) {
    geo_values <- geocode(retailers$address_full[idx])
    if (!is.na(geo_values$lat)) {
      retailers$lat[idx] <- geo_values$lat
    }
    
    # Update longitude if available
    if (!is.na(geo_values$lon)) {
      retailers$lon[idx] <- geo_values$lon
    }
  }
  if (!is.na(retailers$lat[idx])) {next}
  # Check if latitude is missing and old latitude exists
  if (is.na(retailers$lat[idx]) & !is.na(retailers$old_lat[idx])) {
    geo_values <- geocode(retailers$address_full[idx])
    if (!is.na(geo_values$lat)) {
      retailers$lat[idx] <- geo_values$lat
    }
    
    # Update longitude if available
    if (!is.na(geo_values$lon)) {
      retailers$lon[idx] <- geo_values$lon
    }
  }
}

retailers_under_1500 = retailers %>%
  filter(geo_diff <= 1500)

retailers_over_1500 = retailers %>%
  filter(geo_diff > 1500)

retailer_addresses_over_1500 = unique(retailers_over_1500$address_full)

fix_address = retailers_over_1500[grepl("\\{.*\\}", retailers_over_1500$address_full),]
for (idx in 1:nrow(fix_address)) {
  address_object = fix_address$address_full[idx]
  address_string = transform_json(address_object)
  x = geocode(address_string)
  retailers_over_1500[retailers_over_1500$address_full==address_object,]$lat = x$lat
  retailers_over_1500[retailers_over_1500$address_full==address_object,]$lon = x$lon
}




for (idx in 1:length(fix_address)) {
  address = fix_address[idx]
  
  geo_values <- geocode(address)
  retailers_over_1500[retailers_over_1500$address_full==address,]$lat = geo_values$lat
  retailers_over_1500[retailers_over_1500$address_full==address,]$lon = geo_values$lon
}

retailers = bind_rows(retailers_under_1500, retailers_over_1500)

retailers = retailers %>%
  group_by(rownames(retailers)) %>%
  mutate(geo_diff = haversine_distance_feet(lat, lon, old_lat, old_lon)) %>%
  ungroup() %>%
  select(-c("rownames(retailers)"))





