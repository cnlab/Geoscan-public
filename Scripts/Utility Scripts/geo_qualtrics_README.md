# Qualtrics Data Processing R Script Documentation

## Introduction

This R script provides a comprehensive toolkit for downloading, loading, cleaning, processing, and scoring Qualtrics survey data. It is specifically designed for the GeoRemote study but can be adapted for other Qualtrics-based research projects. The script handles multiple survey types across different research sessions and provides seamless integration with REDCap databases.

**Key Features:**
- Download raw survey data directly from Qualtrics API
- Load and clean survey data with automatic column standardization
- Process data across multiple research sessions (baseline, follow-up, scan sessions)
- Convert Qualtrics data format to REDCap-compatible format
- Score psychological questionnaires and behavioral measures
- Handle weekly survey data collection

## Expected File Structure

```
/Volumes/cnlab/GeoRemote/
├── Data/
│   ├── Qualtrics/
│   │   ├── raw/                           # Raw downloaded survey files
│   │   ├── clean/                         # Processed clean survey files  
│   │   ├── scored_survey_measures/        # Scored questionnaire files
│   │   └── archive/                       # Archived old files
│   ├── scoring_rubrics/                   # Questionnaire scoring rubrics
│   └── REDCap/                           # REDCap data files
└── Scripts/
    ├── Utility Scripts/
    │   ├── geo_qualtrics.r               # This script
    │   └── geo_redcap.r                  # REDCap utilities
    └── ...
```

## Quick Start Examples

### Loading Different Survey Types

```r
# Source the script
source("geo_qualtrics.r")

# Load clean survey measures data
survey_data <- load_qualtrics_survey_measures(type = "clean")

# Load raw weekly survey data  
weekly_data <- load_qualtrics_weekly_surveys(type = "raw")

# Load fMRI session survey data
fmri_data <- load_qualtrics_fmri_surveys(type = "clean")
```

### Downloading and Creating Clean Survey Files

```r
# Download all surveys and save to disk
download_raw_qualtrics_surveys(surveys = "all", save = TRUE)

# Create clean survey measures file
clean_survey_data <- create_clean_survey_measures(
  survey = "Survey Measures", 
  save_data = TRUE
)

# Create clean weekly surveys file
clean_weekly_data <- create_clean_survey_measures(
  survey = "Weekly Surveys",
  save_data = TRUE
)
```

### Loading and Processing Scored Surveys

```r
# Score survey measures  
score_qualtrics_surveys(survey_name = "Survey_Measures")

# Load a specific scored questionnaire
panas_scores <- load_scored_survey(scale_name = "PANAS", type = "wide")

# See all available scored scales
available_scales <- load_scored_survey()
```

---

## Function Documentation

### Data Loading Functions

#### `download_raw_qualtrics_surveys()`

Downloads raw survey data directly from Qualtrics using the API.

**Arguments:**
- `surveys` (character): Survey names to download. Use `""` to see available surveys, `"all"` for all surveys, or specify survey names
- `save` (logical): Whether to save downloaded data to disk (default: `FALSE`)  
- `save_qualtrics_credentials` (logical): Whether to overwrite existing API credentials (default: `FALSE`)
- `data_path` (character): Path where data should be saved (default: from config)
- `base_url` (character): Qualtrics base URL (default: from config)
- `QUALTRICS_SURVEY_IDS` (list): Named list of survey IDs (default: from config)

**Returns:**
- Single data frame if one survey requested
- Named list of data frames if multiple surveys requested  
- List of available survey IDs if `surveys = ""`

**Usage Context:**
Use this function to download the latest survey responses from Qualtrics. Requires API credentials. First-time users will be prompted for their API token.

**Example:**
```r
# See available surveys
download_raw_qualtrics_surveys(surveys = "")

# Download specific survey
cotinine_data <- download_raw_qualtrics_surveys(
  surveys = "Cotinine_GeoRemote", 
  save = TRUE
)
```

---

#### `load_surveys()`

Loads previously saved survey data from local files.

