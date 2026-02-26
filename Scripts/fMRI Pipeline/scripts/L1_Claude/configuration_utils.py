#!/usr/bin/env python
# coding: utf-8
"""
fMRI Configuration Helper

Utility functions to create and validate configuration files for fMRI analysis.
"""

import os
import json
import datetime
from pathlib import Path
import pandas as pd
import nibabel as nib


def create_base_config(sub, task, model, data_path, output_path, working_path, 
                       spm_path=None, fsl_path=None):
    """
    Create a basic configuration dictionary with environment settings.
    
    Parameters
    ----------
    sub : str
        Subject ID
    task : str
        Task name
    model : str
        Model name
    data_path : str
        Path to data directory
    output_path : str
        Path to output directory
    working_path : str
        Path to working directory
    spm_path : str, optional
        Path to SPM installation
    fsl_path : str, optional
        Path to FSL installation
    
    Returns
    -------
    dict
        Base configuration dictionary
    """
    config = {
        "Info": {
            "sub": sub,
            "task": task,
            "model": model
        },
        "Environment": {
            "data_path": data_path,
            "output_path": output_path,
            "working_path": working_path
        }
    }
    
    if spm_path:
        config["Environment"]["spm_path"] = spm_path
    
    if fsl_path:
        config["Environment"]["fsl_path"] = fsl_path
    
    return config


def add_smoothing(config, fwhm=6.0):
    """
    Add smoothing parameters to the configuration.
    
    Parameters
    ----------
    config : dict
        Configuration dictionary
    fwhm : float, optional
        Full width at half maximum for smoothing kernel
    
    Returns
    -------
    dict
        Updated configuration dictionary
    """
    config["IsotropicSmooth"] = {"fwhm": fwhm}
    return config


def add_basic_model(config, func_files, event_files, regressor_files=None, 
                   tr=2.0, hpf=128, input_units="secs", output_units="secs",
                   regressor_names=None, mask_image=None):
    """
    Add basic model specification parameters.
    
    Parameters
    ----------
    config : dict
        Configuration dictionary
    func_files : list
        List of functional run files
    event_files : list
        List of event files
    regressor_files : list, optional
        List of regressor files
    tr : float, optional
        Repetition time in seconds
    hpf : float, optional
        High-pass filter cutoff in seconds
    input_units : str, optional
        Units for event onsets ('scans' or 'secs')
    output_units : str, optional
        Units for design specification ('scans' or 'secs')
    regressor_names : list, optional
        Names of regressors to use from regressor files
    mask_image : str, optional
        Path to mask image
    
    Returns
    -------
    dict
        Updated configuration dictionary
    """
    config["SpecifySPMModel"] = {
        "time_repetition": tr,
        "input_units": input_units,
        "output_units": output_units,
        "high_pass_filter_cutoff": hpf,
        "functional_runs": func_files,
        "event_files": event_files
    }
    
    if regressor_files:
        config["SpecifySPMModel"]["regressors"] = regressor_files
        
    if regressor_names:
        config["SpecifySPMModel"]["regressor_names"] = regressor_names
    
    # Add Level1Design section
    config["Level1Design"] = {
        "bases": {"hrf": {"derivs": [0, 0]}},
        "interscan_interval": tr,
        "model_serial_correlations": "AR(1)"
    }
    
    if mask_image:
        config["Level1Design"]["mask_image"] = mask_image
    
    # Add EstimateModel section
    config["EstimateModel"] = {
        "estimation_method": {"Classical": 1}
    }
    
    return config


def add_contrasts(config, contrasts):
    """
    Add contrast definitions to the configuration.
    
    Parameters
    ----------
    config : dict
        Configuration dictionary
    contrasts : list
        List of contrast definitions. Each contrast should be a list:
        [name, type, conditions, weights, (optional session_weights)]
    
    Returns
    -------
    dict
        Updated configuration dictionary
    """
    config["EstimateContrast"] = {
        "contrasts": contrasts
    }
    return config


def add_parametric_modulators(config, condition_pmod_mapping):
    """
    Add parametric modulators to the model.
    
    Parameters
    ----------
    config : dict
        Configuration dictionary
    condition_pmod_mapping : dict
        Dictionary mapping condition names to parametric modulator variables
    
    Returns
    -------
    dict
        Updated configuration dictionary
    """
    if "SpecifySPMModel" not in config:
        raise ValueError("SpecifySPMModel must be added before parametric modulators")
    
    config["SpecifySPMModel"]["pmod"] = condition_pmod_mapping
    return config


