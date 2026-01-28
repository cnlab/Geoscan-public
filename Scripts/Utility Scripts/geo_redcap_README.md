# REDCap Processing Pipeline

## Overview

This R script provides a pipeline for downloading, processing, and managing REDCap data for the Geo Remote Study.

**Primary Use Cases:**
- Download raw REDCap data via API
- Remove identifying information for de-identification
- Collapse some checkbox variables (e.g., race selections)
- Apply some demographic factor coding
- Manage data versions with automatic archiving

## Configuration

### Data Path Setup

The script uses a default data path that can be configured:

```r
# Default configuration
REDCAP_CONFIG <- list(
  uri = 'https://ascredcap.asc.upenn.edu/api/',
  data_path = "/Volumes/cnlab/GeoRemote/Data/",
  pid_pattern = "^GR\\d{3}$",
  exclude_test_pattern = "test"
)
```

**To use a different data path:**
```r
# Option 1: Pass to functions directly
df <- load_redcap_data(data_path = "/your/custom/path")

# Option 2: Modify the global config
REDCAP_CONFIG$data_path <- "/your/custom/path"
```

**Expected Directory Structure:**
```
/your/data/path/
├── Redcap/
│   ├── raw/           # Raw downloads
│   ├── clean/         # Processed data
│   └── utility/
│       └── drop_vars.csv  # Variables to remove
```

### Required Files

- `drop_vars.csv`: CSV file with at least a column named `Variable` containing variable names to remove for de-identification
  - **Location**: `{data_path}/Redcap/utility/drop_vars.csv`
  - **Format**: Must contain column `Variable` with text values of REDCap variable names
  - **Example**:
    ```csv
    Variable
    name_first
    name_last
    email
    phone
    address
    ```
- REDCap API token for downloading fresh data

## Main Data Loading Functions

### Quick Start

```r
# Most common usage - load cached clean data
df <- load_redcap()

# Download fresh data (will prompt for API token)
df <- download_redcap()

# Download with specific API token
df <- download_redcap(api_key = "your_token_here")
```

### Primary Functions

#### `load_redcap_data()`
**Main entry point** for all data loading operations.

```r
load_redcap_data(download = FALSE, 
                 api_key = "", 
                 data_path = REDCAP_CONFIG$data_path,
                 apply_factors = TRUE)
```

**Parameters:**
- `download` (logical): Whether to download fresh data (`TRUE`) or load cached (`FALSE`)
- `api_key` (character): REDCap API token (prompted if empty and downloading)
- `data_path` (character): Base directory path for data storage
- `apply_factors` (logical): Whether to apply demographic factoring to the data

**Returns:** Data frame with processed REDCap data

**Examples:**
```r
# Load cached data with demographic factoring
df <- load_redcap_data()

# Download fresh data without factoring
df <- load_redcap_data(download = TRUE, apply_factors = FALSE)

# Load from custom path
df <- load_redcap_data(data_path = "/custom/path")
```

#### `load_redcap()`
**Convenience wrapper** for loading cached data.

```r
load_redcap(data_path = REDCAP_CONFIG$data_path)
```

**Parameters:**
- `data_path` (character): Base directory path for data storage

**Returns:** Data frame with processed and factored REDCap data

#### `download_redcap()`
**Convenience wrapper** for downloading fresh data.

```r
download_redcap(api_key = "", data_path = REDCAP_CONFIG$data_path)
```

**Parameters:**
- `api_key` (character): REDCap API token (prompted if empty)
- `data_path` (character): Base directory path for data storage

**Returns:** Data frame with freshly downloaded and processed REDCap data

---

## Data Processing Functions

### `download_and_process_redcap()`
Downloads fresh data from REDCap API and processes it through the full pipeline.

```r
download_and_process_redcap(api_key, data_path)
```

**Parameters:**
- `api_key` (character): REDCap API token
- `data_path` (character): Base directory path

**Returns:** Processed data frame

### `load_cached_redcap()`
Loads the most recent cached clean data file.

```r
load_cached_redcap(data_path)
```

**Parameters:**
- `data_path` (character): Base directory path

**Returns:** Data frame from most recent clean file

### `apply_manual_fixes()`
Applies hard-coded data corrections.

```r
apply_manual_fixes(df)
```

**Parameters:**
- `df` (data.frame): Raw REDCap data

**Returns:** Data frame with manual corrections applied

**Current Fixes:**
- Corrects consent_date for participant GR286
- Calculates age from date of birth and consent date

### `filter_valid_participants()`
Filters data to valid participant IDs only.

```r
filter_valid_participants(df)
```

**Parameters:**
- `df` (data.frame): REDCap data with pid column

**Returns:** Filtered data frame

**Filtering Rules:**
- Must match pattern `^GR\d{3}$` (e.g., GR001, GR245)
- Excludes records containing "test" (case-insensitive)

### `remove_identifying_vars()`
Removes identifying variables based on drop list.

```r
remove_identifying_vars(df, data_path)
```

**Parameters:**
- `df` (data.frame): REDCap data
- `data_path` (character): Path to find drop_vars.csv file