**Arguments:**
- `survey_name` (character): Name of survey to load. Use `""` to see available surveys, `"all"` for all surveys
- `type` (character): Type of survey data - `"raw"` or `"clean"` (default: `"raw"`)
- `data_path` (character): Path to data directory (default: from config)

**Returns:**
- Single data frame if one survey requested
- Named list of data frames if multiple surveys requested

**Usage Context:**
Primary function for loading survey data that has been previously downloaded and saved. Supports partial name matching and provides helpful error messages with suggestions.

**Example:**
```r
# Load specific clean survey
survey_data <- load_surveys(
  survey_name = "SurveyMeasures_GeoRemote", 
  type = "clean"
)

# Load all raw surveys
all_surveys <- load_surveys(survey_name = "all", type = "raw")
```

---

#### `load_qualtrics_survey_measures()`, `load_qualtrics_weekly_surveys()`, `load_qualtrics_fmri_surveys()`

Convenience functions for loading specific survey types.

**Arguments:**
- `type` (character): `"clean"` or `"raw"` (default: `"clean"`)
- `data_path` (character): Path to data directory (default: from config)

**Returns:**
- Data frame containing the requested survey data

**Usage Context:**
These are wrapper functions that simplify loading common survey types. They call `load_surveys()` with predefined survey name patterns.

**Example:**
```r
# Load clean survey measures
measures <- load_qualtrics_survey_measures(type = "clean")

# Load raw weekly surveys
weekly <- load_qualtrics_weekly_surveys(type = "raw")
```

---

### Data Processing Functions

#### `clean_survey_measures()`

Comprehensive cleaning function for survey measures data.

**Arguments:**
- `df` (data frame): Raw survey measures data frame

**Returns:**
- Cleaned data frame with standardized column names and processed responses

**Usage Context:**
This function handles the complex task of cleaning and standardizing raw Qualtrics survey data. It renames columns, handles different survey versions, removes test responses, and standardizes data formats.

**Key Processing Steps:**
- Removes empty rows/columns and test participants
- Standardizes column names (converts to lowercase)
- Handles survey version differences (old vs new question formats)
- Extracts participant IDs using regex patterns
- Adds timezone information to datetime columns
- Combines responses from different survey versions

**Example:**
```r
raw_data <- load_surveys(survey_name = "SurveyMeasures", type = "raw")
clean_data <- clean_survey_measures(raw_data)
```

---

#### `filter_session_by_progress()`

Filters participant data to select the best session based on completion progress.

**Arguments:**
- `ppt_df` (data frame): Participant survey data
- `session_number` (character): Session number to filter for (default: `""`)
- `title_name` (character): Title pattern to match (default: `""`)

**Returns:**
- Data frame with single best session record for the participant

**Usage Context:**
Participants may have multiple incomplete sessions. This function intelligently selects the best session based on completion percentage and handles special cases like Session 2 excluded/unexcluded logic.

**Selection Logic:**
1. For Session 2: Prioritizes unexcluded over excluded sessions
2. For other sessions: Selects completed sessions (Progress = 100%) first
3. If no completed sessions: Selects highest progress session
4. For ties: Selects earliest recorded session

**Example:**
```r
# Get best Session 2 record for a participant
participant_data <- survey_data %>% filter(pid == "GR001")
best_session2 <- filter_session_by_progress(
  participant_data, 
  session_number = "2", 
  title_name = "Questionnaires"
)
```

---

#### `convert_qualtrics_to_redcap()`

Converts Qualtrics data format to REDCap-compatible format.

**Arguments:**
- `qualtrics` (data frame): Qualtrics survey data
- `redcap` (data frame): REDCap participant data  
- `redcap_dictionary` (data frame): REDCap data dictionary

**Returns:**
- Data frame formatted for REDCap import

**Usage Context:**
Bridges the gap between Qualtrics and REDCap data systems. Converts response formats, handles checkbox questions, and applies appropriate data transformations based on the REDCap dictionary.

**Key Conversions:**
- Maps categorical responses using REDCap choice labels
- Converts checkbox responses to 1/0 format
- Filters columns to include only REDCap-relevant fields
- Standardizes text formatting and removes display logic columns

