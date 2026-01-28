library(pacman)
p_load(tidyverse,data.table, qualtRics)

# Configuration ----
## Qualtrics config
QUALTRICS_CONFIG <- list(
  uri = "iad1.qualtrics.com",
  data_path = "/Volumes/cnlab/GeoRemote/Data/",
  pid_pattern = "^GR\\d{3}$",
  survey_ids = list(
    "Cotinine_GeoRemote" = "SV_4Mmb2WuyZ8wi7CC", 
    "GoogleMaps_Timeline_GeoRemote" = "SV_5clHlGytvXaeuQ6",
    "ImageTask_GeoRemote" = "SV_bjx9BR3c6r2zO98", 
    "LifeData_RealLifeExp_GeoRemote" = "SV_74yOXRfEikzv8bA",
    "SurveyMeasures_GeoRemote" = "SV_6mxadaCn4QKRwLc", 
    "StudyInstructions_GeoRemote" = "SV_brsqXudHeEWyqOi"
  )
)

# If your working directory is in the GeoRemote Scripts folder, it'll set the correct path. If it's not, it will ask you to select a file in the directory
if ("Scripts" %in% unlist(strsplit(normalizePath("."), "/"))) {
  scripts_directory = paste(unlist(strsplit(normalizePath("."), "/"))[1:which(unlist(strsplit(normalizePath("."), "/"))=="Scripts")],collapse="/")
} else {
  print("Select any file withing Scripts to set up the path")
  temp = file.choose()
  scripts_directory = paste(unlist(strsplit(temp, "/"))[1:which(unlist(strsplit(temp, "/"))=="Scripts")],collapse="/")
  setwd(scripts_directory)
}




# DATA LOADING FUNCTIONS -----

download_raw_qualtrics_surveys <- function(surveys = "", 
                                           save = FALSE, 
                                           save_qualtrics_credentials = FALSE,
                                           data_path = QUALTRICS_CONFIG$data_path,
                                           base_url = QUALTRICS_CONFIG$uri,
                                           QUALTRICS_SURVEY_IDS = QUALTRICS_CONFIG$survey_ids
                                           ) {
  # Input validation
  stopifnot(
    "surveys must be character" = is.character(surveys),
    "save must be logical" = is.logical(save),
    "save_qualtrics_credentials must be logical" = is.logical(save_qualtrics_credentials),
    "data_path must be character" = is.character(data_path)
  )
  
  # Early return for survey list request
  if (surveys == "") {
    message("Available surveys:")
    purrr::walk(names(QUALTRICS_SURVEY_IDS), ~ message("  - ", .x))
    return(QUALTRICS_SURVEY_IDS)
  }
  
  # Nested helper functions
  install_qualtrics_credentials <- function(base_url = base_url,
                                            overwrite=save_qualtrics_credentials) {
    key <- .rs.askForPassword("Please enter your Qualtrics API token")
    qualtrics_api_credentials(
      api_key = key, 
      base_url = base_url,
      overwrite = overwrite,
      install = TRUE
    )
  }
  
  get_survey_metadata <- function(survey_ids = QUALTRICS_SURVEY_IDS) {
    all_surveys() %>%
      filter(id %in% unlist(survey_ids))
  }
  
  download_single_survey <- function(survey_info, should_save = save) {
    message("Downloading survey: ", survey_info$name)
    
    survey_data <- fetch_survey(
      surveyID = survey_info$id,
      verbose = TRUE
    )
    
    if (should_save) {
      save_qualtrics(
        df = survey_data,
        name = paste0(survey_info$name, "_raw"), 
        folder = "raw",
        data_path = data_path
      )
    }
    
    return(survey_data)
  }
  
  # Ensure API credentials are available
  if (Sys.getenv("QUALTRICS_API_KEY") == "") {
    install_qualtrics_credentials()
  }
  
  # Get survey metadata based on request
  surveys_to_download <- if (tolower(surveys) == "all") {
    get_survey_metadata()
  } else {
    # Validate requested surveys exist
    invalid_surveys <- setdiff(surveys, names(QUALTRICS_SURVEY_IDS))
    if (length(invalid_surveys) > 0) {
      stop("Unknown survey(s): ", paste(invalid_surveys, collapse = ", "),
           "\nAvailable surveys: ", paste(names(QUALTRICS_SURVEY_IDS), collapse = ", "))
    }
    
    get_survey_metadata() %>%
      filter(name %in% surveys)
  }
  
  # Download surveys using functional approach
  survey_list <- surveys_to_download %>%
    purrr::transpose() %>%
    purrr::map(~ download_single_survey(.x)) %>%
    set_names(surveys_to_download$name)
  
  # Return single dataframe if only one survey, otherwise return list
  if (length(survey_list) == 1) {
    return(survey_list[[1]])
  } else {
    return(survey_list)
  }
}