def validate_configuration(config, check_files=True):
    """
    Validate the configuration for common errors.
    
    Parameters
    ----------
    config : dict
        Configuration dictionary
    check_files : bool, optional
        Whether to check if referenced files exist
    
    Returns
    -------
    list
        List of validation errors, empty if no errors
    """
    errors = []
    
    # Check required sections
    required_sections = ['Info', 'Environment', 'SpecifySPMModel', 'Level1Design', 'EstimateModel']
    for section in required_sections:
        if section not in config:
            errors.append(f"Missing required section: {section}")
    
    # If any required sections are missing, return early
    if errors:
        return errors
    
    # Check Info section
    if not config['Info'].get('sub'):
        errors.append("Missing subject ID in Info section")
    if not config['Info'].get('task'):
        errors.append("Missing task name in Info section")
    if not config['Info'].get('model'):
        errors.append("Missing model name in Info section")
    
    # Check Environment section
    for key in ['data_path', 'output_path', 'working_path']:
        if not config['Environment'].get(key):
            errors.append(f"Missing {key} in Environment section")
    
    # Check SpecifySPMModel section
    model_spec = config['SpecifySPMModel']
    
    if not model_spec.get('functional_runs'):
        errors.append("No functional runs specified")
    elif not isinstance(model_spec['functional_runs'], list):
        errors.append("functional_runs must be a list")
    
    if not model_spec.get('event_files'):
        errors.append("No event files specified")
    elif not isinstance(model_spec['event_files'], list):
        errors.append("event_files must be a list")
    
    if len(model_spec.get('functional_runs', [])) != len(model_spec.get('event_files', [])):
        errors.append("Number of functional runs must match number of event files")
    
    if model_spec.get('regressors') and len(model_spec['regressors']) != len(model_spec.get('functional_runs', [])):
        errors.append("Number of regressor files must match number of functional runs")
    
    # Check for file existence if requested
    if check_files:
        data_path = config['Environment']['data_path']
        
        for func_file in model_spec.get('functional_runs', []):
            if not os.path.exists(os.path.join(data_path, func_file)):
                errors.append(f"Functional file not found: {func_file}")
        
        for event_file in model_spec.get('event_files', []):
            if not os.path.exists(os.path.join(data_path, event_file)):
                errors.append(f"Event file not found: {event_file}")
        
        if model_spec.get('regressors'):
            for reg_file in model_spec['regressors']:
                if not os.path.exists(os.path.join(data_path, reg_file)):
                    errors.append(f"Regressor file not found: {reg_file}")
    
    # Check Level1Design section
    design = config['Level1Design']
    if not design.get('interscan_interval'):
        errors.append("Missing interscan_interval in Level1Design")
    
    if 'bases' not in design:
        errors.append("Missing bases in Level1Design")
    
    # Check if there are contrasts but no contrast section
    if 'EstimateContrast' in config:
        if not config['EstimateContrast'].get('contrasts'):
            errors.append("EstimateContrast section exists but no contrasts defined")
    
    return errors


