# intakeRetailers.R
# Takes outputs from Geoscanning Retailer Code published as RMD

# Parameters:
# filepath - the location of the most recent retailer codebase, csv file

# Output:
# csv

# Next step is to convert to sf, buffer and join to geotracking observations


intakeRetailers <- function(filepath){
  
  require(tidyverse)
  require(sf)
  
  canonical_names <- c("county", "trade_name", "account", "license_type",
                       "expiration_date", "lat", "lon", "address_full",
                       "publish_date", "state", "expired_y_n")
  
  retailers <- read.csv(filepath) %>%
    dplyr::select(all_of(canonical_names)) %>%
    mutate_if(is.factor, as.character) %>%
    mutate(account = as.character(account)) #%>%
   # mutate(expiration_date = ymd(expiration_date),
          # publish_date = ymd(publish_date))
  
  key_columns <- c("county", "trade_name", "account", "license_type", "state")
  retailer_edits = read_csv(file.path("/Volumes/cnlab/GeoRemote/Data/Retailers","RetailersData_PA_DE_2024_NJ_2022_updated_edits.csv")) %>%
    filter(!is.na(edit))
  retailers <- retailers %>%
    # Remove rows from 'retailers' that match any row in 'retailer_edits' based on the key columns
    anti_join(retailer_edits, by = key_columns) %>%
    # Add the rows from 'retailer_edits' to replace the removed rows
    bind_rows(retailer_edits)
  
  ifelse(names(retailers) != canonical_names, 
       print("WARNING: Column names are non-standard"), 
       print("Column names match standard names"))
  
  cat("\nData contain\n")

  retailers %>%
    filter(is.na(lat) == TRUE) %>%
    nrow() %>%
    print(.)

  print("NA geodata observations")
  
  retailers <- retailers %>% 
    mutate(license_loc_twin = (duplicated(paste(lat, lon)) & duplicated(expiration_date)))
  
  retailers %>%
    filter(license_loc_twin == TRUE) %>%
    nrow() %>%
    print(.)
  
  print("duplicated licenses with the same geolocation coordinates and expiration date")
  
  return(retailers)
  
}

# Vignette
# retailersTest <- intakeRetailers("//jove.design.upenn.edu/Dept-Shares/prax/01 Project Folders/2019_Annenberg_GeoScanning/dataOutputs/all_Retailers_10_20_20.csv")
