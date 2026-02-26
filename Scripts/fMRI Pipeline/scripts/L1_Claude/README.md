# fMRI First-Level Analysis Pipeline

A modular pipeline for first-level fMRI analysis using SPM via Nipype.

## Installation

```bash
pip install -r requirements.txt
```

## Quick Start

Single subject analysis:
```bash
python run_pipeline.py single --bids-root /data/bids --subject 01 --task rest
```

## Batch analysis:

```bash
python run_pipeline.py batch --bids-root /data/bids --subjects 01 02 03 --task rest
```

## Create SLURM script:

```bash
python run_pipeline.py slurm --bids-root /data/bids --subjects 01 02 03 --task rest
```

## Modules

- configuration_utils.py: Create and validate JSON configuration files
- improved_pipeline.py: Core Nipype/SPM pipeline implementation
- quality_control.py: Automated QC and HTML report generation
- visualization.py: Generate publication-ready figures
- run_pipeline.py: Master script for running complete pipeline

## Configuration
Use the Jupyter notebook (fmri_pipeline_config.ipynb) to interactively create configurations, or use the command-line tools.

## Output Structure

output_dir/
├── task-{task}_model-{model}/
│   └── sub-{subject}/
│       ├── spm/          # SPM.mat file
│       ├── betas/        # Beta images
│       ├── con/          # Contrast images
│       ├── spmT/         # T-statistic images
│       ├── qc/           # Quality control reports
│       └── figures/      # Visualization outputs
├── logs/                 # Processing logs
└── configs/             # Saved configurations

**Example Configuration File** (`example_config.json`):
```json
{
    "Info": {
        "sub": "01",
        "task": "rest",
        "model": "default"
    },
    "Environment": {
        "data_path": "/data/bids",
        "output_path": "/data/bids/derivatives/nipype",
        "working_path": "/data/bids/derivatives/work",
        "spm_path": "/opt/spm12",
        "fsl_path": "/opt/fsl"
    },
    "IsotropicSmooth": {
        "fwhm": 6.0
    },
    "SpecifySPMModel": {
        "time_repetition": 2.0,
        "input_units": "secs",
        "output_units": "secs",
        "high_pass_filter_cutoff": 128,
        "functional_runs": ["sub-01/func/sub-01_task-rest_bold.nii"],
        "event_files": ["sub-01/func/sub-01_task-rest_events.tsv"],
        "regressor_names": ["trans_x", "trans_y", "trans_z", "rot_x", "rot_y", "rot_z"]
    },
    "Level1Design": {
        "bases": {"hrf": {"derivs": [0, 0]}},
        "interscan_interval": 2.0,
        "model_serial_correlations": "AR(1)"
    },
    "EstimateModel": {
        "estimation_method": {"Classical": 1}
    },
    "EstimateContrast": {
        "contrasts": [
            ["activation", "T", ["task"], [1]]
        ]
    }
}