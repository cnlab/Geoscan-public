# Step 2: DICOM to BIDS Conversion

This step converts raw DICOM files into [NIfTI](https://nifti.nimh.nih.gov/) format and organizes them into a [BIDS-compliant](https://bids-specification.readthedocs.io/) directory structure using [heudiconv](https://heudiconv.readthedocs.io/en/latest/), run inside a Singularity container.

---

## What is BIDS and why does it matter?

The Brain Imaging Data Structure (BIDS) is a standardized way of organizing neuroimaging data. Consistent naming and folder layout means downstream tools like fMRIPrep and MRIQC can find your files automatically without custom configuration. A BIDS dataset looks like this:

```
bids_data/
├── dataset_description.json
├── participants.tsv
├── sub-001/
│   ├── anat/
│   │   ├── sub-001_T1w.nii.gz
│   │   └── sub-001_T1w.json
│   ├── func/
│   │   ├── sub-001_task-rest_run-1_bold.nii.gz
│   │   └── sub-001_task-rest_run-1_bold.json
│   └── fmap/
│       ├── sub-001_acq-1_epi.nii.gz
│       └── sub-001_acq-1_epi.json
└── sub-002/
    └── ...
```

---

## What is heudiconv?

`heudiconv` (heuristic DICOM converter) automates the conversion from DICOM to NIfTI and handles BIDS naming. It works in two phases:

**Phase 1 — Heuristic mode** (`-c none`): Run on one representative subject to scan all DICOMs and produce a `dicominfo.tsv` file describing every scan series found. No files are converted yet — this is just reconnaissance.

**Phase 2 — Conversion mode** (`-c dcm2niix`): Run on all subjects using a `heuristic.py` configuration file you write based on the Phase 1 output. This actually converts DICOMs to NIfTIs and places them in the correct BIDS folder structure.

> **For new projects:** You must complete Phase 1 once before proceeding. If you are adding new participants to an existing project with a working `heuristic.py`, you can skip directly to Phase 2.

---

## File Locations

| Data type | Path |
|-----------|------|
| Raw DICOMs | `/fmriDataRaw/fmri_data_raw/{project}/{subject}/` |
| BIDS output | `/data00/projects/{project}/data/bids_data/` |
| heudiconv config files | `/data00/projects/{project}/scripts/BIDS/heudiconv/` |
| heuristic.py | `/data00/projects/{project}/scripts/BIDS/heudiconv/code/heuristic.py` |
| Job scripts | `/data00/projects/{project}/scripts/BIDS/jobs/` |

---

## Scripts

| Script | Description |
|--------|-------------|
| `heudiconv_single.ipynb` | Phase 1 + Phase 2 for a single subject — start here for new projects or to debug |
| `heudiconv_batch.ipynb` | Phase 2 only — run conversion across all subjects via bash loop or Slurm |
| `fieldmap_intendedfor.ipynb` | Post-conversion — add `IntendedFor` field to fieldmap JSON sidecars |
| [`heudiconv_tutorial.md`](heudiconv_tutorial.md) | Detailed tutorial: flag explanations, `heuristic.py` guide, multi-session setup |

---

## Step-by-Step Workflow

### Phase 1: Configure heudiconv for a New Project

> **Skip this phase if your project already has a working `heuristic.py`.**

1. Open `heudiconv_single.ipynb`
2. Set your path variables and choose a representative subject (one with a complete set of scans)
3. Run the **Phase 1** cell — this calls heudiconv in `convertall` / `-c none` mode:
   ```bash
   singularity run --cleanenv \
       -B /data00/projects/{project}:/base \
       -B /fmriDataRaw/fmri_data_raw:/raw \
       /data00/tools/singularity_images/heudiconv_0.8.0 \
       -d /raw/{project}/{subject}/*/*.dcm \
       -o heudiconv/ -f convertall -s {subject} -c none --overwrite
   ```
4. Inspect the output `dicominfo.tsv` — the notebook loads it into a Pandas dataframe so you can easily see the scan series and their dimensions
5. **Edit `heuristic.py`** (see below) to map scan series to BIDS file names
6. Delete the `.heudiconv/` hidden folder so Phase 2 runs cleanly
7. Proceed to Phase 2

#### Writing `heuristic.py`

The heuristic file defines two things:

**KEYS** — BIDS output file path templates, created with `create_key()`:
```python
# Anatomical scans
t1w = create_key('sub-{subject}/ses-{session}/anat/sub-{subject}_ses-{session}_T1w')
t2w = create_key('sub-{subject}/ses-{session}/anat/sub-{subject}_ses-{session}_T2w')

# Functional BOLD runs
func_image = create_key('sub-{subject}/ses-{session}/func/sub-{subject}_ses-{session}_task-image_run-{item:01d}_bold')

# Fieldmaps
fmap = create_key('sub-{subject}/ses-{session}/fmap/sub-{subject}_ses-{session}_acq-{item:01d}_epi')
```

**MATCHES** — conditional logic that reads fields from `dicominfo.tsv` and assigns each scan series to a key. Use `series_description` and dimension fields (`dim1`–`dim4`) to uniquely identify each scan type. The `dim4` field (number of volumes) is especially useful for filtering out partial/aborted runs:
```python
for s in seqinfo:
    # T1w anatomical: 256x192x160 volume, named MPRAGE
    if (s.dim1 == 256) and (s.dim2 == 192) and ('MPRAGE_TI1100_ipat2' in s.series_id):
        info[t1w].append(s.series_id)

    # Functional BOLD: 395 volumes (full run), named BOLD_IMAGE
    if (s.dim4 == 395) and ('BOLD_IMAGE' in s.series_id):
        info[func_image].append(s.series_id)

    # Fieldmaps: B0map series
    if 'B0map' in s.series_id:
        info[fmap].append(s.series_id)
```

> **Geoscan reference:** The geoscan project used sessions `t2` and `t3`, subjects labeled `GEO###`, 5 BOLD runs of 395 volumes each (84×84×56), a T1w MPRAGE (256×192×160), a T2w SPACE (256×256×176), and PA-direction EPI fieldmaps. The `heuristic.py` for geoscan is a good reference for multi-run, multi-session setups.

---

### Phase 2: Convert DICOMs to BIDS NIfTIs

Once `heuristic.py` is in place:

**Single subject (for testing or debugging):**
1. Open `heudiconv_single.ipynb`
2. Set your subject ID and paths
3. Run the **Phase 2** conversion cell:
   ```bash
   singularity run --cleanenv \
       -B /data00/projects/{project}:/base \
       -B /fmriDataRaw/fmri_data_raw:/raw \
       /data00/tools/singularity_images/heudiconv_0.8.0 \
       -d /raw/{project}/{subject}/*/*.dcm \
       -o /base/data/bids_data/ \
       -f /base/scripts/BIDS/heudiconv/code/heuristic.py \
       -s {subject} -c dcm2niix -b --overwrite
   ```
4. Verify the output BIDS structure

**Batch (all participants) — two options:**

Open `heudiconv_batch.ipynb` and choose your mode:

*Option A — Bash loop in notebook:* Generates a `.job` file per subject and runs it immediately with `bash`. Good for small datasets or when the cluster is unavailable.

*Option B — Slurm:* Generates `.job` files with Slurm headers (`#SBATCH`) and prints the `sbatch` commands. SSH to the cluster and paste the output to submit jobs in parallel. Best for large datasets.

```bash
# SSH to the Slurm master node
ssh <username>@asc.upenn.edu@cls000

# Then submit each job (printed by the notebook)
cd /data00/projects/{project}/scripts/BIDS/jobs/heudiconv
sbatch -D . -c 8 heudiconv_sub-001.job
sbatch -D . -c 8 heudiconv_sub-002.job
...
```

---

### Phase 3: Add `IntendedFor` to Fieldmap JSON Files

After conversion, heudiconv does not automatically know which functional runs each fieldmap is intended to correct. You must add an `IntendedFor` field to each fieldmap's JSON sidecar file so that fMRIPrep applies the right fieldmap to the right BOLD runs.

1. Open `fieldmap_intendedfor.ipynb`
2. Set `bids_dir` and your subject list
3. For each fieldmap acquisition (`acq-1`, `acq-2`, etc.), edit the matching logic to map it to the correct functional run(s):
   ```python
   # Example: acq-1 fieldmap covers the image task runs
   fmap = [files matching 'acq-1' in fmap/]
   func = [files matching 'task-image' in func/]
   add_intendedfor(SUBJ_DIR, fmap, func)
   ```
4. The function updates the JSON in-place and prints confirmation

> ⚠️ **This step is required before running fMRIPrep.** If `IntendedFor` is missing, fMRIPrep will skip susceptibility distortion correction for those runs.

---

## Verifying Your BIDS Dataset

After conversion, run the [BIDS Validator](https://bids-standard.github.io/bids-validator/) to check for errors:

```bash
# Online: drag your bids_data/ folder to https://bids-standard.github.io/bids-validator/

# Or via Docker/Singularity:
singularity run /data00/tools/singularity_images/bids-validator \
    /data00/projects/{project}/data/bids_data/
```

Common warnings (not errors) you can safely ignore:
- `TASK_EVENTS_TSV_MISSING` — events files added separately in the modeling step
- `IntendedFor` warnings — resolved after running `fieldmap_intendedfor.ipynb`

---

## Expected Output

After a successful conversion, each subject directory should contain:

```
bids_data/sub-{ID}/ses-{session}/
├── anat/
│   ├── sub-{ID}_ses-{session}_T1w.nii.gz
│   ├── sub-{ID}_ses-{session}_T1w.json
│   ├── sub-{ID}_ses-{session}_T2w.nii.gz       # if T2w acquired
│   └── sub-{ID}_ses-{session}_T2w.json
├── func/
│   ├── sub-{ID}_ses-{session}_task-{name}_run-1_bold.nii.gz
│   ├── sub-{ID}_ses-{session}_task-{name}_run-1_bold.json
│   └── ... (one pair per run)
└── fmap/
    ├── sub-{ID}_ses-{session}_acq-1_epi.nii.gz
    ├── sub-{ID}_ses-{session}_acq-1_epi.json    # should contain IntendedFor after Step 3
    └── ...
```

---

## Troubleshooting

**heudiconv finds 0 DICOMs**
Check the `-d` path pattern. The glob pattern must match the actual directory structure of your DICOM files. Print `!ls` on the expected path first to confirm.

**`ERROR: Embedding failed: 'NoneType' object is not subscriptable`**
This is a known benign warning from heudiconv v0.8.0 related to metadata embedding. Conversion still succeeds — verify the NIfTI files were created.

**BIDS directory already exists / partial conversion**
Use `--overwrite` to force re-conversion. If subjects are partially converted, delete their subject folder first and re-run.

**Wrong number of volumes in a run**
If a scan was aborted and restarted, you may have two entries in `dicominfo.tsv` with the same `series_description` but different `dim4`. Use the `dim4` filter in `heuristic.py` to select only complete runs (e.g., `s.dim4 == 395`).

---

## Next Steps

- **Optional:** Run MRIQC on the BIDS dataset before proceeding — see [Step 2.5: MRIQC](README_2.5_mriqc.md)
- **Required:** Proceed to **[Step 3: fMRIPrep](README_3_fmriprep.md)**
