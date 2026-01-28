library(pacman)
p_load(tidyverse,data.table)

# If your working directory is in the GeoRemote Scripts folder, it'll set the correct path. If it's not, it will ask you to select a file in the directory
if ("Scripts" %in% unlist(strsplit(normalizePath("."), "/"))) {
  scripts_directory = paste(unlist(strsplit(normalizePath("."), "/"))[1:which(unlist(strsplit(normalizePath("."), "/"))=="Scripts")],collapse="/")
} else {
  print("Select any file withing Scripts to set up the path")
  temp = file.choose()
  scripts_directory = paste(unlist(strsplit(temp, "/"))[1:which(unlist(strsplit(temp, "/"))=="Scripts")],collapse="/")
}

create_geoscan_lifedata = function() {
  add_day_vars <- function(df) {
    df <- df %>%
      arrange(pid, type, `Notification Date`) %>%  # Arrange the data by pid, Type, and Notification Date
      group_by(pid, type) %>%                      # Group the data by pid and Type
      dplyr::mutate(day = dense_rank(`Notification Date`))  # Add a new variable 'day' as the dense rank within each group
    df <- df %>%
      arrange(pid, type, `Notification Date`) %>%  # Arrange the data by pid, Type, and Notification Date
      group_by(pid) %>%                      # Group the data by pid and Type
      dplyr::mutate(day_in_study = dense_rank(`Notification Date`))  # Add a new variable 'day' as the dense rank within each group
    return(df)
  }
  add_daily_cigarettes_var <- function(df) {
    
    impute_and_calculate <- function(df_subset) {
      # Calculate averages for cvg_1 and cvg_2 within each Type
      daily_cigs <- df_subset %>%
        filter(`Prompt Label` %in% c("cvg_1", "cvg_2")) %>%
        group_by(pid, type) %>%
        dplyr::summarise(
          avg_cvg_1 = mean(as.numeric(Response[`Prompt Label` == "cvg_1"]), na.rm = TRUE),
          avg_cvg_2 = mean(as.numeric(Response[`Prompt Label` == "cvg_2"]), na.rm = TRUE),
          .groups = 'drop'
        )
      
      # Replace NA values in cvg_1 and cvg_2 with the calculated averages within each Type
      df_subset <- df_subset %>%
        left_join(daily_cigs, by = c("pid", "type")) %>%
        dplyr::mutate(Imputed = ifelse(`Prompt Label` %in% c("cvg_1","cvg_2") & is.na(Response), 1, 0),
                      Response = ifelse(`Prompt Label` == "cvg_1" & is.na(Response), avg_cvg_1, Response),
                      Response = ifelse(`Prompt Label` == "cvg_2" & is.na(Response), avg_cvg_2, Response)) %>%
        select(-avg_cvg_1, -avg_cvg_2)
      
      return(df_subset)
    }
    
    # Apply the impute_and_calculate function to each Type group
    
    # Find rows where Responded is not 1 or 0
    rows_to_duplicate <- df[!df$Responded %in% c(0, 1), ]
    rows_to_duplicate <- rows_to_duplicate[rows_to_duplicate$`Session Name` %in% c("Summary_1", "Summary_2"),]
    
    # Create new rows with modified Prompt Label
    new_rows <- rows_to_duplicate %>%
      mutate(`Prompt Label` = case_when(
        `Session Name` == "Summary_1" ~ "cvg_1",
        `Session Name` == "Summary_2" ~ "cvg_2",
        TRUE ~ `Prompt Label`  # Keep original value if neither condition is met
      ))
    
    # Combine original dataframe with new rows
    df <- rbind(df, new_rows)
    df <- df %>%
      group_modify(~ impute_and_calculate(.x)) %>%
      ungroup()
    
    # Now, calculate the daily_cigs as before, within each Type group
    daily_cigs <- df %>%
      dplyr::filter(`Prompt Label` %in% c("cvg_1", "cvg_2")) %>%
      group_by(pid, `Notification Date`, type) %>%
      dplyr::summarise(daily_cigs = sum(as.numeric(Response), na.rm = TRUE), .groups = 'drop')
    
    # Merge the result back to the original dataframe
    df <- left_join(df, select(daily_cigs, pid, `Notification Date`, daily_cigs), by = c("pid", "Notification Date"))
  }
  get_raw_lifedata = function(data_path = "/Volumes/cnlab/GeoScan/") {
    # Get all CSV file paths recursively
    file_paths <- list.files(
      path = file.path(data_path,"LifeData/EMA"),
      pattern = "\\.csv$",
      recursive = TRUE,
      full.names = TRUE
    )
    file_paths = file_paths[-which(str_detect(file_paths,"processed_geoscan_lifedata"))]
    # Extract GEO ID (pid) and condition (Baseline/Intervention) from file paths
    file_info <- tibble(file_path = file_paths) %>%
      mutate(
        pid = str_extract(file_path, "GS\\d+"),  # Extract "GEO123"
        type = if_else(
          str_detect(file_path, "Baseline"), 
          "Baseline", 
          "Intervention"
        )
      )
    # Function to read a CSV and add pid/condition
    read_and_label <- function(file_path, pid, type) {
      read_csv(file_path) %>%
        mutate(
          pid = pid,
          type = type,
          Responded = as.character(Responded),  # Convert to character
          `GPS Latitude` = as.character(`GPS Latitude`),
          `GPS Longitude` = as.character(`GPS Longitude`),
          .before = 1
        )
    }
    
    # Process all files (returns a list of dataframes)
    df_list <- pmap(
      file_info,
      ~ read_and_label(..1, ..2, ..3)
    )
    # Bind all dataframes into one
    combined_df <- bind_rows(df_list) %>%
      mutate(
        `Prompt Label` = str_replace_all(`Prompt Label`, "\\s*\\(\\d+\\)", "")
      )
    return(combined_df)
  }
  
  raw_gs_ema = get_raw_lifedata()
  
  ppts_craving_cigarette = raw_gs_ema %>% filter(Prompt=="Right now, how much are you craving a cigarette?") %>% select(pid) %>% arrange(pid) %>% unique() %>%
    mutate(`Prompt` = "Right now, how much are you craving a cigarette?")
  ppts_smoke_cigarette = raw_gs_ema %>% filter(Prompt=="Right now, how much do you want to smoke a cigarette?") %>% select(pid) %>% arrange(pid) %>% unique() %>%
    mutate(`Prompt` = "Right now, how much do you want to smoke a cigarette?")
  
  process_ema_data = function(df) {
    df = df %>%
      mutate(`Prompt Label` = ifelse(`Prompt Label` == "cigs_1", "cigs", `Prompt Label`)) %>%
      mutate(`Prompt Label` = ifelse(`Prompt Label` == "craving_1", "crave", `Prompt Label`)) %>%
      mutate(`Prompt Label` = ifelse(`Prompt Label` == "ctrl_1", "ctrl", `Prompt Label`)) %>%
      mutate(`Prompt Label` = ifelse(`Prompt Label` == "cvg_1c1", "cvg_1", `Prompt Label`)) %>%
      mutate(`Prompt Label` = ifelse(`Prompt Label` == "lastCig_1", "lastCig", `Prompt Label`)) %>%
      mutate(`Prompt Label` = ifelse(`Prompt Label` == "mood_1", "mood", `Prompt Label`)) %>%
      mutate(`Prompt Label` = ifelse(`Prompt Label` == "rspct_1", "rspct", `Prompt Label`)) %>%
      mutate(`Prompt Label` = ifelse(`Prompt Label` == "cvg_1w", "cvg_1", `Prompt Label`)) %>%
      mutate(`Prompt Label` = ifelse(`Prompt Label` == "cvg_2w", "cvg_2", `Prompt Label`)) %>%
      mutate(`Notification Date` = as.Date(`Notification Time`)) %>%
      mutate(Response = as.numeric(Response)) %>%
      mutate(Response = case_when(
        `Prompt Label` == "crave" & pid %in% ppts_smoke_cigarette$pid & as.numeric(Response) == 0 ~ 11,
        `Prompt Label` == "crave" & pid %in% ppts_smoke_cigarette$pid & !is.na(as.numeric(Response)) ~ as.numeric(Response) * 11,
        TRUE ~ Response  # Keep original value for all other cases
      ))
  
    # add cigs var
    df_cigs <- df %>%
      filter(`Prompt Label` %in% c("cvg_1", "cvg_2")) %>%
      mutate(Response = as.numeric(Response)) %>%
      group_by(pid, `Notification Date`, type, `Prompt Label`) %>%
      summarise(Response = first(Response), .groups = "drop") %>%
      pivot_wider(names_from = `Prompt Label`, 
                  values_from = Response,
                  id_cols = c(pid, `Notification Date`, type)) %>%
      mutate(cvg = case_when(
        is.na(cvg_1) | is.na(cvg_2) ~ NA_real_,
        TRUE ~ cvg_1 + cvg_2
      )) %>%
      select(pid, type, `Notification Date`, cvg)
    
    # Add craving
    crave_avg_data <- df %>%
      filter(grepl("crave", `Prompt Label`, ignore.case = TRUE)) %>%
      mutate(Response = as.numeric(Response)) %>%
      group_by(pid, type, `Notification Date`) %>%
      summarise(crave_avg = mean(Response, na.rm = TRUE), .groups = "drop") %>%
      # Set to NA if no valid crave responses for that day
      mutate(crave_avg = ifelse(is.nan(crave_avg), NA_real_, crave_avg))
    
    
    # Merge back into original dataframe
    df_final <- df %>%
      left_join(df_cigs, by = c("pid", "Notification Date", "type")) %>%
      left_join(crave_avg_data, by = c("pid", "Notification Date", "type")) %>% 
      add_daily_cigarettes_var() %>%
      add_day_vars()
    
    
  }
  processed_geoscan = process_ema_data(raw_gs_ema)
  write.csv(processed_geoscan, 
            file = "/Volumes/cnlab/GeoScan/LifeData/EMA/processed_geoscan_lifedata.csv", 
            row.names = FALSE)
}

load_geoscan_lifedata = function(format, data_path = "/Volumes/cnlab/GeoScan") {
  df = read_csv(file = file.path(data_path,"LifeData/EMA/processed_geoscan_lifedata.csv"))
    
  if (format=="wide") {
    return(
      df_wide=df %>%
        select(c(pid, type, `Notification Date`, `Notification Time`, `Session Instance No`, `Completed Session`, 
                 `Prompt Label`, Response, cvg, crave_avg)) %>%
        tidyr::pivot_wider(
          names_from = "Prompt Label", 
          values_from = "Response",
          values_fill = list(Response = NA)) %>%
        dplyr::mutate(
          `Notification Time` = force_tz(as.POSIXct(`Notification Time`, format = "%Y-%m-%d %H:%M:%S"), tzone="America/New_York"),
        )) 
  }
  return(df)
  
}

