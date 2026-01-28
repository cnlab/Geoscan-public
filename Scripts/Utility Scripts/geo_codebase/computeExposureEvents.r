## Adapted from Ben Muzekari's RMarkdown GeoRemote/Scripts/Aim 1/ComputeExposureEvents.Rmd
library(pacman)
p_load(plyr, dplyr, tidyverse,
       sf, # Will need to install GDAL on your computer
       ggplot2, tigris, tidycensus,
       jsonlite, devtools, 
       leaflet, leaflet.providers, leaflet.extras,
       lubridate)

tryCatch(
  {
  p_load_gh("nyu-mhealth/Mobility")
  },
  error = function(e) {
    # Print the error message
    devtools::install_github("nyu-mhealth/Mobility")
  }
)

# Load scripts from geocodebase
geocodebase_directory = "/Volumes/cnlab/GeoRemote/Scripts/Utility Scripts/geo_codebase/"
geocodebase_scripts = c(
  "uploadGeodata.R", "cleanDates.R",
  "spaceTimeLags.R", "intakeRetailers.R",
  "bufferAndJoin.R", "joinTracts.R",
  "indirectMLM.R", 
  "geotrackingLeaflet.R", "retailersLeaflet.R", "exposureLeaflet.R",
  "intakeSummary.R", "graphicsFunctions.R",
  "removeDuplicates.R"
)
for (script in geocodebase_scripts) {source(paste0(geocodebase_directory, script))}


# load retailer data
retailers_filename = "all_Retailers_aug_2023_DissVersion.csv"
retailers <- intakeRetailers("/Volumes/cnlab/GeoRemote/Data/Retailers/all_Retailers_aug_2023_DissVersion_recoded.csv")
original_retailers <- intakeRetailers("/Volumes/cnlab/GeoRemote/Data/Retailers/all_Retailers_aug_2023_DissVersion.csv")

#NJ data: the retailers from April 2023 to August 2023 in the NJ data set are not up to date due to a clerical error from the NJ state tobacco license process. For the the present analysis, we have assumed the same retailers from March 2023 still hold active licenses because there is not that much of a high turn over rate (confirm) and we assume this will not have a huge impact if not up to date because only X% of participants from April 2023 - Aug 2023 reside in NJ.


# Correct datetime format
# geodata$datetime = as.POSIXct(
#                       strptime(
#                         geodata$datetime, format = "%Y-%m-%dT%H:%M:%S"), 
#                       tz = "EST")
# 
# 
# computeExposureEvents <- function(radius, t, df = geodata, retailers=retailers) {
#   output = list()
#   
#   exposureEvents = df %>% #update time to the time parameter used 
#     stayevent(df = .,  
#               coor = c("lon","lat"), 
#               time = "datetime", 
#               dist.threshold = radius/3.28084, # conversion from feet to meters PARAMETER -  specifying stay event of 100ft between time points 
#               time.threshold = t, # time PARAMETER, 
#               time.units = "mins", 
#               groupvar = "filename") %>%
#     mutate(rg_hr = radiusofgyration(., 
#                                     coor = c("lon","lat"), 
#                                     time = "datetime", 
#                                     time.units = "hour", # PARAMETER
#                                     groupvar = "filename")) %>%
#     spaceTimeLags(., 2272) %>%
#     intakeSummary(.) %>%
#     bufferAndJoin( retailers, ., 2272, 25) %>% #set last number to the buffer zone you want in feet
#     joinTracts(., year = 2020) %>% # we don't really need this as we're not looking at census tract, but could be useful to keep
#     mutate(publish_date = format(strptime(publish_date, format = "%m/%d/%y"), format = "%Y-%m-%d")) %>% 
#     mutate(expiration_date = format(strptime(expiration_date, format = "%m/%d/%y"), format = "%Y-%m-%d")) %>% 
#     mutate(StayEvent = if_else(is.na(stayeventgroup), "No", "Yes"))
# 
#     ObsPerDay_df <- addObservationsPerDay(df=exposureEvents)
#     
#     exposureEvents <- df %>%
#       left_join(ObsPerDay_df, by = c('filename', 'day')) %>%
#       # group_by(lat, lon, publish_date, expiration_date, trade_name) %>%
#       # mutate(license_loc_twin = ifelse(n() > 1, "TRUE", "FALSE")) %>%
#       ungroup()
#     
#     output["exposures"] = exposureEvents
#     output["observations"] = obsPerDay_df
#     return(output)
# }

