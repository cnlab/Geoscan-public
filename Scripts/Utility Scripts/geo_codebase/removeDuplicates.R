# removeDuplicates.R

# INCOMPLETE PENDING COMMENTS FROM TOM

# This function removes duplicated timestamps using a logic
# that tries to determine which duplicate is most likely to be an outlier based
# on time/space lag readings

# First remove exact duplicates where coordinates and time are exactly the same
# Then create rolling averages for lat and lon, grouping by filename and ordering by timestamp
# Rolling averages are computed separately for lead and lag and then these are averaged by timestamp
# Then let's calculate the distance between the actual lat/lon and the rolling lat/lon (e.g. center of mass)
# We call this dist_ctrGravity.
# Then we group by filename and datetime (e.g. each id/timestamp combo),
# We rank them by dist_ctrGravity (smallest first)
# And keep only the first obs (e.g. slice(1))
# We then ungroup and ditch most of the new variables we made

removeDuplicates <- function(dataframe){

  require(sf)
  require(tidyverse)
  require(lubridate)
  require(RcppRoll)
  require(stats)
  
  # Check for poorly arranged data before computing rolling averages
  sortdata <- dataframe %>% arrange(filename, datetime)
  if (sum(dataframe$datetime!=sortdata$datetime)>0) {
    message("Data were not sorted first by participant ID and then by date/time. removeDuplicates has now sorted the data accordingly.")
    dataframe <- dataframe %>% arrange(filename, datetime)
  }
  
  dataframe <- dataframe %>% 
    group_by(filename) %>%
    mutate(rollsdlat = roll_sd(lat, n = 2, align = "right", fill = 99),
           rollsdlon = roll_sd(lon, n = 2, align = "right", fill = 99),
           rollsdtime = roll_sd(datetime, n = 2, align = "right", fill = 99),
           duplicate = ((rollsdlat + rollsdlon + rollsdtime) == 0),
           tsDupsExact = sum(duplicate),               # number of exact duplicate timestamps by participant
           tsDupsSplit = n() - tsDupsExact) %>%        # placeholder for number of duplicate timestamps with split coordinates
    filter(duplicate == FALSE) %>% 
    mutate(rollLagLat = roll_mean(lat, n = 3, align = "right", fill = NA), 
           rollLagLon = roll_mean(lon, n = 3, align = "right", fill = NA),
           rollLeadLat = roll_mean(lat, n = 3, align = "left", fill = NA, weights = c(0,1,1)), 
           rollLeadLon = roll_mean(lon, n = 3, align = "left", fill = NA, weights = c(0,1,1))) %>%
    ungroup() %>%
    rowwise() %>%
    mutate(rollAvgLat = weighted.mean(c(rollLagLat, rollLeadLat), c(.6,.4), na.rm = TRUE),
           rollAvgLon = weighted.mean(c(rollLagLon, rollLeadLon), c(.6,.4), na.rm = TRUE),
           dist_ctrGravity = sqrt(((rollAvgLon - lon)^2) + ((rollAvgLat - lat)^2))) %>%
    group_by(filename, datetime) %>%
    arrange(dist_ctrGravity) %>%
    slice(1) %>%
    ungroup() %>%
    group_by(filename) %>%
    mutate(tsDupsSplit = tsDupsSplit - n()) %>% # update number for duplicate timestamps with split coordinates
    dplyr::select(-c(rollsdlat,
                     rollsdlon,
                     rollsdtime,
                     duplicate,
                     rollLagLat,
                     rollLagLon,
                     rollLeadLat,
                     rollLeadLon,
                     rollAvgLat,
                     rollAvgLon)) %>%
    ungroup()

return(dataframe)
}