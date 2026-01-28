# SETUP ====================================================================

## Set Working Directory ----
if ("Scripts" %in% unlist(strsplit(normalizePath("."), "/"))) {
  scripts_directory = paste(unlist(strsplit(normalizePath("."), "/"))[1:which(unlist(strsplit(normalizePath("."), "/"))=="Scripts")],collapse="/")
} else {
  print("Select any file within Scripts to set up the path")
  temp = file.choose()
  scripts_directory = paste(unlist(strsplit(temp, "/"))[1:which(unlist(strsplit(temp, "/"))=="Scripts")],collapse="/")
}

## Load Required Packages ----
# R Packages, Function to load and install packages simultaneously
if (!requireNamespace("pacman", quietly = TRUE)) {
  install.packages("pacman")
} else {require(pacman)}
p_load(cli, lme4, plyr, tidyverse, ggplot2, DescTools, psych, lmerTest, sjPlot,  hms, data.table, ggeffects, modelr, sf,stringdist,mapview, patchwork,progress,dplyr,readxl, nlme, tigris, install = TRUE)


tryCatch(
  {
    p_load_gh("nyu-mhealth/Mobility")
  },
  error = function(e) {devtools::install_github("nyu-mhealth/Mobility")}
)

## Source Utility Scripts ----
geocodebase_directory = file.path(scripts_directory,"Utility Scripts/geo_codebase/")
geocodebase_scripts = c(
  "uploadGeodata.R", "cleanDates.R",
  "spaceTimeLags.R", "intakeRetailers.R",
  "bufferAndJoin.R", "joinTracts.R",
  "indirectMLM.R", 
  "geotrackingLeaflet.R", "retailersLeaflet.R", "exposureLeaflet.R",
  "intakeSummary.R", "graphicsFunctions.R",
  "removeDuplicates.R"
)

## Load Additional Packages ----
for (script in geocodebase_scripts) {source(paste0(geocodebase_directory, script))}

# CONFIGURATION =============================================================

## Geo Exposure Config ----
GEO_EXPOSURE_CONFIG <- list(

  # Default buffer distances (can be extended in the future)
  
  # Conditional Buffer
  default_buffers = c("500ft", "1000ft"),
  # Small Buffer
  default_small_buffers = c("100ft"),
  
  # Default Types
  default_types = c("Baseline", "Intervention"),
  
  # Default data path
  data_path = "/Volumes/cnlab/GeoRemote/Data"
)

# GEO DATA LOADING FUNCTIONS ===================================================

## Load Day-Level Geo Exposures ----
load_geo_exposures <- function(Type, 
                               buffer = GEO_EXPOSURE_CONFIG$default_buffers,
                               data_path = GEO_EXPOSURE_CONFIG$data_path,
                               include_observations = FALSE,
                               config = GEO_EXPOSURE_CONFIG) {
  
  ### Setup ----
  file_name <- "RetailerExposure/ConditionalBuffer/%s/%s_100ft_nExposures_nObservations.csv"
  col_spec <- readr::cols(
    pid = readr::col_character(),
    day = readr::col_double(),
    n_exposure_per_day = readr::col_double(),
    n_observations_per_day = readr::col_double()
  )
  
  Type <- stringr::str_to_title(tolower(Type))
  
  cli_rule("Loading Day-Level Exposures")
  cli_text("Type: {.field {Type}} | Buffers: {.val {paste(buffer, collapse = ', ')}} | Include Observations: {.val {include_observations}}")
  
  ### Validation ----
  # validate data_path
  if (!dir.exists(data_path)) {
    cli::cli_abort("Data path does not exist: {data_path}")
  }
  
  # validate Type
  if (!tolower(Type) %in% tolower(config$default_types)) {
   cli::cli_abort(
      "Type must be one of: {paste(GEO_EXPOSURE_CONFIG$default_types, collapse = ', ')}\n",
      "Provided: '{Type}'"
    )
  }
  
  # validate and standardize buffer(s)
  if (is.numeric(buffer)) {
    # Handle numeric vector: c(500, 1000) -> c("500ft", "1000ft")
    buffer <- paste0(buffer, "ft")
  } else if (is.character(buffer)) {
    # Handle character vector: c("500", "500ft", "1000") -> c("500ft", "500ft", "1000ft")
    standardized_buffer <- c()
    for (b in buffer) {
      buffer_num <- stringr::str_extract(b, "^[0-9]+")
      if (is.na(buffer_num)) {
        cli::cli_abort("Buffer must contain numeric values (e.g., '500ft', '500', or 500). Invalid: '{b}'")
      }
      standardized_buffer <- c(standardized_buffer, paste0(buffer_num, "ft"))
    }
    buffer <- standardized_buffer
  } else {
    cli::cli_abort("Buffer must be numeric or character vector")
  }
  
  # validate buffer(s) against defaults
  missing_buffers <- buffer[!tolower(buffer) %in% tolower(config$default_buffers)]
  
  if (length(missing_buffers) > 0) {
    cli::cli_warn(c(
      "Some buffers not in default list: {paste(config$default_buffers, collapse = ', ')}",
      "x" = "Not in defaults: {paste(missing_buffers, collapse = ', ')}",
      "i" = "May fail if files do not exist"
    ))
  }
  
  # validate files
  ## Build file paths for all buffers
  file_paths <- purrr::set_names(buffer) %>%
    purrr::map_chr(~ {
      path <- file.path(
        data_path,
        sprintf(file_name, 
                Type, .x)
      )
      if (!file.exists(path)) {
        cli::cli_abort("File not found for {.x}: {path}")
      }
      return(path)
    })
  
  
  # Initialize empty list to store dataframes
  geo_data_list <- list()
  
  ### Data Loading ----
  # Loop over each buffer distance
  for (b in buffer) {
    
    # Construct file path
    file_path <- file_paths[[b]]
    
    # Log loading message
    cli_alert_info("Loading {Type} geo exposures for {b}")
    
    # Load data with explicit column specifications
    geo_data <- tryCatch({
      readr::read_csv(
        file_path, 
        col_types = col_spec,
        show_col_types = FALSE
      )
    }, error = function(e) {
      cli::cli_abort(
        "Failed to read file: {file_path}\n",
        "Error: {e$message}"
      )}
    )
    
    # Validate required columns exist
    required_cols <- c("pid", "day", "n_exposure_per_day", "n_observations_per_day")
    missing_cols <- setdiff(required_cols, colnames(geo_data))
    if (length(missing_cols) > 0) {
      cli::cli_abort(
        "Missing required columns in {file_path}: {paste(missing_cols, collapse = ', ')}"
      )
    }
    
    # Rename the exposure column based on buffer
    exposure_col_name <- glue::glue("daily_exposures_{b}_100ft")
    geo_data <- geo_data %>%
      dplyr::rename(!!exposure_col_name := n_exposure_per_day)
    
    # Remove observations column if !include_observations
    if (!include_observations) {
      geo_data <- geo_data %>%
        dplyr::select(-n_observations_per_day)
    } else {
      # Rename observations column to match buffer naming convention
      observations_col_name <- glue::glue("daily_observations_{b}_100ft")
      geo_data <- geo_data %>%
        dplyr::rename(!!observations_col_name := n_observations_per_day)
    }
    geo_data_list[[b]] <- geo_data
  }
  
  ## Data Merging ----
  # Merge the datasets on 'pid' and 'day'
  if (length(geo_data_list) == 1) {
    # If only one buffer, return it directly
    geo_data_exposures <- geo_data_list[[1]]
  } else {
    # Merge multiple datasets using tidyverse approach
    geo_data_exposures <- purrr::reduce(
      geo_data_list,
      ~ dplyr::full_join(.x, .y, by = c("pid", "day"))
    )
  }
  
  ### Final Processing ----
  result <- geo_data_exposures %>%
    dplyr::arrange(pid, day)
  
  cli::cli_alert_success(
    "Successfully loaded geo exposure data for {Type}: \n{.val {length(unique(result$pid))}} pIDs | {.val {nrow(result)}} rows"
  )
  
  return(result)
}

## Load Within-Day Geo Observations ----
load_geodata <- function(Type,
                         data_path = GEO_EXPOSURE_CONFIG$data_path,
                         config = GEO_EXPOSURE_CONFIG) {
  
  ### Setup ----
  file_name <- "Geodata/clean/merged_%s.csv"

  Type <- stringr::str_to_title(tolower(Type))
  
  cli::cli_rule("Loading within-day geodata")
  cli::cli_text("Type: {.field {Type}}")
  
  ### Validation ----
  # validate data_path
  if (!dir.exists(data_path)) {
    cli::cli_abort("Data path does not exist: {data_path}")
  }
  
  # validate Type
  if (!tolower(Type) %in% tolower(config$default_types)) {
    cli::cli_abort(c(
      "Type must be one of: {paste(config$default_types, collapse = ', ')}",
      "x" = "Provided: '{Type}'"
    ))
  }
  
  # validate file
  file_path <- file.path(data_path, sprintf(file_name, tolower(Type)))
  if (!file.exists(file_path)) {
    cli::cli_abort("File not found: {file_path}")
  }
  
  ### Data Loading ----
  cli::cli_alert_info("Loading {Type} geodata")
  
  geodata <- tryCatch({
    vroom::vroom(
      file_path,
      show_col_types = FALSE,
      progress = TRUE  # Shows built-in progress bar
    ) %>% dplyr::filter(!is.na(datetime) & !is.na(pid))
  }, error = function(e) {
    cli::cli_process_failed()
    cli::cli_abort(c(
      "Failed to read file: {file_path}",
      "x" = "Error: {e$message}"
    ))
  })
  
  ### Data Processing ----
  cli::cli_process_start("Converting datetime to EST and sorting...")
  result <- geodata %>%
    dplyr::mutate(datetime = lubridate::ymd_hms(datetime, tz = "America/New_York", quiet = TRUE)) %>%
    dplyr::arrange(pid, datetime)
  cli::cli_process_done()
  
  cli::cli_alert_success(
    "Successfully loaded {Type} geodata: \n{.val {length(unique(result$pid))}} pIDs | {.val {nrow(result)}} rows"
    )
  
  return(result)
}

