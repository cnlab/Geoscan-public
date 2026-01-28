# Geo Analysis R Script Documentation

This script provides a comprehensive toolkit for analyzing geographic exposure data and ecological momentary assessment (EMA) in the Geoscan Smoking Study. It handles loading, processing, and analyzing location data with retail outlet exposures, integrating EMA responses, and creating statistical models.

## Expected File Structure

The script expects data to be organized in the following directory structure:

```
/Data/
├── Geodata/
│   └── clean/
│       ├── merged_baseline.csv
│       ├── merged_intervention.csv
│       └── descriptives/
├── RetailerExposure/
│   └── ConditionalBuffer/
│   │   ├── Baseline/
│   │   │   ├── 500ft_100ft_nExposures_nObservations.csv
│   │   │   ├── 1000ft_100ft_nExposures_nObservations.csv
│   │   │   ├── 500ft_100ft_exposures.csv
│   │   │   └── 1000ft_100ft_exposures.csv
│   │   └── Intervention/
│   │       └── [similar structure]
│   └── StayEvents/
│       ├── Baseline/
│       └── Intervention/
├── Retailers/
├── LifeData/
│   └── clean/
└── Qualtrics/
    └── scored_survey_measures/
    
```
## Configuration

### GEO_EXPOSURE_CONFIG

A configuration list that defines default parameters for the analysis:

```r
GEO_EXPOSURE_CONFIG <- list(
  default_buffers = c("500ft", "1000ft"),        # Standard buffer distances
  default_small_buffers = c("100ft"),            # Small buffer for stay events
  default_types = c("Baseline", "Intervention"), # Study phases
  data_path = "/Volumes/cnlab/GeoRemote/Data"   # Root data directory
)
```

**Purpose**: Centralizes configuration to ensure consistency across functions and make it easy to modify default parameters.

---

## Data Loading Functions

### `load_geo_exposures()`

**Purpose**: Loads day-level aggregated exposure data for participants.

**Arguments**:
- `Type` (character): Study phase - "Baseline" or "Intervention"
- `buffer` (character/numeric vector): Buffer distances (default: `c("500ft", "1000ft")`)
- `data_path` (character): Path to data directory (default: from config)
- `include_observations` (logical): Whether to include observation counts (default: `FALSE`)
- `config` (list): Configuration object (default: `GEO_EXPOSURE_CONFIG`)

**Returns**: A data frame with columns:
- `pid`: Participant ID
- `day`: Day number
- `daily_exposures_[BUFFER]_100ft`: Exposure counts for each buffer distance
- `daily_observations_[BUFFER]_100ft`: Observation counts (if `include_observations = TRUE`)

**Processing Summary**:
1. Validates input parameters and file paths
2. Loads CSV files for each specified buffer distance
3. Renames columns to include buffer distance in column names
4. Merges multiple buffer datasets on `pid` and `day`
5. Returns sorted, merged dataset

**Usage Example**:
```r
# Load baseline exposures for 500ft and 1000ft buffers
baseline_exposures <- load_geo_exposures(
  Type = "Baseline",
  buffer = c("500ft", "1000ft"),
  include_observations = TRUE
)
```

---

### `load_geodata()`

**Purpose**: Loads within-day GPS tracking data with timestamps.

**Arguments**:
- `Type` (character): Study phase - "Baseline" or "Intervention" 
- `data_path` (character): Path to data directory (default: from config)
- `config` (list): Configuration object (default: `GEO_EXPOSURE_CONFIG`)

**Returns**: A data frame with GPS tracking data including:
- `pid`: Participant ID
- `datetime`: Timestamp in America/New_York timezone
- `day`: Day number
- Additional location and tracking columns

**Processing Summary**:
1. Validates input parameters and file existence
2. Uses `vroom()` for fast loading of large CSV files
3. Filters out rows with missing `datetime` or `pid`
4. Converts datetime to EST timezone using `lubridate`
5. Sorts by participant and timestamp

**Usage Example**:
```r
# Load detailed GPS tracking data
baseline_geodata <- load_geodata(Type = "Baseline")
```

---

### `load_geodata_with_exposures()`

**Purpose**: Combines within-day GPS data with day-level exposure counts.

**Arguments**:
- `Type` (character): Study phase - "Baseline" or "Intervention"
- `buffer` (character/numeric vector): Buffer distances (default: `c("500ft", "1000ft")`)
- `data_path` (character): Path to data directory (default: from config)
- `include_observations` (logical): Whether to include observation counts (default: `FALSE`)
- `config` (list): Configuration object (default: `GEO_EXPOSURE_CONFIG`)

