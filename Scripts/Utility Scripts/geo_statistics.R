
# SETUP ----
library(pacman)
p_load(tidyverse,DiagrammeR, glue, patchwork, gt, clipr, cli)

statistics_config <- list(
  data_path = "/Volumes/cnlab/GeoRemote/Data/"
)

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

# PARTICIPANT LIST FUNCTIONS ----
build_participant_lists = function(save = FALSE, data_path = statistics_config$data_path) {
  directories = setup_directories()
  
  ## Load Redcap ----
  source(file.path(directories$scripts, "/Utility Scripts/geo_redcap.r"))
  redcap <- load_raw_redcap()
  names(redcap) <- sub("^data\\.", "", names(redcap))
  redcap = redcap %>%
    filter(is.na(redcap_repeat_instrument),
           #rid < 2129923, 
           !grepl(pattern="test", pid, ignore.case = TRUE)
    )
  
  ## Load EMA and get rates ----
  source(file.path(directories$scripts, "/Utility Scripts/geo_lifedata.r"))
  ema <- load_lifedata()
  get_ema_rates = function(df) {
    df_summary <- df %>%
      group_by(pid, Type) %>%
      summarise(percent_responded = mean(`Completed Session`) * 100)
  }
  ema_rates = get_ema_rates(ema)
  
  redcap <- redcap %>%
    left_join(
      ema_rates %>%
        pivot_wider(
          names_from = Type,
          values_from = percent_responded,
          names_glue = "{tolower(Type)}_ema_responded"
        ),
      by = "pid"
    )  
  
  
  flowchart_directory = file.path(data_path, "admin/flowchart")
  
  # Load in some data from study log - will need to be updated
  invited_to_call = file.path(flowchart_directory, "invited_to_call.csv") %>%
    read_csv()
  
  call_statuses = file.path(flowchart_directory, "call_outcome.csv") %>%
    read_csv() 
  
  screen_b_statuses = file.path(flowchart_directory, "screen_b_outcome.csv") %>%
    read_csv() 
  
  ## First let's get the call statistics 
  redcap_invited_to_call = redcap %>%
    filter(rid %in% invited_to_call$rid |
             pid != "" |
             intake_outcome %in% c(1,2,6) |
             call_status==2 |
             status > 3 & status != 10 |
             progress > 3) %>%
    distinct()
  
  ## People who were not invited to the call (ineligible from screen a)
  not_invited_to_call = redcap %>%
    anti_join(redcap_invited_to_call, by="rid")
  
  
  redcap_calls_missed = redcap_invited_to_call %>%
    filter(!status %in% c(-1,4,5.1,5.2,6,7.1,7.2,8,8.1,8.2,8.3,9,10),
           !progress %in% c(4,5,6,7,8,9,10),
           !intake_outcome %in% c(1),
           #intake_answer %in% c(NA, 0) | 
           status %in% c(NA,0,1,2,3) |
             progress %in% c(NA,0,1,2,3)) %>%
    distinct()
  
  redcap_call_complete = redcap_invited_to_call %>% 
    anti_join(redcap_calls_missed, by="rid") %>%
    distinct()
  
  # Now find people who were either ineligible from call and
  # who did not complete screen b
  not_started_screenb = redcap_call_complete %>%
    filter(screenb_icf_yesno %in% c(NA,2))
  
  ineligible_from_call = not_started_screenb %>%
    filter(rid %in% call_statuses[call_statuses$outcome=="Ineligible",]$rid |
             eligible != 1)
  not_interested_in_screenb = not_started_screenb %>%
    anti_join(ineligible_from_call)
  
  ## Now lets split screen b by completed, not completed, or ineligible
  started_sb = redcap_call_complete %>%
    anti_join(ineligible_from_call) %>%
    anti_join(not_interested_in_screenb)
  
  # Grab the people who definitely did not move past screen b
  did_not_move_on = started_sb %>%
    filter(seven_eleven_store %in% c(NA,0) |
             cvs_store %in% c(NA, 0) |
             is.na(vax_pic) |
             session_1_consent_complete %in% c(0),
           progress==6 & eligible !=1 |
             progress < 6 | is.na(progress),
           status < 5.2 | is.na(status)) 
  
  # From that group, get people who are ineligible
  ineligible_screenb = did_not_move_on %>%
    filter(eligible!=1 |
             cvs_store==0 |
             seven_eleven_store==0 |
             is.na(vax_pic) |
             screenb_tech_literacy %in% c(-1,0) |
             screenb_vaxcard %in% c(-1,0) |
             screenb_geodata %in% c(-1,0) |
             screenb_store_visits %in% c(-1,0) |
             status == -1,
           status != 2)
  # The people who did not move on and were not ineligible
  not_finished_screenb = did_not_move_on %>%
    anti_join(ineligible_screenb)
  
  # Grab the people who did move on
  sb_eligible = started_sb %>%
    anti_join(ineligible_screenb) %>%
    anti_join(not_finished_screenb)
  
  # Grab people who signed the consent form
  consent_complete = sb_eligible %>%
    filter(session_1_consent_complete==2)
  # Who did not sign the consent
  consent_incomplete = sb_eligible %>%
    anti_join(consent_complete)
  
  s1_complete = redcap %>%
    filter(rid %in% sb_eligible$rid,
           session_1_complete==2)
  
  s1_incomplete = consent_complete %>% 
    anti_join(s1_complete, by='rid')
  
  s1_excluded = consent_complete %>% filter(pid %in% c("GR072","GR200"))
  s1_ineligible = consent_complete %>% filter(pid %in% c("GR130","GR084"))
  s1_lost_contact = consent_complete %>% filter(pid %in% c("GR260","GR226","GR309"))
  s1_withdrew = consent_complete %>% filter(pid %in% c("GR196","GR285"))
  baseline = consent_complete %>% filter(!pid %in% s1_excluded$pid,
                                         !pid %in% s1_lost_contact$pid,
                                         !pid %in% s1_withdrew$pid,
                                         !pid %in% s1_ineligible$pid)
  
  consent_withdrawn = s1_incomplete %>%
    filter(status==8)
  consent_ineligible = s1_incomplete %>%
    filter(status %in% c(7.1, 7.2))
  baseline_low_response = baseline %>% filter(pid %in% c("GR032","GR051","GR054","GR187","GR198","GR206","GR216","GR224", "GR238","GR248","GR250","GR262","GR291"))
  baseline_lost_contact = baseline %>% filter(pid %in% c("GR095","GR153"))
  baseline_excluded = baseline %>% filter(pid %in% c("GR258","GR242","GR014","GR249"))
  
  
  s2_complete = redcap %>%
    filter(session_2_complete==2)
  baseline_ineligible = s1_complete %>%
    anti_join(s2_complete, by='rid') %>%
    filter(status %in% c(7.1, 7.2)) 
  baseline_withdrawn = s1_complete %>%
    anti_join(s2_complete, by='rid') %>%
    filter(status %in% c(8, 8.3))
  
  control = s2_complete %>%
    filter(cond==3)
  control_withdrawn = control %>%
    filter(pid %in% c("GR006"))
  
  control_excluded = control %>%
    filter(pid %in% c("GR094"))
  
  post = s2_complete %>%
    filter(cond==2)
  post_withdrawn = post %>%
    filter(pid %in% c("GR008","GR043", "GR172", "GR253"))
  post_excluded = post %>%
    filter(pid %in% c("GR014","GR087","GR098","GR249","GR264","GR305", "GR313"))
  
  no_post = s2_complete %>%
    filter(cond==1)
  no_post_excluded = no_post %>%
    filter(pid %in% c("GR005", "GR022", "GR023"))
  no_post_withdrawn = no_post %>%
    filter(pid %in% c("GR015", "GR142","GR194","GR203","GR273"))
  
  s3_eligible = s2_complete %>%
    filter(!pid %in% control_withdrawn$pid,
           !pid %in% control_excluded$pid,
           !pid %in% post_withdrawn$pid,
           !pid %in% post_excluded$pid,
           !pid %in% no_post_withdrawn$pid,
           !pid %in% no_post_excluded$pid)
  
  s3_lost = s3_eligible %>%
    filter(status=='8.3')
  s3_lost_post = post %>%
    filter(pid %in% c("GR045","GR240", "GR261", "GR272", "GR254", "GR307", "GR302", "GR296", "GR310"))
  s3_lost_no_post = no_post %>%
    filter(pid %in% c("GR001", "GR018", "GR049", "GR074", "GR160", "GR179", "GR243", "GR282"))
  s3_lost_control = control %>%
    filter(pid %in% c(""))
  s3_complete = s3_eligible %>%
    filter(status=='9')
  post_fmri = s3_complete %>%
    filter(cond==2,
           fmri_consent_complete==2)
  no_post_fmri = s3_complete %>%
    filter(cond==1,
           fmri_consent_complete==2)
  control_fmri = s3_complete %>%
    filter(cond==3,
           fmri_consent_complete==2)
  fmri_lost = s3_complete %>%
    filter(fmri_status %in% c(0,1,2,3.1,3.2,4,5,6,7,8,NA))
  fmri_ineligible = s3_complete %>%
    filter(fmri_status %in% c(-1))
  
  s2_lost_contact = NaN
  s2_excluded = NaN
  
  post_complete = s3_complete %>% filter(cond==2)
  no_post_complete = s3_complete %>% filter(cond==1)
  control_complete = s3_complete %>% filter(cond==3)
  
  ## New variables I added for the aim 1 flowchart
  
  folder_path <- "/Volumes/cnlab/GeoRemote/Data/Geodata/clean/baseline/"
  files <- list.files(folder_path, pattern = "_baseline_geodata\\.csv$", full.names = TRUE)
  file_sizes <- file.info(files)$size
  valid_files <- files[file_sizes > 1]
  participant_ids <- str_extract(basename(valid_files), "^GR\\d+")
  participant_ids <- unique(participant_ids)
  
  s1_excluded = consent_complete %>% filter(pid %in% c("GR072","GR200"))
  s1_ineligible = consent_complete %>% filter(pid %in% c("GR130","GR084"))
  s1_lost_contact = consent_complete %>% filter(pid %in% c("GR260","GR226","GR309"))
  s1_withdrew = consent_complete %>% filter(pid %in% c("GR196","GR285"))
  baseline = consent_complete %>% filter(!pid %in% s1_excluded$pid,
                                         !pid %in% s1_lost_contact$pid,
                                         !pid %in% s1_withdrew$pid,
                                         !pid %in% s1_ineligible$pid)
  
  baseline_low_response = baseline %>% filter(pid %in% c("GR032","GR051","GR054","GR187","GR198","GR206","GR216","GR224", "GR238","GR248","GR250","GR262","GR291"))
  baseline_lost_contact = baseline %>% filter(pid %in% c("GR095","GR153"))
  baseline_excluded = baseline %>% filter(pid %in% c("GR258","GR242","GR014","GR249"))
  
  baseline_no_geodata = baseline %>% filter(pid %in% c("GR202","GR022","GR039","GR098"))
  baseline_semantic_history = baseline %>% filter(pid %in% c("GR056","GR068","GR073","GR115"))
  s2_excluded = baseline %>% filter(pid %in% c("GR014","GR249"))
  baseline_withdrew = baseline %>% filter(pid %in% c("GR043"))
  
  baseline_complete = baseline %>% filter(!pid %in% baseline_low_response$pid,
                                          !pid %in% baseline_lost_contact$pid,
                                          !pid %in% baseline_no_geodata$pid,
                                          !pid %in% baseline_semantic_history$pid,
                                          !pid %in% baseline_excluded$pid,
                                          !pid %in% baseline_withdrew$pid,
                                          !pid %in% s2_excluded$pid)
  
  
  
  randomized = rbind(baseline_complete, baseline_withdrew, s2_excluded, baseline_semantic_history, baseline_no_geodata) %>%
    filter(!pid %in% c("GR312", "GR316"))
  randomized_total = nrow(randomized)
  
  post_store_visits = post %>% filter(num_receipts >= 20)
  no_post_store_visits = no_post %>% filter(num_receipts >= 20)
  participant_list = list(
    "consent_complete" = consent_complete,
    "baseline" = baseline,
    "baseline_complete" = s2_complete,
    "baseline_excluded" = baseline_excluded,
    "baseline_ineligible" = baseline_ineligible,
    "baseline_lost_contact" = baseline_lost_contact,
    "baseline_low_response" = baseline_low_response,
    "baseline_no_geodata" = baseline_no_geodata,
    "baseline_semantic_history" = baseline_semantic_history,
    "baseline_withdrew" = baseline_withdrew,
    "s2_complete" = baseline_complete,
    "randomized" = randomized,
    "control" = control,
    "control_complete" = control_complete,
    "control_excluded" = control_excluded,
    "control_withdrawn" = control_withdrawn,
    "control_fmri" = control_fmri,
    "post" = post,
    "post_complete" = post_complete,
    "post_excluded" = post_excluded,
    "post_withdrawn" = post_withdrawn,
    "post_fmri" = post_fmri,
    "post_store_visits" = post_store_visits,
    "no_post" = no_post,
    "no_post_complete" = no_post_complete,
    "no_post_excluded" = no_post_excluded,
    "no_post_withdrawn" = no_post_withdrawn,
    "no_post_fmri" = no_post_fmri,
    "no_post_store_visits" = no_post_store_visits,
    "s3_complete" = s3_complete
  )
  if (save) {
    saveRDS(participant_list, file.path(flowchart_directory, "participant_list.rds"))
  }
  return(participant_list)
}

