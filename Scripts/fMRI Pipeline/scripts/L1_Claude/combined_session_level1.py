#!/usr/bin/env python3
"""
Template-Based Combined Session Level 1 fMRI Analysis Pipeline
Combines ses-t2 and ses-t3 into single subject-level models using JSON templates
"""

import os
import glob
import pandas as pd
import numpy as np
import json
import shutil
from pathlib import Path
from datetime import datetime
import subprocess
import tempfile
import warnings
warnings.filterwarnings('ignore')

# Import template system (assumes json_template_system.py is available)
from json_template_system import AnalysisTemplateManager, load_project_config

class TemplateBasedCombinedLevel1Pipeline:
    """Level 1 analysis pipeline using JSON templates for configuration"""
    
    def __init__(self, templates_dir, project_name=None, template_files=None):
        self.templates_dir = Path(templates_dir)
        self.template_manager = AnalysisTemplateManager(templates_dir)
        
        # Load configuration from templates
        if template_files:
            # Load specific template files
            self.config = self.load_specific_templates(template_files)
        else:
            # Load templates by project name
            self.config = load_project_config(templates_dir, project_name)
        
        if not self.config:
            raise ValueError("No valid templates found. Create templates first.")
        
        # Extract configuration
        self.project_config = self.config.get('project', {})
        self.dataset_config = self.config.get('dataset', {})
        self.analysis_config = self.config.get('analysis', {})
        self.slurm_config = self.config.get('slurm', {})
        
        # Setup paths from templates
        self.project_path = Path(self.project_config['project_path'])
        self.task_name = self.project_config['task_name']
        self.sessions = self.project_config['sessions']
        
        # Analysis paths
        self.analysis_path = Path(self.analysis_config.get('output_dir', 
            self.project_path / 'derivatives' / 'level1_combined_sessions'))
        self.logs_path = self.analysis_path / 'logs'
        self.jobs_path = self.analysis_path / 'slurm_jobs'
        
        # Analysis parameters from template
        self.analysis_params = self.analysis_config.get('parameters', {})
        self.tr = self.analysis_params.get('tr', 2.0)
        self.hpf = self.analysis_params.get('hpf', 128)
        self.contrasts = self.analysis_config.get('contrasts', [])
        
        # Setup directories and load subjects
        self.setup_directories()
        self.subjects = self.load_subjects_from_template()
        
        print(f"✅ Pipeline initialized with templates")
        print(f"📊 Project: {self.project_config.get('project_name')}")
        print(f"🎯 Task: {self.task_name}")
        print(f"📅 Sessions: {', '.join(self.sessions)}")
        print(f"👥 Subjects: {len(self.subjects)}")
    
    def load_specific_templates(self, template_files):
        """Load specific template files"""
        config = {}
        
        for template_type, file_path in template_files.items():
            try:
                config[template_type] = self.template_manager.load_template(file_path)
                print(f"✅ Loaded {template_type} template: {file_path}")
            except Exception as e:
                print(f"❌ Error loading {template_type} template: {e}")
        
        return config
    
    def setup_directories(self):
        """Create necessary directories"""
        directories = [
            self.analysis_path,
            self.logs_path,
            self.jobs_path,
            self.analysis_path / 'templates_used',
            self.analysis_path / 'combined_events',
            self.analysis_path / 'combined_scans'
        ]
        
        for directory in directories:
            directory.mkdir(parents=True, exist_ok=True)
        
        # Save copies of templates used
        self.save_templates_used()
        
        print(f"📁 Analysis directory: {self.analysis_path}")
    
    def save_templates_used(self):
        """Save copies of templates used for this analysis"""
        templates_backup_dir = self.analysis_path / 'templates_used'
        
        for template_type, template_data in self.config.items():
            backup_file = templates_backup_dir / f"{template_type}_template.json"
            with open(backup_file, 'w') as f:
                json.dump(template_data, f, indent=2)
        
        # Save analysis metadata
        metadata = {
            'analysis_started': datetime.now().isoformat(),
            'templates_dir': str(self.templates_dir),
            'project_name': self.project_config.get('project_name'),
            'analysis_type': self.analysis_config.get('analysis_type'),
            'total_subjects': len(self.dataset_config.get('subjects', []))
        }
        
        metadata_file = templates_backup_dir / 'analysis_metadata.json'
        with open(metadata_file, 'w') as f:
            json.dump(metadata, f, indent=2)
    
    def load_subjects_from_template(self):
        """Load subjects from dataset template"""
        print("📋 Loading subjects from template...")
        
        subjects = []
        template_subjects = self.dataset_config.get('subjects', [])
        
        for subject_template in template_subjects:
            subject_id = subject_template['subject_id']
            
            # Check if subject should be included
            if not subject_template.get('include', True):
                print(f"  ⏭️ {subject_id}: Excluded by template")
                continue
            
            # Check if required sessions are available
            session_data = {}
            has_required_sessions = True
            
            for session in self.sessions:
                if session in subject_template['sessions']:
                    session_template = subject_template['sessions'][session]
                    
                    # Check if session should be included
                    if not session_template.get('include', True):
                        has_required_sessions = False
                        print(f"    ❌ {subject_id} {session}: Excluded by template")
                        break
                    
                    # Build full file paths
                    func_dir = Path(session_template['func_dir'])
                    
                    func_files = [str(func_dir / f) for f in session_template['func_files']]
                    events_files = [str(func_dir / f) for f in session_template['events_files']]
                    confounds_files = [str(func_dir / f) for f in session_template['confounds_files']]
                    
                    # Verify files exist
                    missing_files = []
                    for file_list, file_type in [(func_files, 'func'), 
                                                (events_files, 'events'), 
                                                (confounds_files, 'confounds')]:
                        for file_path in file_list:
                            if not Path(file_path).exists():
                                missing_files.append(f"{file_type}: {file_path}")
                    
                    if missing_files:
                        print(f"    ⚠️ {subject_id} {session}: Missing files: {missing_files}")
                        # Could choose to exclude or continue with available files
                    
                    session_data[session] = {
                        'func_files': func_files,
                        'events_files': events_files,
                        'confounds_files': confounds_files,
                        'func_dir': str(func_dir),
                        'template_data': session_template
                    }
                    
                    print(f"    ✅ {subject_id} {session}: {len(func_files)} runs")
                
                else:
                    has_required_sessions = False
                    print(f"    ❌ {subject_id} {session}: Not in template")
                    break
            
            if has_required_sessions and len(session_data) == len(self.sessions):
                subjects.append({
                    'id': subject_id,
                    'sessions': session_data,
                    'template_data': subject_template,
                    'demographics': subject_template.get('demographics', {})
                })
                print(f"  ✅ {subject_id}: Added to analysis")
            else:
                print(f"  ❌ {subject_id}: Incomplete data or excluded")
        
        print(f"\n📊 Loaded {len(subjects)} subjects from template")
        return subjects
    
    def validate_subjects_against_exclusion_criteria(self):
        """Apply exclusion criteria from dataset template"""
        if 'exclusion_criteria' not in self.dataset_config:
            return self.subjects
        
        criteria = self.dataset_config['exclusion_criteria']
        print(f"\n🔍 Applying exclusion criteria...")
        
        valid_subjects = []
        
        for subject_data in self.subjects:
            subject_id = subject_data['id']
            exclude_subject = False
            exclusion_reasons = []
            
            # Check minimum runs per session
            min_runs = criteria.get('min_runs', 1)
            for session, session_data in subject_data['sessions'].items():
                if len(session_data['func_files']) < min_runs:
                    exclude_subject = True
                    exclusion_reasons.append(f"{session} has {len(session_data['func_files'])} runs (min: {min_runs})")
            
            # Check motion (would need to be implemented with actual motion data)
            max_motion = criteria.get('max_motion')
            if max_motion and self.check_motion_criteria(subject_data, max_motion):
                exclude_subject = True
                exclusion_reasons.append(f"Motion exceeds {max_motion}mm")
            
            # Check required sessions
            required_sessions = criteria.get('required_sessions', self.sessions)
            missing_sessions = [s for s in required_sessions if s not in subject_data['sessions']]
            if missing_sessions:
                exclude_subject = True
                exclusion_reasons.append(f"Missing sessions: {missing_sessions}")
            
            if exclude_subject:
                print(f"  ❌ {subject_id}: Excluded - {'; '.join(exclusion_reasons)}")
            else:
                valid_subjects.append(subject_data)
                print(f"  ✅ {subject_id}: Passed criteria")
        
        print(f"\n📊 Subjects after exclusion: {len(valid_subjects)}/{len(self.subjects)}")
        return valid_subjects
    
    def check_motion_criteria(self, subject_data, max_motion):
        """Check if subject exceeds motion criteria (placeholder)"""
        # This would need actual implementation to read motion parameters
        # from confounds files and calculate framewise displacement
        return False
    
    def combine_events_files_from_template(self, subject_id, output_dir):
        """Combine events files using template specifications"""
        print(f"📋 Combining events files for {subject_id} (template-based)")
        
        subject_data = next(s for s in self.subjects if s['id'] == subject_id)
        combined_events = []
        session_info = []
        
        current_time_offset = 0
        
        for session_idx, session in enumerate(self.sessions):
            session_data = subject_data['sessions'][session]
            
            for run_idx, events_file in enumerate(session_data['events_files']):
                print(f"  📄 Processing {session} - {os.path.basename(events_file)}")
                
                try:
                    events_df = pd.read_csv(events_file, sep='\t')
                except Exception as e:
                    print(f"    ⚠️ Error reading {events_file}: {e}")
                    continue
                
                # Get run duration
                func_file = session_data['func_files'][run_idx] if run_idx < len(session_data['func_files']) else session_data['func_files'][0]
                run_duration = self.get_run_duration(func_file)
                
                # Adjust onset times
                events_df_copy = events_df.copy()
                events_df_copy['onset'] = events_df_copy['onset'] + current_time_offset
                
                # Add session and run info
                events_df_copy['session'] = session
                events_df_copy['session_num'] = session_idx + 1
                events_df_copy['run'] = run_idx + 1
                events_df_copy['original_onset'] = events_df['onset']
                
                combined_events.append(events_df_copy)
                
                session_info.append({
                    'session': session,
                    'session_num': session_idx + 1,
                    'run': run_idx + 1,
                    'start_time': current_time_offset,
                    'duration': run_duration,
                    'end_time': current_time_offset + run_duration,
                    'func_file': func_file,
                    'events_file': events_file
                })
                
                current_time_offset += run_duration
        
        if combined_events:
            combined_df = pd.concat(combined_events, ignore_index=True)
            
            # Save combined events
            combined_events_file = output_dir / f"{subject_id}_combined_events.tsv"
            combined_df.to_csv(combined_events_file, sep='\t', index=False)
            
            # Save session info
            session_info_file = output_dir / f"{subject_id}_session_info.json"
            with open(session_info_file, 'w') as f:
                json.dump(session_info, f, indent=2)
            
            print(f"  ✅ Combined events saved: {combined_events_file}")
            return str(combined_events_file), session_info
        
        return None, []
    
    def combine_scan_lists(self, subject_id, output_dir):
        """Create combined scan list using template specifications"""
        print(f"📷 Creating scan list for {subject_id} (template-based)")
        
        subject_data = next(s for s in self.subjects if s['id'] == subject_id)
        all_scans = []
        scan_info = []
        
        for session_idx, session in enumerate(self.sessions):
            session_data = subject_data['sessions'][session]
            
            for run_idx, func_file in enumerate(session_data['func_files']):
                print(f"  📁 Adding {session} - {os.path.basename(func_file)}")
                
                func_path = Path(func_file)
                if not func_path.exists():
                    print(f"    ⚠️ File not found: {func_file}")
                    continue
                
                try:
                    import nibabel as nib
                    img = nib.load(func_file)
                    n_volumes = img.shape[3] if len(img.shape) > 3 else 1
                    
                    if n_volumes > 1:
                        for vol in range(n_volumes):
                            all_scans.append(f"{func_file},{vol+1}")
                    else:
                        all_scans.append(str(func_file))
                    
                    scan_info.append({
                        'session': session,
                        'session_num': session_idx + 1,
                        'run': run_idx + 1,
                        'func_file': str(func_file),
                        'n_volumes': n_volumes
                    })
                    
                except Exception as e:
                    print(f"    ⚠️ Error processing {func_file}: {e}")
                    continue
        
        # Save scan list and info
        scan_list_file = output_dir / f"{subject_id}_scan_list.txt"
        with open(scan_list_file, 'w') as f:
            for scan in all_scans:
                f.write(f"{scan}\n")
        
        scan_info_file = output_dir / f"{subject_id}_scan_info.json"
        with open(scan_info_file, 'w') as f:
            json.dump(scan_info, f, indent=2)
        
        print(f"  ✅ Scan list saved: {scan_list_file}")
        return str(scan_list_file), scan_info
    
    def combine_confounds(self, subject_id, output_dir, session_info):
        """Combine confounds using template specifications"""
        print(f"🔧 Combining confounds for {subject_id} (template-based)")
        
        subject_data = next(s for s in self.subjects if s['id'] == subject_id)
        combined_confounds = []
        
        for session_entry in session_info:
            session = session_entry['session']
            run_idx = session_entry['run'] - 1
            
            session_data = subject_data['sessions'][session]
            
            if run_idx < len(session_data['confounds_files']):
                confounds_file = session_data['confounds_files'][run_idx]
                
                try:
                    confounds_df = pd.read_csv(confounds_file, sep='\t')
                    
                    # Select key confounds (could be specified in template)
                    key_confounds = [
                        'trans_x', 'trans_y', 'trans_z',
                        'rot_x', 'rot_y', 'rot_z',
                        'framewise_displacement',
                        'global_signal', 'csf', 'white_matter'
                    ]
                    
                    available_confounds = [col for col in key_confounds if col in confounds_df.columns]
                    confounds_subset = confounds_df[available_confounds].fillna(0)
                    
                    combined_confounds.append(confounds_subset)
                    print(f"  📄 Added confounds from {session} run {run_idx + 1}")
                    
                except Exception as e:
                    print(f"    ⚠️ Error reading confounds: {e}")
                    # Create dummy confounds
                    n_volumes = session_entry.get('n_volumes', 150)
                    dummy_confounds = pd.DataFrame(np.zeros((n_volumes, 6)),
                                                 columns=['trans_x', 'trans_y', 'trans_z', 'rot_x', 'rot_y', 'rot_z'])
                    combined_confounds.append(dummy_confounds)
        
        if combined_confounds:
            combined_df = pd.concat(combined_confounds, ignore_index=True)
            confounds_file = output_dir / f"{subject_id}_combined_confounds.txt"
            combined_df.to_csv(confounds_file, sep='\t', index=False, header=False)
            
            print(f"  ✅ Combined confounds saved: {confounds_file}")
            return str(confounds_file)
        
        return None
    
    def get_run_duration(self, func_file):
        """Get duration of functional run"""
        try:
            import nibabel as nib
            img = nib.load(func_file)
            n_volumes = img.shape[3] if len(img.shape) > 3 else img.shape[2]
            duration = n_volumes * self.tr
            return duration
        except:
            return 300.0  # Default fallback
    
    def create_spm_batch_from_template(self, subject_id):
        """Create SPM batch script using template configuration"""
        print(f"🔧 Creating SPM batch for {subject_id} using template")
        
        # Create subject output directory
        subject_output_dir = self.analysis_path / subject_id
        subject_output_dir.mkdir(exist_ok=True)
        
        # Get subject data
        subject_data = next(s for s in self.subjects if s['id'] == subject_id)
        
        # Combine events files using template configuration
        combined_events_file, session_info = self.combine_events_files_from_template(subject_id, subject_output_dir)
        if not combined_events_file:
            return None
        
        # Combine scan lists
        scan_list_file, scan_info = self.combine_scan_lists(subject_id, subject_output_dir)
        
        # Combine confounds
        confounds_file = self.combine_confounds(subject_id, subject_output_dir, session_info)
        
        # Get analysis parameters from template
        analysis_params = self.analysis_config.get('parameters', {})
        conditions_config = self.analysis_config.get('conditions', {})
        
        # Create MATLAB batch script
        batch_content = f'''%% SPM Combined Session Level 1 Analysis (Template-Based)
%% Subject: {subject_id}
%% Sessions: {', '.join(self.sessions)}
%% Template: {self.analysis_config.get('analysis_name', 'unnamed')}
%% Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

%% Initialize SPM
spm('defaults', 'fMRI');
spm_jobman('initcfg');
clear matlabbatch;

%% Analysis directory
analysis_dir = '{subject_output_dir}';

%% Load combined events data
events_file = '{combined_events_file}';
events_data = readtable(events_file, 'FileType', 'text', 'Delimiter', '\\t');

%% Load scan list
scan_list_file = '{scan_list_file}';
scan_list = {{}};
fid = fopen(scan_list_file, 'r');
if fid ~= -1
    line = fgetl(fid);
    while ischar(line)
        scan_list{{end+1}} = line;
        line = fgetl(fid);
    end
    fclose(fid);
end

fprintf('Loaded %d scans for {subject_id}\\n', length(scan_list));

%% Model Specification
matlabbatch{{1}}.spm.stats.fmri_spec.dir = {{analysis_dir}};
matlabbatch{{1}}.spm.stats.fmri_spec.timing.units = 'secs';
matlabbatch{{1}}.spm.stats.fmri_spec.timing.RT = {analysis_params.get('tr', 2.0)};
matlabbatch{{1}}.spm.stats.fmri_spec.timing.fmri_t = 16;
matlabbatch{{1}}.spm.stats.fmri_spec.timing.fmri_t0 = 8;

%% Session: Combined sessions
matlabbatch{{1}}.spm.stats.fmri_spec.sess(1).scans = scan_list';

%% Setup conditions from template
'''
        
        # Add conditions from template
        main_conditions = conditions_config.get('main_conditions', [])
        parametric_modulators = conditions_config.get('parametric_modulators', [])
        
        if main_conditions:
            batch_content += f'''
%% Main conditions from template
main_conditions = {main_conditions};
cond_idx = 1;

for i = 1:length(main_conditions)
    condition_name = main_conditions{{i}};
    
    % Find trials for this condition
    condition_trials = strcmp(events_data.trial_type, condition_name);
    
    if any(condition_trials)
        % Get onsets and durations
        onsets = events_data.onset(condition_trials);
        durations = events_data.duration(condition_trials);
        
        if isempty(durations) || all(isnan(durations))
            durations = zeros(size(onsets));
        end
        
        % Setup condition
        matlabbatch{{1}}.spm.stats.fmri_spec.sess(1).cond(cond_idx).name = condition_name;
        matlabbatch{{1}}.spm.stats.fmri_spec.sess(1).cond(cond_idx).onset = onsets;
        matlabbatch{{1}}.spm.stats.fmri_spec.sess(1).cond(cond_idx).duration = durations;
        
        % Session effect modulator
        if any(condition_trials)
            session_nums = events_data.session_num(condition_trials);
            session_effect = session_nums - mean(session_nums);
            
            matlabbatch{{1}}.spm.stats.fmri_spec.sess(1).cond(cond_idx).pmod(1).name = 'session_effect';
            matlabbatch{{1}}.spm.stats.fmri_spec.sess(1).cond(cond_idx).pmod(1).param = session_effect;
            matlabbatch{{1}}.spm.stats.fmri_spec.sess(1).cond(cond_idx).pmod(1).poly = 1;
        end
        
        cond_idx = cond_idx + 1;
    end
end
'''
        else:
            # Fallback: auto-detect conditions
            batch_content += '''
%% Auto-detect conditions from events
unique_trial_types = unique(events_data.trial_type);
cond_idx = 1;

for i = 1:length(unique_trial_types)
    trial_type = unique_trial_types{i};
    if ~strcmp(trial_type, 'rest') && ~strcmp(trial_type, 'fixation')
        condition_trials = strcmp(events_data.trial_type, trial_type);
        
        if any(condition_trials)
            onsets = events_data.onset(condition_trials);
            durations = events_data.duration(condition_trials);
            
            if isempty(durations) || all(isnan(durations))
                durations = zeros(size(onsets));
            end
            
            matlabbatch{1}.spm.stats.fmri_spec.sess(1).cond(cond_idx).name = char(trial_type);
            matlabbatch{1}.spm.stats.fmri_spec.sess(1).cond(cond_idx).onset = onsets;
            matlabbatch{1}.spm.stats.fmri_spec.sess(1).cond(cond_idx).duration = durations;
            
            % Session effect modulator
            session_nums = events_data.session_num(condition_trials);
            session_effect = session_nums - mean(session_nums);
            
            matlabbatch{1}.spm.stats.fmri_spec.sess(1).cond(cond_idx).pmod(1).name = 'session_effect';
            matlabbatch{1}.smp.stats.fmri_spec.sess(1).cond(cond_idx).pmod(1).param = session_effect;
            matlabbatch{1}.spm.stats.fmri_spec.sess(1).cond(cond_idx).pmod(1).poly = 1;
            
            cond_idx = cond_idx + 1;
        end
    end
end
'''
        
        # Add confounds
        if confounds_file:
            batch_content += f'''
%% Multiple regressors from template
confounds_file = '{confounds_file}';
if exist(confounds_file, 'file')
    matlabbatch{{1}}.spm.stats.fmri_spec.sess(1).multi_reg = {{confounds_file}};
end
'''
        
        # Add session regressors
        batch_content += '''
%% Session-specific regressors
session_regressors = [];
'''
        
        for i, session_entry in enumerate(session_info):
            start_vol = sum([s.get('n_volumes', 0) for s in session_info[:i]]) + 1
            end_vol = start_vol + session_entry.get('n_volumes', 0) - 1
            
            batch_content += f'''
% Session {session_entry['session']} regressor
session_reg_{i+1} = zeros(length(scan_list), 1);
session_reg_{i+1}({start_vol}:{end_vol}) = 1;
session_regressors = [session_regressors, session_reg_{i+1}];
'''
        
        # Additional model parameters from template
        model_basis = analysis_params.get('model_basis', 'hrf')
        model_derivs = analysis_params.get('model_derivatives', [0, 0])
        mask_threshold = analysis_params.get('mask_threshold', 0.8)
        
        batch_content += f'''
%% Add session regressors
if ~isempty(session_regressors)
    session_reg_file = fullfile(analysis_dir, 'session_regressors.txt');
    dlmwrite(session_reg_file, session_regressors, 'delimiter', '\\t');
    
    if exist('confounds_file', 'var') && exist(confounds_file, 'file')
        existing_confounds = dlmread(confounds_file);
        combined_regressors = [existing_confounds, session_regressors];
    else
        combined_regressors = session_regressors;
    end
    
    combined_reg_file = fullfile(analysis_dir, 'combined_regressors.txt');
    dlmwrite(combined_reg_file, combined_regressors, 'delimiter', '\\t');
    matlabbatch{{1}}.spm.stats.fmri_spec.sess(1).multi_reg = {{combined_reg_file}};
end

%% Model settings from template
matlabbatch{{1}}.spm.stats.fmri_spec.fact = struct('name', {{}}, 'levels', {{}});
'''
        
        if model_basis == 'hrf':
            batch_content += f"matlabbatch{{1}}.spm.stats.fmri_spec.bases.hrf.derivs = {model_derivs};\n"
        elif model_basis == 'gamma':
            batch_content += "matlabbatch{1}.spm.stats.fmri_spec.bases.gamma.length = 32;\n"
            batch_content += "matlabbatch{1}.spm.stats.fmri_spec.bases.gamma.order = 1;\n"
        
        batch_content += f'''
matlabbatch{{1}}.spm.stats.fmri_spec.volt = 1;
matlabbatch{{1}}.spm.stats.fmri_spec.global = 'None';
matlabbatch{{1}}.spm.stats.fmri_spec.mthresh = {mask_threshold};
matlabbatch{{1}}.spm.stats.fmri_spec.mask = {{}};
matlabbatch{{1}}.spm.stats.fmri_spec.cvi = 'AR(1)';
matlabbatch{{1}}.spm.stats.fmri_spec.sess(1).hpf = {self.hpf};

%% Model Estimation
matlabbatch{{2}}.spm.stats.fmri_est.spmmat = {{fullfile(analysis_dir, 'SPM.mat')}};
matlabbatch{{2}}.spm.stats.fmri_est.write_residuals = 0;
matlabbatch{{2}}.spm.stats.fmri_est.method.Classical = 1;

%% Contrasts from template
matlabbatch{{3}}.spm.stats.con.spmmat = {{fullfile(analysis_dir, 'SPM.mat')}};
'''
        
        # Add contrasts from template
        for i, contrast in enumerate(self.contrasts, 1):
            contrast_name = contrast['name']
            contrast_type = contrast['type']
            
            if contrast_type == 't':
                contrast_vector = contrast.get('vector', [1])
                batch_content += f'''
matlabbatch{{3}}.spm.stats.con.consess{{{i}}}.tcon.name = '{contrast_name}';
matlabbatch{{3}}.spm.stats.con.consess{{{i}}}.tcon.weights = {contrast_vector};
matlabbatch{{3}}.spm.stats.con.consess{{{i}}}.tcon.sessrep = 'none';
'''
            elif contrast_type == 'f':
                contrast_matrix = contrast.get('matrix', [[1]])
                # Convert to MATLAB format
                matrix_str = '[' + '; '.join([' '.join(map(str, row)) for row in contrast_matrix]) + ']'
                batch_content += f'''
matlabbatch{{3}}.spm.stats.con.consess{{{i}}}.fcon.name = '{contrast_name}';
matlabbatch{{3}}.spm.stats.con.consess{{{i}}}.fcon.weights = {matrix_str};
matlabbatch{{3}}.spm.stats.con.consess{{{i}}}.fcon.sessrep = 'none';
'''
        
        batch_content += '''
matlabbatch{3}.spm.stats.con.delete = 0;

%% Run the analysis
try
    fprintf('Starting SPM analysis for ''' + subject_id + ''' using template\\n');
    tic;
    spm_jobman('run', matlabbatch);
    elapsed_time = toc;
    fprintf('Template-based analysis completed in %.2f minutes\\n', elapsed_time/60);
    
    % Save completion status
    status_file = fullfile(analysis_dir, 'analysis_complete.txt');
    fid = fopen(status_file, 'w');
    fprintf(fid, 'Template-based analysis completed: %s\\n', datestr(now));
    fprintf(fid, 'Template: ''' + self.analysis_config.get('analysis_name', 'unnamed') + '''\\n');
    fprintf(fid, 'Elapsed time: %.2f minutes\\n', elapsed_time/60);
    fclose(fid);
    
catch ME
    fprintf('ERROR in template-based SPM analysis: %s\\n', ME.message);
    error_file = fullfile(analysis_dir, 'analysis_error.txt');
    fid = fopen(error_file, 'w');
    fprintf(fid, 'Template-based analysis failed: %s\\n', datestr(now));
    fprintf(fid, 'Error: %s\\n', ME.message);
    fclose(fid);
    rethrow(ME);
end
'''
        
        # Save batch script
        batch_file = subject_output_dir / f'{subject_id}_level1_template_batch.m'
        with open(batch_file, 'w') as f:
            f.write(batch_content)
        
        print(f"  ✅ Template-based SPM batch created: {batch_file}")
        
        return {
            'batch_file': str(batch_file),
            'output_dir': str(subject_output_dir),
            'events_file': combined_events_file,
            'scan_list_file': scan_list_file,
            'confounds_file': confounds_file,
            'session_info': session_info
        }
    
    def create_slurm_job_from_template(self, subject_id, batch_info):
        """Create SLURM job using template configuration"""
        print(f"🖥️ Creating SLURM job for {subject_id} (template-based)")
        
        # Get SLURM configuration from template
        cluster_settings = self.slurm_config.get('cluster_settings', {})
        software_modules = self.slurm_config.get('software_modules', ['matlab/R2023a'])
        environment = self.slurm_config.get('environment', {})
        submission_options = self.slurm_config.get('submission_options', {})
        
        # Create job script
        job_content = f'''#!/bin/bash
#SBATCH --job-name=spm_l1_template_{subject_id}
#SBATCH --partition={cluster_settings.get('partition', 'normal')}
#SBATCH --time={cluster_settings.get('time', '4:00:00')}
#SBATCH --mem={cluster_settings.get('memory', '16G')}
#SBATCH --cpus-per-task={cluster_settings.get('cpus', 4)}
#SBATCH --output={self.logs_path}/{subject_id}_spm_l1_template_%j.out
#SBATCH --error={self.logs_path}/{subject_id}_spm_l1_template_%j.err
'''
        
        # Add email notifications if specified
        if submission_options.get('email_notifications') and submission_options.get('email_address'):
            job_content += f'''#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user={submission_options['email_address']}
'''
        
        # Load software modules
        job_content += '\n# Load required modules\n'
        for module in software_modules:
            job_content += f'module load {module}\n'
        
        # Set environment variables
        job_content += '\n# Set environment variables\n'
        for env_var, env_value in environment.items():
            job_content += f'export {env_var.upper()}="{env_value}"\n'
        
        job_content += f'''
export SUBJECT_ID="{subject_id}"
export BATCH_FILE="{batch_info['batch_file']}"
export OUTPUT_DIR="{batch_info['output_dir']}"
export TEMPLATE_NAME="{self.analysis_config.get('analysis_name', 'unnamed')}"

# Print job information
echo "=========================================="
echo "SPM Level 1 Analysis (Template-Based)"
echo "Subject: $SUBJECT_ID"
echo "Template: $TEMPLATE_NAME"
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURMD_NODENAME"
echo "Started: $(date)"
echo "=========================================="

# Change to analysis directory
cd "$OUTPUT_DIR"

# Run MATLAB with SPM
matlab -nodisplay -nosplash -batch "
    addpath('$SPM_PATH');
    spm('defaults', 'fMRI');
    spm_jobman('initcfg');
    try
        run('$BATCH_FILE');
        fprintf('SUCCESS: Template-based analysis completed for $SUBJECT_ID\\n');
        exit(0);
    catch ME
        fprintf('ERROR: Template-based analysis failed for $SUBJECT_ID\\n');
        fprintf('Error message: %s\\n', ME.message);
        exit(1);
    end
"

# Check completion
if [ -f "$OUTPUT_DIR/SPM.mat" ] && [ -f "$OUTPUT_DIR/analysis_complete.txt" ]; then
    echo "=========================================="
    echo "SUCCESS: Template-based analysis completed for $SUBJECT_ID"
    echo "Template: $TEMPLATE_NAME"
    echo "Finished: $(date)"
    echo "=========================================="
    exit 0
else
    echo "=========================================="
    echo "ERROR: Template-based analysis failed for $SUBJECT_ID"
    echo "Check log files and output directory"
    echo "Finished: $(date)"
    echo "=========================================="
    exit 1
fi
'''
        
        # Save job script
        job_file = self.jobs_path / f'{subject_id}_spm_level1_template.sh'
        with open(job_file, 'w') as f:
            f.write(job_content)
        
        os.chmod(job_file, 0o755)
        
        print(f"  ✅ Template-based SLURM job created: {job_file}")
        return str(job_file)
    
    def prepare_all_subjects_from_template(self, subjects_to_run=None):
        """Prepare analysis for subjects using template configuration"""
        print("\n🚀 PREPARING TEMPLATE-BASED COMBINED SESSION ANALYSIS")
        print("=" * 70)
        
        # Apply exclusion criteria first
        valid_subjects = self.validate_subjects_against_exclusion_criteria()
        
        if subjects_to_run is None:
            subjects_to_run = [s['id'] for s in valid_subjects]
        
        prepared_jobs = []
        failed_subjects = []
        
        print(f"\n📊 Preparing {len(subjects_to_run)} subjects...")
        
        for subject_data in valid_subjects:
            subject_id = subject_data['id']
            
            if subject_id not in subjects_to_run:
                continue
            
            print(f"\n📊 Preparing {subject_id}")
            print("-" * 40)
            
            try:
                # Create SPM batch using template
                batch_info = self.create_spm_batch_from_template(subject_id)
                
                if batch_info is None:
                    print(f"  ❌ Failed to create template-based batch for {subject_id}")
                    failed_subjects.append(subject_id)
                    continue
                
                # Create SLURM job using template
                job_file = self.create_slurm_job_from_template(subject_id, batch_info)
                
                job_info = {
                    'subject_id': subject_id,
                    'job_file': job_file,
                    'batch_info': batch_info,
                    'status': 'prepared',
                    'template_based': True,
                    'analysis_template': self.analysis_config.get('analysis_name'),
                    'subject_demographics': subject_data.get('demographics', {})
                }
                
                prepared_jobs.append(job_info)
                print(f"  ✅ {subject_id} ready for template-based submission")
                
            except Exception as e:
                print(f"  ❌ Error preparing {subject_id}: {e}")
                failed_subjects.append(subject_id)
        
        # Save comprehensive job summary with template info
        job_summary = {
            'timestamp': datetime.now().isoformat(),
            'analysis_type': 'template_based_combined_sessions',
            'templates_used': {
                'project': self.project_config.get('project_name'),
                'analysis': self.analysis_config.get('analysis_name'),
                'dataset': self.dataset_config.get('dataset_name'),
                'slurm_config': self.slurm_config.get('config_name')
            },
            'template_configurations': {
                'tr': self.tr,
                'hpf': self.hpf,
                'sessions': self.sessions,
                'task_name': self.task_name,
                'n_contrasts': len(self.contrasts)
            },
            'subject_summary': {
                'total_in_template': len(self.dataset_config.get('subjects', [])),
                'passed_exclusion': len(valid_subjects),
                'requested_for_analysis': len(subjects_to_run),
                'successfully_prepared': len(prepared_jobs),
                'failed_preparation': len(failed_subjects)
            },
            'prepared_jobs': prepared_jobs,
            'failed_subjects': failed_subjects,
            'exclusion_criteria': self.dataset_config.get('exclusion_criteria', {}),
            'contrasts': self.contrasts
        }
        
        summary_file = self.analysis_path / 'template_job_summary.json'
        with open(summary_file, 'w') as f:
            json.dump(job_summary, f, indent=2)
        
        print(f"\n📋 TEMPLATE-BASED PREPARATION SUMMARY")
        print("=" * 50)
        print(f"  Analysis template: {self.analysis_config.get('analysis_name')}")
        print(f"  Dataset template: {self.dataset_config.get('dataset_name')}")
        print(f"  Subjects in template: {len(self.dataset_config.get('subjects', []))}")
        print(f"  Passed exclusion criteria: {len(valid_subjects)}")
        print(f"  Jobs prepared: {len(prepared_jobs)}")
        print(f"  Failed preparations: {len(failed_subjects)}")
        
        if failed_subjects:
            print(f"  Failed subjects: {', '.join(failed_subjects)}")
        
        print(f"\n📄 Template-based job summary: {summary_file}")
        
        return prepared_jobs
    
    def submit_template_jobs(self, prepared_jobs=None, submit_method='individual'):
        """Submit jobs using template-specified submission options"""
        print("\n🚀 SUBMITTING TEMPLATE-BASED SLURM JOBS")
        print("=" * 50)
        
        if prepared_jobs is None:
            summary_file = self.analysis_path / 'template_job_summary.json'
            if summary_file.exists():
                with open(summary_file, 'r') as f:
                    job_summary = json.load(f)
                prepared_jobs = job_summary['prepared_jobs']
            else:
                print("❌ No prepared jobs found. Run prepare_all_subjects_from_template() first.")
                return []
        
        # Get submission options from template
        submission_options = self.slurm_config.get('submission_options', {})
        use_array_job = submission_options.get('array_job', False)
        max_concurrent = submission_options.get('max_concurrent', 5)
        
        if submit_method == 'auto':
            submit_method = 'array' if use_array_job else 'individual'
        
        submitted_jobs = []
        
        if submit_method == 'individual':
            print(f"📤 Submitting {len(prepared_jobs)} template-based jobs individually...")
            
            for i, job_info in enumerate(prepared_jobs):
                subject_id = job_info['subject_id']
                job_file = job_info['job_file']
                
                try:
                    cmd = ['sbatch', job_file]
                    result = subprocess.run(cmd, capture_output=True, text=True)
                    
                    if result.returncode == 0:
                        job_id = result.stdout.strip().split()[-1]
                        
                        job_info['slurm_job_id'] = job_id
                        job_info['submission_time'] = datetime.now().isoformat()
                        job_info['status'] = 'submitted'
                        job_info['submission_method'] = 'individual'
                        
                        submitted_jobs.append(job_info)
                        print(f"  ✅ {subject_id}: Job {job_id} submitted (template-based)")
                        
                        # Rate limiting
                        if (i + 1) % max_concurrent == 0 and i < len(prepared_jobs) - 1:
                            print(f"    ⏳ Submitted {i + 1} jobs, pausing...")
                            import time
                            time.sleep(2)
                    
                    else:
                        print(f"  ❌ {subject_id}: Submission failed - {result.stderr}")
                        job_info['status'] = 'submission_failed'
                        job_info['error'] = result.stderr
                
                except Exception as e:
                    print(f"  ❌ {subject_id}: Exception - {e}")
                    job_info['status'] = 'submission_error'
                    job_info['error'] = str(e)
        
        elif submit_method == 'array':
            print("📤 Submitting as template-based array job...")
            submitted_jobs = self.submit_template_array_job(prepared_jobs)
        
        # Save submission summary with template info
        submission_summary = {
            'timestamp': datetime.now().isoformat(),
            'submission_type': 'template_based',
            'analysis_template': self.analysis_config.get('analysis_name'),
            'submitted_jobs': len(submitted_jobs),
            'submission_method': submit_method,
            'template_settings': {
                'array_job_preferred': use_array_job,
                'max_concurrent': max_concurrent,
                'slurm_config': self.slurm_config.get('config_name')
            },
            'jobs': submitted_jobs
        }
        
        submission_file = self.analysis_path / 'template_submission_summary.json'
        with open(submission_file, 'w') as f:
            json.dump(submission_summary, f, indent=2)
        
        print(f"\n📊 TEMPLATE-BASED SUBMISSION SUMMARY")
        print("=" * 40)
        print(f"  Analysis template: {self.analysis_config.get('analysis_name')}")
        print(f"  Jobs submitted: {len(submitted_jobs)}")
        print(f"  Submission method: {submit_method}")
        print(f"  Submission file: {submission_file}")
        
        return submitted_jobs
    
    def submit_template_array_job(self, prepared_jobs):
        """Submit template-based array job"""
        print("📤 Creating template-based array job...")
        
        # Get environment settings from template
        environment = self.slurm_config.get('environment', {})
        cluster_settings = self.slurm_config.get('cluster_settings', {})
        
        array_job_content = f'''#!/bin/bash
#SBATCH --job-name=spm_l1_template_array
#SBATCH --partition={cluster_settings.get('partition', 'normal')}
#SBATCH --time={cluster_settings.get('time', '4:00:00')}
#SBATCH --mem={cluster_settings.get('memory', '16G')}
#SBATCH --cpus-per-task={cluster_settings.get('cpus', 4)}
#SBATCH --array=1-{len(prepared_jobs)}
#SBATCH --output={self.logs_path}/spm_l1_template_array_%A_%a.out
#SBATCH --error={self.logs_path}/spm_l1_template_array_%A_%a.err

# Template-based analysis array job
# Analysis template: {self.analysis_config.get('analysis_name')}
# Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

# Load modules from template
'''
        
        for module in self.slurm_config.get('software_modules', []):
            array_job_content += f'module load {module}\n'
        
        array_job_content += '\n# Environment from template\n'
        for env_var, env_value in environment.items():
            array_job_content += f'export {env_var.upper()}="{env_value}"\n'
        
        array_job_content += f'''

# Array of job files
declare -a JOB_FILES=(
'''
        
        for job_info in prepared_jobs:
            array_job_content += f'    "{job_info["job_file"]}"\n'
        
        array_job_content += f''')

# Get current job
JOB_FILE="${{JOB_FILES[$SLURM_ARRAY_TASK_ID-1]}}"
SUBJECT_ID=$(basename "$JOB_FILE" | cut -d'_' -f1)

echo "=========================================="
echo "SPM Level 1 Template Array Job"
echo "Analysis Template: {self.analysis_config.get('analysis_name')}"
echo "Array Job ID: $SLURM_ARRAY_JOB_ID"
echo "Task ID: $SLURM_ARRAY_TASK_ID"
echo "Subject: $SUBJECT_ID"
echo "Job File: $JOB_FILE"
echo "Started: $(date)"
echo "=========================================="

# Execute the job
bash "$JOB_FILE"
'''
        
        # Save and submit array job
        array_job_file = self.jobs_path / 'spm_level1_template_array.sh'
        with open(array_job_file, 'w') as f:
            f.write(array_job_content)
        
        os.chmod(array_job_file, 0o755)
        
        try:
            cmd = ['sbatch', str(array_job_file)]
            result = subprocess.run(cmd, capture_output=True, text=True)
            
            if result.returncode == 0:
                array_job_id = result.stdout.strip().split()[-1]
                print(f"  ✅ Template-based array job submitted: {array_job_id}")
                
                submitted_jobs = []
                for i, job_info in enumerate(prepared_jobs):
                    job_info['array_job_id'] = array_job_id
                    job_info['array_task_id'] = i + 1
                    job_info['submission_time'] = datetime.now().isoformat()
                    job_info['status'] = 'submitted_array'
                    job_info['submission_method'] = 'array'
                    submitted_jobs.append(job_info)
                
                return submitted_jobs
            else:
                print(f"  ❌ Array job submission failed: {result.stderr}")
                return []
        
        except Exception as e:
            print(f"  ❌ Exception during array job submission: {e}")
            return []
    
    def monitor_jobs(self, check_interval=30):
        """Monitor running jobs"""
        print("\n🔍 MONITORING TEMPLATE-BASED SLURM JOBS")
        print("=" * 50)
        
        # Load submission summary
        submission_file = self.analysis_path / 'template_submission_summary.json'
        if not submission_file.exists():
            print("❌ No submission summary found. Submit jobs first.")
            return
        
        with open(submission_file, 'r') as f:
            submission_data = json.load(f)
        
        submitted_jobs = submission_data['jobs']
        job_ids = [j.get('slurm_job_id') or f"{j.get('array_job_id')}_{j.get('array_task_id')}" 
                   for j in submitted_jobs if 'slurm_job_id' in j or 'array_job_id' in j]
        
        if not job_ids:
            print("❌ No job IDs found in submission summary.")
            return
        
        print(f"📊 Monitoring {len(job_ids)} template-based jobs...")
        print(f"📋 Analysis template: {submission_data.get('analysis_template')}")
        print("  Use Ctrl+C to stop monitoring")
        print("  Jobs will continue running in background")
        print()
        
        try:
            import time
            while True:
                # Check job status
                cmd = ['squeue', '-j', ','.join(job_ids[:20]), '--format=%i,%T,%M,%N']
                try:
                    result = subprocess.run(cmd, capture_output=True, text=True)
                    if result.returncode == 0:
                        lines = result.stdout.strip().split('\n')
                        if len(lines) > 1:  # Has header + data
                            print(f"📊 Job Status ({datetime.now().strftime('%H:%M:%S')})")
                            for line in lines:
                                print(f"  {line}")
                        else:
                            print(f"✅ All template-based jobs completed! ({datetime.now().strftime('%H:%M:%S')})")
                            break
                    else:
                        print(f"⚠️ Error checking job status: {result.stderr}")
                
                except Exception as e:
                    print(f"⚠️ Exception checking jobs: {e}")
                
                print(f"  Next check in {check_interval} seconds...\n")
                time.sleep(check_interval)
        
        except KeyboardInterrupt:
            print("\n🛑 Monitoring stopped. Template-based jobs continue running.")
            print("  Check status manually with: squeue -u $USER")
    
    def check_completion(self):
        """Check which subjects have completed analysis"""
        print("\n📊 CHECKING TEMPLATE-BASED ANALYSIS COMPLETION")
        print("=" * 50)
        
        completed = []
        failed = []
        running = []
        
        for subject_data in self.subjects:
            subject_id = subject_data['id']
            subject_dir = self.analysis_path / subject_id
            
            if not subject_dir.exists():
                continue
            
            spm_file = subject_dir / 'SPM.mat'
            complete_file = subject_dir / 'analysis_complete.txt'
            error_file = subject_dir / 'analysis_error.txt'
            
            if complete_file.exists() and spm_file.exists():
                completed.append(subject_id)
                try:
                    with open(complete_file, 'r') as f:
                        content = f.read()
                    print(f"  ✅ {subject_id}: Template-based analysis completed")
                except:
                    print(f"  ✅ {subject_id}: Completed")
            
            elif error_file.exists():
                failed.append(subject_id)
                try:
                    with open(error_file, 'r') as f:
                        error_content = f.read()
                    print(f"  ❌ {subject_id}: Failed - {error_content.strip()}")
                except:
                    print(f"  ❌ {subject_id}: Failed")
            
            else:
                running.append(subject_id)
                print(f"  ⏳ {subject_id}: Running or not started")
        
        print(f"\n📋 TEMPLATE-BASED COMPLETION SUMMARY")
        print("=" * 40)
        print(f"  Analysis template: {self.analysis_config.get('analysis_name')}")
        print(f"  Completed: {len(completed)}")
        print(f"  Failed: {len(failed)}")
        print(f"  Running/Pending: {len(running)}")
        
        return {
            'completed': completed,
            'failed': failed,
            'running': running
        }