**Returns**: A merged data frame containing:
- All GPS tracking data from `load_geodata()`
- All day-level exposure columns from `load_geo_exposures()`
- Joined on `pid` and `day`

**Processing Summary**:
1. Calls `load_geodata()` to get GPS tracking data
2. Calls `load_geo_exposures()` to get day-level exposures  
3. Performs left join to add exposure data to each GPS point
4. Each GPS observation gets annotated with that day's total exposures

**Usage Example**:
```r
# Load GPS data with daily exposure context
combined_data <- load_geodata_with_exposures(
  Type = "Intervention",
  buffer = "500ft",
  include_observations = FALSE
)
```

---

### `load_geodata_within_day_exposures()`

**Purpose**: Loads individual exposure events with exact timestamps (not aggregated by day). These files are very large and can take a while to load.

**Arguments**:
- `Type` (character): Study phase - "Baseline" or "Intervention"
- `buffer` (character/numeric): Single buffer distance (e.g., "500ft" or 500)
- `data_path` (character): Path to data directory (default: from config)
- `config` (list): Configuration object (default: `GEO_EXPOSURE_CONFIG`)

**Returns**: A data frame with individual exposure events including:
- `pid`: Participant ID
- `datetime`: Exact timestamp of exposure event
- Additional columns describing the specific exposure

**Processing Summary**:
1. Validates and standardizes buffer parameter (accepts numeric or character)
2. Loads CSV file containing individual exposure events
3. Converts datetime strings to POSIXct format in EST timezone
4. Removes columns that are entirely NA
5. Only handles one buffer distance at a time (unlike other functions)

**Usage Example**:
```r
# Load individual exposure events for 500ft buffer
exposure_events <- load_geodata_within_day_exposures(
  Type = "Baseline",
  buffer = 500
)
```

**Context**: Use this when you need the exact timing of exposure events rather than daily aggregates. Useful for analyzing temporal patterns of exposures, duration analysis, or event-based modeling.

---

### `load_stay_events()`

**Purpose**: Loads participant geodata joined wth retailers. Each geo observation will include the retailer if within the buffer.

**Arguments**:
- `type` (character): Study phase - "Baseline" or "Intervention"
- `small_buffer` (character/numeric): Small buffer distance (typically 100ft)
- `conditional_buffer` (character/numeric): Larger conditional buffer (e.g., 500ft, 1000ft)  
- `data_path` (character): Path to data directory (default: from config)
- `config` (list): Configuration object (default: `GEO_EXPOSURE_CONFIG`)

**Returns**: A data frame with stay event data including:
- `pid`: Participant ID
- `datetime`: Timestamp information
- Additional columns describing stay duration and location details

**Processing Summary**:
1. Validates and standardizes both buffer parameters
2. Constructs directory path using both buffer distances
3. Searches for files matching pattern `geodata_with_retailers*.csv`
4. Automatically selects the most recent file (based on modification time)
5. Loads and processes the selected file
6. Converts datetime and removes empty columns

**Usage Example**:
```r
# Load stay events data
stay_data <- load_stay_events(
  type = "Intervention",
  small_buffer = 100,
  conditional_buffer = 500
)
```

---

## Saving Functions

### `save_ema_with_geo_exposures()`

**Purpose**: Saves processed EMA (Ecological Momentary Assessment) data that has been merged with geo exposure data.

**Arguments**:
- `df` (data.frame): The data frame to save
- `buffer` (character/numeric): Buffer distance used in the analysis
- `type` (character): Study phase - "Baseline" or "Intervention"
- `t` (numeric, optional): Time parameter for filename
- `unit` (character, optional): Time unit for filename (required if `t` provided)
- `data_path` (character): Path to data directory (default: from config)
- `config` (list): Configuration object (default: `GEO_EXPOSURE_CONFIG`)

**Returns**: Invisibly returns the full file path where data was saved.

**Processing Summary**:
1. Validates input data frame and parameters
2. Standardizes buffer format (converts numeric to "XXXft" format)
3. Constructs appropriate filename based on parameters
4. Creates output directory if it doesn't exist
5. Warns if file already exists (will be overwritten)
6. Saves using `readr::write_csv()`
7. Verifies successful save and reports file size

**Usage Example**:
```r
# Save processed data
file_path <- save_ema_with_geo_exposures(
  df = processed_data,
  buffer = 500,
  type = "Baseline",
  t = 2,
  unit = "hours"
)
```

---

## EMA Data Loading Functions

### `load_ema_with_covs()`

**Purpose**: Loads Ecological Momentary Assessment (EMA) data and merges it with REDCap covariates/demographic data.