## Load Geo Observations with Day-Level Exposures ----
load_geodata_with_exposures <- function(Type, 
                                        buffer = GEO_EXPOSURE_CONFIG$default_buffers,
                                        data_path = GEO_EXPOSURE_CONFIG$data_path,
                                        include_observations = FALSE,
                                        config = GEO_EXPOSURE_CONFIG) {
  
  ### Setup ----
  Type <- stringr::str_to_title(tolower(Type))
  
  cli::cli_rule("Loading geo observations with day-level exposures")
  cli::cli_text("Type: {.field {Type}} | Buffers: {.val {paste(buffer, collapse = ', ')}}")
  
  # Data Loading ----
  # Load geodata, drop rows with missing pid or day
  cli::cli_h1("Calling load_geodata()")
  geodata <- tryCatch({
    load_geodata(Type, data_path = data_path, 
                 config = config)
  }, error = function(e) {
    cli::cli_abort(c(
      "Failed to load geodata",
      "x" = "Error: {e$message}"
    ))
  })

  # Load geo exposures
  cli::cli_h1("Calling load_geo_exposures()")
  geo_exposures <- tryCatch({
    load_geo_exposures(Type, 
                       buffer = buffer, 
                       data_path = data_path, 
                       include_observations = include_observations,
                       config = config)}, error = function(e) {
    cli::cli_abort(c(
      "Failed to load geo exposures",
      "x" = "Error: {e$message}"
    ))
  })

  # Data Merging ----
  cli::cli_h1("Merging day-level exposure to geo observations on pid, dy")
  
  geodata_with_exposures <- tryCatch({
    dplyr::left_join(geodata, geo_exposures, by = c("pid", "day"))
  }, error = function(e) {
    cli::cli_abort(c(
      "Failed to merge datasets",
      "x" = "Error: {e$message}"
    ))
  })

  cli::cli_alert_success(
    "Successfully loaded and merged {Type} data: {nrow(geodata_with_exposures)} rows with {length(buffer)} buffer(s)"
  )
  
  return(geodata_with_exposures)
}
## Load Within-Day Geo Exposures ----
load_geodata_within_day_exposures <- function(Type, 
                                              buffer,
                                              data_path = GEO_EXPOSURE_CONFIG$data_path,
                                              config = GEO_EXPOSURE_CONFIG) {
  
  file_name <- "RetailerExposure/ConditionalBuffer/%s/%s_100ft_exposures.csv"
  
  # Format Arguments ----
  ## Type
  Type <- stringr::str_to_title(tolower(Type))
  ## Buffer
  if (is.numeric(buffer)) {
    buffer <- paste0(buffer, "ft")
  } else if (is.character(buffer) && length(buffer) == 1) {
    # Remove any existing 'ft' suffix and extract number
    buffer_num <- stringr::str_extract(buffer, "^[0-9]+")
    if (is.na(buffer_num)) {
      cli::cli_abort("Buffer must contain a numeric value (e.g., '500ft', '500', or 500)")
    }
    buffer <- paste0(buffer_num, "ft")
  } else {
    cli::cli_abort("Buffer must be a single numeric or character value")
  }
  
  cli::cli_rule("Loading within-day geo exposures with observations")
  cli::cli_text("Type: {.field {Type}} | Buffer: {.val {buffer}}")
  
  # Validation ----
  # validate data_path
  if (!dir.exists(data_path)) {
    cli::cli_abort("Data path does not exist: {data_path}")
  }
  
  # validate Type
  if (!tolower(Type) %in% tolower(config$default_types)) {
    cli::cli_abort(c(
      "Type must be one of: {paste(config$default_types, collapse = ', ')}",
      "x" = "Provided: '{Type}'"
    ))
  }
  
  # validate buffer
  if (!tolower(buffer) %in% tolower(config$default_buffers)) {
    cli::cli_warn(
      "Buffer not in default list: {paste(config$default_buffers, collapse = ', ')} | Provided: '{buffer}' - may fail if file does not exist"
    )
  }
  
  # validate file
  file_path <- file.path(data_path, sprintf(file_name, Type, buffer))
  if (!file.exists(file_path)) {
    cli::cli_abort("File not found: {file_path}")
  }
  
  # Data Loading ----
  cli::cli_alert_info("Loading {Type} within-day exposures for {buffer}")
  
  geodata_exposures <- tryCatch({
    vroom::vroom(
      file_path,
      show_col_types = FALSE,
      progress = TRUE,  # Shows built-in progress bar
      .name_repair = "unique_quiet"
  ) %>%
      # Remove columns that are all NA
      dplyr::select(where(~ !all(is.na(.x))))
  }, error = function(e) {
    cli::cli_abort(c(
      "Failed to read file: {file_path}",
      "x" = "Error: {e$message}"
    ))
  })
  
  # Data Processing ----
  cli::cli_process_start("Converting datetime...")
  
  result <- geodata_exposures %>%
    dplyr::mutate(datetime = as.POSIXct(datetime, format = "%Y-%m-%dT%H:%M:%S", tz = "America/New_York"))
  
  cli::cli_process_done()
  
  # Data Validation ----
  if (nrow(result) == 0 || ncol(result) == 0) {
    cli::cli_abort("Loaded dataframe is empty: {nrow(result)} rows × {ncol(result)} columns")
  }
  
  cli::cli_alert_success(
    "Successfully loaded {Type} within-day exposures for {buffer}: \n{.val {length(unique(result$pid))}} pIDs | {.val {nrow(result)}} rows"
  )
  
  return(result)
}
## Load Stay Events Data ----
load_stay_events <- function(type, 
                             small_buffer, 
                             conditional_buffer,
                             data_path = GEO_EXPOSURE_CONFIG$data_path,
                             config = GEO_EXPOSURE_CONFIG) {
  
  # Format Arguments ----
  # type
  type <- stringr::str_to_title(tolower(type))
  
  # small buffer
  if (is.numeric(small_buffer)) {
    small_buffer <- paste0(small_buffer, "ft")
  } else if (is.character(small_buffer) && length(small_buffer) == 1) {
    buffer_num <- stringr::str_extract(small_buffer, "^[0-9]+")
    if (is.na(buffer_num)) {
      cli::cli_abort("Small buffer must contain a numeric value (e.g., '100ft', '100', or 100)")
    }
    small_buffer <- paste0(buffer_num, "ft")
  } else {
    cli::cli_abort("Small buffer must be a single numeric or character value")
  }
  
  # conditional buffer
  if (is.numeric(conditional_buffer)) {
    conditional_buffer <- paste0(conditional_buffer, "ft")
  } else if (is.character(conditional_buffer) && length(conditional_buffer) == 1) {
    buffer_num <- stringr::str_extract(conditional_buffer, "^[0-9]+")
    if (is.na(buffer_num)) {
      cli::cli_abort("Conditional buffer must contain a numeric value (e.g., '500ft', '500', or 500)")
    }
    conditional_buffer <- paste0(buffer_num, "ft")
  } else {
    cli::cli_abort("Conditional buffer must be a single numeric or character value")
  }
  
  cli::cli_rule("Loading stay events data")
  cli::cli_text("Type: {.field {type}} | Small Buffer: {.val {small_buffer}} | Conditional Buffer: {.val {conditional_buffer}}")
  
  # Validation ----
  # validate data_path
  if (!dir.exists(data_path)) {
    cli::cli_abort("Data path does not exist: {data_path}")
  }
  
  # validate Type
  if (!tolower(type) %in% tolower(config$default_types)) {
    cli::cli_abort(c(
      "Type must be one of: {paste(config$default_types, collapse = ', ')}",
      "x" = "Provided: '{type}'"
    ))
  }
  
  # validate conditional_buffer is in defaults
  if (!tolower(conditional_buffer) %in% tolower(config$default_buffers)) {
    cli::cli_warn(c(
      "Conditional buffer not in default list: {paste(config$default_buffers, collapse = ', ')}",
      "Provided: '{conditional_buffer}' - proceeding anyway"
    ))
  }
  
  # validate conditional_buffer is in defaults
  if (!tolower(small_buffer) %in% tolower(config$default_small_buffers)) {
    cli::cli_warn(c(
      "Conditional buffer not in default list: {paste(config$default_buffers, collapse = ', ')}",
      "Provided: '{conditional_buffer}' - proceeding anyway"
    ))
  }
  
  # construct directory path
  directory_path <- file.path(
    data_path,
    "RetailerExposure/StayEvents",
    type,
    sprintf("%s_%s", conditional_buffer, small_buffer)
  )
  
  # validate directory exists
  if (!dir.exists(directory_path)) {
    cli::cli_abort("Directory not found: {directory_path}")
  }
  
  # File Searching ----
  cli::cli_alert_info("Searching for stay events files...")
  
  file_pattern <- "^geodata_with_retailers.*\\.csv$"
  file_list <- list.files(
    directory_path,
    pattern = file_pattern,
    full.names = TRUE
  )
  
  if (length(file_list) == 0) {
    cli::cli_abort(c(
      "No files found matching pattern: {file_pattern}",
      "x" = "Directory: {directory_path}"
    ))
  }
  
  cli::cli_text("Found {.val {length(file_list)}} matching files")
  
  # get file info and find most recent
  files_info <- tryCatch({
    file.info(file_list)
  }, error = function(e) {
    cli::cli_abort(c(
      "Failed to get file information",
      "x" = "Error: {e$message}"
    ))
  })
  
  # find most recent file
  most_recent_file <- files_info %>%
    dplyr::mutate(filename = rownames(.)) %>%
    dplyr::filter(isdir == FALSE) %>%
    dplyr::arrange(dplyr::desc(mtime)) %>%
    dplyr::slice(1) %>%
    dplyr::pull(filename)
  
  if (length(most_recent_file) == 0) {
    cli::cli_abort("No valid files found (all entries are directories)")
  }
  
  cli::cli_alert_info("Loading most recent file: {.file {basename(most_recent_file)}}")
  
  # Data Loading ----
  stay_events <- tryCatch({
    vroom::vroom(
      most_recent_file,
      show_col_types = FALSE,
      progress = TRUE,  # Shows built-in progress bar
      .name_repair = "unique_quiet") %>%
      # Remove columns that are all NA
      dplyr::select(where(~ !all(is.na(.x))))
  }, error = function(e) {
    cli::cli_abort(c(
      "Failed to read file: {most_recent_file}",
      "x" = "Error: {e$message}"
    ))
  })
  
  # Data Processing ----
  cli::cli_process_start("Processing datetime and cleaning data...")
  
  result <- stay_events %>%
    dplyr::select(-'...1') %>%  # Remove first column (likely row numbers)
    dplyr::mutate(datetime = lubridate::ymd_hms(datetime, tz = "America/New_York", quiet = TRUE))
  
  cli::cli_process_done()
  
  # Data Valiation ----
  if (nrow(result) == 0 || ncol(result) == 0) {
    cli::cli_abort("Loaded dataframe is empty: {nrow(result)} rows × {ncol(result)} columns")
  }
  
  cli::cli_alert_success(
    "Successfully loaded {type} stay events data: \n{.val {length(unique(result$pid))}} pIDs | {.val {nrow(result)}} rows"
  )
  
  return(result)
}

# SAVING FUNCTIONS ----
# Save EMA data with geo exposures
save_ema_with_geo_exposures <- function(df, 
                                        buffer, 
                                        type, 
                                        t = NULL, unit = NULL,
                                        data_path = GEO_EXPOSURE_CONFIG$data_path,
                                        config = GEO_EXPOSURE_CONFIG) {
  
  Type <- stringr::str_to_title(tolower(type))
  
  cli::cli_rule("Saving EMA data with geo exposures")
  cli::cli_text("Type: {.field {Type}} | Buffer: {.val {buffer}} | Time Parameters: {.val {ifelse(is.null(t), 'None', paste0(t, unit))}}")
  
  # Validation ----
  # validate dataframe
  if (!is.data.frame(df)) {
    cli::cli_abort("Input must be a dataframe")
  }
  
  if (nrow(df) == 0) {
    cli::cli_abort("Cannot save empty dataframe")
  }
  
  # validate data_path
  if (!dir.exists(data_path)) {
    cli::cli_abort("Data path does not exist: {data_path}")
  }
  
  # validate Type
  if (!tolower(Type) %in% tolower(config$default_types)) {
    cli::cli_abort(c(
      "Type must be one of: {paste(config$default_types, collapse = ', ')}",
      "x" = "Provided: '{Type}'"
    ))
  }
  
  # validate and standardize buffer
  if (is.numeric(buffer)) {
    buffer <- paste0(buffer, "ft")
  } else if (is.character(buffer) && length(buffer) == 1) {
    buffer_num <- stringr::str_extract(buffer, "^[0-9]+")
    if (is.na(buffer_num)) {
      cli::cli_abort("Buffer must contain a numeric value (e.g., '500ft', '500', or 500)")
    }
    buffer <- paste0(buffer_num, "ft")
  } else {
    cli::cli_abort("Buffer must be a single numeric or character value")
  }
  
  # validate buffer is in defaults (warning only)
  if (!tolower(buffer) %in% tolower(config$default_buffers)) {
    cli::cli_warn(c(
      "Buffer not in default list: {paste(config$default_buffers, collapse = ', ')}",
      "Provided: '{buffer}' - proceeding anyway"
    ))
  }
  
  # validate time parameters (both or neither)
  if (!is.null(t) && is.null(unit)) {
    cli::cli_abort("If 't' is provided, 'unit' must also be provided")
  }
  if (is.null(t) && !is.null(unit)) {
    cli::cli_abort("If 'unit' is provided, 't' must also be provided")
  }
  
  # BUILD FILE PATH ----
  if (!is.null(t)) {
    filename <- file.path(
      data_path,
      "RetailerExposure",
      "ConditionalBuffer", 
      Type,
      sprintf("%s_100ft_Exposures_With_EMA_%s%s.csv", buffer, t, unit)
    )
  } else {
    filename <- file.path(
      data_path,
      "RetailerExposure",
      "ConditionalBuffer",
      Type,
      paste0(buffer, "_100ft_Exposures_With_EMA.csv")
    )
  }
  
  # Create directory if it doesn't exist
  output_dir <- dirname(filename)
  if (!dir.exists(output_dir)) {
    cli::cli_alert_info("Creating directory: {.file {output_dir}}")
    dir.create(output_dir, recursive = TRUE)
  }
  
  # Check if file already exists
  if (file.exists(filename)) {
    cli::cli_warn("File already exists and will be overwritten: {.file {basename(filename)}}")
  }
  
  # SAVE ----
  cli::cli_alert_info("Saving to: {.file {basename(filename)}}")
  
  tryCatch({
    readr::write_csv(df, filename)
  }, error = function(e) {
    cli::cli_abort(c(
      "Failed to save file: {filename}",
      "x" = "Error: {e$message}"
    ))
  })
  
  # VERIFY SAVE ----
  if (!file.exists(filename)) {
    cli::cli_abort("File was not created successfully: {filename}")
  }
  
  # Get file size for reporting
  file_size <- file.info(filename)$size / (1024^2)  # MB
  
  cli::cli_alert_success(
    "Successfully saved EMA with geo exposures: \n{.val {nrow(df)}} rows × {.val {ncol(df)}} columns | File size: {.val {round(file_size, 2)}} MB"
  )
  
  cli::cli_text("Saved to: {.file {filename}}")
  
  return(invisible(filename))
}
# EMA LOADING FUNCTIONS ----