load_surveys <- function(survey_name = "", 
                         type = "raw", 
                         data_path = QUALTRICS_CONFIG$data_path) {
  
  qualtrics_path <- file.path(data_path, "Qualtrics")
  type_path <- file.path(qualtrics_path, type)
  
  
  # Input validation
  stopifnot(
    "survey_name must be character" = is.character(survey_name),
    "type must be character" = is.character(type) && length(type) == 1,
    "data_path must be character" = is.character(data_path) && length(data_path) == 1
  )
  
  if (!type %in% c("raw", "clean")) {
    stop("Invalid type. Must be 'raw' or 'clean'.")
  }
  
  # Validate paths exist
  if (!dir.exists(data_path)) {
    stop("Data path does not exist: ", data_path)
  }
  if (!dir.exists(qualtrics_path)) {
    stop("Qualtrics directory does not exist: ", qualtrics_path)
  }
  if (!dir.exists(type_path)) {
    stop("Survey type directory does not exist: ", type_path)
  }
  
  # Helper functions
  get_csv_files <- function(path) {
    csv_files = list.files(path, pattern = "\\.csv$", full.names = TRUE) %>%
      .[!file.info(.)$isdir]  # Exclude any directories
    
    if (length(csv_files) == 0) {
      stop("No CSV files found in ", type_path)
    }
    
    return(csv_files)
  }
  
  extract_raw_survey_names <- function(file_paths) {
    survey_names <- basename(file_paths) %>%
      str_extract("(?<=qualtrics_)(.*?)(?=_raw_)")
    
    # Filter out any NA values from failed extractions
    valid_indices <- !is.na(survey_names)
    valid_paths <- file_paths[valid_indices]
    valid_names <- survey_names[valid_indices]
    
    set_names(valid_paths, valid_names)
  }
  
  extract_clean_survey_names <- function(file_paths) {
    survey_names <- basename(file_paths) %>%
      str_extract("(?<=qualtrics_)(.*?)(?=_\\d{4}-\\d{2}-\\d{2}\\.csv$)")
    
    # Filter out any NA values from failed extractions
    valid_indices <- !is.na(survey_names)
    valid_paths <- file_paths[valid_indices]
    valid_names <- survey_names[valid_indices]
    
    set_names(valid_paths, valid_names)
  }
  
  validate_survey_selection <- function(survey_name, available_surveys, type = "raw") {
    # Input validation
    stopifnot(
      "survey_name must be character" = is.character(survey_name),
      "available_surveys must be character" = is.character(available_surveys),
      "type must be character" = is.character(type) && length(type) == 1
    )
    
    if (survey_name == "") {
      message("\nAvailable ", type, " surveys in folder:")
      walk(names(available_surveys), ~ message("  - ", .x))
      
      message("\nSuggestions:")
      message("1. Load one of the available surveys above")
      message("2. Use 'all' to load all available surveys")
      message("3. Check spelling of survey name(s)")
      stop("No survey name provided. Please specify a survey name or use 'all' to load all surveys.")
    }
    
    # If survey_name is empty or "all", return all available surveys
    if (survey_name[1] == "all") {
      return(available_surveys)
    }
    
    # For partial matching, check if any survey_name appears in available surveys
    matching_surveys <- available_surveys[stringr::str_detect(names(available_surveys), 
                                                     paste(survey_name, collapse = "|"))]
    
    if (length(matching_surveys) == 0) {
      message("No matching surveys found for: ", paste(survey_name, collapse = ", "))
      message("\nAvailable ", type, " surveys in folder:")
      purrr::walk(names(available_surveys), ~ message("  - ", .x))
      
      message("\nSuggestions:")
      message("1. Load one of the available surveys above")
      message("2. Use 'all' to load all available surveys")
      message("3. Check spelling of survey name(s)")
      
      stop("No matching survey files found.")
    }
    
    # Return the matching surveys
    return(matching_surveys)
  }
  
  filter_files_by_survey_name <- function(file_paths, survey_names) {
    if (length(survey_names) == 0 || survey_names[1] == "") {
      return(file_paths)
    }
    pattern <- paste(survey_names, collapse = "|")
    file_paths[str_detect(file_paths, pattern)]
  }
  
  load_survey_files <- function(file_paths_named) {
    if (length(file_paths_named) == 0) {
      stop("No matching files found.")
    }
    
    message("Loading ", length(file_paths_named), " survey file(s):")
    purrr::walk2(names(file_paths_named), file_paths_named, 
          ~ message("  - ", .x, " (", basename(.y), ")"))
    
    purrr::map(file_paths_named, ~ read_csv(.x, show_col_types = FALSE))
  }
  
  # Get available CSV files
  csv_files <- get_csv_files(type_path)
  
  # Extract available survey names from files
  available_surveys <- if (type == "raw") {
    csv_files %>%
      extract_raw_survey_names()
  } else if (type == "clean") { 
    csv_files %>%
      extract_clean_survey_names()
  }
  
  # Validate requested survey names
  survey_files = validate_survey_selection(survey_name, available_surveys, type)
  
  # Load the survey data
  survey_data <- load_survey_files(survey_files)
  
  # Return single dataframe if only one survey, otherwise return list
  if (length(survey_data) == 1) {
    return(survey_data[[1]])
  } else {
    return(survey_data)
  }
}

save_qualtrics = function(df, name,folder, data_path = QUALTRICS_CONFIG$data_path) {
  move_old_qualtrics_files <- function(pattern,source_dir, new_dir) {
    
    # Get a list of files in the source directory
    files <- list.files(source_dir)
    # Loop through the list of files
    for (file in files) {
      # Check if the file includes "lifedata_clean" in its name
      if (grepl(sprintf("qualtrics_%s", pattern), file)) {
        # Create the destination folder if it doesn't exist
        dest_folder <- new_dir
        if (!file.exists(dest_folder)) {
          dir.create(dest_folder)
        }
        
        # Construct the new path for the file in the "archive" folder
        new_path <- file.path(dest_folder, file)
        
        # Move the file to the "archive" folder
        file.rename(file.path(source_dir, file), new_path)
      }
    }
  }
  
  move_old_qualtrics_files(pattern=name,
                           file.path(data_path,"Qualtrics", folder), 
                           file.path(data_path, "Qualtrics", folder,"archive"))
  date = Sys.Date()
  write.csv(df,file.path(data_path, 
                         "Qualtrics",
                         folder, 
                         paste0("qualtrics_",name,"_",date,".csv")),
            row.names = FALSE)
  print(sprintf("File Created: %s/Qualtrics/%s/qualtrics_%s_%s.csv", data_path, folder,name,date))
  return(df)
}
load_qualtrics_survey_measures = function(type = "clean",data_path = QUALTRICS_CONFIG$data_path) {
  return(
    load_surveys(
      survey_name = "survey_measures", 
      type = type, 
      data_path = data_path))
}
load_qualtrics_weekly_surveys = function(type = "clean",data_path = QUALTRICS_CONFIG$data_path) {
  return(
    load_surveys(
      survey_name = "weekly_surveys", 
      type = type, 
      data_path = data_path))
}
load_qualtrics_fmri_surveys = function(type = "clean",data_path = QUALTRICS_CONFIG$data_path) {
  return(
    load_surveys(
      survey_name = "fMRI", 
      type = type, 
      data_path = data_path))
}