**Arguments**:
- `Type` (character): Study phase - "Baseline", "Intervention", or "" for all (default: "")
- `ema_variables` (character vector): EMA variables to include (default: "all")
- `redcap_variables` (character vector): REDCap variables to include (default: `c("pid", "age", "gender", "ethnicity", "race")`)
- `data_path` (character): Path to data directory (default: from config)
- `config` (list): Configuration object (default: `GEO_EXPOSURE_CONFIG`)

**Returns**: A data frame containing:
- EMA data (all or selected variables)
- REDCap demographic/covariate data (merged by `pid`)
- Combined dataset ready for analysis

**Processing Summary**:
1. Sources and calls external `load_lifedata()` function for EMA data
2. Filters by study Type if specified
3. Selects specified EMA variables (or keeps all)
4. Sources and calls external `load_redcap()` function for covariates
5. Selects specified REDCap variables
6. Left joins datasets on `pid`
7. Handles missing variables gracefully with warnings

**Usage Example**:
```r
# Load baseline EMA with selected variables and demographics
ema_data <- load_ema_with_covs(
  Type = "Baseline",
  ema_variables = c("pid", "day", "pos", "neg"),
  redcap_variables = c("pid", "age", "gender")
)
```

---

### `load_ema_with_geo_exposures()`

**Purpose**: Loads pre-processed EMA data that has already been merged with geo exposure calculations.

**Arguments**:
- `buffer` (character/numeric): Buffer distance (e.g., 500 or "500ft")
- `type` (character): Study phase - "Baseline" or "Intervention"
- `t` (numeric, optional): Time parameter for specific analysis window
- `unit` (character, optional): Time unit ("hours") - required if `t` provided
- `data_path` (character): Path to data directory (default: from config)
- `config` (list): Configuration object (default: `GEO_EXPOSURE_CONFIG`)

**Returns**: A data frame with:
- EMA response data
- `before_prompt_exposures_[BUFFER]_100ft`: Exposures before each EMA prompt
- `after_prompt_exposures_[BUFFER]_100ft`: Exposures after each EMA prompt
- `Notification Time`: EMA prompt timestamp (converted to EST)

**Processing Summary**:
1. Validates and standardizes buffer format
2. Constructs filename based on buffer, type, and optional time parameters
3. Loads pre-saved CSV file containing merged EMA and exposure data
4. Renames exposure columns to include buffer distance
5. Converts notification time to proper timezone
6. Validates required columns exist

**Usage Example**:
```r
# Load EMA data with 2-hour exposure windows
ema_exposures <- load_ema_with_geo_exposures(
  buffer = 500,
  type = "Intervention", 
  t = 2,
  unit = "hours"
)
```

**Context**: Use this when you need EMA data that has already been processed to include temporal exposure counts. This is typically the result of running `create_ema_var_to_geodata()` or similar processing functions first.

---

## Data Manipulation Functions

### `create_ema_var_to_geodata()` *(Legacy Function)*

**Purpose**: Merges geo exposure data to EMA responses based on temporal proximity - calculates exposures before and after each EMA prompt.

**Arguments**:
- `ema` (data.frame, optional): EMA dataset
- `geodata` (data.frame, optional): Geodata with exposures  
- `buffer` (character/numeric, optional): Buffer distance
- `type` (character, optional): Study phase
- `t` (numeric, optional): Time window in specified units
- `unit` (character): Time unit (default: "hours")
- `data_path` (character): Data directory path

**Returns**: EMA data merged with calculated exposure counts before and after each prompt.

**Processing Summary**:
1. Auto-detects buffer and type from variable names if not provided
2. Loads required datasets if not provided
3. For each participant-day combination:
   - Sorts EMA responses chronologically
   - Calculates unique exposures before each prompt (since previous response or start of day)
   - Calculates unique exposures after each prompt (until next response or end of day)
4. Saves results and merges back to full EMA dataset

**Usage Example**:
```r
# Process exposures around EMA prompts
processed_ema <- create_ema_var_to_geodata(
  buffer = "500ft",
  type = "Baseline",
  t = 2,
  unit = "hours"
)
```

**Context**: This is a complex processing function that should be used when you need to calculate temporal exposure windows around EMA prompts. The function automatically saves results for reuse.

**Note**: This function contains duplicate code and could benefit from refactoring.

---

### `create_ema_var_to_geodata_2_hours()` *(Legacy Function)*

**Purpose**: Similar to `create_ema_var_to_geodata()` but specifically calculates exposures in a 2-to-1 hour window before EMA prompts.

**Arguments**: Same as `create_ema_var_to_geodata()`

