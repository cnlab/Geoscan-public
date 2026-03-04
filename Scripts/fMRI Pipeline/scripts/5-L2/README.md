# Step 5: Second-Level (L2) Group Analysis

Second-level analysis takes the contrast images produced by L1 and tests them at the group level using SPM. Like L1, the entire design is specified in JSON, and the notebook generates Slurm job scripts rather than running SPM directly.

Multiple group analyses — different contrasts, different designs, different subgroups — can all be defined in a single model JSON and submitted in one batch.

---

## How It Works

The L2 pipeline follows the same structure as L1, with one important difference: before generating jobs, the notebook first scans all L1 output directories to build a master table of available contrast images. This table (`contrasts.csv`) is the bridge between L1 and L2 — it maps every subject to every contrast image they have, and L2 job files are built by selecting rows from it.

```
L1 output (derivatives_nocorrection/nipype/{task-X_model-Y}/sub-*/con_*.nii)
      │
      ▼
l2analysis_notebook.ipynb
  ├── scans L1 output dirs, reads each SPM.mat → builds contrasts.csv
  ├── for each SecondLevel job in the model JSON:
  │     selects subjects × contrast(s), merges covariates if any,
  │     writes a resolved l2-{name}.json job file
  │     writes a Slurm l2-{name}.job script
  └── prints sbatch commands
      │
      ▼
scripts/L1/jobs/{task-X_model-Y}/
├── jobs/
│   ├── l2-{name}.json   ←── resolved L2 job spec
│   └── ...
└── slurm/
    ├── l2-{name}.job    ←── Slurm script
    └── ...
      │
      ▼
l2analysis_SPM.py (runs inside Singularity on cluster)
      │
      ▼
derivatives_nocorrection/nipype/{task-X_model-Y}/l2-{name}/
└── SPM.mat, con_*.nii, spmT_*.nii
```

---

## File Locations

| File | Path |
|------|------|
| Notebook | `scripts/L1/l2analysis_notebook.ipynb` |
| Worker script | `scripts/L1/l2analysis_SPM.py` |
| Model JSON | `scripts/L1/model_{task}-{name}.json` (same file as L1, with added `SecondLevel` block) |
| Contrast index | `data/bids_data/derivatives_nocorrection/nipype/{task-X_model-Y}/contrasts.csv` |
| L2 job JSONs | `scripts/L1/jobs/{task-X_model-Y}/jobs/l2-{name}.json` |
| Slurm scripts | `scripts/L1/jobs/{task-X_model-Y}/slurm/l2-{name}.job` |
| Slurm logs | `scripts/L1/jobs/{task-X_model-Y}/slurm/out/l2-{name}.err` |
| L2 output | `data/bids_data/derivatives_nocorrection/nipype/{task-X_model-Y}/l2-{name}/` |
| Working directory | `data/bids_data/derivatives_nocorrection/working/nipype/{task-X_model-Y}/l2-{name}/` |
| Interactive viewer | `scripts/L1/l2_interactive_viewer.ipynb` |
| Quick plot notebook | `scripts/L1/task_images.ipynb` |

---

## Workflow

### Step 1 — Add a `SecondLevel` Block to the Model JSON