# DATA PROCESSING FUNCTIONS -----
clean_survey_measures <- function(df) {
  # Helper function to rename system/metadata columns
  rename_system_columns <- function(df) {
    df %>%
      dplyr::rename(
        # System metadata columns (prefixed with sm_)
        sm_session = session,
        sm_startdate = StartDate,
        sm_enddate = EndDate,
        sm_progress = Progress,
        sm_duration = `Duration (in seconds)`,
        sm_finished = Finished,
        sm_recordeddate = RecordedDate,
        sm_responseid = ResponseId,
        
        # Participant ID
        pid = pID
      )
  }
  
  # Helper function to rename behavioral measure columns
  rename_behavioral_columns <- function(df) {
    df %>%
      dplyr::rename(
        # Behavioral measures - fix special characters
        bhv_01_new_1_1_1 = `bhv_01_new#1_1_1`,
        bhv_01_new_2_1 = `bhv_01_new#2_1`,
        
        # Behavioral measures - standardize underscores
        bhv_10___1 = bhv_10_1,
        bhv_10___4 = bhv_10_4,
        bhv_10___5 = bhv_10_5,
        bhv_10___6 = bhv_10_6,
        bhv_10___8 = bhv_10_8,
        bhv_10___9 = bhv_10_9,
        
        # Substance use measures - fix spaces
        marijuana_use = `marijuana use`,
        marijuana_freq = `marijuana freq`,
        what_treated = `what treated`,
        meds_follow_up = `meds_follow-up`,
        meds_open_ended = `meds_open-ended`
      )
  }
  
  # Helper function to rename belief/attitude columns
  rename_belief_columns <- function(df) {
    df %>%
      dplyr::rename(
        # Belief about cigarettes - self items
        belcig_self_01 = `belCig-self_01`,
        belcig_self_02 = `belCig-self_02`,
        belcig_self_03 = `belCig-self_03`,
        belcig_self_04 = `belCig-self_04`,
        belcig_self_05 = `belCig-self_05`,
        belcig_self_06 = `belCig-self_06`,
        belcig_self_07 = `belCig-self_07`,
        belcig_self_08 = `belCig-self_08`,
        belcig_self_09 = `belCig-self_09`,
        belcig_self_10 = `belCig-self_10`,
        belcig_self_11 = `belCig-self_11`,
        belcig_self_12 = `belCig-self_12`,
        
        # Belief about cigarettes - laws items
        belcig_laws_01 = `belCig-laws_01`,
        belcig_laws_02 = `belCig-laws_02`,
        belcig_laws_03 = `belCig-laws_03`,
        belcig_laws_04 = `belCig-laws_04`,
        belcig_laws_06 = `belCig-laws_06`,
        belcig_laws_07 = `belCig-laws_07`
      )
  }
  
  # Helper function to handle differences between old and new survey versions
  handle_version_differences <- function(df) {
    df %>%
      dplyr::mutate(
        # Smoking behavior - combine old and new versions
        # bhv_01 old: "On average, how much have you smoked per day over the past week?"
        # bhv_01 new: "On average over the past week, how much have you smoked PER DAY?"
        bhv_01_new_1_1_1 = dplyr::coalesce(`bhv_01#1_1_1`, bhv_01_new_1_1_1),
        bhv_01_new_2_1 = dplyr::coalesce(`bhv_01#2_1`, bhv_01_new_2_1),
        
        # Tobacco product use - map old categories to new structure
        # OLD -> NEW mappings documented below:
        # bhv_02_01 (Manufactured cigs) -> bhv_02_new_01
        # bhv_02_07 (E-cigs/vapes) -> bhv_02_new_02  
        # bhv_02_02 (Hand-rolled) -> bhv_02_new_03
        # bhv_02_03 (Kretek) -> bhv_02_new_04
        # bhv_02_04 (Pipes of tobacco) -> bhv_02_new_05
        # bhv_02_06 (Water pipe/hookah/shisha) -> bhv_02_new_08
        # bhv_02a_1/2/3 (Other categories) -> bhv_02_new_13/14/15
        
        bhv_02_new_01 = dplyr::coalesce(bhv_02_01, bhv_02_new_01),
        bhv_02_new_02 = dplyr::coalesce(bhv_02_07, bhv_02_new_02),
        bhv_02_new_03 = dplyr::coalesce(bhv_02_02, bhv_02_new_03),
        bhv_02_new_04 = dplyr::coalesce(bhv_02_03, bhv_02_new_04),
        bhv_02_new_05 = dplyr::coalesce(bhv_02_04, bhv_02_new_05),
        bhv_02_new_08 = dplyr::coalesce(bhv_02_06, bhv_02_new_08),
        
        # Handle "Other" categories with both checkbox and text responses
        bhv_02_new_13 = dplyr::coalesce(bhv_02a_1, bhv_02_new_13),
        bhv_02_new_13_TEXT = dplyr::coalesce(bhv_02a_1_TEXT, bhv_02_new_13_TEXT),
        bhv_02_new_14 = dplyr::coalesce(bhv_02a_2, bhv_02_new_14),
        bhv_02_new_14_TEXT = dplyr::coalesce(bhv_02a_2_TEXT, bhv_02_new_14_TEXT),
        bhv_02_new_15 = dplyr::coalesce(bhv_02a_3, bhv_02_new_15),
        bhv_02_new_15_TEXT = dplyr::coalesce(bhv_02a_3_TEXT, bhv_02_new_15_TEXT)
      )
  }
  
  # Helper function to remove columns that were combined/replaced
  remove_obsolete_columns <- function(df) {
    columns_to_remove <- c(
      # Old bhv_01 variants that were combined
      "bhv_01#1_1_1", "bhv_01#2_1",
      
      # Old bhv_02 variants that were mapped to new structure
      "bhv_02_01", "bhv_02_07", "bhv_02_02", "bhv_02_03", 
      "bhv_02_04", "bhv_02_06",
      
      # Old "other" category variants
      "bhv_02a_1", "bhv_02a_1_TEXT", "bhv_02a_2", "bhv_02a_2_TEXT", 
      "bhv_02a_3", "bhv_02a_3_TEXT"
    )
    
    # Only remove columns that actually exist in the dataframe
    existing_columns_to_remove <- intersect(columns_to_remove, names(df))
    
    if (length(existing_columns_to_remove) > 0) {
      df %>% dplyr::select(-dplyr::all_of(existing_columns_to_remove))
    } else {
      df
    }
  }
  
  # Helper function to standardize column naming patterns
  standardize_column_patterns <- function(df) {
    df %>%
      # Standardize Q264 pattern (specific survey question format)
      dplyr::rename_with(~ stringr::str_replace(.x, "^Q264_", "q264___"), 
                         dplyr::starts_with("Q264_"))
  }

  # Helper function to extract participant IDs
  extract_participant_id <- function(participant_vector) {
    pattern <- "GR\\d{3}"
    return(stringr::str_extract(participant_vector, pattern))
  }
  
  # Helper function to add timezone to datetime columns
  add_timezone_info <- function(df) {
    # Time is loaded as EST/EDT, adding timezone to file
    df %>%
      dplyr::mutate(dplyr::across(dplyr::where(lubridate::is.POSIXt), 
                                  ~ lubridate::force_tz(.x, tzone = "America/New_York")))
  }
  
  # Main cleaning pipeline
  df_cleaned <- df %>%
    # Remove empty rows and columns
    dplyr::filter(dplyr::if_any(dplyr::everything(), ~ !is.na(.x))) %>%
    dplyr::select(dplyr::where(~ !all(is.na(.x)))) %>%
    
    # Filter out test participants
    dplyr::filter(!stringr::str_detect(pID, stringr::regex("test", ignore_case = TRUE))) %>%
    
    # Rename system/metadata columns
    rename_system_columns() %>%
    
    # Rename behavioral measure columns
    rename_behavioral_columns() %>%
    
    # Rename belief/attitude columns
    rename_belief_columns() %>%
    
    # Handle survey version differences (old vs new questions)
    handle_version_differences() %>%
    
    # Clean up temporary columns
    remove_obsolete_columns() %>%
    
    # Standardize special column patterns
    standardize_column_patterns() %>%
    
    # Convert all column names to lowercase
    dplyr::rename_with(tolower) %>%
    
    # Extract and clean participant ID
    dplyr::mutate(pid = extract_participant_id(pid)) %>%
    
    # Add timezone information
    add_timezone_info()
  
  return(df_cleaned)
}