## Load EMA data with covariates ----
load_ema_with_covs <- function(Type = "", 
                               ema_variables = "all", 
                               redcap_variables = c("pid", "age", "gender", "ethnicity", "race"),
                               data_path = GEO_EXPOSURE_CONFIG$data_path,
                               config = GEO_EXPOSURE_CONFIG) {
  
  cli::cli_rule("Loading EMA data with redcap covariates")
  cli::cli_text("Type: {.field {ifelse(Type == '', 'Baseline, Intervention', Type)}} | EMA Variables: {.val {ifelse(length(ema_variables) == 1 && ema_variables == 'all', 'all', paste(head(ema_variables, 3), collapse = ', '))}}")
  cli::cli_text("RedCap Variables: {.val {ifelse(length(redcap_variables) == 1 && redcap_variables == 'all', 'all', paste(head(redcap_variables), collapse = ', '))}}")
  
  ### Validation ----
  #  data_path
  if (!dir.exists(data_path)) {
    cli::cli_abort("Data path does not exist: {data_path}")
  }
  
  # Type
  if (Type != "") {
    Type <- stringr::str_to_title(tolower(Type))
    if (!tolower(Type) %in% tolower(config$default_types)) {
      cli::cli_abort(c(
        "Type must be one of: {paste(config$default_types, collapse = ', ')} or empty string for all types",
        "x" = "Provided: '{Type}'"
      ))
    }
  }
  
  # ema_variables
  if (!is.character(ema_variables) || length(ema_variables) == 0) {
    cli::cli_abort("ema_variables must be a non-empty character vector")
  }
  
  # redcap_variables
  if (!is.character(redcap_variables) || length(redcap_variables) == 0) {
    cli::cli_abort("redcap_variables must be a non-empty character vector")
  }
  
  # scripts_directory
  if (!exists("scripts_directory")) {
    cli::cli_abort("scripts_directory variable not found - ensure it's defined in your environment")
  }
  
  # geo_life_data.r
  geo_lifedata_script <- file.path(scripts_directory, "Utility Scripts/geo_lifedata.r")
  if (!file.exists(geo_lifedata_script)) {
    cli::cli_abort("Required script not found: {geo_lifedata_script}")
  }
  
  ### Data Loading ----
  #### EMA Data ----
  cli::cli_alert_info("Loading EMA lifedata...")
  
  # Source required script
  tryCatch({
    source(geo_lifedata_script)
  }, error = function(e) {
    cli::cli_abort(c(
      "Failed to source geo_lifedata.r script",
      "x" = "Error: {e$message}"
    ))
  })
  
  # Load EMA data
  ema_data <- tryCatch({
    load_lifedata(format = "wide", data_path = data_path)
  }, error = function(e) {
    cli::cli_abort(c(
      "Failed to load EMA lifedata",
      "x" = "Error: {e$message}"
    ))
  })
  
  # Validate
  if (nrow(ema_data) == 0 || ncol(ema_data) == 0) {
    cli::cli_abort("Loaded EMA data is empty: {nrow(ema_data)} rows × {ncol(ema_data)} columns")
  }
  
  cli::cli_alert_success(
    "Successfully loaded {ifelse(Type == '', 'all', Type)} EMA: \n{.val {length(unique(ema_data$pid))}} pIDs | {.val {nrow(ema_data)}} rows"
  )
  
  # Process
  cli::cli_alert_info("Processing EMA data...")
  
  # Filter by Type if specified
  ema_filtered <- ema_data %>%
    {if (Type == "") . else dplyr::filter(., Type == !!Type)}
  
  if (nrow(ema_filtered) == 0) {
    cli::cli_abort("No EMA data remaining after filtering by Type: '{Type}'")
  }
  
  # Select EMA variables if not "all"
  cli::cli_alert_info("Selecting EMA variables: {.val {ifelse(length(ema_variables) == 1 && ema_variables == 'all', 'all', paste(head(ema_variables, 3), collapse = ', '))}}")
  if (length(ema_variables) > 1 && !"all" %in% ema_variables) {
    # Build column list
    ema_columns <- c("pid", ema_variables)
    if (Type == "") {
      ema_columns <- c("pid", "Type", ema_variables)
    }
    
    # Check if requested columns exist
    missing_cols <- setdiff(ema_columns, colnames(ema_filtered))
    if (length(missing_cols) > 0) {
      cli::cli_abort(c(
        "Requested EMA variables not found in data:",
        "x" = "Missing: {paste(missing_cols, collapse = ', ')}"
      ))
    }
    
    ema_filtered <- ema_filtered %>% 
      dplyr::select(dplyr::all_of(ema_columns))
  }
  
  cli::cli_text("EMA data processed: {.val {nrow(ema_filtered)}} rows × {.val {ncol(ema_filtered)}} columns")
  
  #### RedCap Data ----
  # Load if redcap_variables is not 'None'
  if (!("None" %in% redcap_variables)) {
    cli::cli_alert_info("Loading RedCap data...")
    
    # Validate script
    geo_redcap_script <- file.path(scripts_directory, "Utility Scripts/geo_redcap.r")
    if (!file.exists(geo_redcap_script)) {
      cli::cli_abort("Required script not found: {geo_redcap_script}")
    }
    
    # Source script
    tryCatch({
      source(geo_redcap_script)
    }, error = function(e) {
      cli::cli_abort(c(
        "Failed to source geo_redcap.r script",
        "x" = "Error: {e$message}"
      ))
    })
    
    # Load data
    redcap_data <- tryCatch({
      load_redcap(data_path = data_path)
    }, error = function(e) {
      cli::cli_abort(c(
        "Failed to load RedCap data",
        "x" = "Error: {e$message}"
      ))
    })
    
    # Validate data 
    if (nrow(redcap_data) == 0 || ncol(redcap_data) == 0) {
      cli::cli_abort("Loaded RedCap data is empty: {nrow(redcap_data)} rows × {ncol(redcap_data)} columns")
    }
    
    # Process data (filter by variables)
    if ("all" %in% redcap_variables) {
      redcap_vars <- redcap_data
    } else {
      # Check if requested columns exist
      missing_cols <- setdiff(redcap_variables, colnames(redcap_data))
      existing_cols <- intersect(redcap_variables, colnames(redcap_data))
      
      if (length(missing_cols) > 0) {
        cli::cli_warn(c(
          "Some requested RedCap variables not found in data:",
          "x" = "Missing: {paste(missing_cols, collapse = ', ')}",
          "i" = "Continuing with available variables: {paste(existing_cols, collapse = ', ')}"
        ))
      }
      
      # Check if we have any valid columns left
      if (length(existing_cols) == 0) {
        cli::cli_abort(c(
          "None of the requested RedCap variables exist in the data",
          "x" = "Requested: {paste(redcap_variables, collapse = ', ')}",
          "i" = "Available: {paste(head(colnames(redcap_data), 10), collapse = ', ')}..."
        ))
      }
      
      redcap_vars <- redcap_data[, existing_cols, drop = FALSE]
      cli::cli_text("Selected {.val {length(existing_cols)}} RedCap variables")
    }
    
    ### Data Merging ----
    cli::cli_alert_info("Merging EMA and RedCap data...")
    
    result <- tryCatch({
      ema_filtered %>%
        dplyr::left_join(redcap_vars, by = "pid")
    }, error = function(e) {
      cli::cli_abort(c(
        "Failed to merge EMA and RedCap data",
        "x" = "Error: {e$message}"
      ))
    })
    
    cli::cli_alert_success(
      "Successfully loaded and merged EMA with RedCap data: \n{.val {length(unique(result$pid))}} pIDs | {.val {nrow(result)}} rows × {.val {ncol(result)}} columns"
    )
    
  } else {
    # Return only EMA data
    result <- ema_filtered
    
    cli::cli_alert_success(
      "Successfully loaded EMA data (no RedCap): \n{.val {length(unique(result$pid))}} pIDs | {.val {nrow(result)}} rows × {.val {ncol(result)}} columns"
    )
  }
  
  return(result)
}

## Load EMA data with geo exposures ----
load_ema_with_geo_exposures <- function(buffer, 
                                        type, 
                                        t = NULL, 
                                        unit = NULL,
                                        data_path = GEO_EXPOSURE_CONFIG$data_path,
                                        config = GEO_EXPOSURE_CONFIG) {
  
  Type <- stringr::str_to_title(tolower(type))
  
  cli::cli_rule("Loading EMA data with geo exposures (100ft small buffer)")
  cli::cli_text("Type: {.field {Type}} | Buffer: {.val {buffer}} | Time Parameters: {.val {ifelse(is.null(t), 'None', paste0(t, unit))}}")
  
  # Validation ----
  # validate data_path
  if (!dir.exists(data_path)) {
    cli::cli_abort("Data path does not exist: {data_path}")
  }
  
  # validate Type
  if (!tolower(Type) %in% tolower(config$default_types)) {
    cli::cli_abort(c(
      "Type must be one of: {paste(config$default_types, collapse = ', ')}",
      "x" = "Provided: '{Type}'"
    ))
  }
  
  # validate and standardize buffer
  if (is.numeric(buffer)) {
    buffer <- paste0(buffer, "ft")
  } else if (is.character(buffer) && length(buffer) == 1) {
    buffer_num <- stringr::str_extract(buffer, "^[0-9]+")
    if (is.na(buffer_num)) {
      cli::cli_abort("Buffer must contain a numeric value (e.g., '500ft', '500', or 500)")
    }
    buffer <- paste0(buffer_num, "ft")
  } else {
    cli::cli_abort("Buffer must be a single numeric or character value")
  }
  
  # validate buffer is in defaults (warning only)
  if (!tolower(buffer) %in% tolower(config$default_buffers)) {
    cli::cli_warn(c(
      "Buffer not in default list: {paste(config$default_buffers, collapse = ', ')}",
      "Provided: '{buffer}' - proceeding anyway"
    ))
  }
  
  # validate time parameters (both or neither)
  if (!is.null(t) && is.null(unit)) {
    cli::cli_abort("If 't' is provided, 'unit' must also be provided")
  }
  if (is.null(t) && !is.null(unit)) {
    cli::cli_abort("If 'unit' is provided, 't' must also be provided")
  }
  
  # validate t parameter if provided
  if (!is.null(t)) {
    # Convert to character for consistent checking
    t_char <- as.character(t)
    valid_t_values <- c("1", "2", "2_to_1")
    
    if (!t_char %in% valid_t_values) {
      cli::cli_warn(c(
        "Parameter 't' should be one of: {paste(valid_t_values, collapse = ', ')}",
        "x" = "Provided: '{t}'"
      ))
    }
  }
  
  # validate unit parameter if provided
  if (!is.null(unit)) {
    valid_units <- c("hours")
    
    if (!unit %in% valid_units) {
      cli::cli_warn(c(
        "Parameter 'unit' should be one of: {paste(valid_units, collapse = ', ')}",
        "x" = "Provided: '{unit}'"
      ))
    }
  }
  
  # Build File Path ----
  if (!is.null(t)) {
    filename <- file.path(
      data_path,
      "RetailerExposure",
      "ConditionalBuffer", 
      Type,
      sprintf("%s_100ft_Exposures_With_EMA_%s%s.csv", buffer, t, unit)
    )
  } else {
    filename <- file.path(
      data_path,
      "RetailerExposure",
      "ConditionalBuffer",
      Type,
      paste0(buffer, "_100ft_Exposures_With_EMA.csv")
    )
  }
  
  # validate file exists
  if (!file.exists(filename)) {
    cli::cli_abort("File not found: {filename}")
  }
  
  # Data Loading ----
  cli::cli_alert_info("Loading EMA with geo exposures: {.file {basename(filename)}}")
  
  ema_geo_data <- tryCatch({
    readr::read_csv(filename, show_col_types = FALSE)
  }, error = function(e) {
    cli::cli_abort(c(
      "Failed to read file: {filename}",
      "x" = "Error: {e$message}"
    ))
  })
  
  # VALIDATE LOADED DATA
  if (nrow(ema_geo_data) == 0 || ncol(ema_geo_data) == 0) {
    cli::cli_abort("Loaded dataframe is empty: {nrow(ema_geo_data)} rows × {ncol(ema_geo_data)} columns")
  }
  
  # validate required columns exist
  required_cols <- c("before_prompt_exposures", "after_prompt_exposures", "Notification Time")
  missing_cols <- setdiff(required_cols, colnames(ema_geo_data))
  if (length(missing_cols) > 0) {
    cli::cli_abort(c(
      "Missing required columns in data:",
      "x" = "Missing: {paste(missing_cols, collapse = ', ')}"
    ))
  }
  
  # Data Processing ----
  cli::cli_process_start("Processing column names and datetime...")
  
  # Create new column names based on buffer
  before_col_name <- sprintf("before_prompt_exposures_%s_100ft", buffer)
  after_col_name <- sprintf("after_prompt_exposures_%s_100ft", buffer)
  
  result <- ema_geo_data %>%
    dplyr::rename(
      !!before_col_name := before_prompt_exposures,
      !!after_col_name := after_prompt_exposures
    ) %>%
    dplyr::mutate(
      `Notification Time` = lubridate::with_tz(
        as.POSIXct(`Notification Time`, format = "%Y-%m-%d %H:%M:%S"), 
        tzone = "America/New_York"
      )
    )
  cli::cli_process_done()
  
  cli::cli_alert_success(
    "Successfully loaded EMA with geo exposures for {Type}: \n{.val {length(unique(result$pid))}} pIDs | {.val {nrow(result)}} rows × {.val {ncol(result)}} columns"
  )
  
  return(result)
}

## Add condition assignments to a dataframe with pid
add_conditions = function(df,
                          data_path = "/Volumes/cnlab/GeoRemote/Data/") {
  # Validate that df contains a pid column
  stopifnot("Dataframe must contain a 'pid' column" = "pid" %in% names(df))
  
  # Load condition assignments
  conditions = read_csv(file.path(data_path, "Redcap/utility/conditions.csv"))
  
  # Join conditions to dataframe
  result = df %>%
    left_join(conditions, by="pid")
  return(result)
}

