# Scripts
This folder will contain scripts used for cleaning and analysis. There are also some scripts used in the administration of the study in the Admin folder. For more information about the individual scripts, look into each folder's readme files.

## Utility Scripts
This is where reusable scripts that can be used in other files will be kept. For example, the functions to load the redcap and ema data are contained here.

## Geo Template
`Geo_Template.Rmd` is a starter R Markdown template for analysis scripts in this project. It is pre-configured to source the utility scripts and load the REDCap and Lifedata datasets, so you can skip the boilerplate setup and get straight to analysis.

### Using the Template
1. Update the file paths at the top of the script to point to your local copies of the utility scripts.
2. Run the setup chunk to load REDCap and Lifedata into your environment:
```r
source("YOUR_PATH_TO/geo_redcap.r")
source("YOUR_PATH_TO/geo_lifedata.r")

redcap_df   <- load_redcap_data()
lifedata_df <- get_clean_lifedata()
```
3. Add your analysis code in the sections below the setup chunk.
4. Knit the document to produce an HTML or PDF report of your results.


## Analysis Scripts
Different analyses may live in their own folder and contain their output within these folders. This may be subject to change. Anything that can be reused should be moved to the utility folder and then imported.

## fMRI Pipeline
The `fMRI` folder contains the full neuroimaging analysis pipeline, covering everything from raw DICOM transfer through first- and second-level statistical modeling. The pipeline is built around [Nipype](https://nipype.readthedocs.io/en/latest/), with JSON-based job templates and [Slurm](https://slurm.schedmd.com/) submission scripts for running analyses on a high-performance computing (HPC) cluster. Most steps are run interactively via Jupyter notebooks.

### Pipeline Steps

| Step | Description |
|------|-------------|
| 1. DICOMs | Transfer raw scan data from Flywheel to the server |
| 2. BIDS | Convert DICOMs to NIfTI format following the BIDS standard |
| 2.5. MRIQC | Run automated image quality metrics (optional but recommended) |
| 3. fMRIPrep | Preprocess fMRI data and perform quality control |
| 4. L1 Modeling | Run first-level (subject-level) GLM models |
| 5. L2 Modeling | Run second-level (group-level) GLM models |

Steps should be run in order, as each depends on the outputs of the previous one. See the fMRI folder's README and its section-specific READMEs for detailed instructions at each step.

For full setup instructions, dependency requirements, and data conventions, refer to [`fMRI/README.md`](fMRI/README.md).