load_participant_lists = function(data_path = statistics_config$data_path) {
  flowchart_directory = file.path(data_path, "admin/flowchart")
  
  participant_list = readRDS(file.path(flowchart_directory, "participant_list.rds"))
  return(participant_list)
}

# SUMMARY TABLE FUNCTIONS ----
create_summary_demo_table <- function(df_list) {
  # df_list: a named list of dataframes.
  # Example: list("Completed S1" = df1, "Group B" = df2, "Completed S2" = df3)
  
  
  ## When updating, update both summary numbers and rows (the list below)
  get_summary_numbers <- function(df) {
    df %>%
      summarise(
        Age = round(mean(as.numeric(age), na.rm = TRUE), 1),
        Male = round(mean(gender == "1", na.rm = TRUE) * 100, 1),
        Female = round(mean(gender == "2", na.rm = TRUE) * 100, 1),
        Other = round(mean(!gender %in% c("1","2"), na.rm = TRUE) * 100, 1),
        
        # Race (%)
        `American Indian/Alaska Native` = round(mean(race___4, na.rm = TRUE) * 100, 1), 
        `Asian`                         = round(mean(race___1, na.rm = TRUE) * 100, 1), 
        `Black`                         = round(mean(race___2, na.rm = TRUE) * 100, 1), 
        `Pacific Islander/Hawaiian`      = round(mean(race___3, na.rm = TRUE) * 100, 1), 
        `White`                          = round(mean(race___5, na.rm = TRUE) * 100, 1), 
        `Self-Describe`                  = round(mean(race___6, na.rm = TRUE) * 100, 1), 
        `Prefer Not to Say`              = round(mean(race___7, na.rm = TRUE) * 100, 1), 
        
        # Baseline Cigs/Day
        `Cigarettes Per Day` = round(mean(as.numeric(cigs_day_s1), na.rm = TRUE), 1),
        
      )
  }
  
  # Define the structure for the rows:
  # 'name' is what will appear in the "Variable" column.
  # 'var' is the name of the variable in the summary (if NA, this row is a category header).
  rows <- list(
    list(name = "Age", var = "Age"),
    list(name = "Gender", var = NA),
    list(name = "   - Male", var = "Male"),
    list(name = "   - Female", var = "Female"),
    list(name = "   - Other", var = "Other"),
    list(name = "Race", var = NA),
    list(name = "   - American Indian/Alaska Native", var = "American Indian/Alaska Native"),
    list(name = "   - Asian", var = "Asian"),
    list(name = "   - Black", var = "Black"),
    list(name = "   - Pacific Islander/Hawaiian", var = "Pacific Islander/Hawaiian"),
    list(name = "   - White", var = "White"),
    list(name = "   - Self-Describe", var = "Self-Describe"),
    list(name = "   - Prefer Not to Say", var = "Prefer Not to Say"),
    list(name = "Cigarettes Per Day", var = "Cigarettes Per Day")
  )
  
  
  # Compute summaries and sample sizes for each dataframe in the list.
  summaries <- lapply(df_list, function(df) {
    list(summary = get_summary_numbers(df), n = nrow(df))
  })
  
  
  # Build the result tibble with the first column as the row labels.
  result <- tibble(Variable = sapply(rows, function(x) x$name))
  
  # Loop over each dataframe summary in the list to add a new column.
  for(name in names(summaries)) {
    sum_val <- summaries[[name]]$summary
    n_val <- summaries[[name]]$n
    
    # For each defined row, extract the computed value if available;
    # if this row is just a category header (var is NA), return an empty string.
    col_values <- sapply(rows, function(x) {
      if(is.na(x$var)) {
        ""
      } else {
        # Ensure the variable exists in the summary
        if(x$var %in% names(sum_val)) {
          as.character(sum_val[[x$var]])
        } else {
          ""
        }
      }
    })
    
    # Create a dynamic column name that includes the sample size.
    col_name <- paste0(name, " (n=", n_val, ")")
    result[[col_name]] <- col_values
  }
  
  final_table <- result %>%
    gt() %>%
    tab_header(title = "Demographic Summary")
  
  print(final_table)
  
  summary_df <- as.data.frame(result)
  write_clip(summary_df, object_type = "table")
  
  return(summary_df)
}

