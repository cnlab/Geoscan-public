# Geo Remote LifeData Processing Documentation

## Overview

This R script provides a comprehensive pipeline for processing ecological momentary assessment (EMA) data from the Geo Remote study. The script handles loading, cleaning, transforming, and saving lifepack data collected through mobile devices.

## Quick Start

### Loading Processed Data

```r
# Load data in long format (default)
lifedata_long <- load_lifedata(format = "long")

# Load data in wide format
lifedata_wide <- load_lifedata(format = "wide")
```

### Processing Raw Data

```r
# Process all raw data through the full pipeline
cleaned_data <- create_master_lifedata()

# With custom data path
cleaned_data <- create_master_lifedata(data_path = "/path/to/your/data/")
```

**Expected Directory Structure:**
```
/your/data/path/
├── LifeData/
│   ├── raw/           # Raw downloads
│       └── LifeData_NIS        # Notification Initiated Surveys
│   ├── clean/         # Processed data
│   └── utility/
│       └── lifepack_ids_to_remove.csv  # userIDs to remove
│       └── lifepack_ids.csv  # Match pakID to Lifepak name and Type (Baseline/Intervention/Control)
```

## Data Formats

### Long Format
In long format, each row represents a single response to a specific prompt:

| pid   | Notification Date | Prompt Label | Response | Type     |
|-------|-------------------|--------------|----------|----------|
| GR001 | 2024-01-15       | crave        | 3        | Baseline |
| GR001 | 2024-01-15       | stress       | 2        | Baseline |
| GR001 | 2024-01-15       | pos          | 4        | Baseline |

### Wide Format
In wide format, each row represents a complete notification with responses as columns:

| pid   | Notification Date | crave | stress | pos | Type     |
|-------|-------------------|-------|--------|-----|----------|
| GR001 | 2024-01-15       | 3     | 2      | 4   | Baseline |


## High-Level Processing Pipeline

The `create_master_lifedata()` function executes the following pipeline:

1. **Data Loading & Validation**
   - Load raw CSV files from LifeData directory
   - Load RedCap participant information
   - Load lifepack metadata and removal lists
   - Validate file paths and dependencies

2. **Data Integration**
   - Merge lifepack data with participant information
   - Link with RedCap condition assignments
   - Handle participant ID matching across data sources

3. **Data Cleaning**
   - Remove excluded lifepack IDs
   - Separate reset packs into baseline/intervention periods
   - Filter by RedCap date ranges
   - Fix known data entry errors
   - Collapse duplicate notifications

4. **Variable Creation**
   - Add day-in-study and day-in-condition variables
   - Create microaggression and stress event indicators
   - Calculate daily cigarette consumption with imputation
   - Compute daily craving averages
   - Add response time calculations

5. **Data Export**
   - Archive previous versions
   - Save cleaned data with timestamp
   - Return processed dataset

## Function Reference

### Configuration & Validation

#### `validate_dependencies()`
Ensures all required R packages are installed and loaded.

**Returns:** `TRUE` if all dependencies are met, throws error otherwise.

#### `setup_directories(custom_path = NULL)`
Establishes the Scripts directory path for sourcing utility functions.

**Parameters:**
- `custom_path`: Optional custom path to Scripts directory

**Returns:** List with `$scripts` element containing path

#### `validate_file_paths(paths)`
Checks that specified file paths exist.

**Parameters:**
- `paths`: Character vector of file paths to validate

**Returns:** `TRUE` if all paths exist, throws error otherwise

### Data Loading Functions

#### `load_raw_lifedata(path = "LifeData_NIS", pattern = "*.csv", data_path)`
Loads and processes raw lifedata CSV files into long format.

**Parameters:**
- `path`: Subdirectory within LifeData/raw (default: "LifeData_NIS")
- `pattern`: File pattern to match (default: "*.csv")
- `data_path`: Base data path

**Returns:** Long format data frame with all sessions

**Example:**
```r
# Load default NIS data
lifedata <- load_raw_lifedata()

# Load specific subdirectory
pilot_data <- load_raw_lifedata(path = "Pilot_Data", pattern = "pilot_*.csv")
```

#### `load_lifepack_info(data_path)`
Loads lifepack metadata including device assignments.

**Returns:** Data frame with lifepack information

#### `load_removal_ids(data_path)`
Loads list of lifepack IDs to exclude from analysis.

**Returns:** Character vector of IDs to remove

### Variable Creation Functions

#### `add_day_variables(df)`
Adds day-in-study and day-in-condition variables.

**Creates:**
- `day`: Day within each condition type (Baseline, Intervention)
- `day_in_study`: Overall day in study across all conditions

#### `add_microaggression_variables(df)`
Creates daily microaggression indicators and counts.

**Creates:**
- `microagg_day`: Binary indicator for any microaggression on that day
- `microagg_count`: Count of microaggressions reported that day

#### `add_stress_variables(df)`
Creates daily stress event indicators and counts.

**Creates:**
- `stress_day`: Binary indicator for any stress event on that day
- `stress_count`: Count of stress events reported that day

