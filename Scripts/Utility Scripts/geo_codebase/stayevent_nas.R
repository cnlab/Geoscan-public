#stayevent_nas.R

# stayevent() from the Mobility package assigns stayeventgroup IDs only to observations that are flagged as stay events, assigning NA to the rest.
# stayevent_nas() assigns a unique stayeventgroup ID for all NAs.

# Input: dataframe that was just processed by Mobility::stayevent()
# Output: dataframe with a non-NA value for each observation under dataframe$stayeventgroup

# Observations tagged with "NA" at the start are not actually stay events.

stayevent_nas <- function(df){
  
  require(tidyverse)
  
  df <- df %>%
    mutate(stayeventgroup = as.character(stayeventgroup))
  nadf <- df %>% filter(is.na(stayeventgroup)) %>%
           group_by(filename) %>%
           mutate(stayeventgroup = paste("NA", seq(1,length(filename),1))) %>%
           ungroup()
  df <- rbind(df %>% filter(!is.na(stayeventgroup)), nadf) %>% 
  arrange(filename, datetime)

return(df)
}