get_summary_demo_table <- function(groupings, 
                                   new_names = NULL,
                                   data_path = statistics_config$data_path) {
  
  df = load_participant_lists(data_path)
  
  if (!is.null(new_names)) {
    selected_groups <- setNames(df[groupings], new_names)
  } else {
    selected_groups <- df[groupings] 
  }
  
  return(create_summary_demo_table(selected_groups))
}

get_summary_demo_table_whole_study <- function(groupings = c("baseline", "baseline_complete", 
                                                             "s2_complete", "s3_complete", 
                                                             "baseline_low_response"), 
                                               new_names = c(
                                                 "Completed S1", "Completed S2", 
                                                 "Completed Baseline", "Completed S3", 
                                                 "Low EMA"
                                               ),
                                               data_path = statistics_config$data_path) {
  return(get_summary_demo_table(groupings, new_names, data_path))
}

get_summary_demo_table_intervention_by_condition <- function(groupings = c("post", "post_complete", "post_store_visits", 
                                                                           "no_post", "no_post_complete", "no_post_store_visits",
                                                                           "control","control_complete"), 
                                                             new_names = c(
                                                               "7/11 Started", "7/11 S3", "7/11 20 visits",
                                                               "CVS Started", "CVS S3", "CVS 20 visits",
                                                               "Control Started", "Control S3"),
                                                             data_path = statistics_config$data_path) {
  return(get_summary_demo_table(groupings, new_names, data_path))
}