# BM testing:

computeExposureEvents <- function(radius, t, buffer, period = "baseline") {
  # load geodata
  if (period == "baseline"){
    geodata <- read.csv("/Volumes/cnlab/GeoRemote/Data/Geodata/clean/merged_baseline.csv")
  } else if (period == "intervention") {
    geodata <- read.csv("/Volumes/cnlab/GeoRemote/Data/Geodata/clean/merged_intervention.csv")
  }
  
  geodata$datetime <- as.POSIXct(geodata$datetime, format = "%Y-%m-%dT%H:%M:%S", tz = "America/New_York")
  
  # Load retailers
  retailers <- intakeRetailers("/Volumes/cnlab/GeoRemote/Data/Retailers/all_Retailers_aug_2023_DissVersion_recoded.csv")
  
  output = list()
  
  # Check if stay events are already saved
  stayEvents_filename = sprintf("/Volumes/cnlab/GeoRemote/Scripts/Aim 1/Output/StayEvents/cleanData_%sradius_%smins_%s.RData", radius, t, period)
  if (file.exists(stayEvents_filename)) {
    load(stayEvents_filename)
  } else {
  exposureEvents = geodata %>% #update time to the time parameter used 
    stayevent(df = .,  
              coor = c("lon","lat"), 
              time = "datetime", 
              dist.threshold = radius/3.28084, # conversion from feet to meters PARAMETER -  specifying stay event of 100ft between time points 
              time.threshold = t, # time PARAMETER 
              time.units = "mins", 
              groupvar = "filename") %>%
    mutate(rg_hr = radiusofgyration(., 
                                    coor = c("lon","lat"), 
                                    time = "datetime", 
                                    time.units = "hour", # PARAMETER
                                    groupvar = "filename")) %>%
    spaceTimeLags(., 2272) %>%
    intakeSummary(.)
  
  save(exposureEvents,
       file = stayEvents_filename)
  }


    exposureEvents = exposureEvents %>%
      bufferAndJoin( retailers, ., 2272, buffer) %>% #set last number to the buffer zone you want in feet
      joinTracts(., year = 2020) %>% # we don't really need this as we're not looking at census tract, but could be useful to keep
      mutate(publish_date = format(strptime(publish_date, format = "%m/%d/%y"), format = "%Y-%m-%d")) %>% 
      mutate(expiration_date = format(strptime(expiration_date, format = "%m/%d/%y"), format = "%Y-%m-%d")) %>% 
      mutate(StayEvent = if_else(is.na(stayeventgroup), "No", "Yes"))
    
  ObsPerDay_df <- addObservationsPerDay(df=exposureEvents)
  
  exposureEvents <- exposureEvents %>%
    left_join(ObsPerDay_df, by = c('filename', 'day')) %>%
    # group_by(lat, lon, publish_date, expiration_date, trade_name) %>%
    # mutate(license_loc_twin = ifelse(n() > 1, "TRUE", "FALSE")) %>%
    ungroup()
  
  output["exposures"] = exposureEvents
  output["observations"] = ObsPerDay_df
  return(output)
}

addObservationsPerDay = function(df) {
  ObPerDay <- table(df$filename, df$day)
  
  ObPerDay_df <- as.data.frame(ObPerDay)
  
  # Rename the columns to 'filename', 'day', and 'ObsPerDay'
  names(ObPerDay_df) <- c('filename', 'day', 'ObsPerDay')
  # Convert the 'day' column in ObPerDay2_df to numeric (double) type
  ObPerDay_df$day <- as.numeric(as.character(ObPerDay_df$day))
  #now finding google timeline sampling rate per hour for each participant and day
  ObPerDay_df <- ObPerDay_df %>% 
    mutate(ObsRatePerHour = ObsPerDay/24)
  
  # Join the data frames based on 'filename' and 'day'
  # df <- df %>%
  #   left_join(ObPerDay_df, by = c('filename', 'day'))
}