filter_session_by_progress <- function(ppt_df, session_number = "", title_name = "") {
  apply_session_filters <- function(ppt_df, session_number, title_name) {
    
    session_number <- as.character(session_number)
    
    result <- ppt_df %>%
      # Remove Qualtrics display logic columns (typically not needed for analysis)
      dplyr::select(-dplyr::matches("_DO_", ignore.case = TRUE))
    
    # Apply session number filter if specified
    if (session_number != "") {
      result <- result %>%
        dplyr::filter(stringr::str_detect(sm_session, session_number))
    }
    
    # Apply title filter if specified  
    if (title_name != "") {
      result <- result %>%
        dplyr::filter(stringr::str_detect(title, title_name))
    }
    
    return(result)
  }
  
  handle_session_2_logic <- function(session_df) {
    
    # Session 2 has special handling:
    # Some participants were excluded and then redid S2 unexcluded
    # Priority: unexcluded > excluded sessions
    
    s2_unexcluded <- session_df %>%
      dplyr::filter(is.na(week))
    
    s2_excluded <- session_df %>%
      dplyr::filter(stringr::str_detect(as.character(cond), "excl"))
    
    # Prioritize unexcluded sessions
    if (nrow(s2_unexcluded) > 0) {
      message("Using unexcluded Session 2 data")
      return(s2_unexcluded %>% 
               dplyr::filter(sm_recordeddate == min(sm_recordeddate, na.rm = TRUE)))
    }
    
    # Fall back to excluded sessions if available
    if (nrow(s2_excluded) > 0) {
      message("Using excluded Session 2 data (no unexcluded session found)")
      return(s2_excluded %>% 
               dplyr::filter(sm_recordeddate == min(sm_recordeddate, na.rm = TRUE)))
    }
    
    # If neither unexcluded nor excluded sessions found, use standard logic
    message("No excluded/unexcluded Session 2 data found, using standard selection")
    return(select_best_session_standard(session_df))
  }
  
  select_best_session_standard <- function(session_df) {
    
    # Check for completed sessions (Progress == 100)
    completed_sessions <- session_df %>%
      dplyr::filter(sm_progress == 100)
    
    if (nrow(completed_sessions) > 0) {
      # For completed sessions, select earliest recorded date
      return(completed_sessions %>%
               dplyr::filter(sm_recordeddate == min(sm_recordeddate, na.rm = TRUE)))
    }
    
    # No completed sessions found, select session with highest progress
    max_progress <- max(session_df$sm_progress, na.rm = TRUE)
    message(session_df$pid, ": No completed sessions found, selecting session with highest progress (", 
            max_progress, "%)")
    
    return(session_df %>%
             dplyr::filter(sm_progress == max_progress))
  }
  
  # Input validation
  if (nrow(ppt_df) == 0) {
    warning("Input dataframe is empty")
    return(NULL)
  }
  
  # Apply initial filters
  session_df <- apply_session_filters(ppt_df, session_number, title_name)
  
  if (nrow(session_df) == 0) {
    message(unique(ppt_df$pid), ": No sessions found matching criteria: session='", session_number, 
            "', title='", title_name, "'")
    return(NULL)
  }
  
  # Handle special case for Session 2
  if (session_number == "2") {
    return(handle_session_2_logic(session_df))
  }
  
  # Standard session selection logic
  return(select_best_session_standard(session_df))
}

