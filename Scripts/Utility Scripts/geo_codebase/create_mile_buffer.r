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

geodata <- read.csv("/Volumes/cnlab/GeoRemote/Data/Geodata/clean/merged_intervention.csv")
geodata$datetime <- as.POSIXct(geodata$datetime, format = "%Y-%m-%dT%H:%M:%S", tz = "America/New_York")
retailers = read.csv("/Volumes/cnlab/GeoRemote/Data/Geodata/clean/mile_buffer_data/unused_retailers.csv")

ppts = geodata$filename %>% unique()
files <- list.files("/Volumes/cnlab/GeoRemote/Data/Geodata/clean/mile_buffer_data/", full.names = TRUE)

for (ppt_idx in ppts) {
  if (!sum(grepl(ppt_idx, files))) {
    exposureEvents = geodata %>% #update time to the time parameter used 
      filter(filename==ppt_idx) %>%
      stayevent(df = .,  
                coor = c("lon","lat"), 
                time = "datetime", 
                dist.threshold = 100/3.28084, # conversion from feet to meters PARAMETER -  specifying stay event of 100ft between time points 
                time.threshold = 1.5, # time PARAMETER 
                time.units = "mins", 
                groupvar = "filename") %>%
      mutate(rg_hr = radiusofgyration(., 
                                      coor = c("lon","lat"), 
                                      time = "datetime", 
                                      time.units = "hour", # PARAMETER
                                      groupvar = "filename")) %>%
      spaceTimeLags(., 2272)
    
    exposureEvents = exposureEvents %>%
      bufferAndJoin( retailers, ., 2272, 5280) %>% #set last number to the buffer zone you want in feet
      joinTracts(., year = 2020) %>% # we don't really need this as we're not looking at census tract, but could be useful to keep
      mutate(publish_date = format(strptime(publish_date, format = "%m/%d/%y"), format = "%Y-%m-%d")) %>% 
      mutate(expiration_date = format(strptime(expiration_date, format = "%m/%d/%y"), format = "%Y-%m-%d")) %>% 
      mutate(StayEvent = if_else(is.na(stayeventgroup), "No", "Yes"))
    
    retailers = anti_join(retailers, exposureEvents, by="address_full")
    save(exposureEvents, file=sprintf("/Volumes/cnlab/GeoRemote/Data/Geodata/clean/mile_buffer_data/%s_mile_buffer.RData",ppt_idx))
    write.csv(retailers, file="/Volumes/cnlab/GeoRemote/Data/Geodata/clean/mile_buffer_data/unused_retailers.csv")
  }
}