**Returns**: EMA data with exposure counts calculated for 2-1 hours before each prompt.

**Processing Summary**:
1. Similar to main function but uses fixed time window
2. Calculates exposures from 2 hours before prompt to 1 hour before prompt
3. This creates a lagged exposure measure that avoids immediate temporal confounding

**Context**: Use when you need lagged exposure measures that precede EMA responses by a specific time window. This helps establish temporal precedence for causal inference.

---

### `merge_ema_with_geo_exposures()`

**Purpose**: Clean, flexible function to merge EMA data with geo exposure data from various sources.

**Arguments**:
- `ema` (data.frame, optional): EMA dataset
- `geodata` (data.frame, optional): Geo exposure dataset
- `buffer` (character/numeric, optional): Buffer distance
- `type` (character, optional): Study phase
- `t` (numeric, optional): Time parameter
- `unit` (character, optional): Time unit
- `data_path` (character): Data directory path (default: from config)
- `config` (list): Configuration object (default: `GEO_EXPOSURE_CONFIG`)

**Returns**: Merged dataset containing both EMA responses and geo exposure data.

**Processing Summary**:
1. Loads missing datasets using appropriate loading functions
2. Validates that both datasets have required join columns
3. Performs left join on: `pid`, `day`, `Session Name`, and `Notification Time`
4. Validates merge success and reports match statistics
5. Handles missing data gracefully

**Usage Example**:
```r
# Merge existing datasets
merged_data <- merge_ema_with_geo_exposures(
  ema = my_ema_data,
  geodata = my_geo_data
)

# Or load and merge automatically
merged_data <- merge_ema_with_geo_exposures(
  buffer = 500,
  type = "Baseline"
)
```

---

### `add_survey_measure()`

**Purpose**: Adds scored survey measures (e.g., questionnaire scores) to an existing dataframe.

**Arguments**:
- `df` (data.frame): Input dataframe with `pid` column
- `survey` (character): Survey name (matches filename without .csv)
- `session` (numeric/character): Session number(s) or "all" (default: 1)
- `scale_type` (character): Type of score - "main", "sum", "mean", etc. (default: "main")
- `data_path` (character): Data directory path (default: from config)

**Returns**: Input dataframe with added survey score columns. 
- Columns are named {survey}_score if only one scale type is selected
- Columns are named {survey}_{scale_type} if more than one scale type is specified

**Processing Summary**:
1. Searches for survey CSV files in `Qualtrics/scored_survey_measures/` directory
2. Loads survey data and validates required columns: `sm_session`, `scored_scale`, `pid`, `score`
3. Filters by requested sessions and scale types
4. Creates appropriately named columns (e.g., `survey_score_sess1`)
5. Left joins survey scores to input dataframe by `pid`
6. Handles missing participants gracefully

**Usage Example**:
```r
# Add PHQ-9 depression scores from session 1
df_with_phq <- add_survey_measure(
  df = analysis_data,
  survey = "phq9",
  session = 1,
  scale_type = "sum"
)

# Add scores from all sessions
df_with_gad <- add_survey_measure(
  df = df_with_phq,
  survey = "gad7", 
  session = "all"
)
```

**Context**: Use this to add psychological, behavioral, or other survey measures to your analysis dataset. The function handles multiple sessions and score types automatically.

---

### `add_descriptives()`

**Purpose**: Adds participant-level descriptive measures collected from phone metadata

**Arguments**:
- `df` (data.frame): Input dataframe with `pid` column
- `vars` (character): Variables to include - "all" or specific variable names (default: "all")
- `data_path` (character): Data directory path (default: from config)

**Returns**: Input dataframe with added descriptive measures.

**Processing Summary**:
1. Searches `Geodata/clean/descriptives/` directory for CSV files
2. Extracts participant ID from each filename (before first underscore)
3. Loads all files and combines into single dataset
4. Converts numeric columns appropriately
5. Selects requested variables or keeps all
6. Left joins to input dataframe by `pid`

**Usage Example**:
```r
# Add all available descriptive measures
df_with_desc <- add_descriptives(
  df = analysis_data,
  vars = "all"
)

# Add specific mobility measures
df_mobility <- add_descriptives(
  df = analysis_data,
  vars = c("phone_type")
)
```

---

### `split_within_between()`

**Purpose**: Decomposes variables into within-subject and between-subject components for multilevel analysis.

**Arguments**:
- `data` (data.frame): Input dataframe  
- `vars` (character vector): Variables to decompose

