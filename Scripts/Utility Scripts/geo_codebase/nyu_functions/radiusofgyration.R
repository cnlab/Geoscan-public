

# Calculate Radius of Gyration of Spatial Points
#
# This function calculates radius of gyration, defined as the distance moved within a certain
# time period. Distance is calculated using Vincenty's formula.
#
# @param df a data frame object.
# @param coor longitude and latitude of the spatial points in the format of c("lon","lat").
# @param time a POSIXct time object, used to calculate time period.
# @param time.units time units used to group spatial location points. Choose from hour, date,
# and month. Radius of gyration is calculated within each time frame.
# @param groupvar grouping object to stratify time objects. Recommend to be ID for each individual.
# If \code{groupvar} is not specified, \code{time.units} will be used to sort data and calculate radius of gyration.
#
# @return a list of radius of gyration value matching to each spatial point in data frame. points in
# the same time period sepecified in time.units have the same radius of gyration.
#
# @seealso \code{\link{sdspatialpoints}}
#
# @examples
# data("mobility")
# mobility$rg<- radiusofgyration(mobility, coor = c("lon","lat"), time = "datetime", time.units = "date", groupvar = "id")
#
# @import lubridate
# @import plyr
# @importFrom geosphere distVincentyEllipsoid
#
# @export

radiusofgyration<- function(df, coor = NULL, time = NULL, time.units = c("hour", "date", "month"), groupvar = NULL) {
  
  require(lubridate)
  require(dplyr)
  require(geosphere)
  require(tidyverse)
  
  if (is.atomic(df)) {
    df <- data.frame(x = df)
  }
  if (is.null(coor)) {
    stop("Geographic coordinates must be supplied.")
  }
  if (is.null(time)) {
    stop("A time object must be supplied.")
  }
  if (!is.POSIXct(df[time][[1]])){
    stop("Time variable must be POSIXct format.")
  }
  if (length(time.units)!=1) {
    stop("time.units must be a single value.")
  }
  if (!time.units %in% c("hour", "date", "month")) {
    stop("time.units must be hour, date, or month. ")
  }
  
  # Apply the function corresponding to time.units to the time column
  df[[time.units]] <- switch(
    time.units,
    hour = hour(df[[time]]),
    date = as.Date(df[[time]]),
    month = month(df[[time]])
  )
  
  # Group the data based on the provided groupvar and time.units
  if (is.null(groupvar)) {
    df <- df %>%
      arrange(!!sym(time)) %>%
      mutate(group = cumsum(c(1, diff(!!sym(time.units))) != 0))
    message("groupvar is not provided, using time.units as grouping variable.")
  } else {
    df <- df %>%
      arrange(!!sym(groupvar), !!sym(time)) %>%
      group_by(!!sym(groupvar)) %>%
      mutate(newid = interaction(!!sym(groupvar), !!sym(time.units), drop = TRUE)) %>%
      ungroup() %>%
      mutate(group = as.numeric(newid))
  }
  
  # Calculate the radius of gyration for each group using dplyr
  df3 <- df %>%
    group_by(group) %>%
    group_modify(~ data.frame(rg = sdspatialpoints(.x, coor = coor)))
  
  df <- df %>%
    left_join(df3, by = "group")
  
  return(df$rg)
}