# DATA MANIPULATION FUNCTIONS ----
## Merge Geo Exposures to EMA by Time ----
## (UNFACTORED)
create_ema_var_to_geodata = function(ema=NULL, 
                                     geodata=NULL, 
                                     buffer=NULL, 
                                     type=NULL, 
                                     t=NULL, unit="hours", 
                                     data_path = "/Volumes/cnlab/GeoRemote/Data/") {
  rename_exposures <- function(data, buffer) {
    # Construct the new column names using glue syntax
    new_before <- paste0("_before_prompt_exposures_", buffer)
    new_after <- paste0("_after_prompt_exposures_", buffer)
    
    # Use rename with !!sym to dynamically rename columns
    data <- data %>%
      rename(!!new_before := before_prompt_exposures,
             !!new_after := after_prompt_exposures)
    
    return(data)
  }
  check_buffer <- function(var_name) {
    
    # Check for "500ft" or "1000ft" in the variable name
    if (grepl("500ft", var_name)) {
      return("500ft")
    } else if (grepl("1000ft", var_name)) {
      return("1000ft")
    } else {
      stop("Error: buffer argument should be '500ft' or '1000ft'")
    }
  }
  check_type <- function(var_name) {
    
    # Check for "baseline" or "intervention" in the variable name
    if (grepl("baseline", tolower(var_name))) {
      return("Baseline")
    } else if (grepl("intervention", tolower(var_name))) {
      return("Intervention")
    } else {
      stop("Error: type argument should be 'Baseline' or 'Intervention'")
    }
  }
  if (is.null(buffer) && !is.null(geodata)) {
    buffer = check_buffer(substitute(geodata))
  }
  if (is.null(type) && !is.null(geodata)) {
    type = check_type(substitute(geodata))
  }
  if (is.null(geodata) && !is.null(buffer) && !is.null(type)) {
    geodata = load_geodata_within_day_exposures(type, 
                                                buffer, 
                                                data_path=data_path)
  }
  if (is.null(ema) && !is.null(type)) {
    ema = load_ema_with_covs(Type=type, 
                             ema_variables = c('pid','day', 'Session Name', 'Notification Time', 'Response_Time', 'Responded'),
                             data_path = data_path)
  }
  
  
  result_list = list()
  
  unique_pid_day <- ema %>%
    select(pid, day) %>%
    distinct() %>%
    semi_join(geodata, by = "pid")
  
  for(i in 1:nrow(unique_pid_day)) {
    pid_value <- unique_pid_day$pid[i]
    day_value <- unique_pid_day$day[i]
    
    # Filter ema and geodata by the current pid and day
    exposures_subset = geodata %>%
      filter(pid == pid_value, day == day_value)
    responses_subset = ema %>%
      filter(pid == pid_value, day == day_value)
    
    # Sort responses by time to ensure they are in order
    responses_subset <- responses_subset %>%
      arrange(`Notification Time`,Response_Time)
    
    # Initialize at the start of the day
    previous_response_time <- if_else(
      responses_subset$Responded[1] == 1,
      as.POSIXct(paste0(as.Date(responses_subset$Response_Time[1]), " 00:00:00"),format = "%Y-%m-%d %H:%M:%S", tz="America/New_York"),  
      as.POSIXct(paste0(as.Date(responses_subset$`Notification Time`[1]), " 00:00:00"),format = "%Y-%m-%d %H:%M:%S", tz="America/New_York")  
    )
    
    # Loop through the responses and count unique exposures
    if (nrow(exposures_subset) == 0) {
      next
    }
    for(j in 1:nrow(responses_subset)) {
      response_time <- if_else(
        responses_subset$Responded[j] == 1,
        responses_subset$Response_Time[j],
        responses_subset$`Notification Time`[j]
      )
      if (!is.null(t)) {
        previous_response_time = response_time - get(unit)(t)
      }
      
      # Calculate exposures before the current response
      exposures_before <- exposures_subset %>%
        filter(datetime >= previous_response_time & datetime < response_time) %>%
        filter(!is.na(exposure_id))  # Remove NAs
      
      # Get unique exposures before the response
      unique_exposures_before <- unique(exposures_before$exposure_id)
      
      # Count unique exposure_ids before the response
      before_prompt_exposures <- length(unique_exposures_before)
      
      # If it's not the last response, calculate exposures between the current and next Response_Time
      if (j < nrow(responses_subset)) {
        
        next_response_time <- if_else(
          responses_subset$Responded[j + 1] == 1,
          responses_subset$Response_Time[j + 1],
          responses_subset$`Notification Time`[j + 1]
        )
        
        if (!is.null(t)) {
          next_response_time = response_time + get(unit)(t)
        }
        
        exposures_after <- exposures_subset %>%
          filter(datetime > response_time & datetime <= next_response_time) %>%
          filter(!is.na(exposure_id))  # Remove NAs
      } else {
        # If it's the last response, calculate exposures after it until midnight
        end_of_day <- as.POSIXct(paste0(as.Date(response_time), " 23:59:59"),format = "%Y-%m-%d %H:%M:%S", tz="America/New_York")
        
        if (!is.null(t)) {
          end_of_day = response_time + get(unit)(t)
        }
        
        exposures_after <- exposures_subset %>%
          filter(datetime > response_time & datetime <= end_of_day) %>%
          filter(!is.na(exposure_id))  # Remove NAs
      }
      
      # Get unique exposures after the response
      unique_exposures_after <- unique(exposures_after$exposure_id)
      
      # Count unique exposure_ids after the response
      after_prompt_exposures <- length(unique_exposures_after)
      
      # Get the ema var values for this response
      # Store result with before and after exposures
      result_list[[length(result_list) + 1]] <- data.frame(
        pid = pid_value,
        day = day_value,
        `Session Name` = responses_subset$`Session Name`[j],
        `Notification Time` = responses_subset$`Notification Time`[j],
        before_prompt_exposures = before_prompt_exposures,
        after_prompt_exposures = after_prompt_exposures,
        check.names = FALSE)
      
      # Update the previous Response_Time to the current one
      previous_response_time <- response_time
    }
  }
  result_df = bind_rows(result_list)
  
  tryCatch(
    {
      save_ema_with_geo_exposures(result_df, 
                                  buffer, 
                                  type, 
                                  t, unit, 
                                  data_path=data_path)
    },
    error = function(e) {
      message("Error occurred: ", e$message)
    },
    finally = {
      return(merge_ema_with_geo_exposures(ema, 
                                          result_df,
                                          buffer, 
                                          type,
                                          data_path=data_path))
    }
  )
}

## Merge Geo Exposures to EMA within 2 hour window ----
## (UNFACTORED)
create_ema_var_to_geodata_2_hours = function(ema=NULL, 
                                             geodata=NULL, 
                                             buffer=NULL, 
                                             type=NULL, 
                                             t=NULL, unit="hours",
                                             data_path = "/Volumes/cnlab/GeoRemote/Data/") {
  rename_exposures <- function(data, buffer) {
    # Construct the new column names using glue syntax
    new_before <- paste0("_before_prompt_exposures_", buffer)
    new_after <- paste0("_after_prompt_exposures_", buffer)
    
    # Use rename with !!sym to dynamically rename columns
    data <- data %>%
      rename(!!new_before := before_prompt_exposures,
             !!new_after := after_prompt_exposures)
    
    return(data)
  }
  check_buffer <- function(var_name) {
    
    # Check for "500ft" or "1000ft" in the variable name
    if (grepl("500ft", var_name)) {
      return("500ft")
    } else if (grepl("1000ft", var_name)) {
      return("1000ft")
    } else {
      stop("Error: buffer argument should be '500ft' or '1000ft'")
    }
  }
  check_type <- function(var_name) {
    
    # Check for "baseline" or "intervention" in the variable name
    if (grepl("baseline", tolower(var_name))) {
      return("baseline")
    } else if (grepl("intervention", tolower(var_name))) {
      return("intervention")
    } else {
      stop("Error: type argument should be 'baseline' or 'intervention'")
    }
  }
  if (is.null(buffer) && !is.null(geodata)) {
    buffer = check_buffer(substitute(geodata))
  }
  if (is.null(type) && !is.null(geodata)) {
    type = check_type(substitute(geodata))
  }
  if (is.null(geodata) && !is.null(buffer) && !is.null(type)) {
    geodata = load_geodata_within_day_exposures(type, 
                                                buffer, 
                                                data_path = data_path)
  }
  if (is.null(ema) && !is.null(type)) {
    ema = load_ema_with_covs(Type=type, 
                             ema_variables = c('pid','Notification Time', 'Response_Time', 'Responded'),
                             data_path = data_path)
  }
  
  
  result_list = list()
  
  unique_pid_day <- ema %>%
    select(pid, day) %>%
    distinct() %>%
    semi_join(geodata, by = "pid")
  
  for(i in 1:nrow(unique_pid_day)) {
    pid_value <- unique_pid_day$pid[i]
    day_value <- unique_pid_day$day[i]
    
    # Filter ema and geodata by the current pid and day
    exposures_subset = geodata %>%
      filter(pid == pid_value, day == day_value)
    responses_subset = ema %>%
      filter(pid == pid_value, day == day_value)
    
    # Sort responses by time to ensure they are in order
    responses_subset <- responses_subset %>%
      arrange(`Notification Time`,Response_Time)
    
    # Initialize at the start of the day
    previous_response_time <- if_else(
      responses_subset$Responded[1] == 1,
      as.POSIXct(paste0(as.Date(responses_subset$Response_Time[1]), " 00:00:00"),format = "%Y-%m-%d %H:%M:%S", tz="America/New_York"),  
      as.POSIXct(paste0(as.Date(responses_subset$`Notification Time`[1]), " 00:00:00"),format = "%Y-%m-%d %H:%M:%S", tz="America/New_York")  
    )
    
    # Loop through the responses and count unique exposures
    if (nrow(exposures_subset) == 0) {
      next
    }
    for(j in 1:nrow(responses_subset)) {
      response_time <- if_else(
        responses_subset$Responded[j] == 1,
        responses_subset$Response_Time[j],
        responses_subset$`Notification Time`[j]
      )
      if (!is.null(t)) {
        previous_response_time = response_time - get(unit)(t)
      }
      
      # adjust: 2-1 hours before 
      start_time <- response_time - hours(2)
      end_time <- response_time - hours(1)
      
      exposures_before <- exposures_subset %>%
        filter(datetime >= start_time & datetime < end_time) %>%
        filter(!is.na(exposure_id)) # Remove NAs
      
      # Get unique exposures before the response
      unique_exposures_before <- unique(exposures_before$exposure_id)
      
      # Count unique exposure_ids before the response
      before_prompt_exposures <- length(unique_exposures_before)
      
      # If it's not the last response, calculate exposures between the current and next Response_Time
      if (j < nrow(responses_subset)) {
        
        next_response_time <- if_else(
          responses_subset$Responded[j + 1] == 1,
          responses_subset$Response_Time[j + 1],
          responses_subset$`Notification Time`[j + 1]
        )
        
        if (!is.null(t)) {
          next_response_time = response_time + get(unit)(t)
        }
        
        exposures_after <- exposures_subset %>%
          filter(datetime > response_time & datetime <= next_response_time) %>%
          filter(!is.na(exposure_id))  # Remove NAs
      } else {
        # If it's the last response, calculate exposures after it until midnight
        end_of_day <- as.POSIXct(paste0(as.Date(response_time), " 23:59:59"),format = "%Y-%m-%d %H:%M:%S", tz="America/New_York")
        
        if (!is.null(t)) {
          end_of_day = response_time + get(unit)(t)
        }
        
        exposures_after <- exposures_subset %>%
          filter(datetime > response_time & datetime <= end_of_day) %>%
          filter(!is.na(exposure_id))  # Remove NAs
      }
      
      # Get unique exposures after the response
      unique_exposures_after <- unique(exposures_after$exposure_id)
      
      # Count unique exposure_ids after the response
      after_prompt_exposures <- length(unique_exposures_after)
      
      # Get the ema var values for this response
      # Store result with before and after exposures
      result_list[[length(result_list) + 1]] <- data.frame(
        pid = pid_value,
        day = day_value,
        `Session Name` = responses_subset$`Session Name`[j],
        `Notification Time` = responses_subset$`Notification Time`[j],
        before_prompt_exposures = before_prompt_exposures,
        after_prompt_exposures = after_prompt_exposures,
        check.names = FALSE)
      
      # Update the previous Response_Time to the current one
      previous_response_time <- response_time
    }
  }
  result_df = bind_rows(result_list)
  
  save_ema_with_geo_exposures(result_df, 
                              buffer, 
                              type, 
                              "2_to_1", unit, 
                              data_path = data_path)
  return(merge_ema_with_geo_exposures(ema, 
                                      result_df,
                                      buffer, 
                                      type,
                                      data_path = data_path))
}

