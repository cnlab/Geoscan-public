

intakeRetailers <- function(filepath){
  
  require(tidyverse)
  require(lubridate)
  require(dplyr)
  
  canonical_names <- c("county", "trade_name", "account", "license_type",
                       "expiration_date", "lat", "lon", "address_full",
                       "publish_date", "state", "expired_y_n")
  
  df <- read.csv(filepath) %>%
    dplyr::select(all_of(canonical_names)) %>%
    mutate_if(is.factor, as.character) %>%
    mutate(account = as.character(account)) %>%
    # uncomment the code here if necessary
    #mutate(publish_date = format(strptime(publish_date, format = "%m/%d/%y"), format = "%Y-%m-%d")) %>% 
    #mutate(expiration_date = format(strptime(expiration_date, format = "%m/%d/%y"), format = "%Y-%m-%d")) %>% 
    dplyr::select(c(lat, lon, publish_date, expiration_date)) %>%
    mutate(publish_date = ymd(publish_date),
           expiration_date = ymd(expiration_date),
           lat = as.character(lat),
           lon = as.character(lon)) %>% 
    filter(!is.na(publish_date) & !is.na(expiration_date)) %>%
    arrange(lat, lon, expiration_date, publish_date) 
  
  merge_intervals <- function(data) {
    data %>%
      arrange(publish_date) %>% 
      mutate(lag_expiration_date = lag(expiration_date),
             lag_publish_date = lag(publish_date)) %>%
      group_by(group = cumsum(is.na(lag_expiration_date) | publish_date > lag_expiration_date)) %>%
      summarize(lat = first(lat),
                lon = first(lon),
                publish_date = min(publish_date),
                expiration_date = max(expiration_date)) %>%
      ungroup() %>%
      select(-group)
  }
  
  result <- df %>%
    group_by(lat, lon) %>%
    do(merge_intervals(.)) %>%
    do(merge_intervals(.)) %>%
    ungroup()
  
  return(result)
  
}