**Returns**: Input dataframe with added decomposed variables for each input variable:
- `[VAR]_c`: Grand-mean centered variable
- `[VAR]_bw`: Between-subject component (person mean minus grand mean)
- `[VAR]_wn`: Within-subject component (observation minus person mean)
- Supporting variables: `Split_[VAR]`, `GMean_[VAR]`

**Processing Summary**:
1. For each variable, calculates person-level means (`Split_[VAR]`)
2. Calculates grand mean across all participants (`GMean_[VAR]`) 
3. Centers variable around grand mean (`[VAR]_c`)
4. Creates between-subject component: person mean minus grand mean (`[VAR]_bw`)
5. Creates within-subject component: centered observation minus between component (`[VAR]_wn`)

**Usage Example**:
```r
# Decompose exposure and mood variables
df_decomposed <- split_within_between(
  data = analysis_data,
  vars = c("daily_exposures", "mood_rating", "stress_level")
)
```

**Context**: Essential for multilevel modeling where you need to separate within-person effects (does mood change when exposures change for the same person?) from between-person effects (do people with higher average exposures have different average moods?).

---

### `winsorize_variables()`

**Purpose**: Winsorizes (caps extreme values) of variables within groups to reduce influence of outliers.

**Arguments**:
- `df` (data.frame): Input dataframe
- `variables` (character vector): Variables to winsorize
- `group_var` (character): Grouping variable (default: "pid") 
- `lower` (numeric): Lower percentile limit (default: 0.05)
- `upper` (numeric): Upper percentile limit (default: 0.95)

**Returns**: Input dataframe with added winsorized variables (suffix: `_wins`).

**Processing Summary**:
1. Groups data by specified grouping variable (typically participant)
2. For each variable within each group:
   - Calculates specified percentile limits (e.g., 5th and 95th percentiles)
   - Replaces values below lower limit with lower limit value
   - Replaces values above upper limit with upper limit value
3. Creates new variables with `_wins` suffix

**Usage Example**:
```r
# Winsorize exposure variables by participant
df_winsorized <- winsorize_variables(
  df = analysis_data,
  variables = c("daily_exposures", "response_time"),
  group_var = "pid",
  lower = 0.05,
  upper = 0.95
)
```

---

# Data Modeling and Visualization Functions

## Data Modeling Functions

### `create_model_function()`

**Purpose**: Creates customized model-fitting functions with pre-defined base formulas. This is a function factory that returns specialized modeling functions.

**Arguments**:
- `base_formula` (character): The core formula components (predictors + random effects)
- `model_type` (character): Type of model - "lmer" or "lme" (default: "lmer")

**Returns**: A function that can be called with:
- `data` (data.frame): Dataset to model
- `dv` (character): Dependent variable name
- `covs` (character vector, optional): Additional covariates to include
- `...`: Additional arguments passed to the modeling function

**Processing Summary**:
1. Creates a closure that captures the base formula
2. The returned function builds complete formulas by combining DV + covariates + base formula
3. For "lmer": Uses `lmer()` from lme4 package
4. For "lme": Converts lmer-style random effects syntax to lme format and uses `nlme::lme()`
5. Fixes model call objects for proper documentation

**Usage Examples**:
```r
# Create a model function for exposure analysis
exposure_before_model_500ft_wins = create_model_function(
  "before_prompt_exposures_500ft_100ft_wins_wn + before_prompt_exposures_500ft_100ft_wins_bw + day + (1|pid)"
)

# Use the created function to fit a model
lmer_craving_500ft = exposure_before_model_500ft_wins(
  data = within_day_hour_df, 
  dv = "crave_wins",
  covs = "prompt_count"
)
summary(lmer_craving_500ft)

# Create another model function for different buffer size
exposure_before_model_1000ft_wins = create_model_function(
  "before_prompt_exposures_1000ft_100ft_wins_wn + before_prompt_exposures_1000ft_100ft_wins_bw + day + (1|pid)"
)

# Fit model with multiple covariates
lmer_mood_1000ft = exposure_before_model_1000ft_wins(
  data = analysis_data,
  dv = "mood_rating", 
  covs = c("age", "gender", "weekend")
)

# Create lme model function (for nlme package)
exposure_lme_model = create_model_function(
  "exposure_wn + exposure_bw + day + (1|pid)",
  model_type = "lme"
)
```

**Context**: This function factory approach allows you to create standardized model-fitting functions for consistent analysis across different outcomes. Particularly useful when you have a standard set of predictors (like within/between exposure components) that you want to apply to multiple dependent variables.

---

### `get_lme_stats()` 

**Purpose**: Extracts key statistical summaries from fitted lme/lmer models.

**Arguments**:
- `model`: Fitted model object (lme or lmer)