# Convenience functions for template-based workflow
def setup_template_based_analysis(templates_dir, project_name=None):
    """Setup template-based analysis pipeline"""
    print("🚀 Setting up template-based combined session analysis...")
    
    try:
        pipeline = TemplateBasedCombinedLevel1Pipeline(templates_dir, project_name)
        return pipeline
    except Exception as e:
        print(f"❌ Error setting up pipeline: {e}")
        print("💡 Make sure you have created templates first:")
        print("   from json_template_system import create_example_templates")
        print("   create_example_templates('./templates')")
        return None

def create_analysis_from_templates(templates_dir, project_name=None, subjects_subset=None):
    """Complete template-based analysis workflow"""
    # Setup pipeline
    pipeline = setup_template_based_analysis(templates_dir, project_name)
    if pipeline is None:
        return None, None
    
    # Prepare jobs
    prepared_jobs = pipeline.prepare_all_subjects_from_template(subjects_subset)
    
    if not prepared_jobs:
        print("❌ No jobs prepared successfully")
        return pipeline, None
    
    print(f"\n🎯 Template-based preparation complete!")
    print(f"📊 Analysis template: {pipeline.analysis_config.get('analysis_name')}")
    print(f"📋 Jobs prepared: {len(prepared_jobs)}")
    print("\n🔧 Next steps:")
    print("1. Review template-based batch scripts")
    print("2. Submit: pipeline.submit_template_jobs(prepared_jobs)")
    print("3. Monitor: pipeline.monitor_jobs()")
    
    return pipeline, prepared_jobs