## Merge EMA data with geo exposures ----
merge_ema_with_geo_exposures <- function(ema = NULL, 
                                         geodata = NULL, 
                                         buffer = NULL, 
                                         type = NULL, 
                                         t = NULL, 
                                         unit = NULL,
                                         data_path = GEO_EXPOSURE_CONFIG$data_path,
                                         config = GEO_EXPOSURE_CONFIG) {
  
  cli::cli_rule("Merging EMA data with geo exposures")
  cli::cli_text("EMA provided: {.val {!is.null(ema)}} | Geodata provided: {.val {!is.null(geodata)}}")
  cli::cli_text("Type: {.val {ifelse(is.null(type), 'None', type)}} | Buffer: {.val {ifelse(is.null(buffer), 'None', buffer)}}")
  
  # Validation ----
  # validate data_path
  if (!dir.exists(data_path)) {
    cli::cli_abort("Data path does not exist: {data_path}")
  }
  
  # Check that we have a way to get both datasets
  if (is.null(ema) && is.null(type)) {
    cli::cli_abort("Must provide either 'ema' dataframe or 'type' to load EMA data")
  }
  
  if (is.null(geodata) && (is.null(buffer) || is.null(type))) {
    cli::cli_abort("Must provide either 'geodata' dataframe or both 'buffer' and 'type' to load geodata")
  }
  
  # validate type if provided
  if (!is.null(type)) {
    Type <- stringr::str_to_title(tolower(type))
    if (!tolower(Type) %in% tolower(config$default_types)) {
      cli::cli_abort(c(
        "Type must be one of: {paste(config$default_types, collapse = ', ')}",
        "x" = "Provided: '{Type}'"
      ))
    }
  } else {
    Type <- type  # Keep as NULL
  }
  
  # validate and standardize buffer if provided
  if (!is.null(buffer)) {
    if (is.numeric(buffer)) {
      buffer <- paste0(buffer, "ft")
    } else if (is.character(buffer) && length(buffer) == 1) {
      buffer_num <- stringr::str_extract(buffer, "^[0-9]+")
      if (is.na(buffer_num)) {
        cli::cli_abort("Buffer must contain a numeric value (e.g., '500ft', '500', or 500)")
      }
      buffer <- paste0(buffer_num, "ft")
    } else {
      cli::cli_abort("Buffer must be a single numeric or character value")
    }
    
    # validate buffer is in defaults (warning only)
    if (!tolower(buffer) %in% tolower(config$default_buffers)) {
      cli::cli_warn(c(
        "Buffer not in default list: {paste(config$default_buffers, collapse = ', ')}",
        "x" = "Provided: '{buffer}' - may fail if file does not exist"
      ))
    }
  }
  
  # validate time parameters if provided
  if (!is.null(t) && is.null(unit)) {
    cli::cli_abort("If 't' is provided, 'unit' must also be provided")
  }
  if (is.null(t) && !is.null(unit)) {
    cli::cli_abort("If 'unit' is provided, 't' must also be provided")
  }
  
  # Data Loading ----
  # Load geodata if not provided
  if (is.null(geodata)) {
    cli::cli_alert_info("Loading geo exposure data...")
    geodata <- tryCatch({
      load_ema_with_geo_exposures(
        buffer = buffer, 
        type = Type, 
        t = t, 
        unit = unit, 
        data_path = data_path,
        config = config
      )
    }, error = function(e) {
      cli::cli_abort(c(
        "Failed to load geo exposure data",
        "x" = "Error: {e$message}"
      ))
    })
  } else {
    cli::cli_text("Using provided geodata: {.val {nrow(geodata)}} rows × {.val {ncol(geodata)}} columns")
  }
  
  # Load EMA data if not provided
  if (is.null(ema)) {
    cli::cli_alert_info("Loading EMA data...")
    ema <- tryCatch({
      load_ema_with_covs(
        Type = Type, 
        ema_variables = c('pid', 'day', 'Notification Time', 'Response_Time', 'Responded', 'Session Name'),
        data_path = data_path,
        config = config
      )
    }, error = function(e) {
      cli::cli_abort(c(
        "Failed to load EMA data",
        "x" = "Error: {e$message}"
      ))
    })
  } else {
    cli::cli_text("Using provided EMA data: {.val {nrow(ema)}} rows × {.val {ncol(ema)}} columns")
  }
  
  # Validating Merge Data ----
  # Check that both datasets exist and have data
  if (is.null(ema) || nrow(ema) == 0) {
    cli::cli_abort("EMA data is missing or empty")
  }
  
  if (is.null(geodata) || nrow(geodata) == 0) {
    cli::cli_abort("Geodata is missing or empty")
  }
  
  # Check required join columns
  join_cols <- c("pid", "day", "Session Name", "Notification Time")
  
  missing_ema_cols <- setdiff(join_cols, colnames(ema))
  if (length(missing_ema_cols) > 0) {
    cli::cli_abort(c(
      "EMA data missing required join columns:",
      "x" = "Missing: {paste(missing_ema_cols, collapse = ', ')}"
    ))
  }
  
  missing_geo_cols <- setdiff(join_cols, colnames(geodata))
  if (length(missing_geo_cols) > 0) {
    cli::cli_abort(c(
      "Geodata missing required join columns:",
      "x" = "Missing: {paste(missing_geo_cols, collapse = ', ')}"
    ))
  }
  
  # Data Merging ----
  cli::cli_alert_info("Merging EMA and geodata...")
  
  before_rows <- nrow(ema)
  
  result <- tryCatch({
    ema %>% 
      dplyr::left_join(geodata, by = join_cols)
  }, error = function(e) {
    cli::cli_abort(c(
      "Failed to merge datasets",
      "x" = "Error: {e$message}"
    ))
  })
  
  after_rows <- nrow(result)
  
  # Validate merge
  if (before_rows != after_rows) {
    cli::cli_warn("Row count changed during merge: {before_rows} -> {after_rows}")
  }
  
  # Count successful matches
  new_cols <- setdiff(colnames(result), colnames(ema))
  if (length(new_cols) > 0) {
    n_matched <- sum(rowSums(!is.na(result[new_cols])) > 0)
  } else {
    n_matched <- 0
  }
  
  # SUCCESS MESSAGE
  cli::cli_alert_success(
    "Successfully merged EMA with geo exposures: \n{.val {n_matched}} rows received geo data | {.val {nrow(result)}} total rows × {.val {ncol(result)}} columns"
  )
  
  if (length(new_cols) > 0) {
    cli::cli_text("Added columns: {.val {paste(head(new_cols, 5), collapse = ', ')}{ifelse(length(new_cols) > 5, '...', '')}}")
  }
  
  return(result)
}
## Add survey measures to dataframe ----
add_survey_measure <- function(df, 
                               survey, 
                               session = 1,
                               scale_type = "main",
                               data_path = GEO_EXPOSURE_CONFIG$data_path) {
  
  cli::cli_rule("Adding survey measures to dataframe")
  cli::cli_text("Surveys: {.val {paste(head(survey, 3), collapse = ', ')}} | Sessions: {.val {ifelse(identical(session, 'all'), 'all', paste(session, collapse = ', '))}}")
  cli::cli_text("Scale Type: {.val {scale_type}}")
  
  # get survey files
  survey_dir <- file.path(data_path, "Qualtrics/scored_survey_measures")
  available_surveys <- list.files(survey_dir, pattern = "\\.csv$", full.names = FALSE)
  pattern <- paste0("^", survey, "\\.csv$")
  matched_files <- available_surveys[grep(pattern, available_surveys, ignore.case = TRUE)]
  
  if (scale_type == "main") {scale_type = c("sum", "mean")}
  
  # Validation ----
  # data_path
  if (!dir.exists(data_path)) {
    cli::cli_abort("Data path does not exist: {data_path}")
  }
  
  # df$pid
  if (!"pid" %in% colnames(df)) {
    cli::cli_abort("Input dataframe must contain a 'pid' column")
  }
  
  # survey directory
  if (!dir.exists(survey_dir)) {
    cli::cli_abort("Survey measures directory not found: {survey_dir}")
  }
  
  # validate available surveys exist
  if (length(available_surveys) == 0) {
    cli::cli_abort("No survey files found in: {survey_dir}")
  }
  
  if (length(matched_files) == 0) {
    survey_names <- stringr::str_remove(available_surveys, "\\.csv$")
    cli::cli_abort(c(
      "Survey file not found: {survey}",
      "i" = "Available surveys: {paste(survey_names, collapse = ', ')}"
    ))
  }
  
  # Only return one file
  if (length(matched_files) > 1) {
    cli::cli_abort(c(
      "Multiple survey files found for '{survey}':",
      "x" = "Matches: {paste(matched_files, collapse = ', ')}",
      "i" = "Ensure survey names are unique"
    ))
  }
  
  # validate session parameter
  if (!identical(session, "all")) {
    if (!is.numeric(session) && !is.character(session)) {
      cli::cli_abort("Session must be numeric, character, or 'all'")
    }
    # Convert to numeric if character (except "all")
    if (is.character(session)) {
      session_numeric <- suppressWarnings(as.numeric(session))
      if (any(is.na(session_numeric))) {
        cli::cli_abort("All session values must be numeric or 'all'")
      }
      session <- session_numeric
    }
  }
  
  # Load Survey Data ----
  survey_file <- file.path(survey_dir, matched_files)
  
  survey_data <- tryCatch({
    readr::read_csv(survey_file, show_col_types = FALSE)
  }, error = function(e) {
    cli::cli_abort(c(
      "Failed to read survey file: {survey_file}",
      "x" = "Error: {e$message}"
    ))
  })
  
  # validate required columns
  required_cols <- c("sm_session", "scored_scale", "pid", "score")
  missing_cols <- setdiff(required_cols, colnames(survey_data))
  if (length(missing_cols) > 0) {
    cli::cli_abort(c(
      "Survey file missing required columns:",
      "x" = "Missing: {paste(missing_cols, collapse = ', ')}"
    ))
  }
  
  # Validate scale types
  matching_scales <- intersect(scale_type, unique(survey_data$scored_scale))
  
  if (length(matching_scales) == 0) {
    cli::cli_abort(c(
      "None of the specified scale types found in survey data",
      "x" = "Requested: {paste(scale_type, collapse = ', ')}",
      "i" = "Available scales: {paste(unique(survey_data$scored_scale), collapse = ', ')}"
    ))
  }
  
  # Data Processing ----
  result_df <- df
  
  # Determine which sessions to use
  if (identical(session, "all")) {
    sessions_to_use <- sort(unique(survey_data$sm_session))
  } else {
    sessions_to_use <- session
  }
  
  cli::cli_text("Processing {length(matching_scales)} scale(s) × {length(sessions_to_use)} session(s)")
  
  # Track what gets added
  columns_added <- c()
  
  # Loop through each matching scale type
  for (scale in matching_scales) {
    
    # Loop through each session
    for (sess in sessions_to_use) {
      
      # Create column name
      if (length(sessions_to_use) > 1) {
        if (length(scale) == 1) {
          column_name <- paste0(survey, "_score", "_sess", sess)
        } else {column_name <- paste0(survey, "_", scale, "_sess", sess)}
      } else {
        if (length(scale) == 1) {
          column_name <- paste0(survey, "_score")
        } else {column_name <- paste0(survey, "_", scale)}
      }
      
      # Filter data for this specific scale and session
      scale_data <- survey_data %>%
        dplyr::filter(
          sm_session == sess,
          scored_scale == scale
        ) %>%
        dplyr::select(pid, score) %>%
        dplyr::rename(!!column_name := score)
      
      # Check if we have data
      if (nrow(scale_data) == 0) {
        cli::cli_warn("No data found for {scale} in session {sess}")
        next
      }
      
      # Check for duplicate pids (would cause join issues)
      if (any(duplicated(scale_data$pid))) {
        cli::cli_warn("Duplicate PIDs found for {scale} session {sess} - taking first occurrence")
        scale_data <- scale_data %>%
          dplyr::distinct(pid, .keep_all = TRUE)
      }
      
      # Join to result dataframe
      before_rows <- nrow(result_df)
      
      result_df <- result_df %>%
        dplyr::left_join(scale_data, by = "pid")
      
      after_rows <- nrow(result_df)
      
      # Validate join
      if (before_rows != after_rows) {
        cli::cli_warn("Row count changed during join for {column_name}: {before_rows} -> {after_rows}")
      }
      
      # Count matches
      n_matched <- sum(!is.na(result_df[[column_name]]))
      columns_added <- c(columns_added, column_name)
      
      cli::cli_text("Added column: {.val {column_name}} ({n_matched} participants)")
    }
  }
  
  # Success
  cli::cli_alert_success(
    "Successfully added survey measures for {survey}: \n{.val {length(columns_added)}} columns added"
  )
  
  if (length(columns_added) > 0) {
    cli::cli_text("New columns: {.val {paste(columns_added, collapse = ', ')}}")
  }
  
  return(result_df)
}