# EMA TABLE FUNCTIONS ----
create_summary_ema_table <- function(df_list, ema_columns = c("baseline_ema_responded", "intervention_ema_responded")) {
  
  # Function to compute EMA response rate summary for each dataframe
  get_ema_summary <- function(df) {
    
    # Detect if this is wide format (has separate ema rate columns) or long format
    if (any(ema_columns %in% names(df))) {
      # Wide format - handle each EMA column separately
      summary_list <- list()
      
      for (col in ema_columns) {
        if (col %in% names(df)) {
          col_name <- gsub("_ema_responded", "", col)  # baseline_ema_responded -> baseline
          summary_list[[paste0(col_name, "_ema_responded")]] <- paste0(
            round(mean(as.numeric(df[[col]]), na.rm = TRUE), 1), 
            " (", 
            round(sd(as.numeric(df[[col]]), na.rm = TRUE), 1), 
            ")"
          )
        }
      }
      
      return(as_tibble(summary_list))
      
    } else if ("percent_responded" %in% names(df)) {
      # Long format - original behavior
      df %>%
        summarise(
          ema_rate = paste0(round(mean(as.numeric(percent_responded), na.rm = TRUE), 1), " (", round(sd(as.numeric(percent_responded), na.rm = TRUE), 1), ")"),
        )
    } else {
      stop("DataFrame must have either 'percent_responded' column (long format) or EMA rate columns (wide format)")
    }
  }
  
  # Function to get sample sizes excluding NA values
  get_sample_sizes <- function(df) {
    if (any(ema_columns %in% names(df))) {
      # Wide format - count non-NA for each column separately
      sizes <- list()
      for (col in ema_columns) {
        if (col %in% names(df)) {
          col_name <- gsub("_ema_responded", "", col)
          sizes[[paste0(col_name, "_ema_responded")]] <- sum(!is.na(df[[col]]))
        }
      }
      return(sizes)
    } else if ("percent_responded" %in% names(df)) {
      # Long format - count non-NA percent_responded
      return(list(ema_rate = sum(!is.na(df$percent_responded))))
    } else {
      return(list())
    }
  }
  
  # Compute summaries and sample sizes for each dataframe in the list
  summaries <- lapply(df_list, function(df) {
    list(summary = get_ema_summary(df), sample_sizes = get_sample_sizes(df))
  })
  
  # Detect what type of data we're working with based on first dataframe
  first_df <- df_list[[1]]
  if (any(ema_columns %in% names(first_df))) {
    # Wide format - create rows for each EMA column
    rows <- list()
    for (col in ema_columns) {
      if (col %in% names(first_df)) {
        col_name <- gsub("_ema_responded", "", col)  # FIXED: was "_ema_rate"
        rows[[length(rows) + 1]] <- list(
          name = paste(stringr::str_to_title(col_name), "EMA Response Rate"), 
          var = paste0(col_name, "_ema_responded")  # FIXED: was "_ema_rate"
        )
      }
    }
  } else {
    # Long format - original behavior
    rows <- list(
      list(name = "EMA Response Rate", var = "ema_rate")
    )
  }
  
  # Build the result tibble with the first column as the row labels
  result <- tibble(Variable = sapply(rows, function(x) x$name))
  
  # Loop over each dataframe summary in the list to add a new column
  for(name in names(summaries)) {
    sum_val <- summaries[[name]]$summary
    size_val <- summaries[[name]]$sample_sizes
    
    # For each defined row, extract the computed value and corresponding sample size
    col_values <- sapply(rows, function(x) {
      if(is.na(x$var)) {
        ""
      } else {
        # Ensure the variable exists in the summary
        if(x$var %in% names(sum_val)) {
          as.character(sum_val[[x$var]])
        } else {
          ""
        }
      }
    })
    
    # Get sample sizes for each row
    col_sizes <- sapply(rows, function(x) {
      if(is.na(x$var)) {
        0
      } else {
        if(x$var %in% names(size_val)) {
          size_val[[x$var]]
        } else {
          0
        }
      }
    })
    
    # Create result column with sample sizes
    result_col <- character(length(col_values))
    
    for(i in seq_along(col_values)) {
      if(col_values[i] != "" && col_values[i] != "NaN (NaN)") {
        result_col[i] <- paste0(col_values[i], " (n=", col_sizes[i], ")")
      } else {
        result_col[i] <- ""
      }
    }
    
    result[[name]] <- result_col
  }
  
  # Create the GT table
  final_table <- result %>%
    gt() %>%
    tab_header(title = "EMA Summary")
  
  print(final_table)
  
  # Copy to clipboard
  summary_df <- as.data.frame(result)
  write_clip(summary_df, object_type = "table")
  
  return(summary_df)
}

