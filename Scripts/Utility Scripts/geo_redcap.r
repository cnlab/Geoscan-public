## REDCap Geodata Processing Pipeline
## Refactored for modularity and ease of use

library(pacman)
p_load(tidyverse, rjson, REDCapR)

# Configuration ----
REDCAP_CONFIG <- list(
  uri = 'https://ascredcap.asc.upenn.edu/api/',
  data_path = "/Volumes/cnlab/GeoRemote/Data/",
  pid_pattern = "^GR\\d{3}$",
  exclude_test_pattern = "test"
)

# Main Data Loading Functions ----

#' Load REDCap data (main entry point)
#' @param download Logical, whether to download fresh data or load cached
#' @param api_key Character, REDCap API token (prompted if not provided)
#' @param data_path Character, base data directory path
#' @param apply_factors Logical, whether to apply demographic factoring
#' @return Data frame with processed REDCap data
load_redcap_data <- function(download = FALSE, 
                             api_key = "", 
                             data_path = REDCAP_CONFIG$data_path,
                             apply_factors = TRUE) {
  
  df <- if (download) {
    download_and_process_redcap(api_key, data_path)
  } else {
    load_cached_redcap(data_path)
  }
  
  if (apply_factors) {
    df <- factor_demographics(df)
  }
  
  return(df)
}

#' Download fresh data from REDCap API
download_and_process_redcap <- function(api_key, data_path) {
  
  # Handle API key
  if (api_key == "") {
    api_key <- .rs.askForPassword("Please enter your REDCap API token")
    if (is.null(api_key) || api_key == "") stop("API token is required")
  }
  
  # Download data
  message("Downloading data from REDCap...")
  result <- redcap_read_oneshot(redcap_uri = REDCAP_CONFIG$uri, token = api_key)
  
  if (!result$success) {
    stop("Failed to download REDCap data: ", result$status_message)
  }
  
  # Process and save
  df_raw <- result$data
  save_redcap_file(df_raw, "raw", data_path)
  
  df_clean <- df_raw %>%
    apply_manual_fixes() %>%
    filter_valid_participants() %>%
    remove_identifying_vars(data_path) %>%
    collapse_checkbox_vars()
  
  save_redcap_file(df_clean, "clean", data_path)
  message("Data processing complete")
  
  return(df_clean)
}

#' Load most recent cached clean data
load_cached_redcap <- function(data_path) {
  clean_path <- file.path(data_path, "Redcap/clean")
  
  if (!dir.exists(clean_path)) {
    stop("Clean REDCap directory not found. Try download = TRUE")
  }
  
  files <- list.files(clean_path, full.names = TRUE, pattern = "redcap_clean")
  if (length(files) == 0) {
    stop("No clean REDCap files found. Try download = TRUE")
  }
  
  # Get most recent file
  recent_file <- files[which.max(file.mtime(files))]
  message("Loading: ", basename(recent_file))
  
  return(read_csv(recent_file, show_col_types = FALSE))
}

# Data Processing Functions ----

#' Apply manual data fixes
apply_manual_fixes <- function(df) {
  df %>%
    dplyr::mutate(
      consent_date = if_else(pid == "GR286", as.Date("2024-01-25"), consent_date),
      age = floor(interval(dob, consent_date) / years(1))
    )
}

#' Filter to valid participant IDs
filter_valid_participants <- function(df) {
  if (!"pid" %in% names(df)) stop("Data must contain 'pid' column")
  
  initial_n <- nrow(df)
  
  df_filtered <- df %>%
    dplyr::filter(
      stringr::str_detect(pid, REDCAP_CONFIG$pid_pattern),
      !stringr::str_detect(pid, stringr::regex(REDCAP_CONFIG$exclude_test_pattern, ignore_case = TRUE))
    )
  
  message(sprintf("Filtered to %d valid records from %d total", 
                  nrow(df_filtered), initial_n))
  
  return(df_filtered)
}

#' Remove identifying variables based on drop list
remove_identifying_vars <- function(df, data_path) {
  drop_file <- file.path(data_path, "Redcap/utility/drop_vars.csv")
  
  if (file.exists(drop_file)) {
    drop_vars <- read_csv(drop_file, show_col_types = FALSE)$Variable
    n_removed <- length(intersect(names(df), drop_vars))
    df <- df %>% select(!matches(drop_vars))
    message(sprintf("Removed %d identifying variables", n_removed))
  } else {
    warning("Drop variables file not found: ", drop_file)
  }
  
  return(df)
}

#' Collapse checkbox variables (race by default)
collapse_checkbox_vars <- function(df, 
                                   var_name = "race",
                                   pattern = "race___",
                                   multiple_code = "8") {
  
  checkbox_cols <- df %>% select(starts_with(pattern))
  
  if (ncol(checkbox_cols) == 0) {
    warning("No checkbox columns found for pattern: ", pattern)
    return(df)
  }
  
  # Extract and sort column numbers
  col_names <- names(checkbox_cols)
  col_numbers <- as.numeric(str_extract(col_names, "\\d+$"))
  sort_order <- order(col_numbers)
  
  sorted_cols <- checkbox_cols[, sort_order]
  sorted_numbers <- col_numbers[sort_order]
  
  # Collapse each row
  collapsed_values <- apply(sorted_cols, 1, function(row) {
    selected <- which(row == 1)
    
    if (length(selected) == 0) {
      return(NA_character_)
    } else if (length(selected) == 1) {
      return(as.character(sorted_numbers[selected]))
    } else {
      return(multiple_code)
    }
  })
  
  df[[var_name]] <- collapsed_values

  message(sprintf("Collapsed %d checkbox columns into '%s'", 
                  length(col_names), var_name))
  
  return(df)
}

