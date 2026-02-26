# Step 2.5: MRIQC

MRIQC is an optional but highly recommended step that computes **image quality metrics (IQMs)** from your structural and functional MRI data before preprocessing. Running it early helps you catch problematic scans, motion-corrupted runs, or scanner issues before investing time in fMRIPrep.

---

## What is MRIQC?

[MRIQC](https://mriqc.readthedocs.io/en/stable/about.html) extracts no-reference IQMs from T1w, T2w, and BOLD data. It does **not** preprocess your data — it only measures quality. It is built on Nipype and integrates FSL, ANTs, and AFNI internally, follows BIDS, and is distributed as a BIDS App that reads directly from your `bids_data/` directory.

Outputs include:

- **Per-participant HTML reports** with visual QC panels and metric summaries
- **Group-level HTML report** aggregating metrics across all participants
- **JSON files** of all IQMs per scan, and a **group TSV** for downstream exclusion decisions

---

## When to Run It

Run MRIQC **after BIDS conversion (Step 2) and before fMRIPrep (Step 3)**. This gives you a chance to:

- Flag participants with excessive motion or signal dropout before the expensive preprocessing step
- Catch BIDS formatting issues that would also cause fMRIPrep to fail
- Build a QC exclusion list early in the pipeline

---

## File Locations

| Data type | Path |
|-----------|------|
| BIDS input | `/data00/projects/{project}/data/bids_data/` |
| MRIQC output | `/data00/projects/{project}/data/bids_data/derivatives/mriqc/` |
| Working directory | `/data00/projects/{project}/data/bids_data/derivatives/working/` |
| Slurm job scripts | `/data00/projects/{project}/scripts/BIDS/jobs/mriqc/` |
| Singularity image | `/data00/tools/singularity_images/mriqc-0.15.1.simg` |

---

## Scripts

| Script | Description |
|--------|-------------|
| `mriqc_single.bsh` | Run MRIQC on a single participant — use for testing or spot-checking |
| `mriqc_batch.ipynb` | Auto-detect all subjects, generate Slurm job scripts, and print submission commands |

---

## Running MRIQC

### Single Subject (Testing)

Edit the variables at the top of `mriqc_single.bsh` to set your project and subject, then run:

```bash
bash mriqc_single.bsh
```

Use this to confirm MRIQC runs correctly on your data before submitting the full batch to the cluster.

### Batch (All Participants via Slurm)

1. Open `mriqc_batch.ipynb`
2. Set `project` and verify the derived paths in the **Set Variables** cell
3. Run the **Generate Job Scripts** cell — creates one `.job` file per subject, auto-detected from your BIDS directory
4. Run the **Print sbatch Commands** cell — prints the commands to submit to the cluster
5. SSH to the Slurm master node and paste the printed commands:

```bash
# Paste the output from the notebook here, e.g.:
cd /data00/projects/{project}/scripts/BIDS/jobs/mriqc
sbatch -D . -c 8 mriqc_sub-001.job
sbatch -D . -c 8 mriqc_sub-002.job
...
```

---

## Singularity Command Explained

```bash
singularity run --cleanenv \
    -B {bids_dir}:/data \       # bind-mount BIDS directory → /data inside container
    -B {output_dir}:/out \      # bind-mount output directory → /out inside container
    -B {working_dir}:/work \    # bind-mount working directory for intermediate files
    mriqc-0.15.1.simg /data /out participant \
    --nprocs 8 \                # parallel processes per job
    -m bold \                   # modality filter: bold, T1w, T2w (or omit for all)
    --work-dir /work \
    --participant_label {ID}    # subject ID without the 'sub-' prefix
```

> **Note on `-m bold`:** The batch script runs MRIQC on functional data only by default. Remove this flag or use `-m T1w T2w bold` to also evaluate structural scans. Running all modalities is recommended for a complete QC picture.

---

## Understanding the Output

After a successful run, `bids_data/derivatives/mriqc/` will contain:

```
derivatives/mriqc/
├── sub-001/
│   ├── anat/
│   │   └── sub-001_T1w.json          ← IQMs for structural scan
│   └── func/
│       ├── sub-001_task-image_run-1_bold.json
│       └── sub-001_task-image_run-2_bold.json
├── sub-001.html                       ← visual QC report (open in browser)
├── sub-002.html
├── ...
├── group_bold.tsv                     ← all BOLD IQMs across subjects
└── group_T1w.tsv                      ← all T1w IQMs across subjects
```

### Key IQMs to Review

**Functional (BOLD):**

| Metric | What it measures | Flag if... |
|--------|-----------------|------------|
| `fd_mean` | Mean framewise displacement (head motion) | > 0.5 mm |
| `fd_perc` | % of volumes exceeding FD threshold | > 20% |
| `dvars_nstd` | Signal variability across volumes | Unusually high |
| `snr` | Signal-to-noise ratio | Unusually low |
| `tsnr` | Temporal SNR | Unusually low |

**Structural (T1w):**

| Metric | What it measures | Flag if... |
|--------|-----------------|------------|
| `snr_total` | Overall signal-to-noise ratio | Unusually low |
| `efc` | Entropy focus criterion (ghosting/motion) | Unusually high |
| `wm2max` | White matter to max intensity ratio | Outside typical range |

> These thresholds are guidelines — always visually inspect the HTML reports alongside the metrics, especially for borderline cases. Decisions about exclusion should be documented in your project's QC notes.

---

## Troubleshooting

**Job runs but output directory is empty**
Check the `.err` log in `scripts/BIDS/jobs/mriqc/out/`. A common cause is an incorrect bind-mount path — verify the BIDS and output paths exist before submitting.

**`participant_label` not found**
The `--participant_label` flag takes the subject ID *without* the `sub-` prefix (e.g. `001`, not `sub-001`). The batch notebook handles this automatically.

**Working directory errors**
If a previous run failed partway through, stale files in the working directory can cause crashes on re-run. Delete the working directory contents and re-submit: `rm -rf {working_dir}/*`

**Job times out**
The default wall time is 2 days (`--time=2-00:00`). Large datasets with many BOLD runs may require more. Increase the `#SBATCH --time` value in the job template if needed.

---

## Next Step

Once MRIQC has run and you have reviewed the reports, proceed to **[Step 3: fMRIPrep](README_3_fmriprep.md)**.
