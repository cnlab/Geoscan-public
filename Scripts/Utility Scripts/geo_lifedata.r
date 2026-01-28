# Geo Remote LifeData Processing Script
# Refactored version with improved modularity, validation, and testing

library(pacman)
p_load(tidyverse, data.table, lubridate, testthat)

# CONFIGURATION AND VALIDATION ------

LIFEDATA_CONFIG <- list(
  data_path = "/Volumes/cnlab/GeoRemote/Data/"
)

#' Validate required packages are loaded
#' @return logical indicating if all required packages are available
validate_dependencies <- function() {
  required_packages <- c("tidyverse", "data.table", "lubridate")
  missing_packages <- setdiff(required_packages, rownames(installed.packages()))
  
  if (length(missing_packages) > 0) {
    stop("Missing required packages: ", paste(missing_packages, collapse = ", "))
  }
  
  return(TRUE)
}

#' Setup directory paths
#' @param custom_path optional custom path to data directory
#' @return list containing validated directory paths
setup_directories <- function(custom_path = NULL) {
  
  if (!is.null(custom_path)) {
    scripts_directory <- custom_path
  } else if ("Scripts" %in% unlist(strsplit(normalizePath("."), "/"))) {
    scripts_directory <- paste(
      unlist(strsplit(normalizePath("."), "/"))[1:which(unlist(strsplit(normalizePath("."), "/")) == "Scripts")],
      collapse = "/"
    )
  } else {
    message("Select any file within Scripts directory to set up the path")
    temp <- file.choose()
    scripts_directory <- paste(
      unlist(strsplit(temp, "/"))[1:which(unlist(strsplit(temp, "/")) == "Scripts")],
      collapse = "/"
    )
  }
  
  return(list(scripts = scripts_directory))
}

#' Validate file paths exist
#' @param paths character vector of file paths to validate
#' @return logical TRUE if all paths exist, throws error otherwise
validate_file_paths <- function(paths) {
  missing_paths <- paths[!file.exists(paths)]
  
  if (length(missing_paths) > 0) {
    stop("Missing required files/directories: ", paste(missing_paths, collapse = ", "))
  }
  
  return(TRUE)
}

# DATA LOADING FUNCTIONS -------

#' Load lifepack IDs to remove from analysis
#' @param data_path path to data directory
#' @return character vector of IDs to remove
load_removal_ids <- function(data_path=LIFEDATA_CONFIG$data_path) {
  removal_file <- normalizePath(file.path(data_path, "Lifedata/utility/lifepack_ids_to_remove.csv"))
  validate_file_paths(removal_file)
  
  message(sprintf("Loading removal IDs from %s", removal_file))
  tryCatch({
    remove_ids <- read_csv(removal_file, show_col_types = FALSE)
    
    # Clean quotes from IDs
    if ("id" %in% names(remove_ids)) {
      remove_ids$id <- gsub('"', '', remove_ids$id)
      return(remove_ids$id)
    } else {
      warning("'id' column not found in removal file")
      return(character(0))
    }
  }, error = function(e) {
    stop("Failed to load removal IDs: ", e$message)
  })
}

#' Load lifepack information
#' @param data_path path to data directory
#' @return data frame with lifepack information
load_lifepack_info <- function(data_path=LIFEDATA_CONFIG$data_path) {
  lifepack_file <- normalizePath(file.path(data_path, "Lifedata/utility/lifepack_ids.csv"))
  validate_file_paths(lifepack_file)
  
  message(sprintf("Loading lifepack information from %s", lifepack_file))
  tryCatch({
    read_csv(lifepack_file, show_col_types = FALSE)
  }, error = function(e) {
    stop("Failed to load lifepack info: ", e$message)
  })
}