L2 uses the same model JSON as L1, extended with a `SecondLevel` block. Open the model file and add it below the existing keys. See [Model JSON Reference](#model-json-reference) for the full specification.

### Step 2 — Run the Notebook

Open `l2analysis_notebook.ipynb`, set `model_path` to point to your model file, and run all cells.

The notebook will:

1. Load and merge the model JSON and its templates (same as L1)
2. Check that the L1 output directory for this model exists
3. Scan all `sub-*/SPM.mat` files and build `contrasts.csv` — a table mapping each subject to each contrast image path. If `contrasts.csv` already exists from a previous run it is reused; set `"force_update": true` in the JSON to rebuild it after new subjects complete
4. Print a summary table showing how many subjects have each contrast — a quick check for missing L1 outputs
5. For each job in `SecondLevel.job`:
   - Select the relevant subjects and contrast image(s)
   - Merge in covariate data if provided, dropping subjects with missing values
   - Generate auto-contrasts appropriate for the analysis type (e.g. group mean, paired difference)
   - Write a resolved `l2-{name}.json` job file
   - Write a Slurm `l2-{name}.job` script
6. Print per-job status and submission commands

### Step 3 — Submit Jobs to Slurm

Connect to the ASC VPN, SSH to the cluster, and paste the sbatch commands printed by the notebook:

```bash
ssh <JANUS_username>@asc.upenn.edu@cls000

cd /data00/projects/{project}/scripts/L1/jobs/{task-X_model-Y}/slurm
sbatch -D . -c 8 l2-{name}.job
```

L2 jobs are much faster than L1 — most complete in minutes to a few hours depending on sample size and design complexity.

### Step 4 — Check Output

Each L2 job writes to its own subdirectory:

```
derivatives_nocorrection/nipype/{task-X_model-Y}/
└── l2-{name}/
    ├── SPM.mat           ← group-level design matrix
    ├── beta_0001.nii     ← parameter estimates
    ├── con_0001.nii      ← group contrast image
    ├── spmT_0001.nii     ← T-statistic map  ← primary result
    ├── mask.nii          ← analysis mask
    └── ResMS.nii         ← residual mean squares
```

### Step 5 — View Results

Two tools are available for exploring L2 results. See [Viewing Results](#viewing-results).

---

## Model JSON Reference

The `SecondLevel` block is added directly to the same model JSON used for L1. The existing `Environment`, `Info`, and template inheritance all carry over — you do not need a separate file.

```json
{
    "Template": [ "...study template...", "...task template..." ],
    "Info": { "model": "GEO-condition" },

    "SpecifySPMModel": { "...L1 settings..." },
    "EstimateContrast": { "...L1 contrasts..." },

    "SecondLevel": {
        "force_update": false,
        "job": [
            { "...analysis 1..." },
            { "...analysis 2..." }
        ]
    }
}
```

**`force_update`** — Set to `true` to rebuild `contrasts.csv` from scratch. Use this after new subjects finish L1 or after re-running L1 with different settings. Default: `false`.

**`job`** — A list of analysis specifications. Each entry defines one group-level test. Multiple jobs can be listed and are all processed in one notebook run.

---

### Analysis Types

Four SPM group designs are supported. Each is specified by setting `"analysis"` to one of:

| Value | Design | Requires |
|-------|---------|----------|
| `OneSampleTTestDesign` | One-sample T-test (group mean) | 1 contrast |
| `PairedTTestDesign` | Paired T-test (within-subject difference) | 2 contrasts |
| `TwoSampleTTestDesign` | Two-sample T-test (between-group) | 1 contrast + group definition |
| `MultipleRegressionDesign` | Multiple regression | 1 contrast + covariate file |

---

### One-Sample T-Test

Tests whether a contrast is significantly different from zero across all subjects. The most common L2 analysis — equivalent to asking "is there a group-level effect?"

```json
{
    "name": "smoke_v_nonsmoke_all",
    "analysis": "OneSampleTTestDesign",
    "contrast": "smoke_v_nonsmoke_all"
}
```

**`name`** — Label for this analysis. Used to name the output directory (`l2-smoke_v_nonsmoke_all`) and job files. If omitted, defaults to `{analysis}_{contrast}`. Special characters are replaced with underscores.

**`contrast`** — The L1 contrast name to test. Must exactly match a contrast name in `contrasts.csv` (which comes from the SPM.mat `xCon` field). The notebook prints the available names when building `contrasts.csv`.

**Auto-generated L2 contrasts:** `["mean", "T", ["mean"], [1]]` — tests whether the group mean is greater than zero.

---

### One-Sample T-Test with Covariate

Tests the group mean while regressing out (or including) a continuous covariate. Also the design for a **correlation** — use `include_intercept: true` and the T-contrast for the covariate to test its association with the contrast across subjects.

```json
{
    "name": "smoke_v_nonsmoke_by_dependence",
    "analysis": "OneSampleTTestDesign",
    "contrast": "smoke_v_nonsmoke_all",
    "covariate_file": "/data00/projects/geoscan_v2/data/covariates.csv",
    "covariate_names": ["nicotine_dependence", "age"],
    "covariate_centering": {
        "nicotine_dependence": "overall_mean",
        "age": "overall_mean"
    }
}
```

**`covariate_file`** — Absolute path to a CSV or TSV file. Must contain a `sub` column with subject IDs matching the `sub-{ID}` format in `contrasts.csv`. Subjects present in the contrast index but absent from the covariate file (or with missing values) are dropped silently.

**`covariate_names`** — Columns from the covariate file to include as regressors. If omitted, all non-`sub` columns are used.

**`covariate_centering`** — How to center each covariate before entering the model. Options: `"overall_mean"` (default), `"no_centering"`, `"factor1_mean"` / `"factor2_mean"` / `"factor3_mean"`, `"user_specified"`, `"as_implied_by_ancova"`, `"gm"`. Mean-centering is strongly recommended for interpretability of the intercept.

**Auto-generated L2 contrasts:** `["mean", "T", ["mean"], [1]]` plus one T-contrast per covariate: `[covariate_name, "T", [covariate_name], [1]]`.

---

### Paired T-Test

Tests the difference between two conditions within subjects — each subject contributes one image for each condition. Use this when comparing two L1 contrasts that exist for the same subjects (e.g. two task conditions modeled separately at L1).

```json
{
    "name": "retail_smoke_vs_familiar_v_nonsmoke",
    "analysis": "PairedTTestDesign",
    "contrast": ["retail_smoke_familiar", "retail_nonsmoke_familiar"]
}
```

**`contrast`** — A list of exactly two L1 contrast names. Subjects who have both are included; subjects missing either are excluded.

**Auto-generated L2 contrast:** `["{contrast1}>{contrast2}", "T", ["Condition_{1}", "Condition_{2}"], [1, -1]]` — tests condition 1 > condition 2. The reverse direction is not auto-generated; add it via `l2_contrasts` if needed.

---

### Two-Sample T-Test

Compares one L1 contrast between two independent groups of subjects. Groups can be defined explicitly by listing subject IDs, or derived from a binary grouping variable in a covariate file.

**Option A — Explicit group lists:**

```json
{
    "name": "smoke_v_nonsmoke_by_sex",
    "analysis": "TwoSampleTTestDesign",
    "contrast": "smoke_v_nonsmoke_all",
    "groups": [
        ["sub-GEO001", "sub-GEO003", "sub-GEO007"],
        ["sub-GEO002", "sub-GEO004", "sub-GEO008"]
    ]
}
```

**Option B — Grouping variable from covariate file:**

```json
{
    "name": "smoke_v_nonsmoke_by_smoker_status",
    "analysis": "TwoSampleTTestDesign",
    "contrast": "smoke_v_nonsmoke_all",
    "covariate_file": "/data00/projects/geoscan_v2/data/covariates.csv",
    "grouping_variable": "smoker_status"
}
```

`grouping_variable` must be a column in the covariate file with exactly two unique values. Subjects are split by those values; the order of groups follows the sort order of the unique values.

**`dependent`** — Set to `true` if the two groups are dependent (i.e. matched pairs). Default: `false`.

**Auto-generated L2 contrasts:** Three contrasts are created — one testing each group's mean separately (`Group_{1}`, `Group_{2}`), and one testing the difference (`Group1>Group2`).

> **Note:** Covariates are not currently supported for `TwoSampleTTestDesign` beyond the grouping variable.

---

### Multiple Regression

Regresses an L1 contrast against one or more continuous predictors across subjects. Equivalent to a brain-wide correlation or multiple regression. This is the design to use when you have a continuous between-subject variable (e.g. a questionnaire score) and want to find regions where it predicts activation.

```json
{
    "name": "smoke_effect_by_craving",
    "analysis": "MultipleRegressionDesign",
    "contrast": "smoke_v_nonsmoke_all",
    "covariate_file": "/data00/projects/geoscan_v2/data/covariates.csv",
    "covariate_names": ["craving_score"],
    "include_intercept": true
}
```

**`include_intercept`** — Whether to include a constant term in the regression. Default: `true`. Keep this `true` unless you have a specific reason to force the regression through zero.

**Auto-generated L2 contrasts:** One T-contrast per covariate: `[covariate_name, "T", [covariate_name], [1]]`. If `include_intercept` is `true`, also generates `["mean", "T", ["mean"], [1]]`.

---

### Custom L2 Contrasts

All analysis types auto-generate sensible default contrasts (see above). Additional contrasts can be added via `l2_contrasts`, using the same four-element format as L1:

```json
"l2_contrasts": [
    ["smoke_less_nonsmoke", "T", ["Condition_{2}", "Condition_{1}"], [1, -1]]
]
```

The condition names available depend on the analysis type — use `"mean"` for one-sample, `"Condition_{1}"` / `"Condition_{2}"` for paired, `"Group_{1}"` / `"Group_{2}"` for two-sample, and covariate names for regression. Custom contrasts are appended after the auto-generated ones.

---

### Explicit Brain Mask

To restrict the analysis to a specific set of voxels (e.g. an ROI mask or a group-level brain mask), add:

```json
"explicit_mask_file": "/data00/projects/geoscan_v2/data/masks/frontal_roi.nii"
```

The mask file is copied into the L2 output directory before the job runs. If omitted, SPM uses an implicit mask based on the data.

---

### Running Multiple Analyses

All jobs in the `job` array are processed in one notebook run. For example, to run the group mean and a correlation in the same pass:

```json
"SecondLevel": {
    "job": [
        {
            "name": "smoke_v_nonsmoke_group",
            "analysis": "OneSampleTTestDesign",
            "contrast": "smoke_v_nonsmoke_all"
        },
        {
            "name": "smoke_v_nonsmoke_by_craving",
            "analysis": "OneSampleTTestDesign",
            "contrast": "smoke_v_nonsmoke_all",
            "covariate_file": "/data00/projects/geoscan_v2/data/covariates.csv",
            "covariate_names": ["craving_score"]
        },
        {
            "name": "smoke_familiar_v_unfamiliar",
            "analysis": "PairedTTestDesign",
            "contrast": ["retail_smoke_familiar", "retail_smoke_unfamiliar"]
        }
    ]
}
```

Each job produces its own output directory and Slurm job file, submitted independently.

---

## Viewing Results

Two tools are available for exploring L2 results after jobs complete.

### Interactive Viewer — `l2_interactive_viewer.ipynb`

A widget-based viewer that loads all L2 analyses for a given model into a single interface. Recommended for initial exploration and QC.

To launch, open the notebook and run the single cell at the bottom:

```python
viewer = launch_interactive_level2_viewer(
    '/data00/projects/geoscan_v2/data/bids_data/derivatives_nocorrection/nipype/task-image_model-GEO-condition/l2analysis'
)
```

Point this path at the `{task-X_model-Y}` directory — the viewer will find all `l2-*/` subdirectories automatically.

**Controls:**

| Control | Options | Description |
|---------|---------|-------------|
| Contrast | dropdown | Select which L2 result to view |
| Image type | T-statistics / Contrast estimates | `spmT_0001.nii` or `con_0001.nii` |
| Correction | None / FDR / Bonferroni | Multiple comparison correction method |
| Alpha (α) | 0.001 – 0.1 | Significance threshold for FDR or Bonferroni |
| Threshold | 1.0 – 5.0 | T-value threshold when no correction is applied |
| Display | Glass brain / Orthogonal / Mosaic / x / y / z | Visualization mode |

**Buttons:**

- **Update View** — Rerender the plot with current settings
- **Compare Corrections** — Side-by-side panel showing uncorrected, FDR, Bonferroni, and liberal thresholds for the selected contrast
- **Threshold Summary** — Prints a detailed table of surviving voxel counts at multiple thresholds
- **Export Maps** — Saves FDR- and Bonferroni-thresholded NIfTI files to `{l2_path}/exported_maps/`

**Correction methods:**

| Method | Controls | Recommended for |
|--------|---------|-----------------|
| None | Per-voxel type I error rate | Initial exploration only |
| FDR | False discovery rate (q) | Most publications — standard choice |
| Bonferroni | Family-wise error rate (p) | Confirmatory analyses; conservative |

The viewer reads sample size and degrees of freedom from each `SPM.mat` automatically, which it uses to convert T-values to p-values for FDR and Bonferroni calculations.

---

### Quick Plot Notebook — `task_images.ipynb`

A simpler notebook for running a one-sample T-test and viewing the results entirely within Jupyter, without Slurm. Useful for rapid iteration on a single contrast or for situations where the cluster is unavailable. Unlike the main L2 pipeline, this notebook runs SPM directly (requires Matlab on the machine where Jupyter is running).

To use it:

1. Set `model_path` in Cell 1 to your model JSON
2. Run all cells — it will aggregate contrast files, run one-sample T-tests across all L1 contrasts in a single Nipype workflow, and produce inline brain plots thresholded at p < 0.0001 uncorrected

Output goes to `{L1_output}/{task-X_model-Y}/l2analysis/{contrast_name}/`. Because this runs outside Singularity, it requires Matlab and SPM12 to be accessible and configured (the notebook sets paths from `Environment.spm_path`).

> This notebook is best used as a quick sanity check. For any result you intend to report, use the main `l2analysis_notebook.ipynb` + Slurm pipeline, which produces properly structured output and supports all four design types.

---

## Troubleshooting

**`contrasts.csv` is empty or has fewer subjects than expected**
The notebook globs `sub-*/SPM.mat` in the L1 output directory. If some subjects' L1 jobs failed or haven't finished, their `SPM.mat` won't exist and they'll be silently skipped. Check how many rows appear in the printed pivot table (subjects × contrasts) and compare against your full subject list.

**A specific contrast is missing for some subjects**
If an L1 contrast was dropped for some subjects (e.g. because a condition was absent), those subjects will have `NaN` in `contrasts.csv` for that contrast column. The notebook drops subjects with any `NaN` for the required contrast(s) before building the job file. This is reported implicitly in the pivot table — look for contrasts with lower N than expected.

**"First-level output directory not found"**
The notebook checks that `{output_path}/{task-X_model-Y}` exists before proceeding. If it doesn't, L1 has not produced any output yet, or the `Info.task` and `Info.model` values don't match what was used at L1.

**Grouping variable has more than two levels**
`TwoSampleTTestDesign` requires exactly two groups. If the `grouping_variable` column in the covariate file has more unique values after dropping NaN rows, the notebook raises an error. Recode the variable to two levels before running, or use `MultipleRegressionDesign` with a dummy-coded predictor instead.

**Covariate subjects don't match contrast subjects**
The merge between `contrasts.csv` and the covariate file is done on the `sub` column. Subject IDs in the covariate file must match the `sub-{ID}` format used in the contrast index (e.g. `sub-GEO053`). Mismatches result in those subjects being dropped via the `dropna()` after the left join. Print `selected_con_df` in the notebook to inspect the merged table before job files are written.

**L2 job fails immediately on cluster**
Check `slurm/out/l2-{name}.err`. If it shows a Matlab license error, retry later. If the working directory already contains files from a previous partial run, they can cause Nipype conflicts — delete `working/nipype/{task-X_model-Y}/l2-{name}/` before resubmitting.

**Interactive viewer shows no contrasts**
The viewer expects to find `l2-*/` subdirectories within the path provided. Ensure the path ends at the `{task-X_model-Y}` level, not at a specific `l2-{name}` directory. Also confirm that at least one `SPM.mat` exists inside a subdirectory — the viewer uses SPM.mat to extract contrast names and degrees of freedom.