def quick_template_test(templates_dir, project_name=None, n_subjects=2):
    """Quick test with template-based pipeline"""
    pipeline = setup_template_based_analysis(templates_dir, project_name)
    if pipeline is None:
        return None, None
    
    if len(pipeline.subjects) == 0:
        print("❌ No subjects found in templates")
        return pipeline, None
    
    # Use first n subjects
    test_subjects = [s['id'] for s in pipeline.subjects[:n_subjects]]
    
    print(f"\n🧪 Running template-based test on {len(test_subjects)} subjects...")
    print(f"Test subjects: {', '.join(test_subjects)}")
    
    prepared_jobs = pipeline.prepare_all_subjects_from_template(test_subjects)
    
    return pipeline, prepared_jobs

# Example usage
if __name__ == "__main__":
    print("🧠 Template-Based Combined Session Level 1 fMRI Analysis")
    print("=" * 70)
    print()
    print("This pipeline uses JSON templates to configure and run")
    print("combined session Level 1 analyses with SLURM submission.")
    print()
    print("📋 QUICK START:")
    print("1. Create templates:")
    print("   from json_template_system import create_example_templates")
    print("   create_example_templates('./templates')")
    print()
    print("2. Setup pipeline:")
    print("   pipeline = setup_template_based_analysis('./templates', 'geoscan_v2')")
    print()
    print("3. Run analysis:")
    print("   pipeline, jobs = create_analysis_from_templates('./templates')")
    print()
    print("4. Submit jobs:")
    print("   pipeline.submit_template_jobs(jobs)")
    print()
    print("🧪 TESTING:")
    print("   pipeline, jobs = quick_template_test('./templates', n_subjects=2)")
    print()
    print("🎯 FEATURES:")
    print("• JSON-based configuration system")
    print("• Flexible subject and session specification")
    print("• Template-driven analysis parameters")
    print("• Automated exclusion criteria application")
    print("• SLURM job generation with template settings")
    print("• Comprehensive logging and tracking")
    print("• Reproducible analysis workflows")