**Example:**
```r
# Convert survey data for REDCap import
redcap_format <- convert_qualtrics_to_redcap(
  qualtrics = clean_survey_data,
  redcap = redcap_data,
  redcap_dictionary = redcap_dict
)
```

---

#### `get_session_df()`

Extracts session-specific data for all participants.

**Arguments:**
- `session` (character): Session identifier (`"1"`, `"2"`, `"3"`, or `"scan"`)
- `qualtrics` (data frame): Complete Qualtrics survey data
- `redcap` (data frame): REDCap participant data

**Returns:**
- Data frame containing session data for all participants

**Usage Context:**
Processes multi-session study data by extracting the appropriate session records for each participant. Handles session-specific filtering criteria and applies the best-session selection logic.

**Session Configurations:**
- Session 1: Baseline session
- Session 2: Follow-up with questionnaires (handles excluded/unexcluded logic)
- Session 3: Final follow-up with questionnaires  
- Scan: fMRI session data

**Example:**
```r
# Get Session 1 data for all participants
session1_data <- get_session_df(
  session = "1", 
  qualtrics = survey_data, 
  redcap = redcap_data
)
```

---

#### `get_weekly_surveys()`

Extracts weekly survey data with date-based deduplication.

**Arguments:**
- `qualtrics` (data frame): Complete Qualtrics survey data
- `redcap` (data frame): REDCap participant data

**Returns:**
- Data frame containing deduplicated weekly survey responses

**Usage Context:**
Weekly surveys may have multiple responses per day. This function ensures only one complete response per participant per day is retained, prioritizing completed surveys and earliest submission times.

**Example:**
```r
weekly_data <- get_weekly_surveys(
  qualtrics = complete_survey_data,
  redcap = redcap_data
)
```

---

### Data Creation Functions

#### `create_clean_survey_measures()`

High-level function to create clean, processed survey datasets.

**Arguments:**
- `survey` (character): Type of survey - `"Survey Measures"` or `"Weekly Surveys"` (default: `"Survey Measures"`)
- `data_path` (character): Path to data directory (default: from config)
- `save_data` (logical): Whether to save processed data (default: `TRUE`)
- `scripts_directory` (character): Path to scripts directory

**Returns:**
- Processed data frame

**Usage Context:**
This is the main workflow function for creating analysis-ready datasets. It orchestrates the entire pipeline from loading raw data through cleaning, processing, and saving final datasets.

**Processing Pipeline:**
1. Loads REDCap data and dictionary
2. Loads and cleans Qualtrics data
3. Extracts session-specific data
4. Converts to REDCap format
5. Combines sessions appropriately
6. Saves clean datasets

**Example:**
```r
# Create clean survey measures dataset
clean_measures <- create_clean_survey_measures(
  survey = "Survey Measures",
  save_data = TRUE
)

# Create clean weekly surveys dataset  
clean_weekly <- create_clean_survey_measures(
  survey = "Weekly Surveys",
  save_data = TRUE
)
```

---

#### `upload_qualtrics_to_redcap()`

Uploads processed Qualtrics data directly to REDCap database.

**Arguments:**
- `session` (character): Specific session to upload (`"1"`, `"2"`, `"3"`, `"scan"`) or `""` for all sessions
- `data_path` (character): Path to data directory (default: from config)
- `redcap_api_key` (character): REDCap API token (will prompt if empty)
- `scripts_directory` (character): Path to scripts directory
- `dry_run` (logical): If `TRUE`, performs validation without uploading (default: `FALSE`)

**Returns:**
- List containing upload results and summary statistics

**Usage Context:**
Automates the process of uploading survey data to REDCap. Handles participant matching, repeat instrument configuration, and provides detailed upload reporting. Includes dry-run capability for testing.

**Example:**
```r
# Upload all sessions (dry run first)
results <- upload_qualtrics_to_redcap(dry_run = TRUE)

# Upload specific session
results <- upload_qualtrics_to_redcap(
  session = "2", 
  redcap_api_key = "your_api_key"
)
```

---

### Scoring Functions

#### `score_qualtrics_surveys()`

Scores psychological questionnaires and behavioral measures using predefined rubrics.