#' Load raw lifedata files from directory
#' @param path subdirectory within LifeData/raw
#' @param pattern file pattern to match
#' @param data_path base data path
#' @return long format data frame
load_raw_lifedata <- function(path = "LifeData_NIS", pattern = "*.csv", data_path=LIFEDATA_CONFIG$data_path) {
  #' Load all CSV files once
  #' @param file_paths character vector of file paths
  #' @return named list of data frames
  load_all_csv_files <- function(file_paths) {
    raw_data_list <- list()
    column_classes <- NULL
    
    for (file in file_paths) {
      message("Loading file: ", basename(file))
      
      tryCatch({
        if (is.null(column_classes)) {
          df <- read_csv(file, show_col_types = FALSE)
          column_classes <- spec(df)
        } else {
          df <- read_csv(file, col_types = column_classes$col, show_col_types = FALSE)
        }
        
        raw_data_list[[file]] <- df
        
      }, error = function(e) {
        warning("Failed to load file ", file, ": ", e$message)
      })
    }
    
    return(raw_data_list)
  }
  #' Extract session variables from already loaded data
  #' @param raw_data_list named list of data frames
  #' @return list of session variables by session name
  extract_session_variables_from_data <- function(raw_data_list) {
    
    #' Add session variables to list (unchanged - already has single responsibility)
    #' @param vars_list existing list of variables
    #' @param df data frame to extract variables from
    #' @return updated variables list
    add_session_vars_to_list <- function(vars_list, df) {
      
      add_vars_to_list <- function(list, vars, name) {
        if (name %in% names(list)) {
          list[[name]] <- c(list[[name]], vars) %>% unique()
        } else {
          list[[name]] <- vars
        }
        return(list)
      }
      
      for (session_name in unique(df$`Session Name`)) {
        session_df <- df %>%
          select(-matches(c("GPS Latitude Start", "GPS Latitude Finish", 
                            "GPS Longitude Start", "GPS Longitude Finish", "Device ID"))) %>%
          filter(`Session Name` == session_name) %>%
          select((which(names(df) == "Reminders Delivered") + 1):ncol(.))
        
        # Find columns with actual responses
        response_cols <- which(colSums(!is.na(session_df), na.rm = TRUE) > 0)
        
        if (length(response_cols) > 0) {
          first_col <- min(response_cols)
          last_col <- max(response_cols)
          
          session_vars <- session_df %>%
            select(first_col:last_col) %>%
            names()
          
          vars_list <- add_vars_to_list(vars_list, session_vars, session_name)
        }
      }
      
      return(vars_list)
    }
    
    session_vars_list <- list()
    
    for (file_name in names(raw_data_list)) {
      df <- raw_data_list[[file_name]]
      
      if (is.null(df)) next
      
      session_vars_list <- add_session_vars_to_list(session_vars_list, df)
    }
    
    return(session_vars_list)
  }
  
  #' Convert loaded data to long format
  #' @param raw_data_list named list of data frames
  #' @param session_vars_list list of session variables
  #' @return long format data frame
  convert_data_to_long_format <- function(raw_data_list, session_vars_list) {
    
    #' Convert a single data frame to long format
    #' @param data single data frame
    #' @param session_vars_list list of session variables
    #' @return long format data frame for this file
    convert_single_file_to_long <- function(data, session_vars_list) {
      file_long_df <- data.frame()
      
      # Define metadata columns to keep
      metadata_cols <- c(
        "Participant ID",
        "Notification Time",
        "Session Name",
        "Notification No",
        "Responded",
        "Completed Session",
        "Session Instance",
        "Session Instance Response Lapse",
        "Session Length",
        "Reminders Delivered"
      )
      
      # Only keep metadata columns that exist in the data
      metadata_cols <- metadata_cols[metadata_cols %in% names(data)]
      
      for (session_name in names(session_vars_list)) {
        session_vars <- session_vars_list[[session_name]]
        session_vars <- session_vars[session_vars %in% names(data)]
        
        if (length(session_vars) == 0) next
        
        # Filter for this session and convert session vars to character
        session_data <- data %>%
          filter(`Session Name` == session_name) %>%
          dplyr::mutate(across(all_of(session_vars), ~ as.character(.)))
        
        # Only proceed if we have data for this session
        if (nrow(session_data) == 0) next
        
        # Pivot only the session variables, keeping metadata columns
        pivoted_df <- session_data %>%
          select(all_of(c(metadata_cols, session_vars))) %>%
          pivot_longer(
            cols = all_of(session_vars),
            names_to = "Prompt Label",
            values_to = "Response"
          )
        
        file_long_df <- rbind(file_long_df, pivoted_df)
      }
      
      return(file_long_df)
    }
    long_df <- data.frame()
    
    for (file_name in names(raw_data_list)) {
      data <- raw_data_list[[file_name]]
      
      if (is.null(data)) next
      
      tryCatch({
        file_long_df <- convert_single_file_to_long(data, session_vars_list)
        long_df <- rbind(long_df, file_long_df)
        
      }, error = function(e) {
        warning("Failed to process file ", file_name, " for long format conversion: ", e$message)
      })
    }
    
    return(long_df)
  }
  
  
  full_path <- file.path(data_path, "LifeData/raw", path)
  validate_file_paths(full_path)
  
  files <- file.info(list.files(
    path = full_path, 
    pattern = pattern, 
    full.names = TRUE, 
    recursive = TRUE
  ))
  
  if (length(files) == 0) {
    stop("No files found matching pattern '", pattern, "' in ", full_path)
  }
  
  # Load all data once
  raw_data_list <- load_all_csv_files(rownames(files))
  
  # Extract session variables from loaded data
  session_vars_list <- extract_session_variables_from_data(raw_data_list)
  
  # Convert to long format using already loaded data
  long_data <- convert_data_to_long_format(raw_data_list, session_vars_list)
  
  return(long_data)
}



