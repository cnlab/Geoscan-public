# Step 3: fMRIPrep

fMRIPrep is a robust preprocessing pipeline for fMRI data. It performs brain extraction, surface reconstruction, susceptibility distortion correction (SDC), motion correction, spatial normalization, and confound estimation — all documented in a detailed HTML report per participant.

---

## What fMRIPrep Does

fMRIPrep takes your BIDS dataset as input and produces preprocessed NIfTI files and a rich set of confound regressors in `derivatives/`. Key steps include:

- **Anatomical:** brain extraction (ANTs), surface reconstruction (FreeSurfer), tissue segmentation, normalization to MNI space
- **Functional:** slice timing correction (optional), head motion correction, susceptibility distortion correction, registration to anatomical, spatial normalization, confound estimation (motion parameters, CompCor, global signal, FD, DVARS)

Full documentation: [fmriprep.readthedocs.io](https://fmriprep.readthedocs.io)

---

## Distortion Correction Mode

fMRIPrep offers several SDC approaches. This project uses **no fieldmap correction** (`--ignore fieldmaps`), meaning no susceptibility distortion correction is applied. This was chosen because [note your reason here — e.g., fieldmaps were not acquired for all sessions / fieldmap quality was insufficient].

The job template in `fmriprep_slurm.ipynb` reflects this. If you need to switch modes, two alternatives are documented as comments in that notebook:

| Mode | Flag(s) | When to use |
|------|---------|-------------|
| **Fieldmap (B0 map)** | *(default, no flag needed)* | Fieldmaps acquired and in BIDS with `IntendedFor` set |
| **SyN (fieldmap-less)** | `--use-syn-sdc --ignore fieldmaps` | No fieldmaps; estimates distortion from T1w |
| **No correction** | `--ignore fieldmaps` | Skip SDC entirely |

---

## File Locations

All paths below are relative to the project root. The notebooks derive these automatically from their location at `scripts/FMRIPREP/`.

| Data type | Path |
|-----------|------|
| BIDS input | `data/bids_data/` |
| fMRIPrep output | `data/bids_data/derivatives_nocorrection/` |
| Working directory | `data/bids_data/derivatives_nocorrection/working/` |
| FreeSurfer license | `/data00/tools/freesurfer/license.txt` |
| Singularity image | `/data00/tools/singularity_images/fmriprep-20.0.6.simg` |
| Slurm job scripts | `scripts/FMRIPREP/jobs/` |

---

## Scripts

| Script | Description |
|--------|-------------|
| `fmriprep_slurm.ipynb` | Generate Slurm job scripts and print submission commands |
| `view_fmriprep_report.ipynb` | Render a participant's fMRIPrep HTML report inline in the notebook |
| `outlier_detection.ipynb` | Load confounds, compute FD statistics, generate per-run QC plots and HTML reports |
| `generate_outlier_report.ipynb` | Rule-based + auto-motion outlier detection; produces motion regressor files and outlier GIFs |
| `config.R` | Configuration for the `auto-motion-fmriprep` R script used by `generate_outlier_report.ipynb` |

---

## Workflow

### 1. Generate and Submit Jobs

1. Open `fmriprep_slurm.ipynb`
2. All paths are derived automatically — no variables to edit unless you are changing projects
3. Run **Generate Job Scripts** — creates one `.job` file per subject in `scripts/FMRIPREP/jobs/`
4. Run **Print sbatch Commands** — prints the commands to submit
5. SSH to the Slurm cluster and paste:

```bash
ssh <username>@asc.upenn.edu@cls000

cd /data00/projects/{project}/scripts/FMRIPREP/jobs
sbatch -D . -c 8 fmriprep-nocorrection_sub-001.job
sbatch -D . -c 8 fmriprep-nocorrection_sub-002.job
...
```

### 2. Monitor and Re-run

fMRIPrep jobs typically run for several hours per subject. To check job status:
```bash
squeue -u <username>
```

If a subject needs to be re-run (e.g., after fixing BIDS errors), delete the old output first to avoid stale file conflicts. A helper cell in `fmriprep_slurm.ipynb` handles this.

### 3. Review Reports

Once jobs complete, open `view_fmriprep_report.ipynb` to render an individual participant's HTML report directly in the notebook. Review at minimum:
- Registration quality (T1w → MNI, BOLD → T1w)
- Brain mask coverage
- Carpet plot (temporal SNR, FD trace)

### 4. QC and Outlier Detection

Two complementary QC notebooks are available:

**`outlier_detection.ipynb`** — FD-based analysis:
- Loads confounds for one or all subjects
- Calculates FD statistics per run (mean, max, % volumes exceeding threshold)
- Generates FD time-series plots with high-motion volumes marked
- Produces standalone HTML QC reports, optionally appended to fMRIPrep's own reports

**`generate_outlier_report.ipynb`** — Rule-based + auto-motion detection:
- Runs the `auto-motion-fmriprep` R script (configured via `config.R`)
- Applies rule-based thresholds (global signal > 3 SD, FD > 0.75 mm)
- Produces per-subject motion regressor `.tsv` files (used in L1 modeling)
- Generates animated GIFs of outlier volumes for visual inspection
- Outputs `outlier_auto.csv`, `outlier_manual.csv`, and `outlier_summary.csv`

---

## Singularity Command Explained

```bash
singularity run --cleanenv \
    -B /data00/tools/freesurfer/license.txt:/opt/freesurfer/license.txt \  # required FreeSurfer license
    -B {bids_dir}:/data \          # BIDS input
    -B {derivatives_dir}:/out \   # output destination
    -B {working_dir}:/work \      # intermediate files
    -B {home_dir}:/home/fmriprep \ # writable home for fMRIPrep
    --home /home/fmriprep \
    fmriprep-25.0.0.simg /data /out participant \
    --participant-label {ID} \    # subject ID without 'sub-' prefix
    -w /work \
    --ignore slicetiming fieldmaps \  # skip slice timing correction and SDC
    --nthreads 8 \
    --skip-bids-validation
```

> **`--ignore slicetiming`**: Slice timing correction is skipped here. If your acquisition has meaningful inter-slice timing differences and you have the slice timing metadata in your BIDS JSON files, remove this flag.

> **`--skip-bids-validation`**: Skips the internal BIDS validator check to save time. Only use this after you have already confirmed the dataset passes the BIDS Validator externally.

---

## Expected Output

After a successful run, each subject's derivatives will contain:

```
derivatives_nocorrection/
├── fmriprep/
│   ├── sub-001/
│   │   ├── anat/
│   │   │   ├── sub-001_space-MNI152NLin2009cAsym_desc-preproc_T1w.nii.gz
│   │   │   └── sub-001_space-MNI152NLin2009cAsym_dseg.nii.gz
│   │   └── func/
│   │       ├── sub-001_task-image_run-1_space-MNI152NLin2009cAsym_desc-preproc_bold.nii.gz
│   │       ├── sub-001_task-image_run-1_desc-confounds_timeseries.tsv  ← confounds for modeling
│   │       └── sub-001_task-image_run-1_desc-confounds_timeseries.json
│   └── sub-001.html   ← visual QC report
└── freesurfer/
    └── sub-001/       ← FreeSurfer reconstruction
```

The `desc-confounds_timeseries.tsv` files are the key output for the modeling steps — they contain motion parameters, CompCor components, global signal, FD, and DVARS used as nuisance regressors.

---

## Troubleshooting

**Job fails immediately with no output**
Ensure the `out/` log directory exists inside the jobs folder. The notebook creates this automatically, but check: `ls scripts/FMRIPREP/jobs/out/`.

**FreeSurfer license error**
Confirm `/data00/tools/freesurfer/license.txt` exists and is readable. This bind-mount is required even if you are not running surface reconstruction.

**Working directory conflicts on re-run**
Delete the subject's working directory node before resubmitting: the re-run helper cell in `fmriprep_slurm.ipynb` does this.

**`--home` directory errors**
fMRIPrep v25+ requires a writable home directory. The job script bind-mounts `scripts/FMRIPREP/home_dir/` for this purpose. Create it if it doesn't exist: `mkdir -p scripts/FMRIPREP/home_dir`.

---

## Next Step

After reviewing QC reports and generating motion regressor files, proceed to **[Step 4: L1 Modeling](README_4_L1.md)**.
