# Heudiconv Tutorial

This tutorial walks you through configuring and running `heudiconv` for a new project. It is meant to be read alongside `heudiconv_single.ipynb` and consulted when writing your `heuristic.py` file.

For a quick reference on running the conversion, see [`README_2_bids.md`](README_2_bids.md).

**External references:**
- [BIDS specification](https://bids.neuroimaging.io/)
- [Stanford BIDS + heudiconv tutorial](http://reproducibility.stanford.edu/bids-tutorial-series-part-2a/)
- [heudiconv heuristics documentation](https://heudiconv.readthedocs.io/en/latest/heuristics.html)
- [heudiconv step-by-step guide](https://neuroimaging-core-docs.readthedocs.io/en/latest/pages/heudiconv.html)
- [BIDS Validator error reference](https://neuroimaging-core-docs.readthedocs.io/en/latest/pages/bids-validator.html#bidsvalidator)

---

## Overview: How heudiconv works

heudiconv converts raw DICOMs into NIfTI files organized according to the BIDS standard. It runs in two phases:

**Phase 1 — Heuristic/scan mode** (`-c none`): Run once on a representative subject to produce a `dicominfo.tsv` describing every scan series and a `heuristic.py` template to fill in. No files are converted yet.

**Phase 2 — Conversion mode** (`-c dcm2niix`): Run on all subjects using your completed `heuristic.py`. Converts DICOMs to NIfTIs and places them in the correct BIDS folder structure.

> **For existing projects** with a working `heuristic.py`, skip directly to Phase 2 and the [Looping Through Participants](#looping-through-participants) section.

---

## Phase 1: Running heudiconv in Scan Mode

Open `heudiconv_single.ipynb`. Set your paths and run the Phase 1 cell, which calls heudiconv like this:

```bash
singularity run --cleanenv \
    -B /data00/projects/{your_project}/data/bids_data:/base \
    -B /fmriDataRaw/fmri_data_raw:/raw \
    /data00/tools/singularity_images/heudiconv_0.8.0 \
    -d /raw/{your_project}/{subject}/*/*.dcm \
    -o heudiconv/ -f convertall -s {subject} -c none --overwrite
```

**What each flag means:**

| Flag | Meaning |
|------|---------|
| `-B /data00/projects/...:/base` | Bind-mounts your project directory into the container as `/base` |
| `-B /fmriDataRaw/fmri_data_raw:/raw` | Bind-mounts the raw DICOM directory into the container as `/raw` |
| `/data00/tools/singularity_images/heudiconv_0.8.0` | Path to the heudiconv Singularity image (currently v0.8.0) |
| `-d /raw/{project}/{subject}/*/*.dcm` | Glob pattern for finding DICOM files; `/raw` maps to `/fmriDataRaw/fmri_data_raw` |
| `-o heudiconv/` | Output directory for Phase 1 results |
| `-f convertall` | Include all scan types (do not filter) |
| `-s {subject}` | The subject ID to process (e.g. `GEO053`) |
| `-c none` | Scan mode — inspect DICOMs but do not convert |
| `--overwrite` | Overwrite previous Phase 1 output if it exists |

After running, the output lands in a hidden folder:
```
heudiconv/.heudiconv/{subject}/info/
├── dicominfo_ses-{session}.tsv
├── heuristic.py           ← template to edit
├── {subject}_ses-{session}.auto.txt
└── {subject}_ses-{session}.edit.txt
```

---

## Inspecting `dicominfo.tsv`

The notebook loads `dicominfo.tsv` into a Pandas dataframe. The most useful columns for writing your heuristic are:

| Column | What it tells you |
|--------|------------------|
| `series_id` | Unique scan series identifier (number + name) |
| `series_description` | Human-readable scan name from the scanner |
| `dim1`, `dim2`, `dim3` | Voxel dimensions (x, y, z) |
| `dim4` | Number of volumes — critical for filtering out partial/aborted runs |
| `TR` / `TE` | Repetition and echo time |
| `sequence_name` | Scanner sequence code |

---

## Configuring `heuristic.py`

Your `heuristic.py` lives at:
```
{project}/scripts/BIDS/heudiconv/code/heuristic.py
```

It needs two things: **KEYS** and **MATCHES**.

---

### Part 1: KEYS

Keys define the BIDS output path and filename template for each scan type, using `create_key()` inside the `infotodict()` function.

**Rules:**
- Use `{subject}` to generalize across participants
- Use `{session}` if your study has multiple sessions — it must appear in **both** the subdirectory path and the filename, or the BIDS validator will error
- Use `{item:01d}` to auto-increment run numbers when the same sequence repeats
- End every filename with the BIDS modality suffix (`_T1w`, `_bold`, `_epi`, etc.)

```python
def infotodict(seqinfo):

    # ── Anatomical ─────────────────────────────────────────────────────────────
    t1w = create_key('sub-{subject}/ses-{session}/anat/sub-{subject}_ses-{session}_T1w')
    t2w = create_key('sub-{subject}/ses-{session}/anat/sub-{subject}_ses-{session}_T2w')

    # ── Functional BOLD ────────────────────────────────────────────────────────
    # {item:01d} auto-increments: run-1, run-2, run-3 ...
    func_image = create_key('sub-{subject}/ses-{session}/func/sub-{subject}_ses-{session}_task-image_run-{item:01d}_bold')

    # ── Fieldmaps ──────────────────────────────────────────────────────────────
    fmap = create_key('sub-{subject}/ses-{session}/fmap/sub-{subject}_ses-{session}_acq-{item:01d}_epi')

    # Collect all keys in a dictionary — values are filled in by the MATCH section
    info = {
        t1w: [],
        t2w: [],
        func_image: [],
        fmap: [],
    }
```

---

### Part 2: CONDITIONAL MATCHES

Matches are `if` statements inside a `for s in seqinfo:` loop that read fields from the `dicominfo.tsv` and assign scan series to keys. Add a series to the relevant key's list with `info[key].append(s.series_id)`.

**Two types of criteria:**

- **Equality check** — good for numeric fields like dimensions:
  `s.dim3 == 176`
- **Substring check** — good for series names (case-sensitive):
  `'MPRAGE' in s.series_id`

**Using `dim4` to filter partial runs:** If a scan was aborted and restarted, you will have two rows in `dicominfo.tsv` with the same `series_description` but different `dim4`. Filter on the expected full-run volume count to exclude the partial scan:

```python
    for s in seqinfo:

        # T1w MPRAGE: specific dimensions + series name
        if (s.dim1 == 256) and (s.dim2 == 192) and ('MPRAGE_TI1100_ipat2' in s.series_id):
            info[t1w].append(s.series_id)

        # T2w SPACE
        if (s.dim1 == 256) and (s.dim3 == 176) and ('T2_1mm_SPACE' in s.series_id):
            info[t2w].append(s.series_id)

        # BOLD: 395 volumes = full run; this filters out any aborted partial scans
        if (s.dim4 == 395) and ('BOLD_IMAGE' in s.series_id):
            info[func_image].append(s.series_id)

        # Fieldmaps
        if 'FieldMap_PA' in s.series_id:
            info[fmap].append(s.series_id)

    return info
```

> **Tip:** Key variable names (e.g. `t1w`, `func_image`) can be anything — just be consistent. The BIDS output path in `create_key()` is what determines the actual file name.

> **If your keys or conditions were wrong** and you need to re-run Phase 1, delete the participant's hidden folder in both places before re-running:
> ```bash
> rm -fr heudiconv/.heudiconv/
> rm -fr /data00/projects/{project}/data/bids_data/.heudiconv/
> ```
> You may also want to delete the partially-converted subject folder in `bids_data/` before trying again.

---

## Multi-Session Studies

If your project has multiple scan sessions, add the `-ss` flag with the session name to every heudiconv call. You must run Phase 1 and Phase 2 **separately for each session.**

### Phase 1 — Scan each session separately

```bash
# Session 1
singularity run --cleanenv \
    -B /data00/projects/geoscan_v2:/base \
    -B /fmriDataRaw/fmri_data_raw:/raw \
    /data00/tools/singularity_images/heudiconv_0.8.0 \
    -d /raw/geoscan_R01/{subject}_session_1/*/*.dcm \
    -o heudiconv/ -ss session01 -f convertall -s {subject} -c none --overwrite

# Session 2
singularity run --cleanenv \
    -B /data00/projects/geoscan_v2:/base \
    -B /fmriDataRaw/fmri_data_raw:/raw \
    /data00/tools/singularity_images/heudiconv_0.8.0 \
    -d /raw/geoscan_R01/{subject}_session_2/*/*.dcm \
    -o heudiconv/ -ss session02 -f convertall -s {subject} -c none --overwrite
```

### Configure `heuristic.py` for sessions

Include `{session}` in both the folder path **and** filename — this is required:

```python
def infotodict(seqinfo):

    t1w = create_key('sub-{subject}/{session}/anat/sub-{subject}_{session}_T1w')
    func_image = create_key('sub-{subject}/{session}/func/sub-{subject}_{session}_task-image_run-{item:01d}_bold')

    info = {t1w: [], func_image: []}

    for s in seqinfo:
        if 'MPRAGE_TI1100_ipat2' in s.series_id:
            info[t1w].append(s.series_id)
        if (s.dim3 == 56) and ('BOLD_IMAGE_run' in s.series_id):
            info[func_image].append(s.series_id)

    return info
```

### Phase 2 — Convert each session separately

```bash
# Session 1
singularity run --cleanenv \
    -B /data00/projects/geoscan_v2:/base \
    -B /fmriDataRaw/fmri_data_raw:/raw \
    /data00/tools/singularity_images/heudiconv_0.8.0 \
    -d /raw/geoscan_R01/{subject}_session_1/*/*.dcm \
    -o /base/data/bids_data/ \
    -f /base/scripts/BIDS/heudiconv/code/heuristic.py \
    -s {subject} -ss session01 -c dcm2niix -b --overwrite

# Session 2
singularity run --cleanenv \
    -B /data00/projects/geoscan_v2:/base \
    -B /fmriDataRaw/fmri_data_raw:/raw \
    /data00/tools/singularity_images/heudiconv_0.8.0 \
    -d /raw/geoscan_R01/{subject}_session_2/*/*.dcm \
    -o /base/data/bids_data/ \
    -f /base/scripts/BIDS/heudiconv/code/heuristic.py \
    -s {subject} -ss session02 -c dcm2niix -b --overwrite
```

---

## Looping Through Participants

Once `heuristic.py` is configured and tested on one subject, use `heudiconv_batch.ipynb` to run the rest of your participants.

Two options are available — choose based on your dataset size and cluster availability:

| Option | When to use |
|--------|-------------|
| **Bash loop in notebook** | Small datasets, quick re-runs, no cluster access |
| **Slurm job submission** | Large datasets, run subjects in parallel on the HPC |

### Running on the cluster (Slurm)

The batch notebook generates `.job` files and prints the `sbatch` commands. To submit:

1. SSH to the Slurm master node:
   ```bash
   ssh <JANUS_UN>@asc.upenn.edu@cls000
   ```
2. Paste the printed `sbatch` commands into the terminal — one per subject

---

## Final Checklist Before fMRIPrep

Before moving on, confirm the following:

- [ ] `heuristic.py` is saved to `{project}/scripts/BIDS/heudiconv/code/heuristic.py`
- [ ] Phase 1 hidden folder (`.heudiconv/`) has been deleted
- [ ] All subjects converted successfully in `bids_data/`
- [ ] `fieldmap_intendedfor.ipynb` has been run to add `IntendedFor` to fieldmap JSON files
- [ ] BIDS dataset passes the [BIDS Validator](https://bids-standard.github.io/bids-validator/)