## Add descriptive measures ----
add_descriptives <- function(df, 
                             vars = "all",
                             data_path = GEO_EXPOSURE_CONFIG$data_path) {
  
  cli::cli_rule("Adding descriptive measures to dataframe")
  cli::cli_text("Variables: {.val {ifelse(vars == 'all', 'all', paste(head(vars, 5), collapse = ', '))}}")
  
  # Validation ----
  # validate data_path
  if (!dir.exists(data_path)) {
    cli::cli_abort("Data path does not exist: {data_path}")
  }
  
  # validate input dataframe has pid column
  if (!"pid" %in% colnames(df)) {
    cli::cli_abort("Input dataframe must contain a 'pid' column")
  }
  
  # validate descriptives directory exists
  descriptives_dir <- file.path(data_path, "Geodata/clean/descriptives")
  if (!dir.exists(descriptives_dir)) {
    cli::cli_abort("Descriptives directory not found: {descriptives_dir}")
  }
  
  # validate vars parameter
  if (!is.character(vars) && vars != "all") {
    cli::cli_abort("vars must be 'all' or a character vector of variable names")
  }
  
  files <- list.files(
    path = descriptives_dir, 
    pattern = "\\.csv$",
    full.names = TRUE
  )
  
  if (length(files) == 0) {
    cli::cli_abort("No CSV files found in descriptives directory: {descriptives_dir}")
  }
  
  # Data Loading ----
  descriptives_list <- list()
  
  cli::cli_alert_info("Loading descriptive files...")
  cli::cli_progress_bar(total = length(files))
  for (i in seq_along(files)) {
    file <- files[i]
    
    # Extract PID from filename (everything before first underscore)
    pid <- stringr::str_extract(basename(file), "^[^_]+")
    
    if (is.na(pid) || nchar(pid) == 0) {
      cli::cli_warn("Could not extract PID from filename: {basename(file)} - skipping")
      next
    }
    
    # Load file
    descriptives <- tryCatch({
      readr::read_csv(file, 
                      show_col_types = FALSE,
                      col_types = readr::cols(.default = readr::col_character()))
    }, error = function(e) {
      cli::cli_warn("Failed to read file {basename(file)}: {e$message} - skipping")
      return(NULL)
    })
    
    if (is.null(descriptives) || nrow(descriptives) == 0) {
      cli::cli_warn("File {basename(file)} is empty - skipping")
      next
    }
    
    # Add PID column
    descriptives$pid <- pid
    
    # Store in list
    descriptives_list[[length(descriptives_list) + 1]] <- descriptives
    cli::cli_progress_update(status = basename(file))
  }
  cli::cli_progress_done()
  
  # Check if any files were successfully loaded
  if (length(descriptives_list) == 0) {
    cli::cli_abort("No descriptive files could be loaded successfully")
  }
  
  cli::cli_text("Successfully loaded {.val {length(descriptives_list)}} files")
  
  phone_info <- tryCatch({
    dplyr::bind_rows(descriptives_list)
  }, error = function(e) {
    cli::cli_abort(c(
      "Failed to combine descriptive data",
      "x" = "Error: {e$message}"
    ))
  })
  
  phone_info <- phone_info %>%
    dplyr::mutate(dplyr::across(
      dplyr::where(~ all(stringr::str_detect(.x[!is.na(.x)], "^[0-9.-]+$"))), 
      ~ as.numeric(.x)
    ))
  
  # Remove any duplicate rows (same pid + same data)
  initial_rows <- nrow(phone_info)
  phone_info <- phone_info %>%
    dplyr::distinct()
  
  if (nrow(phone_info) < initial_rows) {
    cli::cli_text("Removed {.val {initial_rows - nrow(phone_info)}} duplicate rows")
  }
  
  # VALIDATE VARIABLES 
  available_vars <- setdiff(colnames(phone_info), "pid")
  
  if (vars != "all") {
    missing_vars <- setdiff(vars, available_vars)
    existing_vars <- intersect(vars, available_vars)
    
    if (length(missing_vars) > 0) {
      cli::cli_warn(c(
        "Some requested variables not found in descriptive data:",
        "x" = "Missing: {paste(missing_vars, collapse = ', ')}",
        "i" = "Available: {paste(head(available_vars, 10), collapse = ', ')}{ifelse(length(available_vars) > 10, '...', '')}"
      ))
    }
    
    if (length(existing_vars) == 0) {
      cli::cli_abort(c(
        "None of the requested variables exist in descriptive data",
        "x" = "Requested: {paste(vars, collapse = ', ')}",
        "i" = "Available: {paste(head(available_vars, 10), collapse = ', ')}{ifelse(length(available_vars) > 10, '...', '')}"
      ))
    }
    
    # Select only existing variables
    selected_columns <- c("pid", existing_vars)
    phone_info_subset <- phone_info %>%
      dplyr::select(dplyr::all_of(selected_columns))
    
    cli::cli_text("Selected {.val {length(existing_vars)}} variables: {paste(existing_vars, collapse = ', ')}")
  } else {
    phone_info_subset <- phone_info
    cli::cli_text("Using all {.val {length(available_vars)}} available variables")
  }
  
  # Data Joining ----
  cli::cli_alert_info("Joining descriptive data to input dataframe...")
  
  # Check PID matching
  matching_pids <- intersect(unique(df$pid), unique(phone_info_subset$pid))
  cli::cli_text("PID matching: {.val {length(matching_pids)}} out of {.val {length(unique(phone_info_subset$pid))}} descriptive PIDs found in input dataframe")
  
  if (length(matching_pids) == 0) {
    cli::cli_warn("No matching PIDs found - join will not add any data")
  }
  
  # Track column changes
  before_cols <- ncol(df)
  
  result <- tryCatch({
    dplyr::left_join(df, phone_info_subset, by = "pid")
  }, error = function(e) {
    cli::cli_abort(c(
      "Failed to join descriptive data",
      "x" = "Error: {e$message}"
    ))
  })
  
  after_cols <- ncol(result)
  new_cols <- setdiff(colnames(result), colnames(df))
  
  # SUCCESS MESSAGE
  cli::cli_alert_success(
    "Successfully added descriptive measures: \n{.val {length(matching_pids)}} participants matched | Added {.val {after_cols - before_cols}} columns"
  )
  
  if (length(new_cols) > 0) {
    cli::cli_text("New columns: {.val {paste(head(new_cols, 5), collapse = ', ')}{ifelse(length(new_cols) > 5, '...', '')}}")
  }
  
  return(result)
}

## Split Means Within + Between subs ----
split_within_between <- function(data, vars) {
  # Split variables into within and between components
  cli::cli_rule("Splitting variables into within and between components")
  cli::cli_text("Variables: {.val {paste(vars, collapse = ', ')}}")
  
  # Validation ----
  # Check if all specified variables exist in the dataframe
  missing_vars <- setdiff(vars, colnames(data))
  
  if (length(missing_vars) > 0) {
    cli::cli_abort("Missing variables from dataframe: {paste(missing_vars, collapse = ', ')}")
  }
  
  # Data Processing ----
  result_data <- data
  
  for (var in vars) {
    cli::cli_alert_info("Processing variable: {.field {var}}")
    
    # Create the Split for the specified variable (person-level means)
    result_data[[paste0("Split_", var)]] <- with(result_data, ave(result_data[[var]], pid, FUN = function(x) mean(x, na.rm = TRUE)))
    
    # Set the grand mean
    grand_mean <- mean(result_data[[paste0("Split_", var)]], na.rm = TRUE)
    result_data[[paste0("GMean_", var)]] <- grand_mean
    
    # Subtract grand mean from the raw variable
    result_data[[paste0(var, "_c")]] <- result_data[[var]] - grand_mean
    
    # Create between-subjects mean
    result_data[[paste0(var, "_bw")]] <- with(result_data, ave(result_data[[paste0(var, "_c")]], pid, FUN = function(x) mean(x, na.rm = TRUE)))
    
    # Create within-subjects mean
    result_data[[paste0(var, "_wn")]] <- result_data[[paste0(var, "_c")]] - result_data[[paste0(var, "_bw")]]
    
    cli::cli_text("Created: {.val {paste0(var, c('_c', '_bw', '_wn'), collapse = ', ')}}")
  }
  
  # success message
  new_cols <- setdiff(colnames(result_data), colnames(data))
  
  cli::cli_alert_success(
    "Successfully split {length(vars)} variable(s): \nAdded {.val {length(new_cols)}} columns"
  )
  
  cli::cli_text("New columns: {.val {paste(head(new_cols, 10), collapse = ', ')}{ifelse(length(new_cols) > 10, '...', '')}}")
  
  return(result_data)
}

# Winsorize variables by group ----
winsorize_variables <- function(df, 
                                variables, 
                                group_var = "pid", 
                                lower = 0.05, 
                                upper = 0.95) {
  
  cli::cli_rule("Winsorizing variables by group")
  cli::cli_text("Variables: {.val {paste(head(variables, 5), collapse = ', ')}{ifelse(length(variables) > 5, '...', '')}} | Group: {.field {group_var}}")
  cli::cli_text("Limits: {.val {lower}} - {.val {upper}}")
  
  # Validation ----
  # validate dataframe
  if (!is.data.frame(df)) {
    cli::cli_abort("Input must be a dataframe")
  }
  
  if (nrow(df) == 0) {
    cli::cli_abort("Cannot winsorize empty dataframe")
  }
  
  # validate variables parameter
  if (!is.character(variables) || length(variables) == 0) {
    cli::cli_abort("Variables must be a non-empty character vector")
  }
  
  # validate variables exist in dataframe
  missing_vars <- setdiff(variables, colnames(df))
  if (length(missing_vars) > 0) {
    cli::cli_abort(c(
      "Variables not found in dataframe:",
      "x" = "Missing: {paste(missing_vars, collapse = ', ')}",
      "i" = "Available: {paste(head(colnames(df), 10), collapse = ', ')}{ifelse(ncol(df) > 10, '...', '')}"
    ))
  }
  
  # validate group_var
  if (!is.character(group_var) || length(group_var) != 1) {
    cli::cli_abort("Group variable must be a single character string")
  }
  
  if (!group_var %in% colnames(df)) {
    cli::cli_abort(c(
      "Group variable not found in dataframe: {group_var}",
      "i" = "Available columns: {paste(head(colnames(df), 10), collapse = ', ')}{ifelse(ncol(df) > 10, '...', '')}"
    ))
  }
  
  # validate probability limits
  if (!is.numeric(lower) || !is.numeric(upper) || length(lower) != 1 || length(upper) != 1) {
    cli::cli_abort("Lower and upper must be single numeric values")
  }
  
  if (lower < 0 || lower > 1 || upper < 0 || upper > 1) {
    cli::cli_abort("Lower and upper must be between 0 and 1")
  }
  
  if (lower >= upper) {
    cli::cli_abort("Lower limit must be less than upper limit")
  }
  
  # validate variables are numeric
  non_numeric_vars <- variables[!sapply(df[variables], is.numeric)]
  if (length(non_numeric_vars) > 0) {
    cli::cli_abort(c(
      "All variables must be numeric for winsorizing:",
      "x" = "Non-numeric: {paste(non_numeric_vars, collapse = ', ')}"
    ))
  }
  
  # Data Procesing ----
  cli::cli_alert_info("Winsorizing {length(variables)} variable(s) by {group_var}...")
  
  result <- tryCatch({
    df %>%
      dplyr::group_by(dplyr::across(dplyr::all_of(group_var))) %>%
      dplyr::mutate(dplyr::across(
        dplyr::all_of(variables),
        ~ DescTools::Winsorize(., val = quantile(., probs = c(lower, upper), na.rm = TRUE)),
        .names = "{.col}_wins"
      )) %>%
      dplyr::ungroup()
  }, error = function(e) {
    cli::cli_abort(c(
      "Failed to winsorize variables",
      "x" = "Error: {e$message}"
    ))
  })
  
  # Result Validation ----
  if (nrow(result) != nrow(df)) {
    cli::cli_warn("Row count changed during winsorizing: {nrow(df)} -> {nrow(result)}")
  }
  
  # Check what columns were added
  new_cols <- setdiff(colnames(result), colnames(df))
  expected_cols <- paste0(variables, "_wins")
  
  if (length(new_cols) != length(expected_cols)) {
    cli::cli_warn("Unexpected number of columns created: expected {length(expected_cols)}, got {length(new_cols)}")
  }
  
  # Get summary statistics
  n_groups <- result %>% 
    dplyr::group_by(dplyr::across(dplyr::all_of(group_var))) %>% 
    dplyr::summarise(.groups = "drop") %>% 
    nrow()
  
  # Success message
  cli::cli_alert_success(
    "Successfully winsorized variables: \n{.val {length(variables)}} variables × {.val {n_groups}} groups | Added {.val {length(new_cols)}} columns"
  )
  
  cli::cli_text("New columns: {.val {paste(new_cols, collapse = ', ')}}")
  
  # Show example of winsorizing effect for first variable
  if (length(variables) > 0) {
    var_name <- variables[1]
    wins_name <- paste0(var_name, "_wins")
    
    original_range <- range(df[[var_name]], na.rm = TRUE)
    wins_range <- range(result[[wins_name]], na.rm = TRUE)
    
    cli::cli_text("Example ({var_name}): Original range [{round(original_range[1], 3)}, {round(original_range[2], 3)}] -> Winsorized [{round(wins_range[1], 3)}, {round(wins_range[2], 3)}]")
  }
  
  return(result)
}

