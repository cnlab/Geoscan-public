# First thing needed is outlier ID

library(anomalize)

# We detect observations outside the interquartile range using the `anomalize` package - 
# which is an outlier analysis package designed to play well with the tidyverse.

# We start by creating a data frame called `outliers` where we use the 
# `iqr` function to create new columns (denoted as variable.outlier) that simply 
# consist of "Yes" or "No" observations that denote whether the relevant observation 
# is outside the interquartile range for that variable across our entire data set.

# The parameters of the `iqr` function are described as follows in the `anomlalize` 
# [reference material](https://business-science.github.io/anomalize/reference/anomalize.html):
  
#  "The IQR Method uses an interquartile range of 25 the median. With the default alpha = 0.05, 
# the limits are established by expanding the 25/75 baseline by an IQR Factor of 3 (3X). 
# The IQR Factor = 0.15 / alpha (hence 3X with alpha = 0.05). 
# To increase the IQR Factor controling the limits, decrease the alpha, 
# which makes it more difficult to be an outlier. 
# Increase alpha to make it easier to be an outlier."

# BM: We should have this group by subject. First step of outlier removal should be to remove outliers within participant.
# BM: After that, we could also have a check to see if participants themselves on average are outliers, which is unlikely, but worth checking.

cleanData <- cleanData %>%
  mutate(rg_hr.outlier = iqr(rg_hr, verbose = FALSE),
         lead_lag_avg_mph.outlier = iqr(lead_lag_avg_mph, verbose = FALSE),
         lagDist_ft.outlier = iqr(lagDist_ft, verbose = FALSE),
         mean_3_lagDist_ft.outlier = iqr(mean_3_lagDist_ft, verbose = FALSE))


# Code adapted from Ken Steif - Public Policy Analytics

correlation.long <-
  st_drop_geometry(cleanData) %>%
  filter(rg_hr.outlier == "No" &
           lead_lag_avg_mph.outlier == "No" &
           lagDist_ft.outlier == "No" &
           mean_3_lagDist_ft.outlier == "No") %>%
  dplyr::select(rg_hr, lead_lag_avg_mph, mean_3_lagDist_ft, lagDist_ft, hour, filename) %>%
  gather(Variable, Value, -c(rg_hr,filename))

correlation.cor <-
  correlation.long %>%
  group_by(filename, Variable) %>%
  summarize(correlation = cor(Value, rg_hr, use = "complete.obs"))

# BM: Plotting all subjects at once takes a long time and is maybe not too informative. 
# I added a filter to select by subject. 
# Ideally, I think we'd want to be able to run this and generate a pdf of these plots 
# with one page per subject.
# Making the r = .xx pop more would be helpful. Right now, they're getting lost in the points.
# Get rid of legend (currently says colour \n a red).
pID <- "GEO004"

ggplot(correlation.long %>%
         filter(rg_hr < 20000, filename == pID), aes(Value, rg_hr)) +
  geom_point(size = 0.1, alpha = .25) +
  geom_text(data = correlation.cor %>% filter(filename == pID), 
            aes(label = paste("r =", round(correlation, 2)), colour = "red"),
            x=-Inf, y=Inf, vjust = 1.5, hjust = -0.1) +
  geom_smooth(method = "lm", se = FALSE, colour = "black") +
  facet_wrap(~Variable, ncol = 2, scales = "free") +
  labs(title = paste("rg_hr as function of continuous variables for", pID))+
  plotTheme

# BM: This is something we already have in my script. 
# Probably would generate separate plots by subject because n=30 is a lot of facets

ggplot(cleanData)+
  geom_freqpoly(aes(hour)) +
  facet_grid(dotw~filename, scales = "free")+
  labs(
    title = "Time series of geo-location hits by subject",
    y = "Number of observations",
    x = "Hour")+
  plotTheme

# BM: This is something I could add to my script. 
# Probably would generate separate plots by subject because n=30 is a lot of facets
ggplot(cleanData)+
  geom_point(aes(x =hour, y = rg_hr)) +
  facet_grid(dotw~filename, scales = "free")+
  labs(
    title = "Time series of geo-location hits by subject",
    y = "Radius of gyration",
    x = "Hour")+
  plotTheme

###---- Retailer exposure summary ----

# How many exposures for each individual?
# This needs something about whether retailers were expired
retail_tallies <- cleanData_Retailers_Tracts %>% 
  as.data.frame() %>% ungroup() %>%
  filter(is.na(trade_name)== FALSE) %>% 
  group_by(filename, lat, lon, datetime) %>% 
  slice(1) %>% 
  ungroup() %>% 
  group_by(filename) %>% 
  tally() %>%
  rename(exposures = n) %>%
  left_join(., cleanData_Retailers_Tracts %>% 
              as.data.frame() %>% ungroup() %>%
              filter(is.na(trade_name)== FALSE & is.na(stayeventgroup) == FALSE) %>% 
              group_by(filename, lat, lon) %>% 
              slice(1) %>% 
              ungroup() %>% 
              group_by(filename) %>% 
              tally() %>%
              rename(stayevent_exposures = n))


# Cut out the observations over 30mph

cleanData_Retailers_Tracts %>% 
  as.data.frame() %>% ungroup() %>%
  filter(is.na(trade_name)== FALSE & lead_lag_avg_mph < 30) %>% 
  group_by(filename, lat, lon, datetime) %>% 
  slice(1) %>% ungroup() %>% group_by(filename) %>% tally()

# Should this be joined to the intakeSummary? Like this?

left_join(intakeSummary, retail_tallies) %>% View()

# Sequence of exposures
# This doesn't yet cut out the multiple exposures to a single license at once

ggplot()+
  geom_freqpoly(data = cleanData_Retailers_Tracts %>% 
               as.data.frame() %>% 
               ungroup() %>%
               mutate(exposure_yn = ifelse(is.na(trade_name)== FALSE, "EXPOSURE", "NON-EXPOSURE")),
             aes(hour, color = exposure_yn))+
  facet_wrap(~dotw)+
  plotTheme

# Summary of exposures by retailer

# This is ready to be a function - needs something for whether retailer was open or closed

# Each retailer seems to have variable lat/lon - how do we address this?

exposures_by_location <- cleanData_Retailers_Tracts %>% 
  as.data.frame() %>% ungroup() %>%
  filter(is.na(trade_name)== FALSE & lead_lag_avg_mph < 30) %>% 
  group_by(filename, lat, lon, datetime) %>% 
  slice(1) %>% 
  ungroup() %>% 
  mutate(is_stay_event = ifelse(is.na(stayeventgroup) == FALSE, 1, 0),
         likely_active = ifelse(datetime < expiration_date, 1, 0))%>%
  group_by(filename, trade_name, address_full, account) %>% 
  summarise(n_exposures = n(),
            n_stay_event_exposures = sum(is_stay_event, na.rm = FALSE),
            n_exposures_likely_active = sum(likely_active), na.rm = FALSE) %>%
  mutate(possible_false_positive = n_exposures - n_exposures_likely_active) %>%
  select(-n_exposures_likely_active, -na.rm)