def create_config_from_bids(bids_root, subject, session=None, task=None, 
                          runs=None, model_name="default", output_dir=None, 
                          working_dir=None, space="MNI152NLin2009cAsym", 
                          smoothing=6.0, high_pass=128.0, tr=None):
    """
    Create a configuration from BIDS-formatted data.
    
    Parameters
    ----------
    bids_root : str
        Path to BIDS dataset
    subject : str
        Subject ID (without "sub-" prefix)
    session : str, optional
        Session ID (without "ses-" prefix)
    task : str
        Task name (without "task-" prefix)
    runs : list, optional
        List of run numbers to include
    model_name : str, optional
        Name for the model
    output_dir : str, optional
        Output directory (defaults to bids_root/derivatives/l1analysis)
    working_dir : str, optional
        Working directory (defaults to bids_root/derivatives/work)
    space : str, optional
        Space for functional data
    smoothing : float, optional
        FWHM for smoothing
    high_pass : float, optional
        High-pass filter cutoff in seconds
    tr : float, optional
        Repetition time (if None, will be read from image header)
    
    Returns
    -------
    dict
        Configuration dictionary for the subject
    """
    import glob
    
    # Set up paths
    bids_root = Path(bids_root)
    if output_dir is None:
        output_dir = bids_root / "derivatives" / "l1analysis"
    if working_dir is None:
        working_dir = bids_root / "derivatives" / "work"
    
    # Format subject and session strings
    sub_prefix = f"sub-{subject}"
    ses_prefix = f"ses-{session}" if session else None
    
    # Find functional files
    func_dir = bids_root / sub_prefix
    if ses_prefix:
        func_dir = func_dir / ses_prefix
    func_dir = func_dir / "func"
    
    # Pattern for finding preprocessed files (assuming fMRIPrep output)
    func_pattern = f"{sub_prefix}"
    if ses_prefix:
        func_pattern += f"_{ses_prefix}"
    func_pattern += f"_task-{task}"
    if runs:
        run_files = []
        for run in runs:
            run_pattern = f"{func_pattern}_run-{run}_space-{space}_desc-preproc_bold.nii*"
            run_files.extend(glob.glob(str(func_dir / run_pattern)))
        func_files = sorted(run_files)
    else:
        func_pattern += f"_run-*_space-{space}_desc-preproc_bold.nii*"
        func_files = sorted(glob.glob(str(func_dir / func_pattern)))
    
    if not func_files:
        raise FileNotFoundError(f"No functional files found matching pattern: {func_pattern}")
    
    # Convert to relative paths
    func_files = [str(Path(f).relative_to(bids_root)) for f in func_files]
    
    # Get TR from first image if not provided
    if tr is None:
        img = nib.load(func_files[0])
        tr = img.header.get_zooms()[3]
    
    # Look for event files
    events_dir = bids_root / sub_prefix
    if ses_prefix:
        events_dir = events_dir / ses_prefix
    events_dir = events_dir / "func"
    
    event_files = []
    for func_file in func_files:
        # Extract run number from func_file
        run_match = Path(func_file).name.split('_')
        run_part = next((part for part in run_match if part.startswith("run-")), None)
        
        if run_part:
            event_pattern = f"{sub_prefix}"
            if ses_prefix:
                event_pattern += f"_{ses_prefix}"
            event_pattern += f"_task-{task}_{run_part}_events.tsv"
            event_file = events_dir / event_pattern
            
            if event_file.exists():
                event_files.append(str(event_file.relative_to(bids_root)))
            else:
                raise FileNotFoundError(f"Event file not found: {event_file}")
    
    # Look for confound files (motion parameters, etc.)
    if Path(bids_root / "derivatives" / "fmriprep").exists():
        confound_files = []
        for func_file in func_files:
            func_basename = Path(func_file).name
            # Replace preproc with confounds in filename
            confound_name = func_basename.replace("_desc-preproc_bold.nii", "_desc-confounds_timeseries.tsv")
            confound_name = confound_name.replace("_desc-preproc_bold.nii.gz", "_desc-confounds_timeseries.tsv")
            
            confound_path = bids_root / "derivatives" / "fmriprep" / sub_prefix
            if ses_prefix:
                confound_path = confound_path / ses_prefix
            confound_path = confound_path / "func" / confound_name
            
            if confound_path.exists():
                confound_files.append(str(confound_path.relative_to(bids_root)))
            else:
                confound_files = None
                break
    else:
        confound_files = None
    
    # Create the base configuration
    config = create_base_config(
        sub=subject,
        task=task,
        model=model_name,
        data_path=str(bids_root),
        output_path=str(output_dir),
        working_path=str(working_dir)
    )
    
    # Add smoothing
    if smoothing > 0:
        add_smoothing(config, fwhm=smoothing)
    
    # Add basic model
    default_regressors = ["trans_x", "trans_y", "trans_z", "rot_x", "rot_y", "rot_z"]
    add_basic_model(
        config=config,
        func_files=func_files,
        event_files=event_files,
        regressor_files=confound_files,
        tr=tr,
        hpf=high_pass,
        regressor_names=default_regressors if confound_files else None
    )
    
    # Add a placeholder for contrasts
    config["EstimateContrast"] = {
        "contrasts": []  # User should fill this in based on their task
    }
    
    return config


