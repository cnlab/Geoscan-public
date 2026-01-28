# Update DE Retailers Only

# Code is fully documented in markdown entitled clean_retailers_v3.Rmd / clean_retailers_v3.html

# --- Load Packages ----

library(tidyverse)
library(sf)
library(tigris)
library(tidycensus)
library(lubridate)
library(ggmap)
library(jsonlite)
library(RSocrata)
library(readxl)
library(leaflet)
library(leaflet.providers)
library(readxl)

# Load API key

register_google(key = "YOUR KEY GOES HERE")

# Load canonical names

canonical_names <- c("county", "trade_name", "account", "license_type",
                     "expiration_date", "lat", "lon", "address_full",
                     "publish_date", "state", "expired_y_n")

# Load states for trouble shooting

states_shp <- states()  %>%
  st_as_sf() %>%
  st_transform(crs = 4326)

pa_shp <- states_shp %>%
  filter(STUSPS == "PA")

nj_shp <- states_shp %>%
  filter(STUSPS == "NJ")

de_shp <- states_shp %>%
  filter(STUSPS == "DE")

# Read new data from socrata

## NOTE THAT THE cateogries have changed for how they describe tobacco retailers!

retailers_Socrata_de <- read.socrata("https://data.delaware.gov/resource/5zy2-grhr.json") %>%
  filter(str_detect(category, "CIGARETTE/TOBACCO PRODUCTS SELLER") | 
           str_detect(category, "TOBACCO RETAILER")) %>%
  mutate(publish_date = ymd(current_license_valid_from),
         expiration_date = ymd(current_license_valid_to),
         expired_y_n = "ACTIVE",
         trade_name = business_name,
         county = NA,
         state = "DE") %>%
  rename(lat = geocoded_location.latitude,
         lon = geocoded_location.longitude,
         account = license_number,
         license_type = category) %>%
  mutate(zip = ifelse(str_length(zip) == 9, str_sub(zip, end = -5), zip)) %>%
  filter(zip >= 19701 & zip <= 19980) %>%
  unite(., "address_full", sep = " ",
        c("address_2", "city", "state", "zip")) %>%
  mutate(state = "DE") %>%
  dplyr::select(-business_name, -current_license_valid_from, 
                -current_license_valid_to, -country, -geocoded_location.human_address,
                -address_1) %>%
  mutate_if(is.factor, as.character) %>%
  mutate(address_full = str_replace(address_full, "&", "AND"))

# Load stored data

stored_de <- read.csv("~/GitHub/geoscanning/Data/Retailers/all_Retailers_5_26_21.csv") %>%
  dplyr::select(canonical_names) %>%
  mutate_if(is.factor, as.character) %>%
  mutate(expiration_date = ymd(expiration_date),
         publish_date = ymd(publish_date)) %>%
  filter(state == "DE")

# Join new and stored data

joined_de <- full_join(stored_de, 
                       retailers_Socrata_de, by = c("account", "trade_name")) %>%
  mutate(expired_y_n = ifelse(is.na(expiration_date.y) == TRUE, "EXPIRED", "ACTIVE"),
         expiration_date = if_else(expired_y_n == 'EXPIRED', expiration_date.x, ymd(expiration_date.y)),
         lat = ifelse(is.na(lat.x) == FALSE, lat.x, lat.y),
         lon = ifelse(is.na(lon.x) == FALSE, lon.x, lon.y),
         address_full = ifelse(is.na(address_full.x) == FALSE, address_full.x, address_full.y),
         county = ifelse(is.na(county.y) == TRUE, county.x, county.y),
         publish_date = if_else(is.na(publish_date.y) == TRUE, publish_date.x, publish_date.y),
         license_type = ifelse(is.na(license_type.y) == TRUE, license_type.x, license_type.y),
         state = "DE") %>%
  dplyr::select(-lat.x, -lon.x, -lat.y, -lon.y, 
                -address_full.x, -address_full.y, -county.x, -county.y, -expired_y_n.x, -expired_y_n.y,
                -publish_date.x, -publish_date.y, -state.x, -state.y, -license_type.x, -license_type.y,
                -expiration_date.x, -expiration_date.y)

# Geocode missing info

to_geocode_de <- joined_de %>%
  filter(is.na(lat) == TRUE)

geocoded_de <- geocode(to_geocode_de$address_full, source =  "google") %>%
  cbind(., to_geocode_de %>%
          select(-lat, -lon)) %>%
  rbind(joined_de %>%
          filter(is.na(lat) == FALSE), .)

summary(is.na(geocoded_de$lat))

# There are no NA observations, so we do this
geocoded_de <- joined_de

# Check for bad geocodes

errors_de <- st_join(geocoded_de %>% 
                       filter(is.na(lat) == FALSE) %>% 
                       st_as_sf(., coords = c("lon", "lat"), crs = 4326), 
                     de_shp, 
                     join = st_within, 
                     left = TRUE) %>%
  filter(is.na(STUSPS) == TRUE) %>%
  mutate(lon=map_dbl(geometry, ~st_centroid(.x)[[1]]),
         lat=map_dbl(geometry, ~st_centroid(.x)[[2]]))%>%
  dplyr::select(canonical_names) %>%
  as.data.frame() %>%
  dplyr::select(-geometry) %>%
  rbind(., geocoded_de %>%
          filter(is.na(lat) == TRUE))

# Manually fix bad geocodes

geocoded_de_fixed <- geocoded_de %>%
  mutate(lat = ifelse(account == "2005208433", 39.64222847614057, lat),
         lon = ifelse(account == "2005208433", -75.64473202156881, lon))

# Put all the data back together

allStates_updated <- read.csv("~/GitHub/geoscanning/Data/Retailers/all_Retailers_5_26_21.csv") %>%
  dplyr::select(canonical_names) %>%
  mutate_if(is.factor, as.character) %>%
  mutate(account = as.character(account)) %>%
  mutate(expiration_date = ymd(expiration_date),
         publish_date = ymd(publish_date)) %>%
  filter(state != "DE") %>%
  rbind(., geocoded_de_fixed)

write.csv(allStates_updated, "~/GitHub/geoscanning/Data/Retailers/all_Retailers_5_26_21.csv")
