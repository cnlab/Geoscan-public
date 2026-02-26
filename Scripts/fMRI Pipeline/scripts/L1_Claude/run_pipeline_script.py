#!/usr/bin/env python
# coding: utf-8
"""
Complete fMRI Analysis Pipeline Runner

This script provides a unified interface to run the entire first-level
analysis pipeline including preprocessing, GLM analysis, quality control,
and visualization.
"""

import os
import sys
import json
import argparse
import logging
from pathlib import Path
from datetime import datetime

# Import pipeline modules
from configuration_utils import (
    create_config_from_bids,
    save_config,
    validate_configuration,
    create_batch_configs
)
from improved_pipeline import FMRILevel1Pipeline
from quality_control import QualityControl, run_batch_qc
from visualization import ResultsVisualizer

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger('fmri_pipeline_runner')


class PipelineRunner:
    """Main pipeline runner that coordinates all analysis steps."""
    
    def __init__(self, bids_root, output_dir=None, working_dir=None):
        """
        Initialize the pipeline runner.
        
        Parameters
        ----------
        bids_root : str
            Path to BIDS dataset
        output_dir : str, optional
            Output directory (defaults to bids_root/derivatives/nipype)
        working_dir : str, optional
            Working directory (defaults to bids_root/derivatives/work)
        """
        self.bids_root = Path(bids_root)
        self.output_dir = Path(output_dir) if output_dir else self.bids_root / "derivatives" / "nipype"
        self.working_dir = Path(working_dir) if working_dir else self.bids_root / "derivatives" / "work"
        
        # Create directories
        self.output_dir.mkdir(parents=True, exist_ok=True)
        self.working_dir.mkdir(parents=True, exist_ok=True)
        
        # Set up logging
        log_dir = self.output_dir / "logs"
        log_dir.mkdir(exist_ok=True)
        
        log_file = log_dir / f"pipeline_run_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log"
        file_handler = logging.FileHandler(log_file)
        file_handler.setLevel(logging.INFO)
        formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
        file_handler.setFormatter(formatter)
        logger.addHandler(file_handler)
        
        logger.info(f"Pipeline runner initialized")
        logger.info(f"BIDS root: {self.bids_root}")
        logger.info(f"Output directory: {self.output_dir}")
        logger.info(f"Working directory: {self.working_dir}")
        
    def create_configuration(self, subject, task, model_name="default", session=None,
                           runs=None, space="MNI152NLin2009cAsym", smoothing=6.0,
                           high_pass=128.0, tr=None, contrasts=None):
        """
        Create configuration for a subject.
        
        Parameters
        ----------
        subject : str
            Subject ID
        task : str
            Task name
        model_name : str
            Model name
        session : str, optional
            Session ID
        runs : list, optional
            List of run numbers
        space : str
            Space for functional data
        smoothing : float
            FWHM for smoothing in mm
        high_pass : float
            High-pass filter cutoff in seconds
        tr : float, optional
            Repetition time (will be read from data if not provided)
        contrasts : list, optional
            List of contrast definitions
            
        Returns
        -------
        dict
            Configuration dictionary
        """
        logger.info(f"Creating configuration for sub-{subject}, task-{task}")
        
        try:
            config = create_config_from_bids(
                bids_root=self.bids_root,
                subject=subject,
                session=session,
                task=task,
                runs=runs,
                model_name=model_name,
                output_dir=self.output_dir,
                working_dir=self.working_dir,
                space=space,
                smoothing=smoothing,
                high_pass=high_pass,
                tr=tr
            )
            
            # Add contrasts if provided
            if contrasts:
                config["EstimateContrast"]["contrasts"] = contrasts
            
            # Validate
            errors = validate_configuration(config, check_files=True)
            if errors:
                logger.error(f"Configuration validation errors: {errors}")
                for error in errors:
                    logger.error(f"  - {error}")
                return None
                
            return config
            
        except Exception as e:
            logger.error(f"Error creating configuration: {e}")
            return None
    
    def run_subject(self, config, plugin=None, plugin_args=None, run_qc=True, 
                   run_viz=True, qc_confounds=None):
        """
        Run the full pipeline for a single subject.
        
        Parameters
        ----------
        config : dict or str
            Configuration dictionary or path to config file
        plugin : str, optional
            Nipype plugin to use
        plugin_args : dict, optional
            Plugin arguments
        run_qc : bool
            Whether to run quality control
        run_viz : bool
            Whether to generate visualizations
        qc_confounds : list, optional
            Confound files for QC
            
        Returns
        -------
        dict
            Results summary
        """
        # Load config if path provided
        if isinstance(config, str):
            logger.info(f"Loading configuration from {config}")
            with open(config, 'r') as f:
                config = json.load(f)
                
        subject = config['Info']['sub']
        task = config['Info']['task']
        model = config['Info']['model']
        
        logger.info(f"Starting pipeline for sub-{subject}, task-{task}, model-{model}")
        
        results = {
            'subject': subject,
            'task': task,
            'model': model,
            'status': 'started',
            'start_time': datetime.now().isoformat()
        }
        
        try:
            # Run first-level analysis
            logger.info("Running first-level analysis...")
            pipeline = FMRILevel1Pipeline(config, in_container=False)
            pipeline.run(plugin=plugin, plugin_args=plugin_args)
            results['analysis'] = 'completed'
            logger.info("First-level analysis completed")
            
            # Run quality control
            if run_qc:
                logger.info("Running quality control...")
                qc = QualityControl(self.output_dir, subject, task, model)
                qc_report = qc.generate_report(confound_files=qc_confounds)
                results['qc'] = qc_report
                logger.info("Quality control completed")
            
            # Generate visualizations
            if run_viz:
                logger.info("Generating visualizations...")
                viz = ResultsVisualizer(self.output_dir, subject, task, model)
                viz.generate_report_figures()
                results['visualization'] = 'completed'
                logger.info("Visualizations completed")
                
            results['status'] = 'completed'
            
        except Exception as e:
            logger.error(f"Error running pipeline: {e}")
            results['status'] = 'failed'
            results['error'] = str(e)
            
        results['end_time'] = datetime.now().isoformat()
        
        # Save results summary
        results_file = self.output_dir / f"task-{task}_model-{model}" / f"sub-{subject}" / "pipeline_results.json"
        results_file.parent.mkdir(parents=True, exist_ok=True)
        with open(results_file, 'w') as f:
            json.dump(results, f, indent=2)
            
        return results
    
    def run_batch(self, subjects, task, model_name="default", session=None,
                 contrasts=None, n_jobs=1, plugin='MultiProc'):
        """
        Run pipeline for multiple subjects.
        
        Parameters
        ----------
        subjects : list
            List of subject IDs
        task : str
            Task name
        model_name : str
            Model name
        session : str or list, optional
            Session ID(s)
        contrasts : list, optional
            Contrast definitions
        n_jobs : int
            Number of parallel jobs
        plugin : str
            Nipype plugin to use
            
        Returns
        -------
        list
            List of results for each subject
        """
        logger.info(f"Starting batch processing for {len(subjects)} subjects")
        
        # Handle session input
        if isinstance(session, str):
            sessions = [session] * len(subjects)
        elif isinstance(session, list):
            sessions = session
        else:
            sessions = [None] * len(subjects)
            
        # Create configurations
        configs = []
        for subject, sess in zip(subjects, sessions):
            config = self.create_configuration(
                subject=subject,
                task=task,
                model_name=model_name,
                session=sess,
                contrasts=contrasts
            )
            
            if config:
                # Save config
                config_file = self.output_dir / "configs" / f"sub-{subject}_task-{task}_model-{model_name}.json"
                config_file.parent.mkdir(exist_ok=True)
                save_config(config, str(config_file))
                configs.append(config_file)
            else:
                logger.warning(f"Skipping sub-{subject} due to configuration errors")
                
        # Run analyses
        plugin_args = {'n_procs': n_jobs} if n_jobs > 1 else None
        results = []
        
        for config_file in configs:
            result = self.run_subject(
                config=str(config_file),
                plugin=plugin,
                plugin_args=plugin_args
            )
            results.append(result)
            
        # Generate batch QC summary
        logger.info("Generating batch QC summary...")
        qc_reports = run_batch_qc(self.output_dir, task, model_name, subjects, sessions)
        
        # Save batch summary
        summary = {
            'task': task,
            'model': model_name,
            'n_subjects': len(subjects),
            'n_completed': sum(1 for r in results if r['status'] == 'completed'),
            'n_failed': sum(1 for r in results if r['status'] == 'failed'),
            'timestamp': datetime.now().isoformat(),
            'subjects': results
        }
        
        summary_file = self.output_dir / f"batch_summary_task-{task}_model-{model_name}.json"
        with open(summary_file, 'w') as f:
            json.dump(summary, f, indent=2)
            
        logger.info(f"Batch processing completed: {summary['n_completed']}/{summary['n_subjects']} successful")
        
        return results
    
    def create_slurm_script(self, subjects, task, model_name="default", 
                           session=None, time="2:00:00", mem="8G", cpus=2):
        """
        Create SLURM submission script for batch processing.
        
        Parameters
        ----------
        subjects : list
            List of subject IDs
        task : str
            Task name
        model_name : str
            Model name
        session : str, optional
            Session ID
        time : str
            Time limit
        mem : str
            Memory limit
        cpus : int
            Number of CPUs per task
            
        Returns
        -------
        str
            Path to SLURM script
        """
        script_content = f"""#!/bin/bash
#SBATCH --job-name=fmri_{task}_{model_name}
#SBATCH --output={self.output_dir}/logs/slurm_%A_%a.out
#SBATCH --error={self.output_dir}/logs/slurm_%A_%a.err
#SBATCH --array=0-{len(subjects)-1}
#SBATCH --time={time}
#SBATCH --mem={mem}
#SBATCH --cpus-per-task={cpus}

# Load required modules (adjust for your system)
# module load python/3.8
# module load fsl/6.0.4
# module load matlab/R2021a

# Subject array
subjects=({' '.join(subjects)})
subject=${{subjects[$SLURM_ARRAY_TASK_ID]}}

echo "Processing subject: $subject"
echo "Task: {task}"
echo "Model: {model_name}"

# Run pipeline
python {__file__} single \\
    --bids-root {self.bids_root} \\
    --output-dir {self.output_dir} \\
    --subject $subject \\
    --task {task} \\
    --model {model_name} \\
    {'--session ' + session if session else ''}

echo "Completed subject: $subject"
"""
        
        script_file = self.output_dir / "scripts" / f"run_{task}_{model_name}.sh"
        script_file.parent.mkdir(exist_ok=True)
        
        with open(script_file, 'w') as f:
            f.write(script_content)
            
        os.chmod(script_file, 0o755)
        logger.info(f"Created SLURM script: {script_file}")
        
        return str(script_file)