**Returns:** De-identified data frame

### `collapse_checkbox_vars()`
Collapses REDCap checkbox variables into single variables.

```r
collapse_checkbox_vars(df, 
                       var_name = "race",
                       pattern = "race___",
                       multiple_code = "8")
```

**Parameters:**
- `df` (data.frame): REDCap data
- `var_name` (character): Name for the collapsed variable
- `pattern` (character): Pattern to match checkbox columns
- `multiple_code` (character): Code to use when multiple boxes are checked

**Returns:** Data frame with collapsed checkbox variables

**Behavior:**
- Single selection: Returns the selected option number
- Multiple selections: Returns the `multiple_code` value
- No selections: Returns `NA`

---

## File Management Functions

### `save_redcap_file()`
Saves REDCap data with automatic archiving of old files.

```r
save_redcap_file(df, type, data_path)
```

**Parameters:**
- `df` (data.frame): Data to save
- `type` (character): File type ("raw" or "clean")
- `data_path` (character): Base directory path

**Returns:** Input data frame (for chaining)

**Behavior:**
- Creates timestamped filename: `redcap_{type}_{date}.csv`
- Archives existing files to `archive/` subdirectory
- Creates directories as needed

### `archive_old_files()`
Moves old REDCap files to archive directory.

```r
archive_old_files(source_dir, type)
```

**Parameters:**
- `source_dir` (character): Directory containing files to archive
- `type` (character): File type to match

### `load_raw_redcap()`
Loads raw REDCap files by type.

```r
load_raw_redcap(type = "raw", data_path = REDCAP_CONFIG$data_path)
```

**Parameters:**
- `type` (character): File type to load
- `data_path` (character): Base directory path

**Returns:** Data frame from most recent matching file

---

## Data Dictionary Functions

### `load_redcap_dictionary()`
Loads and processes the REDCap data dictionary.

```r
load_redcap_dictionary(data_path = REDCAP_CONFIG$data_path)
```

**Parameters:**
- `data_path` (character): Base directory path

**Returns:** Data frame with cleaned dictionary columns

**Output Columns:**
- `var`: Variable/field name
- `form`: Form name
- `type`: Field type
- `label`: Field label
- `options`: Choices/calculations/slider labels

---

## Demographic Processing

### `factor_demographics()`
Applies demographic factoring with predefined coding schemes.

```r
factor_demographics(df, variables = c("race", "gender", "ethnicity"))
```

**Parameters:**
- `df` (data.frame): REDCap data
- `variables` (character vector): Variables to factor

**Returns:** Data frame with factored demographic variables

**Supported Variables:**

**Race** (1-8):
1. Asian
2. Black  
3. Pacific Islander or Hawaiian Native
4. American Indian or Alaska Native
5. White
6. Prefer to self-describe
7. Prefer not to say
8. More than one

**Gender** (1-8):
1. Man
2. Woman
3. Prefer not to say
4. Non-binary
5. Genderqueer
6. Agender
7. Gender fluid
8. I prefer to self-describe

**Ethnicity** (0-2):
0. No
1. Yes
2. Prefer not to say

---

## Workflow Examples

### Standard Analysis Workflow

```r
# 1. Load required libraries
library(pacman)
p_load(tidyverse, rjson, REDCapR)

# 2. Source the script
source("geo_redcap.r")

# 3. Load data for analysis
df <- load_redcap()

# 4. Begin analysis
summary(df)
```

### Fresh Data Download Workflow

```r
# 1. Download and process fresh data
df <- download_redcap(api_key = "your_api_token")

# 2. Verify processing
cat("Loaded", nrow(df), "participants\n")
table(df$race, useNA = "ifany")

# 3. Proceed with analysis
```

### Custom Processing Workflow

```r
# 1. Download without demographic factoring
df_raw <- load_redcap_data(download = TRUE, apply_factors = FALSE)

# 2. Apply custom processing
df_custom <- df_raw %>%
  # Your custom steps here
  filter(age >= 18) %>%
  # Then apply standard factoring
  factor_demographics()

# 3. Save custom version
write_csv(df_custom, "custom_processed_data.csv")
```

### Working with Data Dictionary

```r
# Load data dictionary
dict <- load_redcap_dictionary()

# Explore available forms
table(dict$form)

# Find variables related to specific topics
dict %>% filter(str_detect(label, "anxiety|depression"))
```

---

## Error Handling and Troubleshooting

**Common Issues:**

1. **Missing API Token**: Functions will prompt for token if not provided
2. **Missing Data Path**: Check that `data_path` exists and is accessible
3. **No Clean Files**: Run with `download = TRUE` to create initial files
4. **Permission Issues**: Ensure write access to data directories

**File Structure Problems:**
- The script will create necessary directories automatically
- Ensure `drop_vars.csv` exists in `{data_path}/Redcap/utility/`
- The `Variable` column should contain the names of REDCap variables to remove

**Data Issues:**
- Invalid participant IDs are automatically filtered out
- Unexpected demographic values are converted to `NA` with warnings