**Arguments:**
- `survey_name` (character): Type of survey to score - `"Survey_Measures"` or `"fMRI"` (default: `"Survey_Measures"`)
- `data_path` (character): Path to data directory (default: from config)

**Returns:**
- None (saves scored data to files)

**Usage Context:**
Applies standardized scoring rubrics to survey responses. Transforms data to long format, applies questionnaire-specific scoring rules, and saves both comprehensive and individual scale files.

**Output Files:**
- `scored_Survey_Measures.csv`: Complete scored dataset
- Individual scale files (e.g., `PANAS.csv`, `BIS11.csv`)

**Example:**
```r
# Score survey measures
score_qualtrics_surveys(survey_name = "Survey_Measures")

# Score fMRI survey measures
score_qualtrics_surveys(survey_name = "fMRI")
```

---

#### `load_scored_survey()`

Loads previously scored questionnaire data.

**Arguments:**
- `scale_name` (character): Name of specific scale to load, or `""` to see available scales
- `type` (character): Format of returned data - `"long"` or `"wide"` (default: `"long"`)
- `data_path` (character): Path to data directory (default: from config)

**Returns:**
- Data frame with scored questionnaire data
- Character vector of available scales if `scale_name = ""`

**Usage Context:**
Loads scored questionnaire data for analysis. Can return data in long format (one row per subscale per participant) or wide format (one row per participant with subscales as columns).

**Example:**
```r
# See available scored scales
available_scales <- load_scored_survey()

# Load specific scale in wide format
panas_scores <- load_scored_survey(
  scale_name = "PANAS", 
  type = "wide"
)
```

---

### Utility Functions

#### `save_qualtrics()`

Saves Qualtrics data with automatic file archiving and date stamping.

**Arguments:**
- `df` (data frame): Data frame to save
- `name` (character): Base name for the file
- `folder` (character): Subdirectory within Qualtrics folder (`"raw"`, `"clean"`, etc.)
- `data_path` (character): Path to data directory (default: from config)

**Returns:**
- The input data frame (for chaining)

**Usage Context:**
Standard function for saving Qualtrics data with consistent naming conventions. Automatically archives old files with the same name and adds current date stamps.

**File Naming Convention:**
`qualtrics_{name}_{YYYY-MM-DD}.csv`

**Example:**
```r
# Save cleaned survey data
clean_data %>%
  save_qualtrics(
    name = "survey_measures", 
    folder = "clean"
  )
```

---

## Configuration

The script uses a configuration list (`QUALTRICS_CONFIG`) that contains:

- `uri`: Qualtrics base URL
- `data_path`: Base path for data storage
- `pid_pattern`: Regular expression for participant ID validation
- `survey_ids`: Named list mapping survey names to Qualtrics survey IDs

**Modifying Configuration:**
```r
# Update data path
QUALTRICS_CONFIG$data_path <- "/new/path/to/data/"

# Add new survey
QUALTRICS_CONFIG$survey_ids$NewSurvey <- "SV_newsurveyid123"
```

## Dependencies

The script requires these R packages:
- `tidyverse`: Data manipulation and visualization
- `data.table`: Fast data processing  
- `qualtRics`: Qualtrics API interface
- `scorequaltrics`: Questionnaire scoring (custom package)

Install dependencies:
```r
install.packages(c("tidyverse", "data.table", "qualtRics"))
# Install scorequaltrics from your local source
```

## Error Handling and Troubleshooting

**Common Issues:**

1. **API Authentication**: Ensure your Qualtrics API token is valid and has appropriate permissions
2. **File Paths**: Check that data directories exist and are accessible
3. **Survey IDs**: Verify survey IDs in configuration match your Qualtrics surveys
4. **Participant IDs**: Ensure participant IDs follow the expected pattern (GR###)
5. **Missing Data**: Functions handle missing data gracefully but warn when issues are detected

**Debugging Tips:**

- Use `surveys = ""` parameters to see available options
- Check function messages for detailed processing information  
- Use `dry_run = TRUE` for upload functions to test without making changes
- Examine intermediate outputs to understand data transformations