# MAIN PROCESSING FUNCTIONS ----------

## VARIABLE CREATION FUNCTIONS -----------

#' Process all variable additions
#' @param df data frame with lifedata
#' @return data frame with all new variables added
add_all_variables <- function(df) {
  
  #' Add day variables to dataset
  #' @param df data frame with lifedata
  #' @return data frame with day variables added
  add_day_variables <- function(df) {
    
    required_cols <- c("pid", "Type", "Notification Date")
    missing_cols <- setdiff(required_cols, names(df))
    
    if (length(missing_cols) > 0) {
      stop("Missing required columns for day variables: ", paste(missing_cols, collapse = ", "))
    }
    
    df %>%
      dplyr::arrange(pid, Type, `Notification Date`) %>%
      dplyr::group_by(pid, Type) %>%
      dplyr::mutate(day = dense_rank(`Notification Date`)) %>%
      dplyr::ungroup() %>%
      dplyr::arrange(pid, `Notification Date`) %>%
      dplyr::group_by(pid) %>%
      dplyr::mutate(day_in_study = dense_rank(`Notification Date`)) %>%
      dplyr::ungroup()
    
  }
  
  #' Add microaggression variables
  #' @param df data frame with lifedata
  #' @return data frame with microaggression variables added
  add_microaggression_variables <- function(df) {
    
    microagg_labels <- c(
      "Because I am a smoker",
      "Because of another personal attribute", 
      "Because of my education",
      "Because of my gender",
      "Because of my income level",
      "Because of my race",
      "Because of my sexual orientation"
    )
    
    microagg_pattern <- paste(microagg_labels, collapse = "|")
    
    df %>%
      dplyr::group_by(pid, `Notification Date`) %>%
      dplyr::mutate(
        microagg_day = ifelse(
          any(Response == 1 & grepl(microagg_pattern, `Prompt Label`)),
          1, 0
        ),
        microagg_count = sum(
          Response == 1 & grepl(tolower(microagg_pattern), tolower(`Prompt Label`))
        )
      ) %>%
      dplyr::ungroup()
    
  }
  
  #' Add stress event variables
  #' @param df data frame with lifedata
  #' @return data frame with stress variables added
  add_stress_variables <- function(df) {
    
    stress_labels <- c(
      "stress_events_interpersonal tensions",
      "stress_events_health/accident",
      "stress_events_other",
      "stress_events_home", 
      "stress_events_work/education",
      "stress_events_events that happened to others",
      "stress_events_finances",
      "stress_events_being evaluated"
    )
    
    stress_pattern <- paste(stress_labels, collapse = "|")
    
    df %>%
      dplyr::group_by(pid, `Notification Date`) %>%
      dplyr::mutate(
        stress_day = ifelse(
          any(Response == 1 & grepl(stress_pattern, tolower(`Prompt Label`))),
          1, 0
        ),
        stress_count = sum(
          Response == 1 & grepl(stress_pattern, `Prompt Label`)
        )
      ) %>%
      dplyr::ungroup()
    
  }
  
  #' Add daily average craving variable
  #' @param df data frame with lifedata
  #' @return data frame with daily craving average added
  add_daily_craving_average <- function(df) {
    
    avg_craving <- df %>%
      dplyr::filter(`Prompt Label` == "crave") %>%
      dplyr::group_by(pid, `Notification Date`) %>%
      dplyr::summarise(daily_average_crave = mean(as.numeric(Response), na.rm = TRUE), .groups = "drop")
    
    df %>%
      dplyr::left_join(avg_craving, by = c("pid", "Notification Date"))
  }
  
  #' Add daily cigarettes variable with imputation
  #' @param df data frame with lifedata
  #' @return data frame with daily cigarettes variable added
  add_daily_cigarettes <- function(df) {
    
    impute_and_calculate <- function(df_subset) {
      # Calculate averages for cvg_1 and cvg_2 within each Type
      daily_cigs <- df_subset %>%
        filter(`Prompt Label` %in% c("cvg_1", "cvg_2")) %>%
        group_by(pid, Type) %>%
        dplyr::summarise(
          avg_cvg_1 = mean(as.numeric(Response[`Prompt Label` == "cvg_1"]), na.rm = TRUE),
          avg_cvg_2 = mean(as.numeric(Response[`Prompt Label` == "cvg_2"]), na.rm = TRUE),
          .groups = 'drop'
        )
      
      # Replace NA values in cvg_1 and cvg_2 with the calculated averages within each Type
      df_subset <- df_subset %>%
        left_join(daily_cigs, by = c("pid", "Type")) %>%
        dplyr::mutate(Imputed = ifelse(`Prompt Label` %in% c("cvg_1","cvg_2") & is.na(Response), 1, 0),
                      Response = ifelse(`Prompt Label` == "cvg_1" & is.na(Response), avg_cvg_1, Response),
                      Response = ifelse(`Prompt Label` == "cvg_2" & is.na(Response), avg_cvg_2, Response)) %>%
        select(-avg_cvg_1, -avg_cvg_2)
      
      return(df_subset)
    }
    
    # Apply the impute_and_calculate function to each Type group
    df <- df %>%
      group_modify(~ impute_and_calculate(.x)) %>%
      ungroup()
    
    # Now, calculate the daily_cigs as before, within each Type group
    daily_cigs <- df %>%
      dplyr::filter(`Prompt Label` %in% c("cvg_1", "cvg_2")) %>%
      group_by(pid, `Notification Date`, Type) %>%
      dplyr::summarise(daily_cigs = sum(as.numeric(Response), na.rm = TRUE), .groups = 'drop')
    
    # Merge the result back to the original dataframe
    df <- left_join(df, select(daily_cigs, pid, `Notification Date`, daily_cigs), by = c("pid", "Notification Date"))
  }
  
  #' Add response time variable
  #' @param df data frame with lifedata
  #' @return data frame with response time added
  add_response_time <- function(df) {
    
    required_cols <- c("Notification Time", "Session Instance Response Lapse")
    missing_cols <- setdiff(required_cols, names(df))
    
    if (length(missing_cols) > 0) {
      warning("Missing columns for response time calculation: ", paste(missing_cols, collapse = ", "))
      return(df)
    }
    
    df %>%
      dplyr::mutate(
        Response_Time = `Notification Time` + seconds(`Session Instance Response Lapse`)
      )
  }
  
  df %>%
    add_day_variables() %>%
    add_microaggression_variables() %>%
    add_stress_variables() %>%
    add_daily_craving_average() %>%
    add_daily_cigarettes() %>%
    add_response_time()
}