# File Management Functions ----

#' Save REDCap file with automatic archiving
save_redcap_file <- function(df, type, data_path) {
  if (nrow(df) == 0) {
    warning("Empty dataframe - not saving")
    return(df)
  }
  
  save_dir <- file.path(data_path, "Redcap", type)
  dir.create(save_dir, recursive = TRUE, showWarnings = FALSE)
  
  # Archive existing files
  archive_old_files(save_dir, type)
  
  # Save new file
  filename <- sprintf("redcap_%s_%s.csv", type, Sys.Date())
  filepath <- file.path(save_dir, filename)
  
  write_csv(df, filepath)
  message("Saved: ", filepath)
  
  return(df)
}

#' Archive old REDCap files
archive_old_files <- function(source_dir, type) {
  archive_dir <- file.path(source_dir, "archive")
  dir.create(archive_dir, recursive = TRUE, showWarnings = FALSE)
  
  pattern <- sprintf("redcap_%s", type)
  old_files <- list.files(source_dir, pattern = pattern, full.names = TRUE)
  old_files <- old_files[!grepl("archive", old_files)]
  
  if (length(old_files) > 0) {
    file.rename(old_files, file.path(archive_dir, basename(old_files)))
    message(sprintf("Archived %d old file(s)", length(old_files)))
  }
}

#' Load raw REDCap files
load_raw_redcap <- function(type = "raw", data_path = REDCAP_CONFIG$data_path) {
  raw_dir <- file.path(data_path, "Redcap/raw")
  
  if (!dir.exists(raw_dir)) {
    stop("Raw directory not found: ", raw_dir)
  }
  
  files <- list.files(raw_dir, pattern = type, full.names = TRUE)
  if (length(files) == 0) {
    stop("No files found matching type: ", type)
  }
  
  # Get most recent
  recent_file <- files[which.max(file.mtime(files))]
  message("Loading: ", basename(recent_file))
  
  return(read_csv(recent_file, show_col_types = FALSE))
}

# Data Dictionary Functions ----

#' Load and process REDCap data dictionary
load_redcap_dictionary <- function(data_path = REDCAP_CONFIG$data_path) {
  
  raw_dict <- load_raw_redcap("DataDictionary", data_path)
  
  # Check required columns
  required_cols <- c(
    "Variable / Field Name", "Form Name", "Field Type",
    "Field Label", "Choices, Calculations, OR Slider Labels"
  )
  
  missing_cols <- dplyr::setdiff(required_cols, names(raw_dict))
  if (length(missing_cols) > 0) {
    stop("Missing dictionary columns: ", paste(missing_cols, collapse = ", "))
  }
  
  # Clean column names
  clean_dict <- raw_dict %>%
    dplyr::rename(
      var = `Variable / Field Name`,
      form = `Form Name`,
      type = `Field Type`,
      label = `Field Label`,
      options = `Choices, Calculations, OR Slider Labels`
    )
  
  message(sprintf("Loaded dictionary: %d variables across %d forms",
                  nrow(clean_dict), n_distinct(clean_dict$form)))
  
  return(clean_dict)
}

# Demographic Processing ----

#' Apply demographic factoring with predefined schemes
factor_demographics <- function(df, variables = c("race", "gender", "ethnicity")) {
  
  # Demographic coding schemes
  schemes <- list(
    race = list(
      levels = as.character(1:8),
      labels = c("Asian", "Black", "Pacific Islander or Hawaiian Native",
                 "American Indian or Alaska Native", "White", 
                 "Prefer to self-describe", "Prefer not to say", "More than one")
    ),
    gender = list(
      levels = as.character(1:8),
      labels = c("Man", "Woman", "Prefer not to say", "Non-binary",
                 "Genderqueer", "Agender", "Gender fluid", "I prefer to self-describe")
    ),
    ethnicity = list(
      levels = as.character(0:2),
      labels = c("No", "Yes", "Prefer not to say")
    )
  )
  
  # Apply factoring to available variables
  available_vars <- dplyr::intersect(variables, names(df))
  
  for (var in available_vars) {
    if (var %in% names(schemes)) {
      scheme <- schemes[[var]]
      df[[var]] <- factor(df[[var]], levels = scheme$levels, labels = scheme$labels)
    }
  }
  
  if (length(available_vars) > 0) {
    message("Applied demographic factoring to: ", paste(available_vars, collapse = ", "))
  }
  
  return(df)
}

# Convenience Wrappers ----

#' Quick load for interactive use
load_redcap <- function(data_path = REDCAP_CONFIG$data_path) {
  load_redcap_data(download = FALSE, data_path = data_path)
}

#' Quick download for fresh data
download_redcap <- function(api_key = "", data_path = REDCAP_CONFIG$data_path) {
  load_redcap_data(download = TRUE, api_key = api_key, data_path = data_path)
}