convert_qualtrics_to_redcap <- function(qualtrics, redcap, redcap_dictionary) {
  filter_relevant_columns <- function(qualtrics, redcap_dictionary) {
    
    # Build patterns for columns to keep
    column_patterns <- build_column_patterns(redcap_dictionary)
    
    # Identify columns that match our patterns
    columns_to_keep <- identify_matching_columns(names(qualtrics), column_patterns)
    
    # Always keep participant ID
    columns_to_keep <- columns_to_keep | names(qualtrics) == "pid"
    
    # Exclude Qualtrics display logic columns
    columns_to_keep <- columns_to_keep & !grepl("_do_", names(qualtrics), ignore.case = TRUE)
    
    if (sum(columns_to_keep) == 0) {
      warning("No matching columns found between Qualtrics data and REDCap dictionary")
      return(qualtrics[0, ])
    }
    
    message("Keeping ", sum(columns_to_keep), " out of ", ncol(qualtrics), " columns")
    
    return(qualtrics[, columns_to_keep, drop = FALSE])
  }
  
  build_column_patterns <- function(redcap_dictionary) {
    
    patterns <- c(
      redcap_dictionary$var,  # All REDCap variables
      "sm_"                   # System metadata columns
    )
    
    # Add weekly survey patterns if present
    if ("weekly_survey_questions_from_qualtrics" %in% redcap_dictionary$form) {
      patterns <- c(patterns, "week")
    }
    
    return(patterns)
  }
  
  identify_matching_columns <- function(column_names, patterns) {
    
    vapply(column_names, function(col_name) {
      any(vapply(patterns, function(pattern) {
        grepl(pattern, col_name, fixed = TRUE)
      }, logical(1)))
    }, logical(1))
  }
  
  convert_response_formats <- function(filtered_data, redcap_dictionary) {
    
    # Clean text formatting first
    cleaned_data <- clean_text_formatting(filtered_data)
    
    # Convert different question types
    converted_data <- cleaned_data %>%
      convert_categorical_responses(redcap_dictionary) %>%
      convert_checkbox_responses(redcap_dictionary)
    
    return(converted_data)
  }
  
  clean_text_formatting <- function(data) {
    
    data %>%
      dplyr::mutate(dplyr::across(dplyr::everything(), ~ {
        if (is.character(.x)) {
          stringr::str_replace_all(.x, "\n", " ") %>%
            stringr::str_trim()
        } else {
          .x
        }
      }))
  }
  
  convert_categorical_responses <- function(data, redcap_dictionary) {
    
    # Get variables that need categorical conversion
    categorical_vars <- redcap_dictionary %>%
      dplyr::filter(
        type != "checkbox", 
        type != "text", 
        type != "slider",
        var %in% names(data)
      ) %>%
      dplyr::pull(var)
    
    if (length(categorical_vars) == 0) {
      return(data)
    }
    
    message("Converting ", length(categorical_vars), " categorical variables")
    
    for (variable in categorical_vars) {
      
      # Skip if already numeric
      if (is.numeric(data[[variable]])) {
        next
      }
      
      # Get the options for this variable
      options_string <- redcap_dictionary %>%
        dplyr::filter(var == variable) %>%
        dplyr::pull(options)
      
      if (length(options_string) == 0 || is.na(options_string)) {
        next
      }
      
      # Convert options string to lookup dictionary
      label_dict <- parse_redcap_options(options_string)
      
      if (length(label_dict) > 0) {
        data <- data %>%
          dplyr::mutate(!!variable := dplyr::recode(!!rlang::sym(variable), !!!label_dict))
      }
    }
    
    return(data)
  }
  
  parse_redcap_options <- function(options_string) {
    
    if (is.na(options_string) || options_string == "") {
      return(list())
    }
    
    # Split by pipe separator
    option_pairs <- strsplit(options_string, "|", fixed = TRUE)[[1]]
    
    output <- list()
    
    for (pair in option_pairs) {
      pair_trimmed <- stringr::str_trim(pair)
      
      # Match pattern: "number, label" (allowing 1-2 digits)
      matches <- stringr::str_match(pair_trimmed, "^(\\d{1,2})\\s*,\\s*(.*)$")
      
      if (!is.na(matches[1, 1])) {  # If pattern matched
        numeric_code <- stringr::str_trim(matches[1, 2])
        text_label <- stringr::str_trim(matches[1, 3])
        
        if (text_label != "" && numeric_code != "") {
          output[[text_label]] <- numeric_code
        }
      }
    }
    
    return(output)
  }
  
  convert_checkbox_responses <- function(data, redcap_dictionary) {
    
    # Get checkbox variables from dictionary
    checkbox_vars <- redcap_dictionary %>%
      dplyr::filter(type == "checkbox") %>%
      dplyr::pull(var)
    
    if (length(checkbox_vars) == 0) {
      return(data)
    }
    
    checkbox_columns_converted <- 0
    
    for (variable in checkbox_vars) {
      
      # Find all related checkbox columns in the dataframe
      checkbox_pattern <- paste0("^", variable, "_")
      checkbox_columns <- grep(checkbox_pattern, names(data), value = TRUE)
      
      # Exclude text columns (usually for "Other" responses)
      checkbox_columns <- checkbox_columns[!grepl("text", checkbox_columns, ignore.case = TRUE)]
      
      for (checkbox_column in checkbox_columns) {
        if (checkbox_column %in% names(data)) {
          data <- data %>%
            dplyr::mutate(!!rlang::sym(checkbox_column) := ifelse(
              !is.na(!!rlang::sym(checkbox_column)), 1, 0
            ))
          checkbox_columns_converted <- checkbox_columns_converted + 1
        }
      }
    }
    
    if (checkbox_columns_converted > 0) {
      message("Converted ", checkbox_columns_converted, " checkbox columns to 1/0 format")
    }
    
    return(data)
  }
  # Input validation
  if (nrow(qualtrics) == 0) {
    warning("Input Qualtrics dataframe is empty")
    return(qualtrics)
  }
  
  if (nrow(redcap_dictionary) == 0) {
    stop("REDCap dictionary is empty - cannot perform conversion")
  }
  
  # Filter columns to keep only relevant ones
  filtered_data <- filter_relevant_columns(qualtrics, redcap_dictionary)
  
  # Convert labels and format data
  converted_data <- convert_response_formats(filtered_data, redcap_dictionary)
  
  return(converted_data)
}

