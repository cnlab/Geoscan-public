# fMRI Analysis Pipeline — Overview

This repository contains the full neuroimaging analysis pipeline used by the CNLab, covering everything from raw DICOM transfer through first- and second-level statistical modeling. The pipeline is built around [Nipype](https://nipype.readthedocs.io/en/latest/), with JSON-based job templates and [Slurm](https://slurm.schedmd.com/) submission scripts for running analyses on a high-performance computing (HPC) cluster.

---

## Pipeline Sections

| Step | Description |
|------|-------------|
| [1. DICOMs](#1-dicoms) | Transfer raw scan data from Flywheel to the server |
| [2. BIDS](#2-bids) | Convert DICOMs to NIfTI format following the BIDS standard |
| [2.5. MRIQC](#25-mriqc) | Run automated image quality metrics on your BIDS dataset |
| [3. fMRIPrep](#3-fmriprep) | Preprocess fMRI data and perform quality control |
| [4. L1 Modeling](#4-l1-modeling) | Run first-level (subject-level) GLM models |
| [5. L2 Modeling](#5-l2-modeling) | Run second-level (group-level) GLM models |

Each section has its own dedicated README with step-by-step instructions. See the links above or navigate to the relevant folder.

---

## Project Structure

```
Project Name/
├── data/
│   ├── behavioral/             # Raw behavioral data from task runs
│   └── bids_data/
│       ├── sub-001/            # BIDS-formatted fMRI data, participant 1
│       ├── sub-002/            # BIDS-formatted fMRI data, participant 2
│       └── derivatives/        # All outputs from processing and modeling
│
├── models/
│   ├── events/                 # events.tsv files for SPM models
│   ├── jobs/                   # JSON job templates for SPM
│   └── slurm/                  # Slurm job scripts for HPC submission
│
└── scripts/                    # CNLab pipeline scripts
                                # Copy from: data00/tools/cnlab_pipeline
```

---

## Key Technologies

**Nipype** drives the core processing workflows, providing a unified Python interface to tools like FSL, SPM, FreeSurfer, and ANTs. Workflow graphs are defined in Python and executed locally or dispatched to the cluster.

**JSON templates** define the parameters for SPM first- and second-level models (contrasts, regressors, smoothing kernel, etc.). Templates live in `models/jobs/` and are populated programmatically before job submission.

**Slurm** is used to submit computationally intensive jobs (fMRIPrep, L1/L2 modeling) to the HPC cluster. Job scripts live in `models/slurm/` and are generated alongside the JSON templates.

**Python Notebooks** are the primary interface for running this pipeline. Most steps — from BIDS conversion and quality checking through model setup and job submission — are executed interactively via Jupyter notebooks. This makes it easy to inspect outputs, tweak parameters, and re-run individual steps without rerunning the full pipeline.

---

## Dependencies & Required Tools

The following tools must be available in your environment before running the pipeline. Installation instructions and version requirements are noted where applicable.

### Containerized Tools (Singularity)

These tools are run inside [Singularity](https://docs.sylabs.io/guides/latest/user-guide/) containers on the HPC. Container images can be built using [Neurodocker](https://www.repronim.org/neurodocker/).

| Tool | Purpose | Notes |
|------|---------|-------|
| **fMRIPrep** | fMRI preprocessing | Recommended: `fmriprep >= 23.x` |
| **MRIQC** | Image quality metrics | Should match fMRIPrep version series |
| **Neurodocker** | Container image builder | Used to generate Singularity/Docker recipes |

> **Building containers with Neurodocker:**
> ```bash
> # Example: generate a Singularity recipe for fMRIPrep
> neurodocker generate singularity \
>     --base-image debian:bullseye \
>     --fmriprep version=23.2.0 \
>     > fmriprep.def
> singularity build fmriprep.sif fmriprep.def
> ```

### Local / Module Tools

These tools should be available as environment modules on the HPC or installed locally.

| Tool | Purpose | Notes |
|------|---------|-------|
| **FSL** | Neuroimaging utilities & GLM | `module load fsl` |
| **Python 3.x** | Pipeline scripting & notebooks | See Python packages below |
| **Jupyter** | Interactive notebook interface | Required to run pipeline notebooks |

### Python Packages

| Package | Purpose |
|---------|---------|
| `nipype` | Workflow engine and tool interfaces |
| `nilearn` | Neuroimaging data manipulation & visualization |
| `nibabel` | Reading/writing NIfTI and other neuroimaging formats |
| `pandas` | Tabular data handling (events files, metadata) |
| `numpy` | Numerical computing |
| *(add others here)* | |

> **Note:** A `requirements.txt` or `environment.yml` file for conda/pip setup will be added here.

### Additional Dependencies

*(Add any other tools, modules, or environment requirements specific to your cluster setup here.)*

---

## Getting Started

### 1. Set up your scripts directory

Copy the CNLab pipeline scripts to your project:

```bash
cp -r /data00/tools/cnlab_pipeline/* /path/to/your/project/scripts/
```

### 2. Follow the pipeline in order

Each step depends on the outputs of the previous one. Work through the sections sequentially:

```
DICOMs → BIDS → (MRIQC) → fMRIPrep → L1 → L2
```

MRIQC (step 2.5) is optional but recommended before committing to preprocessing.

### 3. Refer to section-specific READMEs

Each major step has its own README with detailed instructions, expected inputs/outputs, and example commands. These are located in the relevant subdirectories or in the `docs/` folder.

---

## Data Conventions

- All participant data should follow [BIDS 1.x](https://bids-specification.readthedocs.io/) naming conventions (e.g., `sub-001`, `ses-01`, `task-rest`).
- Derivatives (fMRIPrep outputs, model outputs) go under `data/bids_data/derivatives/`.
- Events files (`.tsv`) must match the BIDS events specification and live in `models/events/`.

---

## Section READMEs

- [`README_1_dicoms.md`](1-DICOMS/README.md) — Flywheel transfer & DICOM organization
- [`README_2_bids.md`](2-BIDS/README.md) — DICOM → NIfTI/BIDS conversion
- [`README_2.5_mriqc.md`](2.5-MRIQC/README.md) — MRIQC quality metrics
- [`README_3_fmriprep.md`](3-FMRIPREP/README.md) — fMRIPrep preprocessing & QC
- [`README_4_L1.md`](4-L1/README.md) — First-level modeling
- [`README_5_L2.md`](5-L2/README.md) — Second-level modeling

---