def main():
    """Main entry point for the pipeline runner."""
    parser = argparse.ArgumentParser(
        description="fMRI Analysis Pipeline Runner",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Run single subject
  python run_pipeline.py single --bids-root /data/bids --subject sub-01 --task rest
  
  # Run multiple subjects
  python run_pipeline.py batch --bids-root /data/bids --subjects sub-01 sub-02 --task rest
  
  # Create SLURM script
  python run_pipeline.py slurm --bids-root /data/bids --subjects sub-01 sub-02 --task rest
        """
    )
    
    subparsers = parser.add_subparsers(dest='command', help='Command to run')
    
    # Common arguments
    common_parser = argparse.ArgumentParser(add_help=False)
    common_parser.add_argument('--bids-root', required=True, help='Path to BIDS dataset')
    common_parser.add_argument('--output-dir', help='Output directory')
    common_parser.add_argument('--working-dir', help='Working directory')
    common_parser.add_argument('--task', required=True, help='Task name')
    common_parser.add_argument('--model', default='default', help='Model name')
    common_parser.add_argument('--session', help='Session ID')
    common_parser.add_argument('--space', default='MNI152NLin2009cAsym', help='Space')
    common_parser.add_argument('--smoothing', type=float, default=6.0, help='Smoothing FWHM')
    common_parser.add_argument('--high-pass', type=float, default=128.0, help='High-pass filter')
    
    # Single subject command
    single_parser = subparsers.add_parser('single', parents=[common_parser],
                                         help='Run single subject')
    single_parser.add_argument('--subject', required=True, help='Subject ID')
    single_parser.add_argument('--runs', nargs='+', type=int, help='Run numbers')
    single_parser.add_argument('--plugin', default='Linear', help='Nipype plugin')
    single_parser.add_argument('--no-qc', action='store_true', help='Skip QC')
    single_parser.add_argument('--no-viz', action='store_true', help='Skip visualization')
    
    # Batch command
    batch_parser = subparsers.add_parser('batch', parents=[common_parser],
                                        help='Run multiple subjects')
    batch_parser.add_argument('--subjects', nargs='+', required=True, help='Subject IDs')
    batch_parser.add_argument('--n-jobs', type=int, default=1, help='Number of parallel jobs')
    batch_parser.add_argument('--plugin', default='MultiProc', help='Nipype plugin')
    
    # SLURM command
    slurm_parser = subparsers.add_parser('slurm', parents=[common_parser],
                                        help='Create SLURM script')
    slurm_parser.add_argument('--subjects', nargs='+', required=True, help='Subject IDs')
    slurm_parser.add_argument('--time', default='2:00:00', help='Time limit')
    slurm_parser.add_argument('--mem', default='8G', help='Memory limit')
    slurm_parser.add_argument('--cpus', type=int, default=2, help='CPUs per task')
    
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        return
        
    # Initialize runner
    runner = PipelineRunner(
        bids_root=args.bids_root,
        output_dir=args.output_dir,
        working_dir=args.working_dir
    )
    
    # Execute command
    if args.command == 'single':
        config = runner.create_configuration(
            subject=args.subject,
            task=args.task,
            model_name=args.model,
            session=args.session,
            runs=args.runs,
            space=args.space,
            smoothing=args.smoothing,
            high_pass=args.high_pass
        )
        
        if config:
            runner.run_subject(
                config=config,
                plugin=args.plugin,
                run_qc=not args.no_qc,
                run_viz=not args.no_viz
            )
            
    elif args.command == 'batch':
        runner.run_batch(
            subjects=args.subjects,
            task=args.task,
            model_name=args.model,
            session=args.session,
            n_jobs=args.n_jobs,
            plugin=args.plugin
        )
        
    elif args.command == 'slurm':
        script = runner.create_slurm_script(
            subjects=args.subjects,
            task=args.task,
            model_name=args.model,
            session=args.session,
            time=args.time,
            mem=args.mem,
            cpus=args.cpus
        )
        print(f"SLURM script created: {script}")
        print(f"Submit with: sbatch {script}")


if __name__ == "__main__":
    main()