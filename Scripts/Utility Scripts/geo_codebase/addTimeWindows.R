# addTimeWindows.R

# Adds time windows that are useful when later generating time panels  

# Takes output from final iteration of function cleanDates

# Parameters:
# df - the dataframe output from the final iteration of cleanDates

addTimeWindows <- function(df){
  
  require(tidyverse)
  require(lubridate)
  
  df.new <- df %>% 
  mutate(interval60 = floor_date(ymd_hms(datetime), unit = "hour"),
       interval30 = floor_date(ymd_hms(datetime), unit = "30 mins"),
       dotw = wday(interval60, label=TRUE),
       week = case_when(dotw == "Sun" & year(interval60) == 2018 ~ week(interval60) + 1,
                        !(dotw == "Sun" & year(interval60) == 2018) ~ week(interval60)),
       weekend = ifelse(dotw %in% c("Sun","Sat"), "Weekend", "Weekday"),
       hour = as.numeric(format(interval60, "%H"))) %>%
  group_by(filename) %>%
  mutate(week = paste("Week", as.character(week - min(week) + 1))) %>%
  ungroup()
  
  return(df.new)
    
}
  
# Old code for correcting the week assignments for Sundays in 2018 because that year started on a Monday, not a Sunday
  # studyData$week[studyData$dotw=="Sun" & year(studyData$interval60)==2018] <- 
  #   studyData$week[studyData$dotw=="Sun" & year(studyData$interval60)==2018] + 1
  # studyData <- studyData %>%
  #   mutate(week = paste("Week", as.character(week)))