# DATA MODELING FUNCTIONS ----
## Create Model Function Wrapper ----
create_model_function <- function(base_formula, model_type = "lmer") {
  fit_lme_model <- function(formula_obj, data, user_call, ...) {
    
    # Convert lmer-style random effects to lme format
    # deparse() can return multiple lines, so collapse them
    formula_str <- paste(deparse(formula_obj), collapse = " ")
    
    # Extract random effects pattern like (1|pid) or (1 | pid)
    random_pattern <- "\\([^|]+\\|\\s*([^)]+)\\)"
    
    if (grepl(random_pattern, formula_str)) {
      # Extract grouping variable (handles spaces around |)
      grouping_var <- gsub(".*\\([^|]+\\|\\s*([^)]+)\\s*\\).*", "\\1", formula_str)
      grouping_var <- trimws(grouping_var)  # Remove any remaining whitespace
      
      # Remove random effects from fixed effects formula
      # This handles the multi-line case better
      fixed_formula_str <- gsub("\\s*\\+\\s*\\([^)]+\\)", "", formula_str)
      fixed_formula_str <- gsub("\\s*\\([^)]+\\)\\s*\\+?\\s*", "", fixed_formula_str)
      fixed_formula_str <- trimws(fixed_formula_str)  # Clean up whitespace
      
      # Handle case where random effect was at the end
      fixed_formula_str <- gsub("\\+\\s*$", "", fixed_formula_str)
      
      fixed_formula <- as.formula(fixed_formula_str)
      
      # Create random formula
      random_formula <- as.formula(paste("~ 1 |", grouping_var))
      
      # Set default na.action for lme if not specified
      dots <- list(...)
      if (!"na.action" %in% names(dots)) {
        dots$na.action <- na.omit
      }
      
      # Fit lme model
      model <- do.call(lme, c(list(fixed = fixed_formula, 
                                   random = random_formula, 
                                   data = data), dots))
      
      # Fix the call issue for lme models
      proper_call <- call("lme", 
                          fixed = fixed_formula,
                          random = random_formula,
                          data = substitute(data))
      
      # Add any additional arguments from ...
      if (length(dots) > 0) {
        for (i in seq_along(dots)) {
          proper_call[[names(dots)[i]]] <- dots[[i]]
        }
      }
      
      model$call <- proper_call
      
    } else {
      # No random effects, use regular lm
      warning("No random effects detected, fitting with lm instead")
      model <- lm(formula_obj, data = data)
      
      # Fix call for lm models too
      proper_call <- call("lm", 
                          formula = formula_obj,
                          data = substitute(data))
      model$call <- proper_call
    }
    
    return(model)
  }
  # Return the actual model-fitting function
  function(data, dv, covs = NULL, ...) {
    
    # Capture the user's call to this wrapper function
    user_call <- match.call()
    
    # Build the formula string
    if (is.null(covs) || covs == "" || length(covs) == 0) {
      formula_str <- paste(dv, "~", base_formula)
    } else {
      # Handle multiple covariates
      if (length(covs) > 1) {
        covs_str <- paste(covs, collapse = " + ")
      } else {
        covs_str <- covs
      }
      formula_str <- paste(dv, "~", covs_str, "+", base_formula)
    }
    
    # Convert to formula object
    formula_obj <- as.formula(formula_str)
    
    # Print formula for verification (optional - remove if not desired)
    cat("Fitting model with formula:", formula_str, "\n")
    
    # Fit the appropriate model
    if (model_type == "lmer") {
      model <- lmer(formula_obj, data = data, ...)
      
      # Fix the call issue: create a proper call that reflects what the user intended
      proper_call <- call("lmer", 
                          formula = formula_obj, 
                          data = substitute(data))
      
      # Add any additional arguments from ...
      dots <- list(...)
      if (length(dots) > 0) {
        for (i in seq_along(dots)) {
          proper_call[[names(dots)[i]]] <- dots[[i]]
        }
      }
      
      model@call <- proper_call
      
    } else if (model_type == "lme") {
      # For lme, we need to extract random effects from formula
      # and convert to lme syntax
      model <- fit_lme_model(formula_obj, data, user_call, ...)
    } else {
      stop("model_type must be either 'lmer' or 'lme'")
    }
    
    return(model)
  }
}

## Get LME stats ----
## (UNFACTORED)
get_lme_stats <- function(model) {
  var_intercept <- as.numeric(VarCorr(model)[1, "Variance"])
  var_residual <- summary(model)$sigma^2
  icc <- var_intercept / (var_intercept + var_residual)
  r2 <- MuMIn::r.squaredGLMM(model)
  
  list(
    Residual_Variance = var_residual,
    Random_Intercept_Variance = var_intercept,
    ICC = icc,
    Participants = length(unique(getGroups(model))),
    Observations = nobs(model),
    Marginal_R2 = r2[1],
    Conditional_R2 = r2[2]
  )
}

## Create lme Function Wrapper (DEPRECATED) ----
## Instead use create_model_function(..., model_type = "lme")
create_model_function_lme <- function(model, random_effects = ~1 | pid, correlation = NULL, ...) {
  model_formula = function(data, dv, covs = NULL) {
    tryCatch({
      # Check if dependent variable exists in the data
      if (!dv %in% names(data)) {
        stop(paste("Dependent variable", dv, "not found in the dataset."))
      }
      
      # Check for missing covariates
      if (!is.null(covs) && length(covs) > 0) {
        missing_covs <- covs[!covs %in% names(data)]
        if (length(missing_covs) > 0) {
          stop(paste("The following covariates are missing in the dataset:", paste(missing_covs, collapse = ", ")))
        }
      }
      
      # Construct using formula
      covariate_part <- if (is.null(covs) || length(covs) == 0) "" else paste(covs, collapse = " + ")
      formula_text <- paste(dv, "~", paste(c(covariate_part, model), collapse = " + "))
      fixed_formula <- as.formula(formula_text)
      
      # Fit model with lme
      fitted_model <- lme(
        fixed = fixed_formula,
        random = random_effects,
        correlation = correlation,
        data = data,
        na.action = na.omit,
        ...
      )
      
      return(fitted_model)
      
    }, error = function(e) {
      message("Error in model fitting: ", e$message)
      return(NULL)
    })
  }
  
  return(model_formula)
}

# PLOTTING FUNCTIONS ----
## Plot Model Function ----
## (UNFACTORED)
create_plot_model = function(
    model,
    coef_var, 
    title="", 
    x_lab="", 
    y_lab="") {
  format_p_value <- function(p_value) {
    if (p_value < 0.001) {
      return(" < 0.001")
    } else if (p_value < 0.005) {
      return(" < 0.005")
    } else if (p_value < 0.01) {
      return(" < 0.01")
    } else if (p_value < 0.05) {
      return(" < 0.05")
    } else {
      # If p-value is not significant, return the exact p-value rounded to three decimal places
      return(paste(" =", round(p_value, 3)))
    }
  }
  model_summary = summary(model)
  coef_exposure <- model_summary$coefficients[coef_var, ]
  beta_value <- round(coef_exposure["Estimate"], 3)
  t_value <- round(coef_exposure["t value"], 2)
  p_value <- format_p_value(coef_exposure["Pr(>|t|)"])
  
  # set title
  plot_title <- bquote(atop(.(title), 
                            paste(italic(beta), " = ", .(beta_value), ", ", italic(t), " = ", .(t_value), ", ", italic(p), .(p_value))))
  
  # plot
  plot <- sjPlot::plot_model(model, 
                             type = "eff", 
                             terms = c(coef_var),
                             ci.lvl = 0.95,
                             colors = "darkblue") + 
    labs(x = x_lab, 
         y = y_lab, 
         title = plot_title) +
    #ylim(30, 60) +
    #xlim(-200, 200) +
    # Apply custom plot aesthetics
    plot_aes
  plot(plot)
  return(plot)
}

## Plot Model Effects ----
## (UNFACTORED)
plot_model_effects <- function(data, response_var, predictor_var, model_var, 
                               scale = FALSE,
                               n = 25, 
                               plot_title_text = "", 
                               x_label = "", 
                               y_label = "") {
  # https://osf.io/preprints/psyarxiv/7j4ey
  # https://github.com/cnlab/shine-mindfulness-mvpa/blob/main/code/analysis_task.Rmd
  
  # Check if scaling was applied during modeling, and apply the same transformation here
  points_within <- data %>%
    select(pid, {{ response_var }}, {{ predictor_var }}) %>%
    mutate(type = "within-person",
           predicted = if (scale) scale({{ response_var }}) else {{ response_var }}) %>%
    rename("x" = {{ predictor_var }})
  # Get predicted values from the model, ensuring vals are within expected range
  vals <- modelr::seq_range(points_within$x, n = n)
  predicted <- ggeffects::ggpredict({{ model_var }}, c(paste0(deparse(substitute(predictor_var)), " [vals]")),
                                    ci_level = 0.95) %>%
    data.frame()
  # Extract statistics from the model
  model_summary <- summary({{ model_var }})
  coef_exposure <- model_summary$coefficients[deparse(substitute(predictor_var)), ]
  # Extract the beta, t-value, and p-value for the predictor variable
  beta_value <- round(coef_exposure["Estimate"], 3)
  t_value <- round(coef_exposure["t value"], 2)
  p_value <- round(coef_exposure["Pr(>|t|)"], 3)
  # Add stats to the plot title
  plot_title <- bquote(atop(.(plot_title_text), 
                            paste(italic(beta), " = ", .(beta_value), ", ", italic(t), " = ", .(t_value), ", ", italic(p), " = ", .(p_value))))
  # Plot with all the adjustments
  plot <- ggplot(predicted, aes(x, predicted)) +
    # Individual-level associations (for each pid)
    stat_smooth(data = points_within, aes(group = interaction(pid, type)), 
                geom = "line", method = "lm", alpha = 0.05, se = FALSE, size = 1.25, fullrange = TRUE) + 
    # Ribbon for confidence interval in lighter maroon
    geom_ribbon(aes(ymin = conf.low, ymax = conf.high), alpha = .3, fill = "maroon", color = NA) +
    # Line for the overall best-fit in maroon
    geom_line(size = 2, color = "maroon") +
    # Customize colors and labels
    scale_fill_manual(name = "trial type", values = palette_condition) +
    scale_color_manual(name = "trial type", values = palette_condition) +
    labs(x = x_label, 
         y = y_label,
         title = plot_title) +  # Add dynamic title with stats
    ylim(0, 100) +  # Keep the y-axis within 0-100 range
    plot_aes + 
    theme(legend.position = "top", 
          panel.grid.major.x = element_blank(),  # Remove vertical grid lines
          panel.grid.minor.x = element_blank(),  # Remove minor vertical grid lines
          plot.title = element_text(size = rel(1.5), hjust = 0.5),  # Title scales relative to window size
          axis.title.x = element_text(size = rel(1.2)),  # X-axis label scaling
          axis.title.y = element_text(size = rel(1.2)),  # Y-axis label scaling
          axis.text = element_text(size = rel(0.9)),  # Axis text scaling
          legend.text = element_text(size = rel(0.8)))  # Legend text scaling
  
  return(plot)
}


# STAY EVENTS FUNCTIONS ----
## Create Conditional Buffer exposure files ----
## (UNFACTORED)
run_conditional_buffer = function(type, 
                                  small_buffer,
                                  conditional_buffer,
                                  retailer_filename,
                                  geodata = NULL,
                                  create_stay_events = FALSE,
                                  stay_event_config = list(
                                    radius = 100,
                                    t = 1.5
                                  ),
                                  data_path = "/Volumes/cnlab/GeoRemote/Data/"
) {
  load_retailer_data <- function(retailer_filename, data_path) {
    # Determine if the path is absolute or relative
    if (!grepl("^(/|[A-Za-z]:)", retailer_filename)) {
      # If relative, construct the full path
      retailer_filepath <- file.path(data_path, 
                                     "Retailers", 
                                     retailer_filename)
    } else {
      # If absolute, use the provided path
      retailer_filepath <- retailer_filename
    }
    
    # Check if the file exists and load it
    if (file.exists(retailer_filepath)) {
      sprintf("Loading retailer data: %s", retailer_filepath)
      retailer <- intakeRetailers(retailer_filepath) %>%
        distinct(lat, lon, .keep_all = TRUE) %>%
        mutate(retailer_id = rownames(.))
      return(retailer)
    } else {
      stop("Retailer file not found at: ", retailer_filepath)
    }
  }
  create_new_stay_events = function(geodata, 
                                    retailers, 
                                    stay_event_config) {
    sprintf("Creating new stay events with t = %s and radius = %s", stay_event_config[["t"]], stay_event_config[["radius"]])
    stayEvents = geodata %>% #update time to the time parameter used 
      stayevent(df = .,  
                coor = c("lon","lat"), 
                time = "datetime", 
                dist.threshold = stay_event_config[["radius"]]/3.28084, # conversion from feet to meters PARAMETER -  specifying stay event of 100ft between time points 
                time.threshold = stay_event_config[["t"]], # time PARAMETER 
                time.units = "mins", 
                groupvar = "filename") %>%
      mutate(rg_hr = radiusofgyration(., 
                                      coor = c("lon","lat"), 
                                      time = "datetime", 
                                      time.units = "hour", # PARAMETER
                                      groupvar = "filename")) %>%
      spaceTimeLags(., 2272)
    return(stayEvents)
  }
  inSmallBuffer = function(stayEvent_df, smallBuffer_df) {
    print("Checking observations that are in small buffer")
    joined_df <- st_drop_geometry(stayEvent_df) %>%
      filter(!is.na(retailer_id)) %>%
      semi_join(st_drop_geometry(smallBuffer_df), by = c("pid", "datetime_id", "retailer_id"))
    
    # Apply the comparison function to each row and add the 'matching' column
    df <- stayEvent_df %>%
      mutate(in_buffer = ifelse(id %in% joined_df$id, 1, 0))
    return(df)
  }
  combine_stay_events_with_retailers = function(stay_events, retailers, buffer) {
    sprintf("Combining stay events with retailers. Buffer: %sft", buffer)
    stay_events_with_stores <- stay_events %>%
      bufferAndJoin(retailers, ., 2272, buffer) %>%
      left_join(retailers, by = "retailer_id") %>% #c("trade_name", "expired_y_n","expiration_date","publish_date","address_full", "account")) %>%
      dplyr::rename(lat_ppt = lat.x, lon_ppt = lon.x, lat_retailer = lat.y, lon_retailer = lon.y) %>%
      rename_with(~ str_replace(., "\\.x$", ""), ends_with(".x")) %>%
      select(-ends_with(".y")) %>%
      mutate(
        publish_date = as.Date(publish_date, format = "%Y-%m-%d"),
        expiration_date = as.Date(expiration_date, format = "%Y-%m-%d")
      ) %>%
      mutate(
        retailer_status = case_when(
          is.na(publish_date) & is.na(expiration_date) ~ "Active",
          datetime >= publish_date & datetime <= expiration_date ~ "Active",
          TRUE ~ "Expired"
        )
      ) %>%
      dplyr::mutate(id = row_number(),
                    retailer_location = paste(lat_retailer, lon_retailer))
    
    return(stay_events_with_stores)
  }
  move_old_stayevent_files <- function(pattern, source_dir, new_dir) {
    
    # Get a list of files in the source directory
    files <- list.files(source_dir)
    # Loop through the list of files
    for (file in files) {
      # Check if the file includes pattern in its name
      if (grepl(pattern, file)) {
        # Create the destination folder if it doesn't exist
        dest_folder <- new_dir
        if (!file.exists(dest_folder)) {
          sprintf("Creating %s", dest_folder)
          dir.create(dest_folder)
        }
        
        # Construct the new path for the file in the "archive" folder
        new_path <- file.path(dest_folder, file)
        
        sprintf("Moving %s to %s", file, new_path)
        # Move the file to the "archive" folder
        file.rename(file.path(source_dir, file), new_path)
      }
    }
  }
  save_stayevents = function(df, 
                             name="geodata_with_retailers",
                             folder, 
                             retailer_filename, 
                             conditional_buffer, small_buffer) {
    readme_content <- sprintf(
      "File Name: %s\nDate Saved: %s\nMatched with retailer file: %s\nConditional Buffer: %s\nSmall Buffer: %s\n\n", name, Sys.Date(), retailer_filename, conditional_buffer, small_buffer)
    
    move_old_stayevent_files(pattern=name,source_dir = folder, new_dir = file.path(folder, "archive"))
    move_old_stayevent_files(pattern=paste0(name, "*README.txt"),source_dir = folder, new_dir = file.path(folder, "archive"))
    date = Sys.Date()
    stayevent_filename = paste0(folder,"/",name,"_",date,".csv")
    readme_filename = file.path(folder, paste0(name,"_",date,"_README.txt"))
    
    # Save datetime with timezone
    df = df %>%
      mutate(datetime = format(datetime, "%Y-%m-%d %H:%M:%S %Z")) %>%
      st_drop_geometry()
    
    sprintf("Saving file: %s", stayevent_filename)
    write.csv(df,stayevent_filename)
    sprintf("Saving file: %s", readme_filename)
    writeLines(readme_content, readme_filename)
    return(df)
  }
  
  # Load retailer_data 
  retailers = load_retailer_data(retailer_filename, data_path)
  
  # Load geodata
  if (is.null(geodata)) {
    geodata = load_geodata(type, data_path = data_path)
  }
  
  # Load stay events *or* create stay events
  if(create_stay_events==FALSE) {
    load_stay_events(type, small_buffer, conditional_buffer,
                     data_path = data_path)
  } else {
    stay_events = create_new_stay_events(geodata, retailers, stay_event_config) %>%
      arrange(pid, datetime)
    
    # Add datetime_id
    stay_events = stay_events %>%
      group_by(pid) %>%
      arrange(datetime) %>% # Ensure the datetime is sorted within each participant
      dplyr::mutate(datetime_id = row_number()) %>%
      ungroup()
    
    stay_events_with_stores_conditional_buffer = combine_stay_events_with_retailers(stay_events, retailers, conditional_buffer)
    stay_events_with_stores_small_buffer = combine_stay_events_with_retailers(stay_events, retailers, small_buffer)
    
    stay_events_with_stores = stay_events_with_stores_conditional_buffer %>%
      inSmallBuffer(stay_events_with_stores_small_buffer)
  }
  save_stayevents(df=stay_events_with_stores, 
                  name="geodata_with_retailers", 
                  folder=file.path(data_path, 
                                   "RetailerExposure/StayEvents",
                                   str_to_title(tolower(type)),
                                   sprintf("%sft_%sft", conditional_buffer, small_buffer)), 
                  retailer_filename,
                  conditional_buffer,
                  small_buffer)
}

