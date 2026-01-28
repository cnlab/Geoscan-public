#timePanels.R

# Generates the following sets of time panels binned by participant, day, and hour. 
# (1) Frequency of geolocation observations (points plots)
# (2) Frequency of geolocation observations (heatmaps for count and z)
# (3) Average lag distance of geolocation observations (heatmaps for raw value and z)
# (4) Average lag time of geolocation obserations (heatmaps for raw value and z)
# (5) Average lag mph of geolocation observations (heatmaps for raw value and z)
# (6) Average radius of gyration for geolocation observations (heatmaps for raw value and z)

# Inputs
# (1) df.raw: raw dataframe after removing duplicate timestamps using removeDuplicates.R and running timeWindows.R
# (2) df.cleaned: cleaned dataframe after adding space-time metrics and trimming extreme outliers
# (3) time: timestamp to be appended on data file outputs
# (4) plotpath: path to where plots will be saved
# (5) tablespath: path to where tabular data will be saved

# Outputs
# (1) returns plots object which is required for printing a pdf in the main script
# (2) saves plots in plotspath as an .RData file which can be dynamically visualized using the time panels shiny app 
# (3) saves tabular data used to generate the plots as a .csv in tablespath

# Time Panels Shiny App
# For the pilot data, this is found at /Volumes/cnlab/GeoScan/Pilot_Analyses/Figures/QC/shiny_qc_review_060921.R

