# removeDuplicates.R

# INCOMPLETE PENDING COMMENTS FROM TOM

# This function removes duplicated timestamps using a logic
# which tries to determine which duplicate is most likely to be an outlier based
# on time/space lag readings

# requirements - sf, tidyverse, lubridate, RcppRoll

library(sf)
library(tidyverse)
library(lubridate)
library(RcppRoll)

# Testing this out - uploading the clean test data set
cleanData <- uploadGeodata("Data/Geotracking/multi_json_test") %>%
  cleanDates(., "2019-04-22 21:30:45", "2019-08-05 15:17:47", "file1.json") %>% # parameter
  cleanDates(., "2019-04-22 21:30:45", "2019-08-05 15:17:47", "file2.json")

nrow(cleanData) == length(unique(cleanData$datetime))

#There are no duplicates, so we will randomly make some - generate some random
# numbers in a column, for 5% of them we will make their datetime equal to the 
# lead datetime
# Then reset the datetime as dttm (it loses this for some reason)

cleanData <- cleanData %>%
  mutate(random = runif(nrow(cleanData), min = 0, max = 40),
         datetime = ifelse(random > 38, lead(datetime), datetime),
         datetime = as.POSIXct(as.numeric(datetime), # go from unix time to POSIXct date time
                               origin = "1970-01-01")) %>%
  select(-random)

nrow(cleanData) == length(unique(cleanData$datetime))

# Create rolling averages for lat and lon
# let's just do this for n = 3 to start but this can be altered
# THis is done grouping by filename and ordering by timestamp
# Then let's calculate the distance between the actual lat/lon
# and the rolling lat/lon (e.g. center of mass) - this is the second mutate command
# We call this dist_ctrGravity.
# Then we group by filename and datetime (e.g. each id/timestamp combo),
# We rank them by dist_ctrGravity (smallest first)
# And keep only the first obs (e.g. slice(1))
# We then ungroup and ditch the new variables we made

# THis is only being done for the lag observations, not the lead
# I suspect the effect is the same as if we used the lead though.

# This should work even if the timestamps and lat/lon are identical because it throws out all
# but the first filename/timestamp pair if they are ordered.

cleanData %>% 
  group_by(filename) %>%
  arrange(datetime)%>%
  mutate(roll3lat = roll_mean(lat, n = 3, align = "right", fill = NA), 
         roll3lon = roll_mean(lon, n = 3, align = "right", fill = NA)) %>%
  mutate(dist_ctrGravity = sqrt(((roll3lon - lon)^2) + ((roll3lat - lat)^2))) %>%
  group_by(filename, datetime) %>%
  arrange(dist_ctrGravity) %>%
  slice(1) %>%
  ungroup() %>%
  dplyr::select(-c(roll3lon, roll3lat, dist_ctrGravity)) %>%
  ungroup()

# Next this has to be turned into a function, error checked, etc.,