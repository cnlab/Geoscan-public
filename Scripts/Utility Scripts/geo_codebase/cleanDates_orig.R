# cleanDates.R

# Clean Dates to remove geodata outside study range and then add time window metrics for later diagnostics

# Takes outputs from function uploadGeodata

# Parameters:
# df - a dataframe output from uploadGeodata
# dateRangeMin - a minimum bound (noninclusive) of the date range. format "yyyy-mm-dd hh:mm:ss" using a 24hr time for hour
# dateRangeMax - a minimum bound (noninclusive) of the date range. format "yyyy-mm-dd hh:mm:ss" using a 24hr time for hour
# fileName - a name for the the json file for the subject in question e.g. "file1.json" - found in the column filename of the output from uploadGeodata


cleanDates <- function(df, dateRangeMin, dateRangeMax, fileName){

  require(tidyverse)
  require(lubridate)
  
  cleaned.df <- df %>%
    mutate(keep = case_when(filename == fileName & 
                            datetime > dateRangeMin & 
                            datetime < dateRangeMax ~ 1)) %>%
    filter((is.na(keep) == FALSE & filename == fileName) | filename != fileName) %>%
    mutate(interval60 = floor_date(ymd_hms(datetime), unit = "hour"),
           interval30 = floor_date(ymd_hms(datetime), unit = "30 mins"),
           week = week(interval60),
           dotw = wday(interval60, label=TRUE),
           weekend = ifelse(dotw %in% c("Sun","Sat"), "Weekend", "Weekday"),
           hour = as.numeric(format(interval60, "%H"))) %>%
    group_by(filename) %>%
    mutate(week = week - min(week) + 1) %>%
    ungroup() %>%
    dplyr::select(-keep)
  
  return(cleaned.df)
    
}

#  Vignettes:
#  Clean dates for a single subject, filename 'file1.json``
#  testCleanDatesIndividual <- cleanDates(test, "2019-04-22 21:30:45", "2019-08-05 15:17:47", "file1.json")

# Clean dates for multiple subjects
# testCleanDatesMultiple <- test %>%
#                          cleanDates(., "2019-04-22 21:30:45", "2019-08-05 15:17:47", "file1.json") %>%
#                          cleanDates(., "2019-04-22 21:30:45", "2019-08-05 15:17:47", "file2.json")