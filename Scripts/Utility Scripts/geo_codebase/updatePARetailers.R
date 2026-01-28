# Update PA Retailers Only

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

## 4.1. Load new data from Socrata

retailers_Socrata_pa <- read.socrata("https://data.pa.gov/resource/ut72-sft8.json") %>%
  filter(county != "UNKNOWN/OUT OF STATE",
         license_type != "Vending") %>%
  mutate(publish_date = today(tzone = "America/New_York"),
         state = "PA",
         expiration_date = ymd(expiration_date)) %>%
  rename(lat = location_1.latitude,
         lon = location_1.longitude,
         address_full = location_1.human_address) %>%
  dplyr::select(-legal_name, -postal_code, -country) %>%
  mutate_if(is.factor, as.character) %>%
  mutate(address_full = str_replace(address_full, "&", "AND"))

# Load stored retailer database, filter for only PA observations

stored_pa <- read.csv("~/GitHub/geoscanning/Data/Retailers/all_Retailers_5_20_21.csv") %>%
  dplyr::select(canonical_names) %>%
  mutate_if(is.factor, as.character) %>%
  mutate(expiration_date = ymd(expiration_date),
         publish_date = ymd(publish_date)) %>%
  filter(state == "PA")

# Join the new and the stored data

joined_pa <- full_join(stored_pa, 
                       retailers_Socrata_pa, by = c("account", "trade_name")) %>%
  mutate(expired_y_n = ifelse(is.na(expiration_date.y) == TRUE, "EXPIRED", "ACTIVE"),
         expiration_date = if_else(expired_y_n == 'EXPIRED', expiration_date.x, ymd(expiration_date.y)),
         lat = ifelse(is.na(lat.x) == FALSE, lat.x, lat.y),
         lon = ifelse(is.na(lon.x) == FALSE, lon.x, lon.y),
         address_full = ifelse(is.na(address_full.x) == FALSE, address_full.x, address_full.y),
         county = ifelse(is.na(county.y) == TRUE, county.x, county.y),
         publish_date = if_else(is.na(publish_date.y) == TRUE, publish_date.x, publish_date.y),
         license_type = ifelse(is.na(license_type.y) == TRUE, license_type.x, license_type.y),
         state = "PA") %>%
  dplyr::select(-lat.x, -lon.x, -lat.y, -lon.y, 
                -address_full.x, -address_full.y, -county.x, -county.y,
                -publish_date.x, -publish_date.y, -state.x, -state.y, -license_type.x, -license_type.y,
                -expiration_date.x, -expiration_date.y)

# See how many NAs we have in our geolocations

summary(is.na(joined_pa$lat))

# Do a first pass at geocoding

to_geocode_pa <- joined_pa %>%
  filter(is.na(lat) == TRUE)

geocoded_pa <- geocode(to_geocode_pa$address_full, source =  "google") %>%
  cbind(., to_geocode_pa %>%
          select(-lat, -lon)) %>%
  rbind(joined_pa %>%
          filter(is.na(lat) == FALSE), .)

summary(is.na(geocoded_pa$lat))

# Perform an error check for bad geocodes

errors_pa <- st_join(geocoded_pa %>% 
                       filter(is.na(lat) == FALSE) %>% 
                       st_as_sf(., coords = c("lon", "lat"), crs = 4326), 
                     pa_shp, 
                     join = st_within, 
                     left = TRUE) %>%
  filter(is.na(STUSPS) == TRUE) %>%
  mutate(lon=map_dbl(geometry, ~st_centroid(.x)[[1]]),
         lat=map_dbl(geometry, ~st_centroid(.x)[[2]]))%>%
  dplyr::select(canonical_names) %>%
  as.data.frame() %>%
  dplyr::select(-geometry) %>%
  rbind(., geocoded_pa %>%
          filter(is.na(lat) == TRUE))

# Manually geocode failures

geocoded_pa_fixed <- geocoded_pa %>%
  mutate(lat = ifelse(account %in% c("02**1873", "33**3114"), NA, lat),
         lon = ifelse(account %in% c("02**1873", "33**3114"), NA, lon)) %>%
  mutate(lat = ifelse(account == "70**5157", 42.074211070532854,  lat),
         lon = ifelse(account == "70**5157", -80.14327133127297, lon)) %>%
  mutate(lat = ifelse(account %in% c("25**1938", "25**8306"), 42.210053022150504,   lat),
         lon = ifelse(account %in% c("25**1938", "25**8306"), -79.84988587711423, lon)) %>%
  mutate(lat = ifelse(account == "09**0009", 40.12615975272745,  lat),
         lon = ifelse(account == "09**0009", -74.83672149886412,  lon)) %>%
  mutate(lat = ifelse(account == "40**3538", 41.33283809763932,  lat),
         lon = ifelse(account == "40**3538", -75.95459226289694,  lon)) %>%
  mutate(lat = ifelse(account == "09**2991", 40.10934146246511,   lat),
         lon = ifelse(account == "09**2991", -74.95117508837193,  lon))

# Append to the rest of the retailers and write it out

allStates_updated <- read.csv("~/GitHub/geoscanning/Data/Retailers/all_Retailers_5_20_21.csv") %>%
  dplyr::select(canonical_names) %>%
  mutate_if(is.factor, as.character) %>%
  mutate(account = as.character(account)) %>%
  mutate(expiration_date = ymd(expiration_date),
         publish_date = ymd(publish_date)) %>%
  filter(state != "PA") %>%
  rbind(., geocoded_pa_fixed)

write.csv(allStates_updated, "~/GitHub/geoscanning/Data/Retailers/all_Retailers_5_26_21.csv")