**Returns**: A list containing:
- `Residual_Variance`: Within-subject error variance
- `Random_Intercept_Variance`: Between-subject variance (intercept)
- `ICC`: Intraclass correlation coefficient
- `Participants`: Number of unique participants
- `Observations`: Number of total observations
- `Marginal_R2`: R² for fixed effects only
- `Conditional_R2`: R² for fixed + random effects

**Processing Summary**:
1. Extracts variance components from model object
2. Calculates ICC as ratio of between-subject to total variance
3. Uses `MuMIn::r.squaredGLMM()` for R² calculations
4. Counts participants and observations

**Usage Example**:
```r
# Get model statistics
model_stats <- get_lme_stats(lmer_craving_500ft)
cat("ICC:", round(model_stats$ICC, 3))
cat("Conditional R²:", round(model_stats$Conditional_R2, 3))
```

**Context**: Useful for model diagnostics and reporting. The ICC tells you how much variation is between vs. within participants.

---

### `create_model_function_lme()` *(Legacy Function)*

**Purpose**: Earlier version of model function factory specifically for lme models. Still in use for now


---

## Plotting Functions

### `create_plot_model()`

**Purpose**: Creates publication-ready plots of model effects with statistical annotations.

**Arguments**:
- `model`: Fitted model object
- `coef_var` (character): Name of coefficient/predictor to plot
- `title` (character): Plot title (default: "")
- `x_lab` (character): X-axis label (default: "")
- `y_lab` (character): Y-axis label (default: "")

**Returns**: A ggplot object showing the effect of the specified predictor.

**Processing Summary**:
1. Extracts coefficient statistics (beta, t-value, p-value) from model summary
2. Formats p-values with appropriate precision (< 0.001, < 0.01, etc.)
3. Uses `sjPlot::plot_model()` to create effect plots
4. Adds statistical information to plot title
5. Applies custom aesthetics (requires `plot_aes` to be defined)

**Usage Example**:
```r
# Plot effect of within-person exposures on craving
exposure_plot <- create_plot_model(
  model = lmer_craving_500ft,
  coef_var = "before_prompt_exposures_500ft_100ft_wins_wn",
  title = "Effect of Exposure on Craving",
  x_lab = "Before-prompt Exposures (within-person)",
  y_lab = "Craving Rating"
)
```

**Context**: Creates standardized effect plots with embedded statistics for manuscript figures. Assumes existence of a custom `plot_aes` theme object.

---

### `plot_model_effects()` *(Legacy Function)*

**Purpose**: Creates detailed effect plots showing both individual-level and population-level associations.

**Arguments**:
- `data` (data.frame): Dataset used in modeling
- `response_var` (character): Dependent variable name (unquoted)
- `predictor_var` (character): Predictor variable name (unquoted)  
- `model_var`: Fitted model object (unquoted)
- `scale` (logical): Whether to scale the response variable (default: FALSE)
- `n` (numeric): Number of prediction points (default: 25)
- `plot_title_text` (character): Plot title
- `x_label` (character): X-axis label
- `y_label` (character): Y-axis label

**Returns**: A ggplot object with individual regression lines and population effect.

**Processing Summary**:
1. Extracts individual-level data and applies scaling if requested
2. Generates prediction values using `ggeffects::ggpredict()`
3. Extracts model statistics for annotation
4. Creates plot with:
   - Individual participant regression lines (semi-transparent)
   - Population-level effect line (bold, colored)
   - Confidence intervals (shaded ribbon)
   - Statistical annotations in title

**Usage Example**:
```r
# Plot with individual and population effects
detailed_plot <- plot_model_effects(
  data = analysis_data,
  response_var = crave_wins,
  predictor_var = before_prompt_exposures_500ft_100ft_wins_wn,
  model_var = lmer_craving_500ft,
  scale = FALSE,
  plot_title_text = "Exposure Effects on Craving",
  x_label = "Within-Person Exposure Change",
  y_label = "Craving (0-100)"
)
```

**Context**: This creates rich visualizations that show both the population-level effect and individual variation. Particularly useful for multilevel models where individual patterns may vary around the overall trend.

**Dependencies**: 
- Requires `palette_condition` and `plot_aes` objects to be defined
- Uses several packages: `modelr`, `ggeffects`, `ggplot2`
- Assumes response variable is on 0-100 scale (hardcoded y-axis limits)

**Limitations**:
- Contains hardcoded aesthetic choices and y-axis limits
- Requires pre-defined theme and color palette objects
- Uses deprecated `size` parameter in `geom_line()` (should be `linewidth`)

---

# Stay Events and Processing Functions

## Stay Events Functions

