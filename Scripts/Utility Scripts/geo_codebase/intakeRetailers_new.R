library(tidyverse)
library(sf)
library(lubridate)

filepath <- "/Volumes/cnlab/GeoRemote/Data/Retailers/all_Retailers_aug_2023_DissVersion_recoded.csv"

canonical_names <- c("county", "trade_name", "account", "license_type",
                     "expiration_date", "lat", "lon", "address_full",
                     "publish_date", "state", "expired_y_n")

retailers_test <- read.csv(filepath) %>%
  dplyr::select(all_of(canonical_names)) %>%
  mutate_if(is.factor, as.character) %>%
  mutate(account = as.character(account)) %>%
  mutate(publish_date = format(strptime(publish_date, format = "%m/%d/%y"), format = "%Y-%m-%d")) %>% 
  mutate(expiration_date = format(strptime(expiration_date, format = "%m/%d/%y"), format = "%Y-%m-%d"))
  
retailers_test %>% 
  nrow() %>% 
  print(.) # 47644 observations from raw data

# option 1
# for the same retailer store (same lat and lon)
# take the earliest publish date and the latest expiration date
# assume that there is no interuption in between the earliest publish date and latest expiration date
result1 <- retailers_test %>% 
  mutate(publish_date = na_if(publish_date, ""),
         expiration_date = na_if(expiration_date, ""),
         publish_date = ymd(publish_date),
         expiration_date = ymd(expiration_date)) %>% 
  group_by(lat, lon) %>%
  summarize(earliest_publish_date = min(publish_date, na.rm = TRUE),
            latest_expiration_date = max(expiration_date, na.rm = TRUE)) 
# 33796 distinct locations


# option 2 - creating a stack of publish date and expiration date pair
# among all data entires that belong to the same retailer store (same lat and lon)
# obtain the first pair of expiration and publish date pair
# loop through the entries from the same locations: 
  # entires where expiration date and publish date are the same, no update. 
  # entries where the expiration date are the same, but publish date are different, keep earlier publish date
  # entries where publish date are the same, but expiration date are different, keep later expiration date
  # entries where expiration date and publish date all different from before, keep both as their own entries

process_dates <- function(df) {
  library(dplyr)
  
  df <- df %>%
    dplyr::select(c(lat, lon, publish_date, expiration_date)) %>%
    mutate(publish_date = ymd(publish_date),
           expiration_date = ymd(expiration_date),
           lat = as.character(lat),
           lon = as.character(lon)) %>% 
    filter(!is.na(publish_date) & !is.na(expiration_date)) %>%
    arrange(lat, lon, expiration_date, publish_date) # group by different trade name
  
  result <- df[0, ] 
  unique_locations <- unique(df %>% select(lat, lon))
  
  for (loc in 1:nrow(unique_locations)) {
    loc_data <- df %>%
      filter(lat == unique_locations$lat[loc] & lon == unique_locations$lon[loc])
    
    if (nrow(loc_data) == 1){
      result <- rbind(result, loc_data)
    }
      
    if (nrow(loc_data) > 1) {
      compare_df <- loc_data[1, ]  # Start with the first row of the location data


      for (i in 2:nrow(loc_data)) {
        new_row <- loc_data[i, ]
        matched <- FALSE
        
        if (!is.na(new_row$publish_date) && !is.na(compare_df$publish_date) &&
            !is.na(new_row$expiration_date) && !is.na(compare_df$expiration_date)) {
          
          if (new_row$publish_date == compare_df$publish_date && 
              new_row$expiration_date == compare_df$expiration_date) {
            matched <- TRUE
            }
          if (new_row$expiration_date == compare_df$expiration_date && 
              new_row$publish_date != compare_df$publish_date) {
            compare_df$publish_date <- min(new_row$publish_date, compare_df$publish_date)
            matched <- TRUE
            }
          if (new_row$publish_date == compare_df$publish_date && 
              new_row$expiration_date != compare_df$expiration_date) {
            compare_df$expiration_date <- max(new_row$expiration_date, compare_df$expiration_date)
            matched <- TRUE
            }
          if (matched == FALSE) {
            
            if (new_row$expiration_date < compare_df$expiration_date && 
                new_row$publish_date > compare_df$publish_date) {
              # No need to do anything here
            } 
            result <- rbind(result, compare_df) 

            compare_df <- new_row
            }
        }
        
      }
    result <- rbind(result, compare_df)   
    }
    
  }
  
  return(result)
}

result2 <- process_dates(retailers_test)

## A list of test cases
# -75.1658879 for JFK (multiple occurences, complex case, merge, keep )
# -75.2321069 for MASON DIXON (simple case, just pick one)
# -75.1147327 for LIGHTHOUSE RD (date range within date range) the new function takes care of it
# -75.5701536 for CENTRAL AVE LAUREL DE (two different date range, keep two occurence)
# -75.2013466 merge publish date
# -75.102923  overlapping date range, do not fall entirely within
# -75.250581. this is a really fuzzy case


# option 3 - a simplified version from option 2 (pending)
process_dates_simplified <- function(df){
  library(dplyr)
  library(lubridate)
  
  # initial data preparation, same as before
  df <- df %>%
    select(lat, lon, publish_date, expiration_date) %>%
    mutate(
      publish_date = ymd(publish_date),
      expiration_date = ymd(expiration_date),
      lat = as.character(lat),
      lon = as.character(lon)
    ) %>%
    filter(!is.na(publish_date) & !is.na(expiration_date)) %>%
    arrange(lat, lon, publish_date, expiration_date)
  
  merge_intervals <- function(data) {
    data %>%
      arrange(publish_date) %>% # sort the data by publish date
      mutate(
        lag_expiration_date = lag(expiration_date),
        lag_publish_date = lag(publish_date)
      ) %>%
      group_by(group = cumsum(is.na(lag_expiration_date) | publish_date > lag_expiration_date)) %>%
      summarize(
        lat = first(lat),
        lon = first(lon),
        publish_date = min(publish_date),
        expiration_date = max(expiration_date)
      ) %>%
      ungroup() %>%
      select(-group) # Removes the temporary group column. 
  }
  
  result <- df %>%
    group_by(lat, lon) %>%
    do(merge_intervals(.)) %>%
    do(merge_intervals(.)) %>%
    ungroup()
  
  return(result)
}


result3 <- process_dates_simplified(retailers_test)

result3.1 <- process_dates_simplified(result3)

results4 <- process_dates_simplified(retailers_test)