#### `add_daily_craving_average(df)`
Calculates daily average craving scores.

**Creates:**
- `daily_average_crave`: Mean craving score for each day

#### `add_daily_cigarettes(df)`
Calculates daily cigarette consumption with imputation for missing values.

**Process:**
1. Calculates within-condition averages for `cvg_1` and `cvg_2`
2. Imputes missing values using condition-specific means
3. Sums daily cigarette consumption
4. Marks imputed values

**Creates:**
- `daily_cigs`: Total cigarettes per day
- `Imputed`: Binary indicator for imputed responses

#### `add_response_time(df)`
Calculates actual response time by adding lapse to notification time.

**Creates:**
- `Response_Time`: POSIXct timestamp of actual response

### Data Processing Functions

#### `remove_lifepack_ids(df, removal_ids)`
Filters out participants marked for exclusion.

#### `add_participant_info(lifedata, lifepack_ids, redcap)`
Merges lifedata with participant information and condition assignments.

**Process:**
1. Merges with lifepack metadata
2. Links with RedCap participant IDs across multiple ID columns
3. Adds condition assignments

#### `separate_reset_packs(lifedata, redcap)`
Classifies reset pack data as Baseline or Intervention based on RedCap timing.

**Logic:**
- Checks RedCap ID columns for participant matches
- ID columns with "1" → Baseline period
- ID columns with "2" → Intervention period
- Renames "Control" to "Intervention"

#### `filter_by_redcap_dates(lifedata, redcap)`
Filters lifedata to only include dates specified in RedCap date ranges.

#### `fix_response_errors(df, fixes = NULL)`
Corrects known data entry errors.

#### `collapse_duplicates(df)`
Handles duplicate notifications by keeping the most complete response.

**Process:**
1. Identifies notifications with multiple session instances
2. For each duplicate group, prioritizes non-NA values
3. Uses most recent session instance as tiebreaker

### Data I/O Functions

#### `save_lifedata(df, name, folder, data_path)`
Saves processed data with archiving of previous versions.

**Parameters:**
- `df`: Data frame to save
- `name`: Name suffix for file
- `folder`: Destination folder within LifeData directory
- `data_path`: Base data path

**Process:**
1. Archives existing files with same name pattern
2. Creates timestamped filename
3. Saves as CSV using `data.table::fwrite()`

#### `load_lifedata(format = "long", data_path)`
Loads the most recent cleaned lifedata file.

**Parameters:**
- `format`: "long" or "wide"
- `data_path`: Base data path

**Returns:** Cleaned lifedata in specified format

### Utility Functions

#### `windsorize_variable(df, variable, lower = 3, upper = 3, method = "sd")`
Handles outliers by winsorizing extreme values.

**Parameters:**
- `df`: Data frame
- `variable`: Variable name or prompt label to windsorize
- `lower`/`upper`: Threshold values
- `method`: "sd" (standard deviation) or "quartile"

**Methods:**
- `"sd"`: Caps values at mean ± (threshold × SD)
- `"quartile"`: Uses IQR method with 1.5×IQR fence

**Example:**
```r
# Windsorize craving responses at 3 SD
cleaned_data <- windsorize_variable(lifedata, "crave", method = "sd")

# Use quartile method for cigarette consumption
cleaned_data <- windsorize_variable(lifedata, "daily_cigs", method = "quartile")
```

## Configuration

The script uses a global configuration list:

```r
LIFEDATA_CONFIG <- list(
  data_path = "/Volumes/cnlab/GeoRemote/Data/"
)
```

All functions use this default path unless explicitly overridden.

## Dependencies

Required R packages:
- `tidyverse`: Data manipulation and visualization
- `data.table`: Fast data I/O
- `lubridate`: Date/time handling

## Examples

### Complete Workflow
```r
# Process raw data through full pipeline
cleaned_data <- create_master_lifedata()

# Load processed data for analysis
analysis_data <- load_lifedata(format = "wide")

# Apply windsorizing to handle outliers
analysis_data <- windsorize_variable(analysis_data, "daily_cigs", method = "sd")

# Save custom processed version
save_lifedata(analysis_data, name = "analysis_ready", folder = "processed")
```

### Custom Processing
```r
# Load only raw data without full processing
raw_data <- load_raw_lifedata(path = "Custom_Export")

# Apply specific cleaning steps
custom_cleaned <- raw_data %>%
  add_day_variables() %>%
  add_daily_craving_average()

# Save intermediate result
save_lifedata(custom_cleaned, name = "partial_clean", folder = "intermediate")
```

### Data Exploration
```r
# Load long format for modeling
model_data <- load_lifedata(format = "long")

# Filter to specific prompts
craving_data <- model_data %>%
  filter(`Prompt Label` == "crave")

# Load wide format for correlation analysis
correlation_data <- load_lifedata(format = "wide")

# Examine daily patterns
daily_summary <- correlation_data %>%
  group_by(pid, Type, day) %>%
  summarise(
    avg_crave = mean(daily_average_crave, na.rm = TRUE),
    total_cigs = first(daily_cigs),
    stress_events = first(stress_count)
  )
```