### `run_conditional_buffer()` 

**Purpose**: Comprehensive function that processes GPS data to create stay events and match them with retailer locations using conditional buffer logic.

**Arguments**:
- `type` (character): Study phase - "Baseline" or "Intervention"
- `small_buffer` (numeric): Small buffer distance in feet (typically 100ft)
- `conditional_buffer` (numeric): Larger conditional buffer in feet (e.g., 500ft, 1000ft)
- `retailer_filename` (character): Path to retailer data file
- `geodata` (data.frame, optional): Pre-loaded GPS data (will load if NULL)
- `create_stay_events` (logical): Whether to create new stay events (default: FALSE)
- `stay_event_config` (list): Configuration for stay event detection:
  - `radius` (numeric): Distance threshold in feet (default: 100)
  - `t` (numeric): Time threshold in minutes (default: 1.5)
- `data_path` (character): Root data directory path

**Returns**: Processed stay events data with retailer matching information.

**Processing Summary**:
1. **Load Retailer Data**: Reads retailer location file and creates unique retailer IDs
2. **Load/Create Stay Events**: 
   - If `create_stay_events = FALSE`: Loads existing stay events
   - If `create_stay_events = TRUE`: Creates new stay events using mobility algorithms
3. **Stay Event Detection**: Uses `stayevent()` function to identify periods where participants remained in small areas
4. **Spatial Matching**: 
   - Matches stay events to retailers within conditional buffer
   - Determines which observations fall within small buffer
5. **Retailer Status**: Evaluates if retailers were active/expired during visit
6. **File Management**: Archives old files and saves new results with metadata

**Usage Example**:
```r
# Process baseline data with conditional buffer logic
stay_events <- run_conditional_buffer(
  type = "Baseline",
  small_buffer = 100,
  conditional_buffer = 500,
  retailer_filename = "retailers_2023.csv",
  create_stay_events = TRUE,
  stay_event_config = list(radius = 100, t = 2.0)
)
```

**Context**: This is a complex pipeline function that handles the entire workflow from raw GPS data to retailer-matched stay events. The "conditional buffer" approach means participants must be within the small buffer (100ft) to count as an exposure, but retailers within the larger conditional buffer (500ft+) are considered for matching.

**Internal Helper Functions**:
- `load_retailer_data()`: Handles retailer data loading with path resolution
- `create_new_stay_events()`: Generates stay events using mobility algorithms
- `inSmallBuffer()`: Determines which observations are within small buffer
- `combine_stay_events_with_retailers()`: Spatial joining of stays and retailers
- `save_stayevents()`: File saving with archival and metadata

**Dependencies**: Requires external functions like `intakeRetailers()`, `stayevent()`, `bufferAndJoin()`, `radiusofgyration()`, and `spaceTimeLags()`.

---

### `join_exposures()`

**Purpose**: Combines individual participant exposure files into a single dataset and joins with stay events data.

**Arguments**:
- `dir` (character): Directory containing individual exposure CSV files
- `df` (data.frame): Stay events dataframe to join with (optional, will load if not provided)

**Returns**: Combined dataset with stay events and exposure information merged.

**Processing Summary**:
1. Searches directory for files matching pattern `*_exposure.csv`
2. Loads each file and extracts participant ID from filename
3. Combines all individual exposure files into single dataframe
4. Joins exposure data with stay events data on `id` column
5. Cleans up duplicate columns from the join

**Usage Example**:
```r
# Combine exposure files from a directory
combined_data <- join_exposures(
  dir = "/path/to/exposure/files/",
  df = my_stay_events_data
)
```

**Context**: This function aggregates the output of individual exposure calculations (typically generated by `calculate_exposures()`) back into a complete dataset for analysis.

---

### `calculate_exposures()` 

**Purpose**: Calculates unique exposure events by tracking when participants move between retailers and determining continuous exposure periods.

**Arguments**:
- `stay_events` (data.frame, optional): Stay events data
- `type` (character): Study phase (required if stay_events is NULL)
- `conditional_buffer` (numeric): Conditional buffer distance (required if stay_events is NULL)  
- `small_buffer` (numeric): Small buffer distance (required if stay_events is NULL)
- `start_from` (character, optional): Participant ID to resume processing from
- `data_path` (character): Root data directory path

**Returns**: Saves individual exposure files and creates combined exposure dataset.

**Processing Summary**:
1. **Data Loading**: Loads stay events data if not provided
2. **Participant Loop**: Processes each participant individually with progress tracking
3. **Temporal Sequencing**: For each participant, processes observations chronologically
4. **Exposure Logic**: 
   - Creates new exposure ID when participant first enters small buffer near retailer
   - Continues same exposure ID if participant remains near same retailer
   - Creates new exposure ID when participant moves to different retailer