timePanels <- function(df.raw, df.cleaned, time, plotpath, tablespath){
  
  require(tidyverse)
  require(ggpubr)
  
  ## DATA TABLES

  bintable_raw <- df.raw %>% addTimeWindows() %>% 
    group_by(filename, week, dotw, weekend, hour, period_flag) %>% 
    tally() %>% group_by(filename) %>% 
    mutate(z.n = scale(n)) %>% ungroup()
  
  bintable_fin <- df.cleaned %>%
    as.data.frame() %>%
    dplyr::select(-geometry) %>%
    group_by(filename, week, dotw, weekend, hour) %>%
    summarize(n = n(),
              dist = mean(lagDist_ft, na.rm=TRUE),
              time = mean(as.numeric(lagTime), na.rm=TRUE),
              speed = mean(lagmph, na.rm=TRUE),
              rg_hr = mean(rg_hr, na.rm=TRUE)) %>%
    group_by(filename) %>%
    #tally() %>% group_by(filename) %>%
    mutate(z.n = scale(n),
           z.dist = scale(dist),
           z.time = scale(time),
           z.speed = scale(speed),
           z.rg_hr = scale(rg_hr)) %>% ungroup()
  
  write.csv(bintable_raw, paste(tablespath, "geolocation_coverage_raw_", timestamp, ".csv", sep = ""), row.names = FALSE)
  write.csv(bintable_fin, paste(tablespath, "geolocation_coverage_fin_", timestamp, ".csv", sep = ""), row.names = FALSE)
  
  ## PLOTS
  
  plots <- list()
  
  for (p in unique(bintable_raw$filename)) {
    
    ## POINT PLOTS OF OBSERVATION FREQUENCY
    #fill/color="transparent" if you have a lot of points falling on top of each other (i.e., > 2)
    
    flagTypes <- length(unique(bintable_raw$period_flag[bintable_raw$filename==p]))
    
    plots[[p]][["points"]] <- ggplot() + 
      geom_point(data = bintable_raw %>% filter(filename == p & period_flag == TRUE), aes(x = hour, y = n, color = "raw - within study period"), size = 2) +
      facet_grid(week~dotw) + 
      labs(title=paste("Geolocation coverage for", p, sep = " "),
           x = "Hour of the day",
           y = "Number of tracks") +
      plotTheme
    if (flagTypes>1) {
      plots[[p]][["points"]] <- plots[[p]][["points"]] + 
        geom_point(data = bintable_raw %>% filter(filename == p & period_flag == FALSE), aes(x = hour, y = n, color = "raw - not in study period"), size = 2)
    }
    
    plots[[p]][["points"]] <- plots[[p]][["points"]] + 
      geom_point(data = bintable_fin %>% filter(filename == p), inherit.aes = FALSE, aes(x = hour, y = n, color = "cleaned"), size = 1) + 
      facet_grid(week~dotw) + 
      if (flagTypes>1) {
        scale_color_manual(values = c("cleaned" = "red", "raw - not in study period" = "blue", "raw - within study period" = "black"))
      } else {scale_color_manual(values = c("cleaned" = "red", "raw - within study period" = "black"))}
    
    ## HEATMAPS OF OBSERVATION FREQUENCY:
    
    # Raw data
    nmap <- ggplot(bintable_raw %>% filter(filename == p)) +
      geom_tile(aes(x = hour, y = week, fill=q5(n)), color = "white", size = 0.1, alpha = .75) +
      scale_fill_viridis(discrete = TRUE, labels=qBr(bintable_raw, "n")) +
      facet_grid(~dotw) +
      labs(title=paste("Raw data: Count and z-scored geolocation observations for", p, sep = " "),
           x = "Hour of the day",
           y = "Study week",
           fill = "n by\nquintile") +
      plotTheme
    zmap <- ggplot(bintable_raw %>% filter(filename == p)) +
      geom_tile(aes(x = hour, y = week, fill=z.n), color = "white", size = 0.1, alpha = .75) +
      scale_fill_viridis() +
      facet_grid(~dotw) +
      labs(x = "Hour of the day",
           y = "Study week",
           fill = "z score") +
      plotTheme 
    plots[[p]][["heat_raw"]] <- ggarrange(nmap, zmap, nrow = 2)
    
    # Cleaned data
    nmap <- ggplot(bintable_fin %>% filter(filename == p)) +
      geom_tile(aes(x = hour, y = week, fill=q5(n)), color = "white", size = 0.1, alpha = .75) +
      scale_fill_viridis(option = "inferno", discrete = TRUE, labels=qBr(bintable_fin, "n")) +
      facet_grid(~dotw) +
      labs(title=paste("Final cleaned data: Count and z-scored geolocation observations for", p, sep = " "),
           x = "Hour of the day",
           y = "Study week",
           fill = "n by\nquintile") +
      plotTheme
    zmap <- ggplot(bintable_fin %>% filter(filename == p)) +
      geom_tile(aes(x = hour, y = week, fill=z.n), color = "white", size = 0.1, alpha = .75) +
      scale_fill_viridis(option = "inferno") +
      facet_grid(~dotw) +
      labs(x = "Hour of the day",
           y = "Study week",
           fill = "z score") +
      plotTheme
    plots[[p]][["heat_fin"]] <- ggarrange(nmap, zmap, nrow = 2)
    
    ## HEATMAPS OF LAG DISTANCE
    nmap <- ggplot(bintable_fin %>% filter(filename == p)) +
      geom_tile(aes(x = hour, y = week, fill=q5(dist)), color = "white", size = 0.1, alpha = .75) +
      scale_fill_viridis(option = "magma", discrete = TRUE, labels=qBr(bintable_fin, "dist")) +
      facet_grid(~dotw) +
      labs(title=paste("Final cleaned data: Value and z-scored mean lag distance for", p, sep = " "),
           x = "Hour of the day",
           y = "Study week",
           fill = "distance (ft)\nby quintile") +
      plotTheme
    zmap <- ggplot(bintable_fin %>% filter(filename == p)) +
      geom_tile(aes(x = hour, y = week, fill=z.dist), color = "white", size = 0.1, alpha = .75) +
      scale_fill_viridis(option = "magma") +
      facet_grid(~dotw) +
      labs(x = "Hour of the day",
           y = "Study week",
           fill = "z score") +
      plotTheme
    plots[[p]][["heat_dist"]] <- ggarrange(nmap, zmap, nrow = 2)
    
    ## HEATMAPS OF LAG TIME
    nmap <- ggplot(bintable_fin %>% filter(filename == p)) +
      geom_tile(aes(x = hour, y = week, fill=q5(time)), color = "white", size = 0.1, alpha = .75) +
      scale_fill_viridis(option = "plasma", discrete = TRUE, labels=qBr(bintable_fin, "time")) +
      facet_grid(~dotw) +
      labs(title=paste("Final cleaned data: Value and z-scored mean lag time for", p, sep = " "),
           x = "Hour of the day",
           y = "Study week",
           fill = "time (s)\nby quintile") +
      plotTheme
    zmap <- ggplot(bintable_fin %>% filter(filename == p)) +
      geom_tile(aes(x = hour, y = week, fill=z.time), color = "white", size = 0.1, alpha = .75) +
      scale_fill_viridis(option = "plasma") +
      facet_grid(~dotw) +
      labs(x = "Hour of the day",
           y = "Study week",
           fill = "z score") +
      plotTheme
    plots[[p]][["heat_time"]] <- ggarrange(nmap, zmap, nrow = 2)
    
    ## HEATMAPS OF LAG SPEED
    nmap <- ggplot(bintable_fin %>% filter(filename == p)) +
      geom_tile(aes(x = hour, y = week, fill=q5(speed)), color = "white", size = 0.1, alpha = .75) +
      scale_fill_viridis(option = "viridis", discrete = TRUE, labels=qBr(bintable_fin, "speed")) +
      facet_grid(~dotw) +
      labs(title=paste("Final cleaned data: Value and z-scored mean lag speed for", p, sep = " "),
           x = "Hour of the day",
           y = "Study week",
           fill = "speed (mph)\nby quintile") +
      plotTheme
    zmap <- ggplot(bintable_fin %>% filter(filename == p)) +
      geom_tile(aes(x = hour, y = week, fill=z.speed), color = "white", size = 0.1, alpha = .75) +
      scale_fill_viridis(option = "viridis") +
      facet_grid(~dotw) +
      labs(x = "Hour of the day",
           y = "Study week",
           fill = "z score") +
      plotTheme
    plots[[p]][["heat_speed"]] <- ggarrange(nmap, zmap, nrow = 2)
    
    ## HEATMAPS OF RADIUS OF GYRATION
    nmap <- ggplot(bintable_fin %>% filter(filename == p)) +
      geom_tile(aes(x = hour, y = week, fill=q5(rg_hr)), color = "white", size = 0.1, alpha = .75) +
      scale_fill_viridis(option = "cividis", discrete = TRUE, labels=qBr(bintable_fin, "rg_hr")) +
      facet_grid(~dotw) +
      labs(title=paste("Final cleaned data: Value and z-scored mean hourly radius of gyration for", p, sep = " "),
           x = "Hour of the day",
           y = "Study week",
           fill = "radius (m)\nby quintile") +
      plotTheme
    zmap <- ggplot(bintable_fin %>% filter(filename == p)) +
      geom_tile(aes(x = hour, y = week, fill=z.rg_hr), color = "white", size = 0.1, alpha = .75) +
      scale_fill_viridis(option = "cividis") +
      facet_grid(~dotw) +
      labs(x = "Hour of the day",
           y = "Study week",
           fill = "z score") +
      plotTheme
    plots[[p]][["heat_rg"]] <- ggarrange(nmap, zmap, nrow = 2)
    
  }
  
  # Saving plots object as .RData for dynamic review with Shiny
  save(plots, file=gsub(".pdf", ".RData", plotpath))
  
  return(plots)
}