get_session_df <- function(session = "", qualtrics, redcap) {

  validate_session_inputs <- function(session, qualtrics, redcap) {
    
    if (missing(session) || session == "") {
      stop("Session parameter is required")
    }
    
    if (missing(qualtrics) || nrow(qualtrics) == 0) {
      stop("Qualtrics dataframe is required and cannot be empty")
    }
    
    if (missing(redcap) || nrow(redcap) == 0) {
      stop("REDCap dataframe is required and cannot be empty")
    }
    
    if (!"pid" %in% names(redcap)) {
      stop("REDCap data must contain 'pid' column")
    }
  }
  
  get_session_configuration <- function(session) {
    
    session <- as.character(session)
    
    # Session configuration lookup table
    session_configs <- list(
      "1" = list(
        session_number = "1",
        title_name = "",
        description = "Session 1 (baseline)"
      ),
      "2" = list(
        session_number = "2", 
        title_name = "Questionnaires",
        description = "Session 2 with questionnaires"
      ),
      "3" = list(
        session_number = "3",
        title_name = "Questionnaires", 
        description = "Session 3 with questionnaires"
      ),
      "scan" = list(
        session_number = "scan",
        title_name = "",
        description = "Scan session"
      )
    )
    
    config <- session_configs[[session]]
    
    if (!is.null(config)) {
      message("Processing ", config$description)
    }
    
    return(config)
  }
  
  get_participant_ids <- function(redcap) {
    
    participant_ids <- unique(redcap$pid)
    
    # Remove any NA values
    participant_ids <- participant_ids[!is.na(participant_ids)]
    
    message("Found ", length(participant_ids), " unique participants")
    
    return(participant_ids)
  }
  
  extract_session_data_for_participants <- function(participant_ids, qualtrics, session_config) {
    
    # Use vectorized approach instead of loop
    session_data <- participant_ids %>%
      purrr::map_dfr(~ {
        
        participant_data <- qualtrics %>%
          dplyr::filter(pid == .x)
        
        if (nrow(participant_data) == 0) {
          return(tibble::tibble())
        }
        
        # Call filter_session_by_progress with appropriate parameters
        filter_session_by_progress(
          ppt_df = participant_data,
          session_number = session_config$session_number,
          title_name = session_config$title_name
        )
      })
    
    return(session_data)
  }

  # Input validation
  validate_session_inputs(session, qualtrics, redcap)
  
  # Get session configuration
  session_config <- get_session_configuration(session)
  
  if (is.null(session_config)) {
    warning("Unsupported session type: ", session)
    return(tibble::tibble())
  }
  
  # Get unique participant IDs
  participant_ids <- get_participant_ids(redcap)
  
  if (length(participant_ids) == 0) {
    warning("No participant IDs found in REDCap data")
    return(tibble::tibble())
  }
  
  # Extract session data for all participants
  session_data <- extract_session_data_for_participants(
    participant_ids, qualtrics, session_config
  )
  
  message("Extracted session data for ", nrow(session_data), " participant records")
  
  return(session_data)
}

get_weekly_surveys = function(qualtrics, redcap) {
  validate_weekly_survey_inputs <- function(qualtrics, redcap) {
    
    if (missing(qualtrics) || nrow(qualtrics) == 0) {
      stop("Qualtrics dataframe is required and cannot be empty")
    }
    
    if (missing(redcap) || nrow(redcap) == 0) {
      stop("REDCap dataframe is required and cannot be empty")
    }
    
  }
  validate_weekly_survey_inputs(qualtrics, redcap)
  
  output = tibble()
  weekly_surveys = qualtrics %>%
    dplyr::filter(stringr::str_detect(title, "Weekly Survey")) %>%
    dplyr::mutate(date = as.Date(sm_recordeddate))
  
  for (ppt in unique(redcap$pid)){
    date = weekly_surveys %>% filter(pid==ppt) %>% pull(date)
    for (day in date) {
      day_df = weekly_surveys %>% 
        dplyr::filter(
          pid==ppt, 
          date==day,
          sm_progress==100,
          sm_recordeddate == min(sm_recordeddate))
      output = bind_rows(output, day_df)
    }
  }
  return(output)
}

load_base_survey_data <- function(data_path, scripts_directory = NULL, survey_forms = "survey_measures") {
  
  # Validate scripts directory
  if (is.null(scripts_directory)) {
    if (exists("scripts_directory", envir = .GlobalEnv)) {
      scripts_directory <- get("scripts_directory", envir = .GlobalEnv)
    } else {
      stop("scripts_directory must be provided or defined in global environment")
    }
  }
  
  # Load REDCap utilities
  redcap_script_path <- file.path(scripts_directory, "Utility Scripts", "geo_redcap.r")
  if (!file.exists(redcap_script_path)) {
    stop("REDCap utility script not found at: ", redcap_script_path)
  }
  
  message("Loading REDCap utility functions...")
  source(redcap_script_path)
  
  # Load data sources
  message("Loading REDCap data...")
  redcap <- load_redcap(data_path = data_path)
  
  message("Loading REDCap dictionary...")
  redcap_dict <- load_redcap_dictionary(data_path = data_path) %>%
    dplyr::filter(form %in% survey_forms)
  
  message("Loading and cleaning Qualtrics data...")
  qualtrics <- load_surveys(survey_name = "SurveyMeasures_GeoRemote", data_path = data_path) %>%
    clean_survey_measures()
  
  return(list(
    redcap = redcap,
    redcap_dict = redcap_dict,
    qualtrics = qualtrics
  ))
}

extract_all_sessions <- function(qualtrics, redcap, redcap_dict, convert_to_redcap = TRUE) {
  
  message("Extracting session data...")
  
  sessions <- list(
    session1 = get_session_df(session = "1", qualtrics, redcap),
    session2 = get_session_df(session = "2", qualtrics, redcap), 
    session3 = get_session_df(session = "3", qualtrics, redcap),
    scan = get_session_df(session = "scan", qualtrics, redcap)
  )
  
  if (convert_to_redcap) {
    message("Converting to REDCap format...")
    sessions <- purrr::map(sessions, ~ {
      if (nrow(.x) > 0) {
        convert_qualtrics_to_redcap(.x, redcap, redcap_dict)
      } else {
        .x
      }
    })
  }
  
  # Report session sizes
  session_counts <- purrr::map_int(sessions, nrow)
  message("Session record counts: ", paste(names(session_counts), session_counts, sep = "=", collapse = ", "))
  
  return(sessions)
}

# DATA CREATION ----

