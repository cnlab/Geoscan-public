# cleanDates.R

# Clean Dates to remove geodata outside study start/end dates. 
# The function also flags observations during specified intervals (e.g., between track 1 and track 2).

# Takes outputs from function uploadGeodata

# Parameters:
# df - a dataframe output from uploadGeodata
# dateRangeMin - a minimum bound (noninclusive) of the date range. format "yyyy-mm-dd hh:mm:ss" using a 24hr time for hour
# dateRangeMax - a minimum bound (noninclusive) of the date range. format "yyyy-mm-dd hh:mm:ss" using a 24hr time for hour
# addFlags - a boolean that determines whether it's necessary to flag observations outside of formal tracking periods
# fileName - a name for the the json file for the subject in question e.g. "file1.json" - found in the column filename of the output from uploadGeodata

cleanDates <- function(df, dateRangeMin, dateRangeMax, addFlags, fileName){

  require(tidyverse)
  require(lubridate)
  
  cleaned.df <- df %>%
    mutate(keep = case_when(filename == fileName & 
                            datetime > dateRangeMin & 
                            datetime < dateRangeMax ~ 1)) %>%
    filter((is.na(keep) == FALSE & filename == fileName) | filename != fileName) %>%
    dplyr::select(-keep)
  
  if (addFlags==TRUE) {
    start <- unique(df$end1[df$filename==fileName])
    end <- unique(df$start2[df$filename==fileName])
    cleaned.df <- cleaned.df %>%
      mutate(period_flag = case_when(filename == fileName &
                                     datetime %within% (start %--% end) ~ 0,
                                     TRUE ~ as.numeric(period_flag)))
  }
  
  return(cleaned.df)
    
}

#  Vignettes:
#  Clean dates for a single subject, filename 'file1.json``
#  testCleanDatesIndividual <- cleanDates(test, "2019-04-22 21:30:45", "2019-08-05 15:17:47", "file1.json")

# Clean dates for multiple subjects
# testCleanDatesMultiple <- test %>%
#                          cleanDates(., "2019-04-22 21:30:45", "2019-08-05 15:17:47", "file1.json") %>%
#                          cleanDates(., "2019-04-22 21:30:45", "2019-08-05 15:17:47", "file2.json")