def save_config(config, output_file=None):
    """
    Save configuration to a JSON file.
    
    Parameters
    ----------
    config : dict
        Configuration dictionary
    output_file : str, optional
        Output file path. If None, generates a default name
    
    Returns
    -------
    str
        Path to saved configuration file
    """
    if output_file is None:
        # Generate filename from config info
        sub = config['Info']['sub']
        task = config['Info']['task']
        model = config['Info']['model']
        timestamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
        output_file = f"sub-{sub}_task-{task}_model-{model}_{timestamp}.json"
    
    with open(output_file, 'w') as f:
        json.dump(config, f, indent=2)
    
    return output_file


def load_events_and_add_contrasts(config, contrast_mapping=None):
    """
    Load event files and add standard contrasts based on condition names.
    
    Parameters
    ----------
    config : dict
        Configuration dictionary
    contrast_mapping : dict, optional
        Optional mapping of condition names to contrast weights
        
    Returns
    -------
    dict
        Updated configuration with contrasts
    """
    data_path = config['Environment']['data_path']
    event_files = config['SpecifySPMModel']['event_files']
    
    # Load the first event file to get condition names
    event_file = os.path.join(data_path, event_files[0])
    events = pd.read_csv(event_file, sep='\t')
    
    # Get unique condition names
    conditions = events['trial_type'].unique().tolist()
    
    # Create basic contrasts for each condition
    contrasts = []
    for condition in conditions:
        # Add simple contrast for each condition vs baseline
        contrasts.append([f"{condition}", "T", [condition], [1]])
    
    # Add contrasts from mapping if provided
    if contrast_mapping:
        for name, mapping in contrast_mapping.items():
            contrast_conds = []
            contrast_weights = []
            
            for cond, weight in mapping.items():
                if cond in conditions:
                    contrast_conds.append(cond)
                    contrast_weights.append(weight)
            
            if contrast_conds:
                contrasts.append([name, "T", contrast_conds, contrast_weights])
    
    # Add contrasts to config
    config = add_contrasts(config, contrasts)
    
    return config


def create_batch_configs(subjects, sessions=None, **kwargs):
    """
    Create configurations for multiple subjects.
    
    Parameters
    ----------
    subjects : list
        List of subject IDs
    sessions : list, optional
        List of session IDs
    **kwargs : dict
        Additional arguments for create_config_from_bids
    
    Returns
    -------
    list
        List of saved configuration file paths
    """
    config_files = []
    
    if sessions is None:
        sessions = [None] * len(subjects)
    elif len(sessions) == 1 and len(subjects) > 1:
        sessions = sessions * len(subjects)
    
    for subject, session in zip(subjects, sessions):
        try:
            config = create_config_from_bids(subject=subject, session=session, **kwargs)
            output_file = save_config(config)
            config_files.append(output_file)
            print(f"Created config for sub-{subject}: {output_file}")
        except Exception as e:
            print(f"Error creating config for sub-{subject}: {e}")
    
    return config_files


if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description="Create fMRI analysis configuration files")
    parser.add_argument("bids_dir", help="Path to BIDS dataset directory")
    parser.add_argument("--subject", "-s", required=True, help="Subject ID")
    parser.add_argument("--session", help="Session ID")
    parser.add_argument("--task", "-t", required=True, help="Task name")
    parser.add_argument("--runs", nargs="+", type=int, help="Run numbers to include")
    parser.add_argument("--model", default="default", help="Model name")
    parser.add_argument("--output", "-o", help="Output directory")
    parser.add_argument("--smoothing", type=float, default=6.0, help="Smoothing FWHM")
    parser.add_argument("--highpass", type=float, default=128.0, help="High-pass filter cutoff")
    parser.add_argument("--space", default="MNI152NLin2009cAsym", help="Space for functional data")
    
    args = parser.parse_args()
    
    try:
        config = create_config_from_bids(
            bids_root=args.bids_dir,
            subject=args.subject,
            session=args.session,
            task=args.task,
            runs=args.runs,
            model_name=args.model,
            output_dir=args.output,
            smoothing=args.smoothing,
            high_pass=args.highpass,
            space=args.space
        )
        
        config = load_events_and_add_contrasts(config)
        output_file = save_config(config)
        print(f"Configuration saved to: {output_file}")
        
    except Exception as e:
        print(f"Error creating configuration: {e}")
