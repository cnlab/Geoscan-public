# Step 1: DICOM Transfer

This step covers getting your raw scan data from [UPenn Flywheel](https://upenn.flywheel.io/) onto the fMRI server, organized and ready for BIDS conversion.

---

## Overview

Raw fMRI data is acquired and stored on Flywheel. Before any processing can begin, DICOMs need to be transferred to the server and organized into a consistent folder structure. The scripts in this step handle that transfer using the [Flywheel Python SDK](https://flywheel-io.gitlab.io/product/backend/sdk/branches/master/python/index.html).

**You do not have to use these scripts.** As long as your DICOMs end up in the expected directory structure (see below), the rest of the pipeline will work regardless of how they were transferred — manual download, `rsync`, or any other method. The notebook here is simply a convenience wrapper for the Flywheel SDK download.

---

## Expected Output Structure

After this step, your DICOMs should be organized as follows:

```
/fmriDataRaw/fmri_data_raw/
└── {PROJECT}/
    ├── sub-001/
    │   └── *.dcm  (or scan-labeled subdirectories)
    ├── sub-002/
    └── ...
```

> **This structure is what matters.** BIDS conversion (Step 2) will look for DICOMs organized by subject under the project directory. As long as your files land here in a consistent layout, the conversion scripts will work.

---

## Prerequisites

### Flywheel Access

- Log in via Pennkey at https://upenn.flywheel.io/
- Navigate to your **Profile** page to retrieve your **API key** — treat this like a password and never commit it to version control
- Your data is organized in Flywheel under: `Group / Project / Subject / Session`
  - Example lookup path: `falklab/myproject/sub-001/CAMRIS^Falk`

### Python Environment

Install the Flywheel SDK if not already available:

```bash
pip install flywheel-sdk
```

### Config File Setup

Your API key is stored in a local config file that is excluded from version control (`.gitignore` includes `*.ini`). On first use, run the config setup cell in the notebook to create:

```
~/configs/config.ini
```

---

## Scripts

| Script | Description |
|--------|-------------|
| `flywheel_download_single.ipynb` | Download DICOMs for a single participant — start here |
| `flywheel_download_batch.ipynb` | Loop across a list of participants and download in bulk |

Both notebooks follow the same core logic. The batch version wraps the single-subject workflow in a reusable `transfer_data()` function and loops over a participant list. Always run the single-subject notebook first to confirm your credentials and Flywheel labels are correct before running the batch.

---

## Running the Download (Single Subject)

1. Open `flywheel_download_single.ipynb`
2. On first run, follow the **API Key Setup** section to create your config file at `~/configs/config.ini`
3. Set your project and participant variables:
   ```python
   group_label          = "your_group"          # Flywheel group (e.g. lab name)
   project_label        = "your_project"        # Flywheel project label
   subject_id_flywheel  = "sub-001"             # Subject ID as listed on Flywheel
   out_project          = "your_local_project"  # Local folder under /fmriDataRaw/fmri_data_raw/
   subject_id_local     = "sub-001"             # Subject ID for local storage
   ```
4. Run all cells — the notebook will:
   - Authenticate with the Flywheel API
   - Look up the session for your subject
   - Download a `.tar` archive (~1 GB) to a local `working_data/` directory
   - Extract all `dicom.zip` archives into the subject's output directory on the server
5. Verify the output with the final listing cell

## Running the Download (Batch / All Participants)

1. Confirm the single-subject notebook works for at least one subject first
2. Open `flywheel_download_batch.ipynb`
3. Set the shared project variables and your participant list:
   ```python
   group_label  = "your_group"
   in_project   = "your_project"
   in_prefix    = "sub"           # prefix as listed on Flywheel
   out_project  = "your_local_project"
   out_prefix   = "sub"           # prefix for local storage (can differ from in_prefix)
   subs         = ['001', '002', '003', ...]  # numeric portion only, without prefix
   ```
4. Run the loop cell — the notebook will iterate through each subject and:
   - **Skip** any subject whose output directory already exists (safe to re-run after failures)
   - Report any failed subjects in a summary at the end
5. Re-add any failed subjects to `subs` and re-run, or use the single-subject notebook to debug them individually

---

## Cleaning Up

The `.tar` archives downloaded to `working_data/` can be large (~1 GB per subject). Once you have verified the DICOMs extracted correctly, you can safely delete them:

```bash
# Verify your path before running — this deletes recursively!
rm -r /path/to/project/working_data/
```

Flywheel retains the original data, so you can always re-download if needed.

---

## Troubleshooting

**API key not found / authentication error**
Run the config setup cell again and confirm your key matches what's shown at https://upenn.flywheel.io/#/profile.

**Output directory permission errors**
JupyterHub may not respect secondary group permissions. If you hit a permissions error on directory creation, contact your system admin or manually set permissions:
```bash
sudo chgrp <your_group> -R /fmriDataRaw/fmri_data_raw/
```

**Session not found on Flywheel lookup**
Double-check the group label, project label, and subject ID. These must match exactly as they appear in the Flywheel URL.

---

## Next Step

Once your DICOMs are on the server and organized by subject, proceed to **[Step 2: BIDS Conversion](README_2_bids.md)**.