#' Create master lifedata dataset
#' @param data_path path to data directory
#' @param config optional configuration list
#' @return processed lifedata data frame
create_master_lifedata <- function(data_path=LIFEDATA_CONFIG$data_path, config = NULL) {
  

  #' Remove specified lifepack IDs from dataset
  #' @param df data frame containing lifedata
  #' @param removal_ids character vector of IDs to remove
  #' @return filtered data frame
  remove_lifepack_ids <- function(df, removal_ids) {
    if (!"userID" %in% names(df)) {
      stop("userID column not found in data frame")
    }
    
    if (length(removal_ids) == 0) {
      message("No IDs specified for removal")
      return(df)
    }
    
    original_rows <- nrow(df)
    df_filtered <- df %>%
      filter(!userID %in% removal_ids)
    
    removed_rows <- original_rows - nrow(df_filtered)
    message("Removed ", removed_rows, " rows based on removal IDs")
    
    return(df_filtered)
  }
  
  #' Add participant ID and lifepack information to dataset
  #' @param lifedata data frame with lifedata
  #' @param lifepack_ids data frame with lifepack information
  #' @param redcap data frame with redcap data
  #' @return merged data frame with participant info
  add_participant_info <- function(lifedata, lifepack_ids, redcap) {
    
    # Validate required columns
    required_lifedata_cols <- c("pakID", "userID")
    required_lifepack_cols <- c("pakID")
    
    missing_lifedata_cols <- setdiff(required_lifedata_cols, names(lifedata))
    missing_lifepack_cols <- setdiff(required_lifepack_cols, names(lifepack_ids))
    
    if (length(missing_lifedata_cols) > 0) {
      stop("Missing required columns in lifedata: ", paste(missing_lifedata_cols, collapse = ", "))
    }
    
    if (length(missing_lifepack_cols) > 0) {
      stop("Missing required columns in lifepack_ids: ", paste(missing_lifepack_cols, collapse = ", "))
    }
    
    # Prepare redcap data
    redcap_prepared <- redcap %>%
      select(
        pid, cond,
        redcap_id1 = lifedata_id1,
        redcap_id1b = lifedata_id1b,
        redcap_id1c = lifedata_id1c,
        redcap_id2 = lifedata_id2,
        redcap_id2b = lifedata_id2b,
        redcap_id2c = lifedata_id2c_3
      )
    
    # Merge with lifepack info
    merged_data <- merge(lifedata, lifepack_ids, by = "pakID")
    
    # Add participant IDs
    potential_id_columns <- c("redcap_id1", "redcap_id1b", "redcap_id1c", 
                              "redcap_id2", "redcap_id2b", "redcap_id2c")
    
    for (i in seq_along(potential_id_columns)) {
      id_column <- potential_id_columns[i]
      redcap_subset <- redcap_prepared %>% select(pid, all_of(id_column))
      
      merged_data <- merge(merged_data, redcap_subset, 
                           by.x = "userID", by.y = id_column, all.x = TRUE)
      
      # Rename the pid column to avoid conflicts
      names(merged_data)[ncol(merged_data)] <- paste0('pid_', i)
    }
    
    # Combine all pid columns
    merged_data <- merged_data %>%
      unite(pid, pid_1, pid_2, pid_3, pid_4, pid_5, pid_6, sep = " ", na.rm = TRUE)
    
    # Add conditions
    conditions <- redcap_prepared %>% select(pid, cond)
    merged_data <- merge(merged_data, conditions, by = 'pid')
    
    return(merged_data)
  }
  
  #' Separate reset packs into baseline or intervention periods
  #' @param lifedata data frame with lifedata
  #' @param redcap data frame with redcap data
  #' @return data frame with updated Type column
  separate_reset_packs <- function(lifedata, redcap) {
    
    if (!"Type" %in% names(lifedata)) {
      warning("Type column not found in lifedata")
      return(lifedata)
    }
    
    # Get user IDs that used reset packs
    reset_uids <- lifedata %>%
      dplyr::filter(Type == "Base_Control") %>%
      dplyr::pull(userID) %>%
      unique()
    
    baseline_ids <- lifedata %>%
      dplyr::filter(Type == "Baseline") %>%
      dplyr::pull(userID) %>%
      unique()
    
    control_ids <- lifedata %>%
      dplyr::filter(Type == "Control") %>%
      dplyr::pull(userID) %>%
      unique()
    
    # RedCap columns to check
    id_columns <- c("lifedata_id1", "lifedata_id1b", "lifedata_id1c",
                    "lifedata_id2", "lifedata_id2b", "lifedata_id2c_3")
    
    message("Separating reset packs to Baseline or Control")
    
    for (uid in reset_uids) {
      for (col in id_columns) {
        if (col %in% names(redcap)) {
          # Filter out NA values before using grepl, then check if any match
          col_values <- redcap[[col]][!is.na(redcap[[col]])]
          
          if (length(col_values) > 0 && any(grepl(uid, col_values))) {
            if (grepl('1', col) && !uid %in% baseline_ids) {
              lifedata[lifedata$userID == uid, ]$Type <- "Baseline"
              message(sprintf("Moving uid %s to baseline", uid))
              break
            }
            if (grepl('2', col) && !uid %in% control_ids) {
              lifedata[lifedata$userID == uid, ]$Type <- "Control"
              message(sprintf("Moving uid %s to control", uid))
              break
            }
          }
        }
      }
    }
    
    # Rename Control to Intervention
    lifedata <- lifedata %>%
      mutate(Type = ifelse(Type == "Control", "Intervention", Type))
    
    return(lifedata)
  }
  
  #' Filter lifepack data by RedCap date ranges
  #' @param lifedata data frame with lifedata
  #' @param redcap data frame with redcap data
  #' @return filtered data frame
  filter_by_redcap_dates <- function(lifedata, redcap) {
    
    if (!"Notification Date" %in% names(lifedata)) {
      stop("Notification Date column not found in lifedata")
    }
    
    # Get date variable patterns
    pattern <- "lifedata_pak[1-2][a-d]_start|lifedata_pak[1-2][a-d]_end"
    redcap_vars <- names(redcap)[grepl(pattern, names(redcap))]
    dates_from_redcap <- split(redcap_vars, gl(length(redcap_vars)/2, 2))
    
    user_id_vars <- c("lifedata_id1", "lifedata_id1b", "lifedata_id1c",
                      "lifedata_id2", "lifedata_id2b", "lifedata_id2c_3")
    
    subset_df <- data.frame()
    
    for (r_idx in 1:nrow(redcap)) {
      record <- redcap[r_idx, ]
      ppt_lifedata <- lifedata %>% filter(pid == record$pid)
      
      for (pair_idx in seq_along(dates_from_redcap)) {
        if (pair_idx > length(user_id_vars)) break
        
        user_id_var <- user_id_vars[pair_idx]
        if (!user_id_var %in% names(record)) next
        
        user_id <- record[[user_id_var]]
        if (is.na(user_id) || user_id == "") next
        
        pair_of_dates <- dates_from_redcap[[pair_idx]]
        dates <- c(
          as.Date(record[[pair_of_dates[1]]]),
          as.Date(record[[pair_of_dates[2]]])
        ) %>% sort()
        
        if (any(is.na(dates))) next
        
        ppt_lifedata_subset <- ppt_lifedata %>%
          filter(
            userID == user_id &
              `Notification Date` >= dates[1] &
              `Notification Date` <= dates[2]
          )
        
        ppt_lifedata <- anti_join(ppt_lifedata, ppt_lifedata_subset, by = "Notification Time")
        subset_df <- rbind(subset_df, ppt_lifedata_subset)
      }
    }
    
    return(subset_df)
  }
  
  #' Fix specific erroneous CVG responses
  #' @param df data frame with lifedata
  #' @param fixes list of fixes to apply (default uses known corrections)
  #' @return data frame with corrected responses
  fix_response_errors <- function(df, fixes = NULL) {
    
    if (is.null(fixes)) {
      # Default fixes for known issues
      fixes <- list(
        list(pid = "GR282", date = "2024-02-07", label = "cvg_2", old_value = 709, new_value = NA),
        list(pid = "GR217", date = "2023-10-21", label = "cvg_1", old_value = 1e+07, new_value = NA)
      )
    }
    
    for (fix in fixes) {
      condition <- df$pid == fix$pid & 
        df$`Notification Date` == fix$date & 
        df$`Prompt Label` == fix$label & 
        df$Response == fix$old_value
      
      if (any(condition, na.rm = TRUE)) {
        df[which(condition), ]$Response <- fix$new_value
        message(sprintf("Fixed response for pid %s, date %s, label %s", 
                        fix$pid, fix$date, fix$label))
      }
    }
    
    return(df)
  }
  
  #' Collapse duplicate notifications
  #' @param df data frame with lifedata
  #' @return data frame with duplicates collapsed
  collapse_duplicates <- function(df) {
    
    required_cols <- c("Notification Date", "pid", "Notification No", "Session Name", "Session Instance")
    missing_cols <- setdiff(required_cols, names(df))
    
    if (length(missing_cols) > 0) {
      stop("Missing required columns for duplicate collapse: ", paste(missing_cols, collapse = ", "))
    }
    
    message("Finding duplicates...")
    
    duplicate_notifications <- df %>%
      dplyr::group_by(`Notification Date`, pid, `Notification No`, `Session Name`) %>%
      dplyr::summarise(unique_sessions = n_distinct(`Session Instance`), .groups = "drop") %>%
      dplyr::filter(unique_sessions > 1) %>%
      dplyr::select(-unique_sessions)
    
    message("Found ", nrow(duplicate_notifications), " notifications with duplicates")
    
    if (nrow(duplicate_notifications) == 0) {
      return(df)
    }
    
    # Extract and collapse duplicates
    duplicate_rows <- df %>%
      dplyr::semi_join(duplicate_notifications, 
                       by = c("Notification Date", "pid", "Notification No", "Session Name"))
    
    collapsed_duplicates <- duplicate_rows %>%
      dplyr::group_by(`Notification Date`, pid, `Notification No`, `Session Name`, `Prompt Label`) %>%
      dplyr::arrange(desc(`Session Instance`), .by_group = TRUE) %>%
      dplyr::summarise(
        across(everything(), ~ {
          non_na_vals <- na.omit(.x)
          if (length(non_na_vals) > 0) {
            first(non_na_vals)
          } else {
            first(.x)
          }
        }),
        .groups = "drop"
      )
    
    # Combine with non-duplicates
    non_duplicate_rows <- df %>%
      dplyr::anti_join(duplicate_notifications, 
                       by = c("Notification Date", "pid", "Notification No", "Session Name"))
    
    final_data <- bind_rows(non_duplicate_rows, collapsed_duplicates) %>%
      dplyr::arrange(pid, `Notification Date`, `Notification No`, `Session Name`, `Prompt Label`)
    
    message("Collapsed ", nrow(df) - nrow(final_data), " duplicate rows")
    
    return(final_data)
  }
  
  
  # Validate dependencies and paths
  validate_dependencies()
  validate_file_paths(data_path)
  
  # Set up directories
  dirs <- setup_directories()
  
  # Source redcap script
  source(file.path(dirs$scripts, "Utility Scripts/geo_redcap.r"))
  
  # Load required data
  message("Loading RedCap data...")
  redcap <- load_redcap(data_path = data_path)
  
  message("Loading lifedata files...")
  lifedata <- load_raw_lifedata(data_path = data_path) %>%
    tidyr::separate(`Participant ID`, into = c("pakID", "userID"), sep = "-")
  
  lifepack_ids <- load_lifepack_info(data_path)
  
  removal_ids <- load_removal_ids(data_path)
  
  # Process data through pipeline
  message("Processing lifedata through cleaning pipeline...")
  
  cleaned_data <- lifedata %>%
    remove_lifepack_ids(removal_ids) %>%
    add_participant_info(lifepack_ids, redcap) %>%
    separate_reset_packs(redcap) %>%
    mutate(`Notification Date` = as.Date(`Notification Time`)) %>%
    filter_by_redcap_dates(redcap) %>%
    fix_response_errors() %>%
    collapse_duplicates() %>%
    add_all_variables() %>%
    mutate(
      Responded = ifelse(Responded == "User didn't respond to this notification", 0, Responded)
    )
  
  # Save cleaned data
  save_lifedata(cleaned_data, name = "clean", folder = "clean", data_path = data_path)
  
  return(cleaned_data)
}