5. **Retailer Status Check**: Excludes expired retailers from exposure calculations
6. **File Output**: Saves individual participant files and combined dataset

**Algorithm Details**:
- **First Observation**: If within small buffer, assign new exposure ID
- **Subsequent Observations**: 
  - If same retailer as previous observation: continue existing exposure ID
  - If new retailer and within small buffer: create new exposure ID
  - If outside small buffer: no exposure assigned *unless* two consecutive geo observations within the conditional buffer.

**Usage Example**:
```r
# Calculate exposures for all participants
calculate_exposures(
  type = "Intervention",
  conditional_buffer = 500,
  small_buffer = 100,
  start_from = "12345"  # Resume from specific participant
)
```

**Context**: This is the core algorithm for defining what constitutes an "exposure event." It handles the complex logic of determining when a participant starts and stops being exposed to a retailer location.

---

### `create_nExposures_nObservations()`

**Purpose**: Creates daily summary statistics of exposure counts and observation counts per participant.

**Arguments**:
- `type` (character): Study phase - "Baseline" or "Intervention"
- `conditional_buffer` (numeric): Conditional buffer distance
- `data_path` (character): Root data directory path

**Returns**: Saves CSV file with daily exposure and observation summaries.

**Processing Summary**:
1. Loads individual exposure files from directory
2. Combines all participant exposure data
3. Joins with stay events data for complete information
4. Groups by participant and day to calculate:
   - `n_exposure_per_day`: Count of distinct exposure events per day
   - `n_observations_per_day`: Count of distinct GPS observations per day
5. Saves summary file for use in daily-level analyses

**Usage Example**:
```r
# Create daily summaries for baseline period
create_nExposures_nObservations(
  type = "Baseline", 
  conditional_buffer = 500
)
```

**Context**: This creates the day-level summary data that is used by functions like `load_geo_exposures()` for daily aggregated analyses.

---

## Miscellaneous Functions

### `get_statistics()` *(Legacy Function)*

**Purpose**: Calculates participant-level exposure statistics across all study days.

**Arguments**:
- `df` (data.frame): Dataset with exposure information

**Returns**: Data frame with participant-level summary statistics:
- `n_day`: Number of days with data
- `median_exposures_per_day`: Median daily exposure count
- `mean_exposure_per_day`: Mean daily exposure count  
- `sd_exposure_per_day`: Standard deviation of daily exposures

**Processing Summary**:
1. Groups data by participant and day
2. Counts distinct exposures per day (handling NA values as 0)
3. Summarizes across days within each participant
4. Calculates central tendency and variability measures

**Usage Example**:
```r
# Get exposure statistics for all participants
participant_stats <- get_statistics(exposure_data)
head(participant_stats)
```

**Context**: Useful for descriptive analysis and identifying participants with unusual exposure patterns.

---

### `check_days()`

**Purpose**: Identifies participants who are missing data for expected study days.

**Arguments**:
- `df` (data.frame): Dataset with `pid` and `day` columns

**Returns**: Character vector of participant IDs who are missing any days from 1-14.

**Processing Summary**:
1. Defines expected days as 1:14 (typical study duration)
2. For each participant, checks which days are present in data
3. Identifies participants missing any expected days
4. Returns vector of problematic participant IDs

**Usage Example**:
```r
# Check for participants with missing days
missing_data_pids <- check_days(analysis_data)
cat("Participants with missing days:", length(missing_data_pids))
print(missing_data_pids)
```

**Context**: Important data quality check to identify participants who may need to be excluded from analyses requiring complete daily data.

---

## Implementation Notes

**Legacy Code Status**: All functions in this section are marked as "UNFACTORED," indicating they may contain:
- Repetitive code patterns
- Hard-coded parameters that could be configurable
- Limited error handling
- Inconsistent coding style

**Computational Intensity**: Several functions (`run_conditional_buffer()`, `calculate_exposures()`) are computationally intensive and process large spatial datasets. They include:

**File Management**: These functions handle complex file operations:
- Automatic archiving of old results
- Timestamped output files
- README file generation for documentation
- Directory structure creation

**Spatial Processing Dependencies**: The functions rely on several external spatial processing functions that should be available in the geo codebase:
- `stayevent()`: Stay event detection algorithm
- `bufferAndJoin()`: Spatial buffer and join operations
- `intakeRetailers()`: Retailer data processing
- `radiusofgyration()`: Mobility metric calculation
- `spaceTimeLags()`: Temporal-spatial analysis