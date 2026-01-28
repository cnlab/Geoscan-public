# Update NJ Retailers Only

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

# Load stored retailer database, filter for only NJ observations

stored_nj <- read.csv("~/GitHub/geoscanning/Data/Retailers/all_Retailers_10_20_20.csv") %>%
  dplyr::select(canonical_names) %>%
  mutate_if(is.factor, as.character) %>%
  mutate(expiration_date = ymd(expiration_date),
         publish_date = ymd(publish_date)) %>%
  filter(state == "NJ")

# Load new data, impute expiration date, pub date and acount numbers

retailers_new_NJ <- read_excel("~/GitHub/geoscanning/Data/Retailers/NJ/NJ Cigarette Retailers 2021 (OPRA C172455).xlsx", skip = 2)  %>%
  mutate(Zip = ifelse(str_length(Zip) == 9, str_sub(Zip, end = -5), Zip))%>%
  unite(., "address_full", sep = ", ",
        c("Street", "City", "State", "Zip")) %>%
  mutate(address_full = str_replace(address_full, "&", "AND"))%>%
  mutate(expired_y_n = "ACTIVE", 
         expiration_date = ymd("2022-03-31"),  # is this correct?
         publish_date = ymd("2021-04-01"),
         account = str_c("NJ_21", row_number(), sep = "_"), 
         license_type = NA, county = NA,
         state = "NJ",
         Trade = ifelse(is.na(Trade) == TRUE, Name, Trade)) %>% 
  rename(trade_name = Trade) %>% 
  dplyr::select(-Name)

# Join new and old retailers

NJ_join <- full_join(stored_nj, retailers_new_NJ, by = "address_full") %>%
  mutate(expired_y_n = ifelse(is.na(expiration_date.y) == TRUE, "EXPIRED", "ACTIVE"),
         expiration_date = if_else(expired_y_n == 'EXPIRED', expiration_date.x, ymd(expiration_date.y)),
         county = ifelse(is.na(county.y) == TRUE, county.x, county.y),
         publish_date = if_else(is.na(publish_date.y) == TRUE, publish_date.x, publish_date.y),
         license_type = ifelse(is.na(license_type.y) == TRUE, license_type.x, license_type.y),
         account = ifelse(is.na(account.x) == FALSE, account.x, account.y),
         trade_name = ifelse(is.na(trade_name.y) == FALSE, trade_name.y, trade_name.x),
         expiration_date = if_else(is.na(expiration_date.y) == FALSE, expiration_date.y, expiration_date.x),
         expiration_date = if_else(is.na(expiration_date.y) == FALSE, expiration_date.y, expiration_date.x),
         publish_date = if_else(is.na(publish_date.x) == FALSE, publish_date.x, publish_date.y),
         state = "NJ",
         county = NA) %>%
  select(-state.x, - state.y, -county.y, -county.x, -account.x, -account.y, -trade_name.y, -trade_name.x,
         -expired_y_n.x, -expired_y_n.y, -expiration_date.y, -expiration_date.x, -license_type.x, -license_type.y,
         -publish_date.x, -publish_date.y) %>%
  dplyr::select(canonical_names)


# Geocode missing observations

to_geocode_nj <- NJ_join %>%
  filter(is.na(lat) == TRUE)

geocoded_nj <- geocode(to_geocode_nj$address_full, source =  "google") %>%
  cbind(., to_geocode_nj %>%
          select(-lat, -lon)) %>%
  rbind(NJ_join %>%
          filter(is.na(lat) == FALSE), .)

summary(is.na(geocoded_nj$lat))

# Do an error check

errors_nj <- st_join(geocoded_nj %>% 
                       filter(is.na(lat) == FALSE) %>% 
                       st_as_sf(., coords = c("lon", "lat"), crs = 4326), 
                     nj_shp, 
                     join = st_within, 
                     left = TRUE) %>%
  filter(is.na(STUSPS) == TRUE) %>%
  mutate(lon=map_dbl(geometry, ~st_centroid(.x)[[1]]),
         lat=map_dbl(geometry, ~st_centroid(.x)[[2]]))%>%
  dplyr::select(canonical_names) %>%
  as.data.frame() %>%
  dplyr::select(-geometry) %>%
  rbind(., geocoded_nj %>%
          filter(is.na(lat) == TRUE)%>%
          dplyr::select(canonical_names))

summary(is.na(errors_nj$lat))

nrow(errors_nj)

# Write out errors

write.csv(errors_nj, "filepath goes here")

# Manually geocode failures

geocoded_nj_fixed <- geocoded_nj %>%
  mutate(lat = ifelse(account == "NJ_21_39", 40.7500365, lat),
         lon = ifelse(account == "NJ_21_39", -74.4007652, lon)) %>%
  mutate(lat = ifelse(account == "NJ_21_355", 39.9564604, lat),
         lon = ifelse(account == "NJ_21_355", -74.3901497, lon)) %>%
  mutate(lat = ifelse(account == "NJ_21_1147", 40.8887832, lat),
         lon = ifelse(account == "NJ_21_1147", -74.2052412, lon)) %>%
  mutate(lat = ifelse(account == "NJ_21_2595", 40.0371906, lat),
         lon = ifelse(account == "NJ_21_2595", -74.6204419, lon)) %>%
  mutate(lat = ifelse(account == "NJ_21_3351", 40.6375167, lat),
         lon = ifelse(account == "NJ_21_3351", -74.2504544, lon)) %>%
  mutate(lat = ifelse(account == "NJ_21_5044", 39.6835413, lat),
         lon = ifelse(account == "NJ_21_5044", -74.247067, lon)) %>%
  mutate(lat = ifelse(account == "NJ_21_7350", 40.8084251, lat),
         lon = ifelse(account == "NJ_21_7350", -74.0699432, lon)) %>%
  mutate(lat = ifelse(account == "NJ_21_7492", 39.3790428, lat),
         lon = ifelse(account == "NJ_21_7492", -74.5570303, lon)) %>%
  mutate(lat = ifelse(account == "NJ_21_7964", 40.1908179, lat),
         lon = ifelse(account == "NJ_21_7964", -74.0220776, lon)) %>%
  mutate(lat = ifelse(account == "NJ_21_8162", 40.7058303, lat),
         lon = ifelse(account == "NJ_21_8162", -74.0863637, lon)) %>%
  mutate(lat = ifelse(account == "NJ_21_8241", 39.823292, lat),
         lon = ifelse(account == "NJ_21_8241", -75.1625697, lon)) %>%
  mutate(lat = ifelse(account == "NJ_21_8320", 40.4835723, lat),
         lon = ifelse(account == "NJ_21_8320", -74.4802993, lon)) %>%
  mutate(lat = ifelse(account == "NJ_21_8420", 40.3166463, lat),
         lon = ifelse(account == "NJ_21_8420", -73.9811359, lon)) %>%
  mutate(lat = ifelse(account == "NJ_21_8489", 40.9451284, lat),
         lon = ifelse(account == "NJ_21_8489", -74.1476539, lon))

# Append to the rest of the retailers and write it out

allStates_updated <- read.csv("~/GitHub/geoscanning/Data/Retailers/all_Retailers_10_20_20.csv") %>%
  dplyr::select(canonical_names) %>%
  mutate_if(is.factor, as.character) %>%
  mutate(account = as.character(account)) %>%
  mutate(expiration_date = ymd(expiration_date),
         publish_date = ymd(publish_date)) %>%
  filter(state != "NJ") %>%
  rbind(., geocoded_nj_fixed)

write.csv(allStates_updated, "~/GitHub/geoscanning/Data/Retailers/all_Retailers_5_20_21.csv")