create_clean_survey_measures <- function(survey = "Survey Measures", 
                                         data_path = QUALTRICS_CONFIG$data_path,
                                         save_data = TRUE,
                                         scripts_directory = scripts_directory) {
  
  # Input validation (kept as nested function)
  validate_inputs <- function() {
    if (!is.character(survey) || length(survey) != 1) {
      stop("survey must be a single character string")
    }
    
    if (!survey %in% c("Survey Measures", "Weekly Surveys")) {
      stop("survey must be either 'Survey Measures' or 'Weekly Surveys'")
    }
    
    if (!dir.exists(data_path)) {
      stop("Data path does not exist: ", data_path)
    }
  }
  
  # Process survey measures data (updated to use shared utilities)
  process_survey_measures <- function() {
    
    # Save processed data
    save_survey_measures <- function(data) {
      if (!save_data) {
        message("Skipping data saving (save_data = FALSE)")
        return()
      }
      
      message("Saving Survey Measures...")
      save_qualtrics(
        df = data$survey_measures,
        name = "survey_measures",
        folder = "clean", 
        data_path = data_path
      )
      
      message("Saving fMRI Surveys...")
      save_qualtrics(
        df = data$scan_data,
        name = "fMRI",
        folder = "clean",
        data_path = data_path
      )
      
      message("Survey measures data saved successfully")
    }
    
    # Load data using shared utility
    base_data <- load_base_survey_data(data_path, scripts_directory, "survey_measures")
    
    # Extract sessions using shared utility  
    sessions <- extract_all_sessions(
      base_data$qualtrics, 
      base_data$redcap, 
      base_data$redcap_dict, 
      convert_to_redcap = TRUE
    )
    
    # Combine regular sessions
    survey_measures <- dplyr::bind_rows(
      sessions$session1, 
      sessions$session2, 
      sessions$session3
    ) %>%
      dplyr::select(dplyr::where(~ !all(is.na(.x))))  # Remove empty columns
    
    # Process scan data separately (doesn't include SLEI)
    scan_data <- sessions$scan %>%
      dplyr::select(dplyr::where(~ !all(is.na(.x)))) %>%  # Remove empty columns
      dplyr::select(-dplyr::contains("slei"))  # fMRI doesn't complete SLEI
    
    combined_data <- list(
      survey_measures = survey_measures,
      scan_data = scan_data
    )
    
    save_survey_measures(combined_data)
    
    message("Survey measures processing completed. Records: ", nrow(survey_measures))
    
    return(survey_measures)
  }
  
  # Process weekly surveys data (updated to use shared utilities for base data)
  process_weekly_surveys <- function() {
    
    # Save weekly survey data
    save_weekly_data <- function(data) {
      if (!save_data) {
        message("Skipping data saving (save_data = FALSE)")
        return()
      }
      
      message("Saving weekly surveys...")
      save_qualtrics(
        df = data,
        name = "weekly_surveys",
        folder = "clean",
        data_path = data_path
      )
      
      message("Weekly surveys data saved successfully")
    }
    
    # Load base data using shared utility (but need weekly forms)
    base_data <- load_base_survey_data(
      data_path, 
      scripts_directory, 
      c("survey_measures", "weekly_survey_questions_from_qualtrics")
    )
    
    weekly_surveys_dictionary <- base_data$redcap_dict %>% 
      dplyr::filter(form == "weekly_survey_questions_from_qualtrics")
    
    message("Processing weekly surveys...")
    weekly_data <- get_weekly_surveys(base_data$qualtrics, base_data$redcap) %>%
      dplyr::select(dplyr::where(~ !all(is.na(.x)))) %>%  # Remove empty columns
      convert_qualtrics_to_redcap(., base_data$redcap, weekly_surveys_dictionary)
    
    save_weekly_data(weekly_data)
    
    message("Weekly surveys processing completed. Records: ", nrow(weekly_data))
    
    return(weekly_data)
  }
  
  # Main execution flow
  tryCatch({
    validate_inputs()
    
    # Process based on survey type
    if (survey == "Survey Measures") {
      return(process_survey_measures())
    } else if (survey == "Weekly Surveys") {
      return(process_weekly_surveys()) 
    }
    
  }, error = function(e) {
    message("Error in create_clean_survey_measures: ", e$message)
    stop(e)
  })
}


upload_qualtrics_to_redcap <- function(session = "", 
                                       data_path = QUALTRICS_CONFIG$data_path,
                                       redcap_api_key = "",
                                       scripts_directory = scripts_directory,
                                       dry_run = FALSE) {
  # Handle API key
  if (redcap_api_key == "" && dry_run == FALSE) { # Only prompt if not dry run) 
    redcap_api_key <- .rs.askForPassword("Please enter your REDCap API token or 'dry' for a dry run")
    if (is.null(redcap_api_key) || api_key == "") stop("API token is required")
    if (redcap_api_key == "dry") {
      dry_run <- TRUE
      message("Running in dry run mode - no data will be uploaded")
    }
  }
  
  
  # Input validation
  validate_upload_inputs <- function() {
    if (!dir.exists(data_path)) {
      stop("Data path does not exist: ", data_path)
    }
    
    if (!dry_run && (is.null(redcap_api_key) || redcap_api_key == "")) {
      stop("redcap_api_key is required for actual uploads. Use dry_run = TRUE for testing.")
    }
    
    if (session != "" && !session %in% c("1", "2", "3", "scan")) {
      stop("session must be empty (all sessions) or one of: '1', '2', '3', 'scan'")
    }
  }
  
  # Upload a single session to REDCap
  upload_session_data <- function(session_data, 
                                  session_number, 
                                  redcap_data,
                                  repeat_instrument = "survey_measures") {
    
    # Upload individual participant data
    upload_participant_data <- function(participant_data, api_key) {
      if (dry_run) {
        message("  [DRY RUN] Would upload ", nrow(participant_data), " records")
        return(list(success = TRUE, dry_run = TRUE))
      }
      
      tryCatch({
        response <- redcap_write(
          ds_to_write = participant_data,
          redcap_uri = 'https://ascredcap.asc.upenn.edu/api/',
          token = api_key
        )
        return(response)
      }, error = function(e) {
        return(list(success = FALSE, error = e$message))
      })
    }
    
    if (nrow(session_data) == 0) {
      message("No data to upload for session ", session_number)
      return(list(session = session_number, uploads = 0, errors = 0))
    }
    
    message("Uploading session ", session_number, " data for ", 
            length(unique(session_data$pid)), " participants...")
    
    participants <- unique(session_data$pid)
    upload_results <- list()
    successful_uploads <- 0
    failed_uploads <- 0
    
    for (participant in participants) {
      tryCatch({
        participant_session_data <- session_data %>%
          dplyr::filter(pid == participant) %>%
          dplyr::mutate(
            rid = redcap_data %>% dplyr::filter(pid == participant) %>% dplyr::pull(rid),
            survey_measures_complete = "2",
            redcap_repeat_instance = session_number,
            redcap_repeat_instrument = repeat_instrument
          ) %>%
          dplyr::select(-pid)
        
        upload_result <- upload_participant_data(participant_session_data, redcap_api_key)
        
        if (isTRUE(upload_result$success) || isTRUE(upload_result$dry_run)) {
          successful_uploads <- successful_uploads + 1
        } else {
          failed_uploads <- failed_uploads + 1
          message("  Failed upload for participant ", participant, 
                  ": ", upload_result$error %||% "Unknown error")
        }
        
        upload_results[[participant]] <- upload_result
        
      }, error = function(e) {
        failed_uploads <<- failed_uploads + 1
        message("  Error processing participant ", participant, ": ", e$message)
        upload_results[[participant]] <<- list(success = FALSE, error = e$message)
      })
    }
    
    message("Session ", session_number, " upload completed: ", 
            successful_uploads, " successful, ", failed_uploads, " failed")
    
    return(list(
      session = session_number,
      uploads = successful_uploads,
      errors = failed_uploads,
      details = upload_results
    ))
  }
  
  # Process specific session or all sessions
  process_uploads <- function(sessions_data, redcap_data) {
    
    session_config <- list(
      "1" = list(data = sessions_data$session1, number = "1"),
      "2" = list(data = sessions_data$session2, number = "2"),
      "3" = list(data = sessions_data$session3, number = "3"),
      "scan" = list(data = sessions_data$scan, number = "scan")
    )
    
    if (session != "") {
      # Upload specific session
      if (!session %in% names(session_config)) {
        stop("Invalid session specified: ", session)
      }
      
      config <- session_config[[session]]
      result <- upload_session_data(config$data, config$number, redcap_data)
      return(list(result))
    } else {
      # Upload all sessions
      message("Uploading all sessions...")
      results <- purrr::map(session_config, ~ {
        upload_session_data(.x$data, .x$number, redcap_data)
      })
      return(results)
    }
  }
  
  # Main execution pipeline
  tryCatch({
    validate_upload_inputs()
    
    # Load all required data (using shared utilities where possible)
    base_data <- load_base_survey_data(data_path, scripts_directory, "survey_measures")
    
    # Extract and convert session data (using shared utility)
    sessions <- extract_all_sessions(
      base_data$qualtrics, 
      base_data$redcap, 
      base_data$redcap_dict, 
      convert_to_redcap = TRUE
    )
    
    # Process uploads
    upload_results <- process_uploads(sessions, base_data$redcap)
    
    # Summary reporting
    total_successful <- sum(purrr::map_int(upload_results, "uploads"))
    total_errors <- sum(purrr::map_int(upload_results, "errors"))
    
    message("\n=== UPLOAD SUMMARY ===")
    message("Total successful uploads: ", total_successful)
    message("Total failed uploads: ", total_errors)
    if (dry_run) message("*** DRY RUN - No actual uploads performed ***")
    
    return(upload_results)
    
  }, error = function(e) {
    message("Error in upload_qualtrics_to_redcap: ", e$message)
    stop(e)
  })
}