# DATA I/O FUNCTIONS --------------

#' Save lifedata with archiving
#' @param df data frame to save
#' @param name name suffix for file
#' @param folder folder to save in
#' @param data_path base data path
#' @return saved data frame
save_lifedata <- function(df, name, folder, data_path=LIFEDATA_CONFIG$data_path) {
  
  # Archive old files
  move_old_files <- function(pattern, source_dir, archive_dir) {
    files <- list.files(source_dir)
    matching_files <- files[grepl(sprintf("lifedata_%s", pattern), files)]
    
    if (length(matching_files) > 0) {
      if (!dir.exists(archive_dir)) {
        dir.create(archive_dir, recursive = TRUE)
      }
      
      for (file in matching_files) {
        file.rename(
          file.path(source_dir, file),
          file.path(archive_dir, file)
        )
      }
    }
  }
  
  source_dir <- file.path(data_path, "Lifedata", folder)
  archive_dir <- file.path(source_dir, "archive")
  
  move_old_files(name, source_dir, archive_dir)
  
  # Save new file
  date_stamp <- Sys.Date()
  filename <- sprintf("lifedata_%s_%s.csv", name, date_stamp)
  filepath <- file.path(source_dir, filename)
  
  fwrite(df, filepath, row.names = FALSE)
  message("File created: ", filepath)
  
  return(df)
}

