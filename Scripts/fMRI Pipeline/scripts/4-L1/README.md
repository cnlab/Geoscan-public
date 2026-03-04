# Step 4: First-Level (L1) GLM Analysis

First-level analysis fits a subject-by-subject general linear model (GLM) to the preprocessed BOLD data using SPM via Nipype. The design matrix is fully specified through **JSON model files**, making it easy to define, version-control, and reuse models across tasks and projects without editing any Python code.

---

## How It Works

The pipeline has three components that work together:

```
Model JSON file(s)
      │
      ▼
l1analysis_notebook.ipynb   ←── reads model JSON, resolves templates,
      │                          validates files, generates per-subject jobs
      │
      ▼
scripts/L1/jobs/{task-X_model-Y}/
├── jobs/
│   ├── sub-001.json    ←── fully resolved per-subject model spec
│   └── sub-002.json
└── slurm/
    ├── sub-001.job     ←── Slurm job that runs l1analysis_SPM.py
    └── sub-002.job
      │
      ▼
l1analysis_SPM.py (Nipype + SPM worker, runs inside Singularity on cluster)
      │
      ▼
data/bids_data/derivatives_nocorrection/nipype/{task-X_model-Y}/
└── sub-001/        ←── SPM.mat, beta images, contrast images
```

The notebook never runs SPM itself — it only generates the job files. All heavy computation happens on the Slurm cluster via `l1analysis_SPM.py` running inside a Singularity container with Matlab and SPM.

### Nipype Pipeline Steps

The worker script is a lightweight wrapper around the following Nipype nodes, executed in order:

1. **Smoothing** (optional) — [IsotropicSmooth](https://nipype.readthedocs.io/en/latest/api/generated/nipype.interfaces.fsl.maths.html#isotropicsmooth): applies spatial smoothing to the BOLD before modeling. Skipped if `fwhm` is `0`.
2. **Specify SPM model** — [SpecifySPMModel](https://nipype.readthedocs.io/en/latest/api/generated/nipype.algorithms.modelgen.html#specifyspmmodel): reads event files, motion regressors, and outlier indices; constructs the session info structure passed to SPM.
3. **Generate design matrix** — [Level1Design](https://nipype.readthedocs.io/en/latest/api/generated/nipype.interfaces.spm.model.html#level1design): creates the SPM design matrix (`SPM.mat`) from the session info, HRF basis, and timing parameters.
4. **Estimate model** — [EstimateModel](https://nipype.readthedocs.io/en/latest/api/generated/nipype.interfaces.spm.model.html#estimatemodel): fits the GLM and writes beta images.
5. **Estimate contrasts** (optional) — [EstimateContrast](https://nipype.readthedocs.io/en/latest/api/generated/nipype.interfaces.spm.model.html#estimateconstrast): computes contrast images (`con_*.nii`) and T-statistic maps (`spmT_*.nii`).

---

## File Locations

All paths below assume the scripts are in `scripts/L1/` relative to the project root.

| File | Path |
|------|------|
| Notebook | `scripts/L1/l1analysis_notebook.ipynb` |
| Worker script | `scripts/L1/l1analysis_SPM.py` |
| Model JSON files | `scripts/L1/model_{task}-{name}.json` |
| Template JSON files | `scripts/L1/` (referenced by model JSONs) |
| Per-subject job JSONs | `scripts/L1/jobs/{task-X_model-Y}/jobs/sub-{ID}.json` |
| Slurm job scripts | `scripts/L1/jobs/{task-X_model-Y}/slurm/` |
| Slurm logs | `scripts/L1/jobs/{task-X_model-Y}/slurm/out/` |
| Processed event files | `scripts/L1/jobs/{task-X_model-Y}/events/` |
| L1 output | `data/bids_data/derivatives_nocorrection/nipype/{task-X_model-Y}/sub-{ID}/` |
| Working directory | `data/bids_data/derivatives_nocorrection/working/nipype/{task-X_model-Y}/sub-{ID}/` |
| Singularity image | `/data00/tools/singularity_images/neurodocker.sqsh` |

---

## Workflow

### Step 1 — Create or Select a Model JSON

Each model is defined in a `.json` file at `scripts/L1/`. The naming convention is `model_{task}-{modelname}.json`. Set `model_path` in the notebook to point to it:

```python
model_path = L1_path + '/model_images-GEO.json'
```

See [Model JSON Reference](#model-json-reference) below for a full walkthrough of how model files are structured and how to write your own.

### Step 2 — Run the Notebook

Open `l1analysis_notebook.ipynb` and run all cells. The notebook will:

1. Load the model JSON and merge any referenced templates
2. Detect all subjects in the BIDS derivatives directory (or use the explicit list in the JSON)
3. Validate that all required files exist for each subject (functional runs, event files, regressors)
4. Process event files: apply any `event_options` (renaming, filtering, melting) and `pmod` transformations; save a copy of the final processed events file per run to `jobs/{task-X_model-Y}/events/` for later reference
5. Extract outlier volumes from the motion regressor files and write per-run outlier index files
6. Auto-generate basic contrasts (one per condition) if requested, then append any custom contrasts
7. Remove contrasts whose conditions are missing for a given subject
8. Write one fully resolved `sub-{ID}.json` per subject into the `jobs/` folder
9. Write one Slurm `.job` file per subject into the `slurm/` folder
10. Print per-subject status: `job created` or a list of issues found

### Step 3 — Submit Jobs to Slurm

First, connect to the ASC VPN. Then SSH to the Slurm master node:

```bash
ssh <JANUS_username>@asc.upenn.edu@cls000
```

If prompted with *"The authenticity of host 'cls000' can't be established… Are you sure you want to continue connecting?"*, type `yes`.

Paste the output from the notebook's **Run All Models** cell to submit the full batch:

```bash
cd /data00/projects/{project}/scripts/L1/jobs/{task-X_model-Y}/slurm
sbatch -D . -c 8 sub-GEO001.job
sbatch -D . -c 8 sub-GEO002.job
...
```

To test a single subject first, use the **Test Drive** cell output, which prints the raw Singularity command you can run directly without Slurm.

### Step 4 — Monitor Jobs

While jobs are running, check their status on the cluster:

```bash
squeue -u <JANUS_username>
```

This shows all jobs currently queued or running under your username, their status (`R` = running, `PD` = pending), and elapsed time. If a job fails, check its error log:

```bash
cat scripts/L1/jobs/{task-X_model-Y}/slurm/out/sub-{ID}.err
```

The `.out` file in the same directory contains the full Nipype log if you need more detail on what the pipeline was doing when it failed.

### Step 5 — Check Output

After jobs complete, verify that the expected output files are present for each subject:

```
derivatives_nocorrection/nipype/{task-X_model-Y}/sub-001/
├── SPM.mat                      ← design matrix and estimation results
├── beta_0001.nii ... beta_N.nii ← parameter estimates (one per regressor + constant)
├── con_0001.nii ... con_N.nii   ← contrast images
├── spmT_0001.nii ...            ← T-statistic maps
├── mask.nii                     ← analysis mask
└── ResMS.nii                    ← residual mean squares
```

A subject whose job succeeded but whose output folder is absent or missing `SPM.mat` should be checked via its `.err` log. The `con_*.nii` and `spmT_*.nii` images are the primary outputs passed to second-level (group) analysis.

---

## Model JSON Reference

Models are specified across a hierarchy of JSON files that are merged together at runtime. Each layer adds more specificity, and more specific files always override broader ones. The geoscan image task model uses three layers:

```
study-geoscanR01-GEO.json     ←── lab/study-wide defaults (paths, SPM settings, motion regressors)
        +
task_images-GEO.json          ←── task-specific settings (runs, file paths, subject exclusions)
        +
model_images-GEO.json         ←── model-specific settings (event mapping, contrasts)
        =
sub-GEO053.json               ←── fully resolved per-subject job (auto-generated by notebook)
```

The model file (the most specific) declares which templates it inherits via the `"Template"` key. The notebook loads these in order and merges them using a **non-destructive** strategy: a key defined in a more specific file is never overwritten by a broader template. The model file always wins, the task template fills in what the model doesn't define, and the study template fills in whatever remains.

Any setting from the study or task template can be overridden by redefining it in the model file. For example, to use a different smoothing kernel for a specific model, add `"IsotropicSmooth": {"fwhm": 8}` to the model JSON and it will take precedence over the study-level default.

---

### Layer 1: Study Template — `study-geoscanR01-GEO.json`

This file defines everything shared across all models run on this study: server paths, SPM estimation settings, smoothing kernel, high-pass filter, and the motion regressors to include. It is never pointed to directly — it is always referenced as a template by other files.

```json
{
    "Description": [
        "GEoscan R01 default pipeline",
        "4mm FWHM smoothing",
        "No global scaling",
        "FAST correlation",
        "x_trans, y_trans, z_trans, x_rot, y_rot, z_rot, trash regressor (FD > 0.75 | GS > 3 SD)"
    ],

    "Environment": {
        "job_path": "models",
        "spm_path": "/data00/tools/spm12mega",
        "fsl_path": "/data00/tools/fsl",
        "data_path": "/data00/projects/geoscan_v2",
        "output_path": "/data00/projects/geoscan_v2/data/bids_data/derivatives_nocorrection/nipype",
        "working_path": "/data00/projects/geoscan_v2/data/bids_data/derivatives_nocorrection/working/nipype"
    },

    "Info": {
        "tr": 1,
        "sub_container": "data/bids_data/derivatives_nocorrection/"
    },

    "IsotropicSmooth": {
        "fwhm": 4
    },

    "SpecifySPMModel": {
        "input_units": "secs",
        "output_units": "secs",
        "high_pass_filter_cutoff": 180,
        "regressor_names": [
            "trans_x", "trans_y", "trans_z", "rot_x", "rot_y", "rot_z", "trash"
        ]
    },

    "Level1Design": {
        "bases": { "hrf": { "derivs": [0, 0] } },
        "timing_units": "secs",
        "global_intensity_normalization": "none",
        "model_serial_correlations": "FAST"
    },

    "EstimateModel": {
        "estimation_method": { "Classical": 1 },
        "write_residuals": false
    },

    "EstimateContrast": {
        "basic_contrasts": true
    }
}
```

**`Environment`** — Absolute server paths. `data_path` is the root against which all relative paths elsewhere in the JSON resolve. `job_path` (relative to `data_path`) is where per-subject JSON jobs and Slurm scripts are written. `spm_path` and `fsl_path` are used when running outside Singularity.

**`Info`** — `tr` is the repetition time in seconds, used automatically by both `SpecifySPMModel` and `Level1Design`. `sub_container` is the path pattern (relative to `data_path`) used to auto-detect subjects — the notebook globs for `sub-*/` directories within it.

**`IsotropicSmooth`** — Applies FSL `IsotropicSmooth` to the preprocessed BOLD before modeling. `fwhm: 4` applies 4mm smoothing. Set `fwhm: 0` to skip smoothing entirely (e.g. for MVPA single-trial beta models). If smoothing is skipped and functional files are `.gz`, they are gunzipped automatically before being passed to SPM.

**`SpecifySPMModel`** — `input_units` and `output_units` should be `"secs"`. `high_pass_filter_cutoff` is in seconds (180s here, vs SPM's default of 128s). `regressor_names` lists the columns to pull from the motion regressor TSV files produced by `generate_outlier_report.ipynb`: six motion parameters plus `trash`, which is the binary spike regressor flagging volumes that exceeded the FD or global signal threshold.

**`Level1Design`** — `bases: {"hrf": {"derivs": [0, 0]}}` uses the canonical HRF with no temporal or dispersion derivatives. `model_serial_correlations: "FAST"` applies FAST autocorrelation correction (preferred over `"AR(1)"` for short TRs like 1s). `global_intensity_normalization: "none"` disables global scaling.

**`EstimateModel`** — Classical (ReML) estimation. `write_residuals: false` skips saving residual images, which are large and only needed for specific diagnostics.

**`EstimateContrast`** — `basic_contrasts: true` tells the notebook to auto-generate one T-contrast per condition (and per pmod, if any). These are computed first, before any manually specified contrasts.

---

### Layer 2: Task Template — `task_images-GEO.json`

This file defines everything specific to the image task: which runs exist, which subjects to exclude, and where to find the functional, event, and regressor files for each subject-run. It is also referenced as a template rather than run directly.

```json
{
    "Description": "Geoscan Image Task",

    "Info": {
        "task": "image",
        "run": [ 1, 2, 3, 4, 5 ],
        "exclude": {
            "sub": [
                "GEO021", "GEO047", "GEO064", "GEO068", "GEO070",
                "GEO073", "GEO074", "GEO078",
                "GS005",  "GS008",  "GS017",  "GS022",  "GS024",
                "GS025",  "GS028",  "GS031",  "GS032"
            ],
            "run": {}
        }
    },

    "SpecifySPMModel": {
        "functional_runs": "data/bids_data/derivatives_nocorrection/sub-{sub}/ses-t2/func/sub-{sub}_ses-t2_task-{task}_run-{run}_space-MNI152NLin2009cAsym_desc-preproc_bold.nii.gz",
        "event_files":     "data/bids_data/derivatives_nocorrection/sub-{sub}/ses-t2/func/sub-{sub}_ses-t2_task-{task}_run-{run}_events.tsv",
        "regressors":      "data/bids_data/derivatives_nocorrection/outlier/regressors/sub-{sub}/sub-{sub}_ses-t2_task-{task}_run-{run}_desc-motion_timeseries.tsv"
    }
}
```

**`Info.task`** — The BIDS task label, used to fill `{task}` in path templates and to name the output directory.

**`Info.run`** — Run numbers to include. The notebook loops over these for each subject, filling `{run}` into path templates. Individual runs can be excluded per subject via `exclude.run` — see [Per-Subject Run Exclusions](#per-subject-run-exclusions).

**`Info.exclude.sub`** — Subjects to skip entirely, listed as bare IDs without the `sub-` prefix. Subjects are excluded here rather than deleted from BIDS to preserve a clear QC record within the pipeline configuration.

**`SpecifySPMModel` path templates** — The three paths use `{sub}`, `{task}`, and `{run}` placeholders filled in per subject-run. Paths are relative to `data_path` from the study template:

- `functional_runs` — fMRIPrep-preprocessed BOLD in MNI space
- `event_files` — BIDS events TSV with onset, duration, and trial_type columns. The BIDS standard specifies one events file per task, but the pipeline supports any naming or location as long as the path template resolves correctly. A copy of the final processed events file (after `event_options` are applied) is saved per run to `jobs/{task-X_model-Y}/events/` for later reference.
- `regressors` — motion regressor TSV files from `generate_outlier_report.ipynb`, containing the columns named in `regressor_names` in the study template

The notebook validates that every resolved path actually exists for every subject-run before writing any job files.

---

### Layer 3: Model File — `model_images-GEO.json`

This is the file you point the notebook at. It defines what is unique to a specific model: which templates to inherit, how to map raw event types to conditions in the design matrix, and which contrasts to estimate. Everything not defined here falls through to the task and study templates.

```json
{
    "Description": ["Model by condition"],
    "Template": [
        "/data00/projects/geoscan_v2/scripts/L1/study-geoscanR01-GEO.json",
        "/data00/projects/geoscan_v2/scripts/L1/task_images-GEO.json"
    ],

    "Info": {
        "model": "GEO-condition"
    },

    "SpecifySPMModel": {
        "event_options": {
            "map_event": {
                "retail_smoke_familiar":      ["stimuli_retail_smoke_familiar"],
                "retail_smoke_unfamiliar":    ["stimuli_retail_smoke_unfamiliar"],
                "retail_nonsmoke_familiar":   ["stimuli_retail_nonsmoke_familiar"],
                "retail_nonsmoke_unfamiliar": ["stimuli_retail_nonsmoke_unfamiliar"],
                "standard_smoke":    ["stimuli_standard_smoke"],
                "standard_nonsmoke": ["stimuli_standard_nonsmoke"],
                "personal_smoke":    ["stimuli_personal_smoke"],
                "personal_nonsmoke": ["stimuli_personal_nonsmoke"],
                "rating": ["rating"]
            },
            "exclude_events": ["stimuli_rest"]
        }
    },

    "EstimateContrast": {
        "contrasts": [
            ["standardSmoke_v_standardNonsmoke",
             "T", ["standard_smoke", "standard_nonsmoke"], [1, -1]],

            ["retailSmokeFamiliar_v_retailNonsmokeFamiliar",
             "T", ["retail_smoke_familiar", "retail_nonsmoke_familiar"], [1, -1]],

            ["retailSmoke_v_retailNonsmoke",
             "T", ["retail_smoke_familiar", "retail_smoke_unfamiliar",
                   "retail_nonsmoke_familiar", "retail_nonsmoke_unfamiliar"],
             [0.5, 0.5, -0.5, -0.5]],

            ["smoke_v_nonsmoke_all",
             "T", ["standard_smoke", "standard_nonsmoke",
                   "personal_smoke", "personal_nonsmoke",
                   "retail_smoke_familiar", "retail_smoke_unfamiliar",
                   "retail_nonsmoke_familiar", "retail_nonsmoke_unfamiliar"],
             [0.25, -0.25, 0.25, -0.25, 0.25, 0.25, -0.25, -0.25]],

            ["smoke_v_nonsmoke_nopersonal",
             "T", ["standard_smoke", "standard_nonsmoke",
                   "retail_smoke_familiar", "retail_smoke_unfamiliar",
                   "retail_nonsmoke_familiar", "retail_nonsmoke_unfamiliar"],
             [0.33, -0.33, 0.33, 0.33, -0.33, -0.33]]
        ]
    }
}
```

**`Template`** — A list of template files to inherit, applied in order. The notebook resolves the fully merged model before generating any job files. This key is consumed by the notebook and is not passed to SPM.

**`Info.model`** — The model name label, used to construct the output directory name (`task-image_model-GEO-condition`) and all job file names.

**`SpecifySPMModel.event_options`** — Transformations applied to each subject's event TSV before it is passed to SPM. Two operations are used here:

- `map_event`: renames raw trial type labels into the condition names that will appear in the design matrix. Each key is the desired condition name; each value is a list of raw trial types that map to it. Any raw trial type not listed here is left unchanged. For example, `"stimuli_retail_smoke_familiar"` in the raw TSV becomes `"retail_smoke_familiar"` in the model.
- `exclude_events`: drops the listed trial types before modeling. `"stimuli_rest"` is excluded here because rest periods serve as the implicit baseline and should not appear as explicit regressors.

Other available operations are `include_event` (keep only these trial types, drop all others) and `melt_event` (split a single trial type into per-item subtypes based on a column value — useful for single-trial beta models).

**`EstimateContrast.contrasts`** — Manually defined T-contrasts, each specified as `[name, type, conditions, weights]`. Because `basic_contrasts: true` is inherited from the study template, the notebook first auto-generates one T-contrast per condition, then appends these differential contrasts.

For a simple pairwise difference, use `[1, -1]`. When averaging across multiple conditions, weights should reflect the balanced comparison — e.g. `[0.5, 0.5, -0.5, -0.5]` contrasts two smoke conditions against two non-smoke conditions. Each contrast is validated per subject: if a condition is absent from that subject's events, the contrast is dropped for that subject only with a warning, and the job is still created and submitted.

---

## Creating a New Model

To define a new model variant — a different event grouping, a parametric modulator, or different SPM settings — follow these steps:

1. Copy an existing model JSON and rename it: `model_{task}-{newname}.json`
2. Update `"Info": {"model": "newname"}` — this determines the output directory name
3. Keep the same `Template` references unless you need to change study- or task-level settings
4. Modify `event_options`, `pmod`, `contrasts`, or any other keys as needed
5. Point the notebook at the new file and run

You do not need to duplicate paths, the TR, or SPM settings — those come from the templates automatically. Any template value can be overridden by redefining it in the model file.

### Adding a Parametric Modulator

To modulate a condition by a continuous variable from the event file, add a `pmod` block to `SpecifySPMModel`:

```json
"SpecifySPMModel": {
    "pmod": {
        "standard_smoke": "craving_rating"
    },
    "pmod_options": ["zscore"]
}
```

This adds `standard_smokexcraving_rating^1` as an additional regressor alongside the main condition regressor. `pmod_options` transforms the modulator values before passing them to SPM. Available operations, applied in order: `"zscore"` (standardize to mean=0, SD=1), `"rank"` (replace with rank order), `"minmax_scale"` (scale to [0, 1]), and `"fillna"` (replace NaN with column mean).

If a subject has zero variance in the modulator, the pmod is dropped for that subject to avoid a singular design matrix, and the issue is reported in the notebook output. If individual trials have missing values, those trials are separated into a `{condition}_nopmod` regressor rather than dropped, so no data is lost.

### Per-Subject Run Exclusions

To exclude specific runs for specific subjects (e.g. a run with a scanner error), add to `Info.exclude.run` in the model or task JSON:

```json
"exclude": {
    "sub": ["GEO021"],
    "run": {
        "GEO005": [3],
        "GEO012": [1, 2]
    }
}
```

---

## Troubleshooting

**"File missing" error in the notebook**
The notebook validates all functional, event, and regressor files before writing any job files. Check the printed path carefully. Common causes: fMRIPrep did not complete for that subject, the path template has the wrong session label, or motion regressor files from `generate_outlier_report.ipynb` have not been generated yet.

**"No subjects found" error**
Either `Info.sub` is empty or the `sub_container` glob pattern matches no directories. To debug, run `glob.glob(os.path.join(env['data_path'], sub_container, 'sub-*/'))` in the notebook.

**Contrast removed for some subjects**
If a trial type is absent from a subject's events, any contrast requiring that condition is dropped for that subject only. This is reported as an issue in the notebook output. The job is still created and submitted — the missing contrast simply will not appear in that subject's output.

**Pmod zero-variance warning**
If a modulator has no variability for a given subject, the pmod is dropped for that subject to prevent a singular design matrix. The issue is reported in the notebook output.

**Job fails with no useful output in `.err`**
Check that the Matlab license server is reachable from the cluster (`squeue` will show the job as failed very quickly if not). If the `.err` file says only `Killed` or is empty, the job likely hit the memory limit — increase `#SBATCH --mem` in the Slurm job template.

**Re-running a subject**
Delete the subject's output and working directories before resubmitting, then re-run the notebook to regenerate the job file:

```bash
rm -rf data/bids_data/derivatives_nocorrection/nipype/{task-X_model-Y}/sub-{ID}
rm -rf data/bids_data/derivatives_nocorrection/working/nipype/{task-X_model-Y}/sub-{ID}
```

**Inspecting the resolved job JSON**
Before submitting, open `scripts/L1/jobs/{task-X_model-Y}/jobs/sub-{ID}.json` to see the fully merged model with all paths, event files, regressors, and contrasts resolved for that subject. This is the exact specification passed to SPM and is a useful first check when debugging unexpected model behavior.