get_summary_ema_table <- function(groupings, new_names, data_path = statistics_config$data_path) {
  df = load_participant_lists(data_path)
  
  if (!is.null(new_names)) {
    selected_groups <- setNames(df[groupings], new_names)
  } else {
    selected_groups <- df[groupings] 
  }
  
  return(create_summary_ema_table(selected_groups))
}

get_summary_ema_table_whole_study <- function(groupings = c("baseline", "s2_complete", 
                                                            "post", "no_post", "control",
                                                            "baseline_low_response"), 
                                              new_names = c(
                                                "Full Baseline Sample", "Full Intervention Sample", 
                                                "7-11 Condition", "CVS Condition", "Control Condition",
                                                "Baseline Low EMA"),
                                              data_path = statistics_config$data_path) {
  return(get_summary_ema_table(groupings, new_names, data_path))
}

# RANDOM STATISTICS ----
check_receipt_numbers = function(data_path = statistics_config$data_path) {
  directories = setup_directories()
  
  ## Load Redcap ----
  source(file.path(directories$scripts, "/Utility Scripts/geo_redcap.r"))
  redcap = load_redcap() 
  redcap_receipts = redcap %>%
    dplyr::filter(!is.na(num_receipts), num_receipts > 0) %>%
    dplyr::select(pid,num_receipts)
  
  ## Load receipt counts ----
  receipt_counts = file.path(data_path, "Receipts","receipt_coding_counts.csv") %>%
    read_csv()
  
  ## Check all participants are coded ----
  ### Missing participants?
  only_in_redcap <- redcap_receipts %>% 
    distinct(pid) %>% 
    anti_join(receipt_counts %>% distinct(pid), by = "pid") %>% 
    pull(pid)
  
  only_in_receipt_counts <- receipt_counts %>% 
    distinct(pid) %>% 
    anti_join(redcap_receipts %>% distinct(pid), by = "pid") %>% 
    pull(pid)
  
  ### Pad shorter vector with empty strings
  max_length <- max(length(only_in_redcap), length(only_in_receipt_counts))
  
  if(length(only_in_redcap) < max_length) {
    only_in_redcap <- c(only_in_redcap, rep("", max_length - length(only_in_redcap)))
  }
  
  if(length(only_in_receipt_counts) < max_length) {
    only_in_receipt_counts <- c(only_in_receipt_counts, rep("", max_length - length(only_in_receipt_counts)))
  }
  
  ### Create table
  table_data <- data.frame(
    col1 = only_in_redcap,
    col2 = only_in_receipt_counts,
    stringsAsFactors = FALSE
  )
  
  names(table_data) <- c(paste("Only in redcap"), paste("Only in receipt coding"))
  
  ### Print table with cli
  cli_text("{.strong Differences:}")
  print(table_data, row.names = FALSE)

  print(redcap_receipts %>% filter(pid %in% only_in_redcap))
  
 ### pids without coded receipts: GR061, GR070, GR114, GR179, GR197, GR192                       
 ### GR251, GR286, GR279. GR302
  
  ## Check receipt counts ----
  receipt_counts = receipt_counts %>%
    dplyr::mutate(total_receipts = dated_receipts + undated_receipts)
  
  joined_receipts <- receipt_counts %>%
    left_join(redcap_receipts, by = "pid") %>%
    mutate(receipt_difference = total_receipts - num_receipts)
}






