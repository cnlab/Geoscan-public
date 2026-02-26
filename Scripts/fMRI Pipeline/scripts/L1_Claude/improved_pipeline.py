#!/usr/bin/env python
# coding: utf-8
"""
fMRI First-Level Analysis Pipeline

This script implements a first-level GLM analysis for task-based fMRI data
using SPM (via Nipype). It takes a JSON configuration file that specifies
all parameters for the analysis.

Usage:
    python l1analysis_SPM.py path/to/config.json
"""

import os
import sys
import json
import copy
import argparse
import logging
from pathlib import Path

import nipype.interfaces.io as nio
import nipype.interfaces.spm as spm
import nipype.interfaces.fsl as fsl
import nipype.interfaces.matlab as mlab
import nipype.pipeline.engine as pe
import nipype.algorithms.modelgen as model
from nipype.interfaces.base import Bunch
from nipype.algorithms.misc import Gunzip
from nipype.interfaces.utility import IdentityInterface

import pandas as pd
import numpy as np
import nibabel as nib

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger('fmri_l1_pipeline')


class FMRILevel1Pipeline:
    """First-level fMRI analysis pipeline using Nipype and SPM."""
    
    def __init__(self, config_file, in_container=False):
        """
        Initialize the pipeline with a configuration file.
        
        Parameters
        ----------
        config_file : str
            Path to the JSON configuration file
        in_container : bool, optional
            Whether running in a container environment
        """
        self.in_container = in_container
        self.load_config(config_file)
        self.setup_environment()
        self.pipeline = None
        
    def load_config(self, config_file):
        """Load and validate the configuration file."""
        logger.info(f"Loading configuration from: {config_file}")
        with open(config_file, 'r') as f:
            self.config = json.load(f)
            
        # Basic validation
        required_sections = ['Info', 'Environment', 'SpecifySPMModel', 'Level1Design', 'EstimateModel']
        for section in required_sections:
            if section not in self.config:
                raise ValueError(f"Missing required section '{section}' in configuration file")
                
        logger.info(f"Configuration loaded for sub-{self.config['Info']['sub']}, task-{self.config['Info']['task']}")
        
    def setup_environment(self):
        """Configure environment variables and paths."""
        env = self.config['Environment']
        
        # Adjust paths if running in container
        if self.in_container:
            env['data_path'] = '/data'
            env['output_path'] = '/output'
            env['working_path'] = '/working'
            
        # Create job name
        job_name = f"task-{self.config['Info']['task']}_model-{self.config['Info']['model']}"
        
        # Set up working and output directories
        env['working_path'] = os.path.join(env['working_path'], job_name)
        env['output_path'] = os.path.join(env['output_path'], job_name)
        
        # Ensure paths exist
        os.makedirs(env['working_path'], exist_ok=True)
        os.makedirs(env['output_path'], exist_ok=True)
        
        # Configure external software
        if not self.in_container:
            # Configure MATLAB/SPM
            if 'spm_path' in env:
                mlab.MatlabCommand.set_default_paths(env['spm_path'])
            
            # Configure FSL
            if 'fsl_path' in env and os.environ.get('FSLDIR') is None:
                paths = os.environ.get('PATH', "").split(os.pathsep)
                paths.append(os.path.join(env['fsl_path'], "bin"))
                os.environ['PATH'] = os.pathsep.join(paths)
                
        mlab.MatlabCommand.set_default_matlab_cmd("matlab -nodesktop -nosplash")
        os.environ['FSLOUTPUTTYPE'] = 'NIFTI'
        
        logger.info(f"Environment configured. Output will be saved to: {env['output_path']}")
    
    @staticmethod
    def ensure_list(obj):
        """Convert single items to lists if they aren't already."""
        if not isinstance(obj, list):
            return [obj]
        return obj
        
    def create_subject_info(self):
        """
        Create the subject information for the model from event files and regressors.
        
        Returns
        -------
        dict
            Model specification arguments with subject_info populated
        """
        logger.info("Creating subject information from events and regressors")
        modelspec_args = copy.deepcopy(self.config['SpecifySPMModel'])
        env = self.config['Environment']
        
        # Ensure input fields are lists
        for field in ['functional_runs', 'event_files', 'regressors', 'outlier_files']:
            if field in modelspec_args:
                modelspec_args[field] = self.ensure_list(modelspec_args[field])
        
        subject_info = []
        
        # Process each run
        for event_file, regressor_file, func_file in zip(
            modelspec_args['event_files'], 
            modelspec_args['regressors'], 
            modelspec_args['functional_runs']
        ):
            # Calculate max scan time from the functional image
            func_img = nib.load(os.path.join(env['data_path'], func_file))
            tr_max = func_img.header.get_data_shape()[-1] * modelspec_args['time_repetition']
            
            # Load and filter event file
            event_path = os.path.join(env['data_path'], event_file)
            logger.debug(f"Processing events from: {event_path}")
            event = (pd.read_csv(event_path, sep='\t')
                    .query('onset >= 0')
                    .query(f'onset <= {tr_max}')
                    .sort_values(by='onset')
                    .reset_index(drop=True))

            # Prepare the bunch object for this run
            bunch = {
                'conditions': [],
                'onsets': [],
                'durations': []
            }

            # Process each trial type in the event file
            for trial_type, trial_df in event.groupby('trial_type'):
                bunch['conditions'].append(trial_type)
                bunch['onsets'].append(trial_df['onset'].tolist())
                bunch['durations'].append(trial_df['duration'].tolist())
            
            # Process regressors
            regressor_path = os.path.join(env['data_path'], regressor_file)
            logger.debug(f"Processing regressors from: {regressor_path}")
            
            if regressor_file.endswith('txt'):
                regressors = np.loadtxt(regressor_path).T.tolist()
                regressor_names = [f"R{i}" for i in range(len(regressors))]
            else:
                regressors_array = pd.read_csv(regressor_path, sep='\t')
                regressor_names = modelspec_args.get('regressor_names', regressors_array.columns.tolist())
                regressors = regressors_array[regressor_names].fillna(0).values.T.tolist()
            
            bunch['regressors'] = regressors
            bunch['regressor_names'] = regressor_names
            
            # Process parametric modulators if present
            if modelspec_args.get('pmod'):
                bunch['pmod'] = []
                
                for condition in bunch['conditions']:
                    pmod_args = None
                    
                    if modelspec_args['pmod'].get(condition):
                        pmod_args = {'name': [], 'param': [], 'poly': []}
                        pmod_variables = self.ensure_list(modelspec_args['pmod'][condition])

                        for pmod_variable in pmod_variables:
                            pmod_param = event.query(f'trial_type == "{condition}"')[pmod_variable]
                            
                            # Replace missing with mean and check variation
                            pmod_param = pmod_param.fillna(pmod_param.mean())
                            if pmod_param.var() == 0:
                                continue
                            
                            pmod_args['name'].append(pmod_variable)
                            pmod_args['param'].append(pmod_param.values.tolist())
                            pmod_args['poly'].append(1)
                        
                        if pmod_args['name']:  # Only add if we have valid modulators
                            pmod_args = Bunch(**pmod_args)
                            
                    bunch['pmod'].append(pmod_args)
            
            subject_info.append(Bunch(**bunch))
        
        # Process outlier files
        outlier_files = []
        if modelspec_args.get('outlier_files'):
            for outlier_file in modelspec_args['outlier_files']:
                outlier_files.append(os.path.join(env['data_path'], outlier_file))
            
            if outlier_files:
                modelspec_args['outlier_files'] = outlier_files
        
        # Remove keys that have been processed
        for parameter in ['functional_runs', 'event_files', 'regressors', 'regressor_names', 'pmod']:
            if parameter in modelspec_args:
                del modelspec_args[parameter]
        
        # Set the subject info
        modelspec_args['subject_info'] = subject_info
        
        return modelspec_args
    
    def build_preprocessing_node(self):
        """
        Create a preprocessing node based on configuration.
        
        Returns
        -------
        nipype.pipeline.engine.Node
            Preprocessing node
        """
        logger.info("Creating preprocessing node")
        env = self.config['Environment']
        func_files = [os.path.join(env['data_path'], f) 
                     for f in self.ensure_list(self.config['SpecifySPMModel']['functional_runs'])]
        
        # Check if smoothing is needed
        if self.config.get("IsotropicSmooth", {}).get("fwhm", 0) != 0:
            logger.info(f"Setting up smoothing with FWHM: {self.config['IsotropicSmooth']['fwhm']}")
            preproc = pe.MapNode(
                interface=fsl.IsotropicSmooth(**self.config['IsotropicSmooth']), 
                iterfield='in_file', 
                name="smooth"
            )
            preproc.inputs.in_file = func_files
            
        # If no smoothing but data is compressed, set up gunzip
        elif func_files[0].endswith('.gz'):
            logger.info("Setting up gunzip for compressed input files")
            preproc = pe.MapNode(
                interface=Gunzip(), 
                iterfield='in_file', 
                name="gunzip"
            )
            preproc.inputs.in_file = func_files
            
        # Otherwise just pass through the files
        else:
            logger.info("Using identity node for functional data")
            preproc = pe.MapNode(
                interface=IdentityInterface(fields=['out_file']), 
                iterfield='out_file', 
                name="identity"
            )
            preproc.inputs.out_file = func_files
            
        return preproc
    
    def build_pipeline(self):
        """
        Build the complete analysis pipeline.
        
        Returns
        -------
        nipype.pipeline.engine.Workflow
            The complete pipeline
        """
        logger.info("Building pipeline")
        env = self.config['Environment']
        sub_id = self.config['Info']["sub"]
        
        # Initialize the preprocessing node
        preproc = self.build_preprocessing_node()
        
        # Create model specification
        modelspec_args = self.create_subject_info()
        modelspec = pe.Node(model.SpecifySPMModel(**modelspec_args), name="modelspec")
        
        # Set up level 1 design
        level1design_args = self.config['Level1Design']
        if level1design_args.get('mask_image'):
            level1design_args['mask_image'] = os.path.join(
                env['data_path'], 
                level1design_args['mask_image']
            )
        level1design = pe.Node(spm.Level1Design(**level1design_args), name="level1design")
        
        # Set up model estimation
        level1estimate_args = self.config['EstimateModel']
        level1estimate = pe.Node(spm.EstimateModel(**level1estimate_args), name="level1estimate")
        
        # Initialize the first level analysis workflow
        l1analysis = pe.Workflow(base_dir=env['working_path'], name='l1analysis')
        
        # Connect basic pipeline
        l1analysis.connect([
            (modelspec, level1design, [('session_info', 'session_info')]),
            (level1design, level1estimate, [('spm_mat_file', 'spm_mat_file')])
        ])
        
        # Initialize outputs for datasink
        datasink_outputs = [
            ('level1estimate.beta_images', '@betas'),
            ('level1estimate.mask_image', '@mask'),
            ('level1estimate.residual_images', '@residuals')
        ]
        
        # Add contrast estimation if contrasts are specified
        if self.config.get('EstimateContrast', {}).get('contrasts', []):
            logger.info(f"Adding contrast estimation with {len(self.config['EstimateContrast']['contrasts'])} contrasts")
            
            # Convert contrast lists to tuples
            conestimate_args = self.config['EstimateContrast']
            conestimate_args['contrasts'] = [tuple(contrast) for contrast in conestimate_args['contrasts']]
            
            # Create the contrast estimation node
            conestimate = pe.Node(spm.EstimateContrast(**conestimate_args), name="conestimate")
            
            # Connect to the workflow
            l1analysis.connect([
                (level1estimate, conestimate, [
                    ('spm_mat_file', 'spm_mat_file'),
                    ('beta_images', 'beta_images'),
                    ('residual_image', 'residual_image')
                ])
            ])
            
            # Add contrast outputs to datasink
            datasink_outputs.extend([
                ('conestimate.spm_mat_file', '@spm'),
                ('conestimate.con_images', '@con'),
                ('conestimate.spmT_images', '@spmT'),
                ('conestimate.spmF_images', '@spmF')
            ])
        else:
            # If no contrasts, just save the SPM file
            datasink_outputs.append(('level1estimate.spm_mat_file', '@spm'))
        
        # Set up the datasink
        datasink = pe.Node(
            nio.DataSink(
                base_directory=env['output_path'], 
                container=f"sub-{sub_id}"
            ), 
            name="datasink"
        )
        
        # Create the complete pipeline
        pipeline = pe.Workflow(base_dir=env['working_path'], name=f"sub-{sub_id}")
        
        # Connect preprocessing to level1 analysis
        pipeline.connect([
            (preproc, l1analysis, [('out_file', 'modelspec.functional_runs')]),
            (l1analysis, datasink, datasink_outputs)
        ])
        
        self.pipeline = pipeline
        logger.info("Pipeline built successfully")
        return pipeline
    
    def run(self, plugin=None, plugin_args=None):
        """
        Run the pipeline.
        
        Parameters
        ----------
        plugin : str, optional
            Plugin to use for execution
        plugin_args : dict, optional
            Plugin arguments
        
        Returns
        -------
        nipype.pipeline.engine.Workflow
            The executed pipeline
        """
        if self.pipeline is None:
            self.build_pipeline()
            
        logger.info(f"Executing pipeline for sub-{self.config['Info']['sub']}")
        self.pipeline.run(plugin=plugin, plugin_args=plugin_args)
        logger.info("Pipeline execution completed")
        return self.pipeline


def main():
    """Parse arguments and run the pipeline."""
    parser = argparse.ArgumentParser(description="fMRI First-Level Analysis Pipeline")
    parser.add_argument("config", help="Path to JSON configuration file")
    parser.add_argument("--plugin", help="Nipype execution plugin", default=None)
    args = parser.parse_args()
    
    # Check if running in container
    in_container = bool(os.environ.get('SINGULARITY_CONTAINER'))
    
    # Initialize and run pipeline
    pipeline = FMRILevel1Pipeline(args.config, in_container)
    pipeline.build_pipeline()
    pipeline.run(plugin=args.plugin)


if __name__ == "__main__":
    main()