# SCORING FUNCTIONS ----
score_qualtrics_surveys <- function(survey_name = "Survey_Measures", 
                                    data_path = QUALTRICS_CONFIG$data_path) {
  
  # Process survey data with unified pipeline
  process_survey <- function(survey_type) {
    
    # Configuration for different survey types
    survey_config <- list(
      "Survey_Measures" = list(
        loader = load_qualtrics_survey_measures,
        output_file = "scored_Survey_Measures.csv"
      ),
      "fMRI" = list(
        loader = load_qualtrics_fmri_surveys,
        output_file = "scored_fMRI_Survey_Measures.csv"
      )
    )
    
    config <- survey_config[[survey_type]]
    if (is.null(config)) stop("Invalid survey_name: ", survey_type)
    
    # Setup directories and load data
    scored_dir <- file.path(data_path, "Qualtrics/scored_survey_measures")
    rubric_dir <- file.path(data_path, "scoring_rubrics")
    
    scoring_rubrics <- data.frame(
      file = dir(rubric_dir, pattern = '.*_scoring_rubric.*.csv', full.names = TRUE)
    )
    
    # Load and transform data
    df_long <- config$loader(data_path = data_path) %>%
      tidyr::pivot_longer(
        cols = -c(sm_startdate, sm_enddate, sm_progress, sm_duration, sm_finished,
                  sm_recordeddate, sm_responseid, sm_session, pid),
        names_to = "item",
        values_to = "value",
        values_transform = as.character
      ) %>%
      dplyr::mutate(survey_name = "Survey_Measures")
    
    # Score questionnaires
    scoring <- scorequaltrics::get_rubrics(scoring_rubrics, type = 'scoring')
    
    scored <- df_long %>%
      dplyr::group_by(sm_session) %>%
      dplyr::group_modify(~ scorequaltrics::score_questionnaire(.x, scoring, SID = "pid", psych = FALSE)) %>%
      dplyr::ungroup() %>%
      dplyr::rename(pid = SID) %>%
      dplyr::arrange(sm_session, scale_name, pid)
    
    # Save results
    readr::write_csv(scored, file.path(scored_dir, config$output_file))
    
    # Save individual scale files
    purrr::walk(unique(scored$scale_name), ~ {
      readr::write_csv(
        dplyr::filter(scored, scale_name == .x),
        file.path(scored_dir, paste0(.x, ".csv"))
      )
    })
    
    message("Scored ", survey_type, " surveys: ", length(unique(scored$scale_name)), " scales")
  }
  
  process_survey(survey_name)
}

load_scored_survey <- function(scale_name = "", 
                               type = "long", 
                               data_path = QUALTRICS_CONFIG$data_path) {
  
  survey_dir <- file.path(data_path, "Qualtrics/scored_survey_measures")
  
  # List available scales if none specified
  if (scale_name == "") {
    files <- list.files(survey_dir, pattern = "\\.csv$", full.names = TRUE)
    available_scales <- stringr::str_extract(basename(files), "^[^.]+")
    
    message("Available scales: ", paste(available_scales, collapse = ", "))
    return(available_scales)
  }
  
  # Load specified scale
  files <- list.files(survey_dir, pattern = paste0(scale_name, ".csv$"), full.names = TRUE)
  
  if (length(files) == 0) {
    stop("Scale not found: ", scale_name)
  }
  
  survey_df <- readr::read_csv(files[1], show_col_types = FALSE)
  
  # Convert to wide format if requested
  if (type == "wide") {
    survey_df <- survey_df %>%
      dplyr::select(pid, sm_session, survey_name, scale_name, scored_scale, score) %>%
      tidyr::pivot_wider(names_from = scored_scale, values_from = score)
  }
  
  return(survey_df)
}