#' Load cleaned lifedata
#' @param format "long" or "wide"
#' @param data_path base data path
#' @return lifedata data frame
load_lifedata <- function(format = "long", data_path=LIFEDATA_CONFIG$data_path) {
  
  #' Convert long format to wide format
  #' @param df long format data frame
  #' @return wide format data frame
  convert_to_wide_format <- function(df) {
    
    df %>%
      dplyr::select(-Imputed) %>%
      tidyr::pivot_wider(
        names_from = "Prompt Label",
        values_from = "Response",
        values_fill = list(Response = NA)
      ) %>%
      dplyr::mutate(
        across(c(pos, neg, stress, talkAll_val, talkAll_urge), as.numeric),
        `Notification Time` = force_tz(
          as.POSIXct(`Notification Time`, format = "%Y-%m-%d %H:%M:%S"), 
          tzone = "America/New_York"
        ),
        Response_Time = force_tz(
          as.POSIXct(Response_Time, format = "%Y-%m-%d %H:%M:%S"), 
          tzone = "America/New_York"
        )
      ) %>%
      dplyr::group_by(pid, Type, day) %>%
      dplyr::mutate(
        daily_average_pos = mean(pos, na.rm = TRUE),
        daily_average_neg = mean(neg, na.rm = TRUE),
        daily_stress = mean(stress, na.rm = TRUE),
        daily_talkAll_val = mean(talkAll_val, na.rm = TRUE),
        daily_talkAll_urge = mean(talkAll_urge, na.rm = TRUE)
      ) %>%
      dplyr::ungroup()
  }
  
  
  clean_dir <- file.path(data_path, "Lifedata/clean")
  files <- file.info(list.files(clean_dir, full.names = TRUE))
  
  if (nrow(files) == 0) {
    stop("No cleaned lifedata files found in ", clean_dir)
  }
  
  # Get most recent file
  latest_file <- files %>%
    dplyr::mutate(filename = rownames(.)) %>%
    dplyr::filter(!isdir) %>%
    dplyr::arrange(desc(mtime)) %>%
    dplyr::slice(1) %>%
    dplyr::pull(filename)
  
  df <- read_csv(latest_file, show_col_types = FALSE)
  
  if (format == "long") {
    return(df)
  } else if (format == "wide") {
    return(convert_to_wide_format(df))
  } else {
    stop("Format must be 'long' or 'wide'")
  }
}