plotObservationsPerDay = function(radius, t, df) {
  ggplot(df, aes(x = day, y = ObsRatePerHour, group = filename, color = filename)) +
    geom_line() +
    scale_x_continuous(breaks = unique(df$day)) +
    labs(x = "Day", y = "ObsRatePerHour", title = "Rate of Google Timeline observations per hour for each participant") +
    guides(color = "none")  # Remove the color legend
}

createExposureEvents = function(df, ObsPerDay_df) {
  "
  Creating Exposure Variable 

  Immediate Exclusions from Exposure Computations:
    
    (1) Any observations outside of tristate area (by default because we don't have retailer data outside of this area). 
    (2) Rows without Retailer Info (-X obs with 100-ft buffer)
    (3) Rows without any lag speeds below 30 mph (-x obs with 100-ft buffer) - didn't remove but make a column marking this. Want to investigate this variable more. 
                                                       
    We therefore compute several variables that allow us to further determine whether or not an intersecting point-in-polygon incident is actually an exposure. By carrying along our inputed and measured speed variables and time lag variables we can figure out if there was a passby at high speed or actually some lingering. For now, I'm opting to restrict exposure computations to exposure events with at least one lagmph of no more than 30 mph.
    
    Speed Information: Each metric computed for all grouped points for a given combination of participant, retailer, stay event, and bin (i.e., 'exposure')
    obs - total number of geolocation observations
    rg_hr - average radius of gyration in meters
    duration_seconds - total exposure duration. Equals zero if just one point.
    min_lag_mph - the min value of imputed lag velocity.
    max_lag_mph - the max value of imputed lag velocity.
    range_lag_mph - the range of imputed lag velocity.
    max_measured_mph - the max value of measured velocity. 
    three_time_lags_sec - the mean value of each observation’s averaged three distance lags.
    
    License Information:
    license_created - The date associated with the creation/renewal of the retailer license in the data set (be careful - the license database is periodically updated, and may have new renewal dates that post-date exposures to the same location under a previous license).
    license_expiration - Expiration date of retailer license
    license_active - A variable which indicates whether the license was active at the time of the exposure measurement.
"
  
  #If something seems off try adding dplyr:: before group_by and summarize
  # Summarize exposures by participant, day, and discrete space-time groupings (i.e., stay events)
  # exposure_df <- df %>% data.frame() %>%
  #   select(-geometry) %>% #deleting geometry due to an error with vector size that kept popping up
  #   # need to add something that accounts for time window of duplicate retailer coordinates.
  #   filter(is.na(trade_name) == FALSE,   # dropping 724188 observations without retailer exposure 
  #          license_loc_twin == FALSE) %>% # dropping 24202 observations with licenses that are registered to the exact same coordinates.
  #   group_by(filename, day, stayeventgroup, StayEvent, trade_name) %>% #added trade name because it was off in grouping exposures
  #   summarize(min_datetime = min(datetime),
  #             max_datetime = max(datetime),
  #             duration_seconds = max_datetime - min_datetime,
  #             licenses = n(),
  #             active_licenses = sum(max_datetime < as.POSIXct(expiration_date, tz = "America/New_York") &
  #                                     max_datetime > as.POSIXct(publish_date, tz = "America/New_York")), #before the expiration date and after the publish date
  #             #active_licenses = sum(max_datetime < as.POSIXct(expiration_date, tz = "America/New_York")), 
  #             distinct_exposures = if_else(active_licenses > 0,
  #                                          n_distinct(trade_name),
  #                                          NA), #active_licenses counts the same unique retailer multiple times even if the time point or lat&lon don't change, so this counts each unique retailer as one exposure, but only if the license is active 
  #             rg_hr = mean(rg_hr),
  #             min_lag_mph = min(lagmph),
  #             max_lag_mph = max(lagmph),
  #             avg_lag_mph = mean(lagmph, na.rm=TRUE),
  #             range_lag_mph = max(lagmph) - min(lagmph),
  #             three_time_lags_sec = mean(mean_3_lagDist_ft), 
  #             max_measured_mph = max(velocity),
  #             license_created = min(ymd(publish_date)),
  #             license_expiration = max(ymd(expiration_date)), 
  #   ) %>%
  #   filter(active_licenses > 0) %>%     #Dropping exposure events involving inactive licenses
  #   mutate(HighSpeed = if_else(min_lag_mph < 30, "No", "Yes")) %>% #Brad initially filtered these out so should look into it more: filter(min_lag_mph < 30)   #Dropping 1181 exposure events without at least one observation with an inferred speed under 30 mph
  #   #filter(min_lag_mph < 5) %>% 
  #   group_by(filename, day) %>%
  #   mutate(daysAdExposure = sum(distinct_exposures)) %>% #primary measure
  #   mutate(regSpeedExpo = sum(distinct_exposures[which(min_lag_mph < 30)])) %>% #primary measure when infered mph is under 30
  #   mutate(daysAdStayEventUniqueRetailers = sum(ifelse(StayEvent == "Yes", distinct_exposures, 0))) 
  
  #If something seems off try adding dplyr:: before group_by and summarize
  # Summarize exposures by participant, day, and discrete space-time groupings (i.e., stay events)
  ExposureDF_100radius_1.5mins_25ft <- cleanData_Retailers_Tracts_100radius_1.5mins_25ftBuffer %>% data.frame() %>%
    select(-geometry) %>% #deleting geometry due to an error with vector size that kept popping up
    # need to add something that accounts for time window of duplicate retailer coordinates.
    filter(is.na(trade_name) == FALSE, # dropping observations without retailer exposure
           license_loc_twin == FALSE) %>%  # dropping observations with licenses that are registered to the exact same coordinates.
    mutate(grouping_var = if_else(is.na(stayeventgroup), row_number(), as.numeric(stayeventgroup))) %>% # BM adding line, assigns row number to NAs so we can properly count pass by's
    group_by(filename, day, grouping_var, StayEvent, trade_name) %>% #added trade name because it was off in grouping exposures
    summarize(min_datetime = min(datetime),
              max_datetime = max(datetime),
              duration_seconds = max_datetime - min_datetime,
              licenses = n(),
              active_licenses = sum(max_datetime < as.POSIXct(expiration_date, tz = "America/New_York") &
                                      max_datetime > as.POSIXct(publish_date, tz = "America/New_York")), #before the expiration date and after the publish date
              distinct_exposures = if_else(active_licenses > 0,
                                           n_distinct(trade_name),
                                           NA), # active_licenses counts the same unique retailer multiple times even if the time point or lat&lon don't change, so this counts each unique retailer as one exposure, but only if the license is active # BM it'already grouped by trade_name though so I think this just gives a count of 1 for every row 
              rg_hr = mean(rg_hr),
              min_lag_mph = min(lagmph),
              max_lag_mph = max(lagmph),
              avg_lag_mph = mean(lagmph, na.rm=TRUE),
              range_lag_mph = max(lagmph) - min(lagmph),
              three_time_lags_sec = mean(mean_3_lagDist_ft), 
              max_measured_mph = max(velocity),
              license_created = min(ymd(publish_date)),
              license_expiration = max(ymd(expiration_date)),
              stayeventgroup = first(stayeventgroup)) %>%
    ungroup() %>%
    filter(active_licenses > 0) %>% #Dropping exposure events involving inactive licenses
    group_by(filename, day) %>%
    mutate(daysAdExposure_25ft = n_distinct(grouping_var[distinct_exposures > 0]), #primary measure
           regSpeedExpo_25ft = n_distinct(grouping_var[distinct_exposures > 0 & min_lag_mph < 5])) %>%   #primary measure when inferred mph is under 5         
    # daysAdStayEventUniqueRetailers_25ft = sum(ifelse(StayEvent == "Yes", distinct_exposures, 0))) %>% #counts it as a new stayevent if there are different retailers within the same stayevent - BM this sums unique stay events by filename and day because distinct_exposures should always be 1. So if there's multiple stayevents within a day, it counts how many. Commenting this line though because it's not used below.
    # select(-grouping_var) %>% # Remove the grouping_var column
    left_join(ObsPerDay_df, by = c('filename', 'day'))
  
    regSpeedStayEventsDF <- exposure_df %>%
      distinct(filename, day, StayEvent, stayeventgroup, .keep_all = TRUE) %>%
      group_by(filename, day) %>%
      summarize(regSpeedStayEvent = sum(ifelse(StayEvent == "Yes" & min_lag_mph < 5, distinct_exposures, 0)))
    
    daysAdStayEventsDF <- exposure_df %>%
      distinct(filename, day, StayEvent, stayeventgroup, .keep_all = TRUE) %>%
      group_by(filename, day) %>%
      summarize(daysAdStayEvent = sum(ifelse(StayEvent == "Yes", distinct_exposures, 0))) %>%
      left_join(regSpeedStayEventsDF, by = c("filename", "day"))
    
    exposure_df <- exposure_df %>%
      left_join(daysAdStayEventsDF, by = c("filename", "day"))  %>%
      mutate(pid = filename) %>% 
      distinct(pid, day, daysAdExposure, regSpeedExpo, regSpeedStayEvent, daysAdStayEvent)
    
    exposure_merged_df <- ObsPerDay_df %>%
      mutate(pid = filename) %>%
      left_join(exposure_df, by = c('pid', 'day'))
    
    
    exposure_merged_df <- exposure_merged_df %>% 
      mutate(
        daysAdExposure = ifelse(is.na(daysAdExposure) & ObsPerDay >= 0, 0, daysAdExposure),
        regSpeedExpo = ifelse(is.na(regSpeedExpo) & ObsPerDay >= 0, 0, regSpeedExpo),
        regSpeedStayEvent = ifelse(is.na(regSpeedStayEvent) & ObsPerDay >= 0, 0, regSpeedStayEvent),
        daysAdStayEvent = ifelse(is.na(daysAdStayEvent) & ObsPerDay >= 0, 0, daysAdStayEvent))
}

# df_sf <- st_as_sf(x, coords = c("lon", "lat"), crs = 4326) 
# 
# # Create sf object for retailers
# retailers_sf <- st_as_sf(retailers, coords = c("lon", "lat"), crs = 4326)
# 
# # Create a 25-foot buffer around points where stayEvents is not NA in df
# df_buffer <- st_buffer(df_sf[!is.na(x$stayeventgroup), ], dist = 25, joinStyle = "ROUND")
# 
# # Create a 100-foot buffer around centroids of retailers
# retailers_buffer <- st_buffer(st_centroid(retailers_sf), dist = 100, joinStyle = "ROUND")
# 
# # Plot points from df with different colors for points where stayEvents is not NA
# mapview(df_sf, color = "blue", alpha.regions = 0.5) +
#   mapview(df_buffer, col.regions = "red", alpha.regions = 0.3) +
#   # Plot points from retailers with a 100-foot buffer
#   mapview(retailers_sf, color = "green", alpha.regions = 0.5) +
#   mapview(retailers_buffer, col.regions = "yellow", alpha.regions = 0.3)
# 
# retailers_buffer <- retailers %>%
#   filter(is.na(lat) == FALSE) %>%
#   st_as_sf(., coords = c("lon", "lat"), crs = 4326) %>% #org. 4326, also test 3857
#   st_transform(crs = inputCRS) %>% #uncomment out if needed, there was an error in simple codebase and this line fixed it
#   st_buffer(., inputDistance) # the number here is the buffer size in feet
# 
# 
# "51956
# 6500 SALTSBURG RD PENN HILLS PA 15235-2122"