## Join Exposures ----
## (UNFACTORED)
join_exposures = function(dir, df="") {
  files = list.files(path=dir)[grepl("*_exposure.csv",list.files(path=dir))]
  exposure_df = data.frame()
  for (file in files) {
    temp = read_csv(file.path(dir,file), show_col_types = FALSE) %>%
      dplyr::mutate(pid = substr(file,1,5))
    
    exposure_df = exposure_df %>%
      rbind(temp) 
  }
  
  # If you need you can load the df with the stores here
  if (!is.data.frame(df)) {
    df = load_stay_events(type, small_buffer, conditional_buffer, 
                          data_path = "/Volumes/cnlab/GeoRemote/Data/")
  }
  output_df = left_join(df, exposure_df, by="id", suffix=c("","_exposure")) %>%
    select(-ends_with("_exposure"))
  return(output_df)
}


## Calculate Exposures ----
## (UNFACTORED)
calculate_exposures = function(stay_events=NULL,
                               type=NULL,
                               conditional_buffer=NULL,
                               small_buffer=NULL,
                               start_from=NULL,
                               data_path = "/Volumes/cnlab/GeoRemote/Data/") {
  
  if (is.null(stay_events)) {
    if (is.null(type)) {
      stop("Type must be specified as Baseline or Intervention")
    }
    if (is.null(conditional_buffer)) {
      stop("Conditional buffer must be specified (500ft, 1000ft")
    }
    if (is.null(small_buffer)) {
      stop("Small buffer must be specified (100ft")
    }
    stay_events_with_stores = load_stay_events(type, 
                                               small_buffer, 
                                               conditional_buffer, 
                                               data_path = data_path)
  }
  stay_events_with_stores = stay_events_with_stores %>%
    dplyr::arrange(pid)
  exposure_list_output = data.frame(pid=character(), id = integer(), exposure_id = integer(), datetime=POSIXct(), day=integer())
  pid_list = unique(stay_events_with_stores$pid)
  if (!is.null(start_from)) {
    pid_start = which(pid_list==start_from)
    pid_list = pid_list[pid_start:length(pid_list)]
  }
  pb <- progress_bar$new(
    format = "  Progress [:bar] :percent in :elapsed (ETA: :eta)",
    total = length(pid_list),  # Total iterations
    clear = FALSE,  # Don't clear the bar on completion
    width = 60
  )
  # Loop through participants
  for (ppt in pid_list) {
    if (ppt == "GR201") {return(NULL)}
    exposure_list = data.frame(id = integer(), exposure_id = integer())
    # if (sum(grepl(ppt, files))) { next }
    ppt_df = stay_events_with_stores %>%
      dplyr::filter(pid == ppt)
    exposure_id = 0 
    
    # Loop through datetime_id
    for (t_idx in unique(ppt_df$datetime_id)) {
      current_time = ppt_df %>%
        dplyr::filter(datetime_id == t_idx)
      
      # If no stores in the current time (assuming length is 1)
      if (sum(is.na(current_time$address_full))) { next }
      
      previous_time = ppt_df %>%
        dplyr::filter(datetime_id == t_idx - 1)
      
      # Loop through the current time observations
      for (retailer_idx in 1:nrow(current_time)) {
        retailer_observation = current_time[retailer_idx,]
        
        # Skip the row if the retailer status is expired
        if (retailer_observation$expired_y_n == "EXPIRED") { next }
        
        # Special handling only for the first row
        if (t_idx == 1) {
          # If the first row's distance is less than buffer, assign new exposure ID
          if (retailer_observation$in_buffer) {
            exposure_id = exposure_id + 1
            exposure_list = rbind(exposure_list, data.frame(pid = ppt, id = retailer_observation$id, exposure_id = exposure_id, datetime=retailer_observation$datetime, day=retailer_observation$day))
          }
          next
        }
        
        # Check if exposure is in the previous observation
        if (retailer_observation$address_full %in% previous_time$address_full) {
          # If it is, check if it already has an exposure ID
          matching_id = previous_time %>%
            dplyr::filter(address_full == retailer_observation$address_full) %>%
            dplyr::arrange(retailer_id) %>%
            dplyr::pull(id)
          matching_exposure_id = exposure_list %>% 
            dplyr::filter(id == matching_id[1]) %>%
            dplyr::pull(exposure_id)
          if (length(matching_exposure_id) > 0) {
            exposure_list = rbind(exposure_list, data.frame(pid = ppt, id = retailer_observation$id, exposure_id = matching_exposure_id, datetime=retailer_observation$datetime, day=retailer_observation$day))
            next
          } else {
            # If not, create new exposure ID and assign it to the current and previous observations
            exposure_id = exposure_id + 1
            exposure_list = rbind(exposure_list, data.frame(pid = ppt, id = matching_id[1], exposure_id = exposure_id, datetime=previous_time$datetime[1], day=previous_time$day[1])) # Previous observation
            exposure_list = rbind(exposure_list, data.frame(pid = ppt, id = retailer_observation$id, exposure_id = exposure_id, datetime=retailer_observation$datetime, day=retailer_observation$day)) # Current observation
            next
          }
        }
        # If first instance and distance is less than buffer, assign new exposure ID
        if (retailer_observation$in_buffer) {
          exposure_id = exposure_id + 1
          exposure_list = rbind(exposure_list, data.frame(pid = ppt, id = retailer_observation$id, exposure_id = exposure_id, datetime=retailer_observation$datetime, day=retailer_observation$day))
          next
        }
      }
    }
    filename = file.path(data_path,
                         "RetailerExposure",
                         "ConditionalBuffer",
                         str_to_title(tolower(type)),
                         sprintf("%sft_%sft", conditional_buffer, small_buffer),
                         paste0(ppt, "_exposure.csv"))
    write_csv(exposure_list, filename)
    pb$tick()
    exposure_list_output = rbind(exposure_list_output, exposure_list)
  }
  # Join exposures with stay events
  if (!is.null(start_from)) {
    stay_events_with_exposures = join_exposures(file.path(data_path,
                                                          "RetailerExposure",
                                                          "ConditionalBuffer",
                                                          str_to_title(tolower(type)),
                                                          sprintf("%sft_%sft", conditional_buffer, small_buffer)), df=stay_events_with_stores)
  }
  stay_events_with_exposures = stay_events_with_stores %>%
    left_join(exposure_list_output, by="id", suffix=c("","_exposure"))
  filename = file.path(data_path,
                       "RetailerExposure",
                       "ConditionalBuffer",
                       str_to_title(tolower(type)),
                       sprintf("%sft_%sft_exposures.csv", conditional_buffer, small_buffer))
  sprintf("Saving: %s", filename)
  write_csv(stay_events_with_exposures, filename)
}

## Create nExposures_nObservations summary files ----
create_nExposures_nObservations = function(type, conditional_buffer,
                                           data_path = "/Volumes/cnlab/GeoRemote/Data/") {
  dir = file.path(data_path,
                  sprintf("RetailerExposure/ConditionalBuffer/%s/%sft_100ft/",
                          str_to_title(tolower(type)), conditional_buffer)
  )
  files = list.files(path=dir)[grepl("*_exposure.csv",list.files(path=dir))]
  exposure_df = data.frame()
  for (file in files) {
    temp = read_csv(file.path(dir,file), show_col_types = FALSE) %>%
      mutate(pid = substr(file,1,5))
    
    exposure_df = exposure_df %>%
      rbind(temp) 
  }
  if (!is.data.frame(df)) {
    df = load_stay_events(type, 100, conditional_buffer)
  }
  exposure_df = left_join(df, exposure_df, by="id", suffix=c("","_exposure")) %>%
    select(-ends_with("_exposure"))
  summary <- exposure_df %>%
    group_by(pid, day) %>%
    dplyr::summarise(
      # Count distinct exposures per day
      n_exposure_per_day = n_distinct(exposure_id, na.rm = TRUE),
      # Count total observations per day
      n_observations_per_day = n_distinct(datetime_id, na.rm = TRUE),
    ) %>%
    arrange(pid, day) # Sort by participant and day
  filename = file.path(data_path,
                       "RetailerExposure",
                       "ConditionalBuffer",
                       str_to_title(tolower(type)),
                       sprintf("%sft_%sft_nExposures_nObservations.csv", conditional_buffer, 100))
  sprintf("Saving: %s", filename)
  write_csv(summary, filename)
}

# MISC ----

## Get Exposure Statistics ----
## (UNFACTORED)
get_statistics = function(df) {
  summary = df %>%
    group_by(pid, day) %>%
    summarise(
      n_exposure_per_day = ifelse(all(is.na(exposure_id)), 0, n_distinct(exposure_id, na.rm = TRUE))
    ) %>%
    ungroup() %>%
    group_by(pid) %>%
    summarise(
      n_day = n_distinct(day),
      median_exposures_per_day = median(n_exposure_per_day, na.rm = TRUE),
      mean_exposure_per_day = mean(n_exposure_per_day, na.rm = TRUE),
      sd_exposure_per_day = sd(n_exposure_per_day, na.rm = TRUE)
    )
}

## Check Days ----
check_days <- function(df) {
  # Get the unique pid values
  pids <- unique(df$pid)
  expected_days <- 1:14
  # Initialize a vector to store pids that don't have all days
  missing_days_pids <- c()
  
  # Loop through each pid and check for missing days
  for (pid in pids) {
    # Subset the dataframe for the current pid
    pid_df <- df[df$pid == pid, ]
    
    # Get the days present for the current pid
    pid_days <- pid_df$day
    
    # Check if any expected day is missing
    if (!all(expected_days %in% pid_days)) {
      missing_days_pids <- c(missing_days_pids, pid)
    }
  }
  
  return(missing_days_pids)
}