#' Windsorize variables to handle outliers
#' @param df data frame
#' @param variable variable name to windsorize
#' @param lower lower threshold
#' @param upper upper threshold
#' @param method "sd" or "quartile"
#' @return windsorized data frame
windsorize_variable <- function(df, variable, lower = 3, upper = 3, method = "sd") {
  
  method <- match.arg(method, choices = c("sd", "quartile"))
  is_col_name <- variable %in% names(df)
  
  if (!is_col_name && !"Prompt Label" %in% names(df)) {
    stop("Variable not found and Prompt Label column missing")
  }
  
  if (method == "sd") {
    df <- df %>%
      dplyr::group_by(pid, Type) %>%
      dplyr::mutate(
        sd_val = ifelse(is_col_name,
                       sd(as.numeric(.data[[variable]]), na.rm = TRUE),
                       sd(as.numeric(Response[`Prompt Label` == variable]), na.rm = TRUE)),
        
        mean_val = ifelse(is_col_name,
                         mean(as.numeric(.data[[variable]]), na.rm = TRUE),
                         mean(as.numeric(Response[`Prompt Label` == variable]), na.rm = TRUE)),
        
        upper_sd = mean_val + (upper * sd_val),
        lower_sd = pmax(mean_val - (lower * sd_val), 0),
        
        Response = ifelse(
          is_col_name,
          dplyr::case_when(
            as.numeric(.data[[variable]]) > upper_sd ~ upper_sd,
            as.numeric(.data[[variable]]) < lower_sd ~ lower_sd,
            TRUE ~ as.numeric(.data[[variable]])
          ),
          dplyr::case_when(
            `Prompt Label` == variable & as.numeric(Response) > upper_sd ~ upper_sd,
            `Prompt Label` == variable & as.numeric(Response) < lower_sd ~ lower_sd,
            TRUE ~ as.numeric(Response)
          )
        ),
        Response = as.character(round(Response, 2))
      ) %>%
      dplyr::ungroup() %>%
      dplyr::select(-sd_val, -mean_val, -upper_sd, -lower_sd)
      
  } else if (method == "quartile") {
    df <- df %>%
      dplyr::group_by(pid, Type) %>%
      dplyr::mutate(
        lower_q = pmax(quantile(as.numeric(Response[`Prompt Label` == variable]), lower, na.rm = TRUE), 0),
        upper_q = quantile(as.numeric(Response[`Prompt Label` == variable]), upper, na.rm = TRUE),
        iqr = upper_q - lower_q,
        upper_quartile = upper_q + 1.5 * iqr,
        lower_quartile = lower_q - 1.5 * iqr,
        
        Response = case_when(
          `Prompt Label` == variable & as.numeric(Response) > upper_quartile ~ upper_quartile,
          `Prompt Label` == variable & as.numeric(Response) < lower_quartile ~ lower_quartile,
          TRUE ~ as.numeric(Response)
        )
      ) %>%
      dplyr::ungroup() %>%
      dplyr::select(-lower_q, -upper_q, -iqr, -upper_quartile, -lower_quartile)
  }
  
  return(df)
}