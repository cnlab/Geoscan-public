#!/usr/bin/env python3
"""
JSON Template System for fMRI Analysis Pipeline
Flexible configuration system using JSON templates
"""

import os
import json
import glob
from pathlib import Path
from datetime import datetime
import warnings
warnings.filterwarnings('ignore')

class AnalysisTemplateManager:
    """Manages JSON templates for fMRI analysis configuration"""
    
    def __init__(self, templates_dir=None):
        if templates_dir is None:
            templates_dir = Path.cwd() / 'analysis_templates'
        
        self.templates_dir = Path(templates_dir)
        self.templates_dir.mkdir(exist_ok=True)
        
        # Template schemas
        self.schemas = {
            'project': self.get_project_schema(),
            'dataset': self.get_dataset_schema(),
            'analysis': self.get_analysis_schema(),
            'slurm': self.get_slurm_schema()
        }
    
    def get_project_schema(self):
        """Schema for project-level configuration"""
        return {
            "type": "object",
            "properties": {
                "project_name": {"type": "string"},
                "project_path": {"type": "string"},
                "derivatives_path": {"type": "string"},
                "task_name": {"type": "string"},
                "sessions": {
                    "type": "array",
                    "items": {"type": "string"}
                },
                "bids_compliant": {"type": "boolean"},
                "description": {"type": "string"},
                "created": {"type": "string"},
                "modified": {"type": "string"}
            },
            "required": ["project_name", "project_path", "task_name", "sessions"]
        }
    
    def get_dataset_schema(self):
        """Schema for dataset/subject configuration"""
        return {
            "type": "object",
            "properties": {
                "dataset_name": {"type": "string"},
                "subjects": {
                    "type": "array",
                    "items": {
                        "type": "object",
                        "properties": {
                            "subject_id": {"type": "string"},
                            "include": {"type": "boolean"},
                            "sessions": {
                                "type": "object",
                                "patternProperties": {
                                    "ses-.*": {
                                        "type": "object",
                                        "properties": {
                                            "func_dir": {"type": "string"},
                                            "func_files": {
                                                "type": "array",
                                                "items": {"type": "string"}
                                            },
                                            "events_files": {
                                                "type": "array", 
                                                "items": {"type": "string"}
                                            },
                                            "confounds_files": {
                                                "type": "array",
                                                "items": {"type": "string"}
                                            },
                                            "include": {"type": "boolean"},
                                            "notes": {"type": "string"}
                                        }
                                    }
                                }
                            },
                            "notes": {"type": "string"},
                            "demographics": {
                                "type": "object",
                                "properties": {
                                    "age": {"type": "number"},
                                    "sex": {"type": "string"},
                                    "group": {"type": "string"}
                                }
                            }
                        },
                        "required": ["subject_id", "sessions"]
                    }
                },
                "exclusion_criteria": {
                    "type": "object",
                    "properties": {
                        "max_motion": {"type": "number"},
                        "min_runs": {"type": "integer"},
                        "required_sessions": {
                            "type": "array",
                            "items": {"type": "string"}
                        }
                    }
                },
                "created": {"type": "string"},
                "modified": {"type": "string"}
            },
            "required": ["dataset_name", "subjects"]
        }
    
    def get_analysis_schema(self):
        """Schema for analysis configuration"""
        return {
            "type": "object",
            "properties": {
                "analysis_name": {"type": "string"},
                "analysis_type": {"type": "string", "enum": ["level1_combined", "level1_separate", "level2", "level3"]},
                "description": {"type": "string"},
                "parameters": {
                    "type": "object",
                    "properties": {
                        "tr": {"type": "number"},
                        "hpf": {"type": "number"},
                        "smoothing": {"type": "number"},
                        "mask_threshold": {"type": "number"},
                        "model_basis": {"type": "string"},
                        "model_derivatives": {
                            "type": "array",
                            "items": {"type": "integer"}
                        }
                    }
                },
                "contrasts": {
                    "type": "array",
                    "items": {
                        "type": "object",
                        "properties": {
                            "name": {"type": "string"},
                            "description": {"type": "string"},
                            "type": {"type": "string", "enum": ["t", "f"]},
                            "vector": {
                                "type": "array",
                                "items": {"type": "number"}
                            },
                            "matrix": {
                                "type": "array",
                                "items": {
                                    "type": "array",
                                    "items": {"type": "number"}
                                }
                            }
                        },
                        "required": ["name", "type"]
                    }
                },
                "conditions": {
                    "type": "object",
                    "properties": {
                        "main_conditions": {
                            "type": "array",
                            "items": {"type": "string"}
                        },
                        "parametric_modulators": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "condition": {"type": "string"},
                                    "modulator_name": {"type": "string"},
                                    "column_name": {"type": "string"},
                                    "polynomial": {"type": "integer"}
                                }
                            }
                        }
                    }
                },
                "output_dir": {"type": "string"},
                "created": {"type": "string"},
                "modified": {"type": "string"}
            },
            "required": ["analysis_name", "analysis_type", "parameters", "contrasts"]
        }
    
    def get_slurm_schema(self):
        """Schema for SLURM configuration"""
        return {
            "type": "object",
            "properties": {
                "config_name": {"type": "string"},
                "cluster_settings": {
                    "type": "object",
                    "properties": {
                        "partition": {"type": "string"},
                        "time": {"type": "string"},
                        "memory": {"type": "string"},
                        "cpus": {"type": "integer"},
                        "nodes": {"type": "integer"},
                        "exclusive": {"type": "boolean"}
                    }
                },
                "software_modules": {
                    "type": "array",
                    "items": {"type": "string"}
                },
                "environment": {
                    "type": "object",
                    "properties": {
                        "matlab_path": {"type": "string"},
                        "spm_path": {"type": "string"},
                        "fsl_path": {"type": "string"},
                        "freesurfer_home": {"type": "string"}
                    }
                },
                "submission_options": {
                    "type": "object",
                    "properties": {
                        "array_job": {"type": "boolean"},
                        "max_concurrent": {"type": "integer"},
                        "dependency": {"type": "string"},
                        "email_notifications": {"type": "boolean"},
                        "email_address": {"type": "string"}
                    }
                },
                "created": {"type": "string"},
                "modified": {"type": "string"}
            },
            "required": ["config_name", "cluster_settings"]
        }
    
    def create_template(self, template_type, template_data, filename=None):
        """Create a template file"""
        if template_type not in self.schemas:
            raise ValueError(f"Unknown template type: {template_type}")
        
        # Add metadata
        template_data['template_type'] = template_type
        template_data['created'] = datetime.now().isoformat()
        template_data['modified'] = datetime.now().isoformat()
        
        # Generate filename if not provided
        if filename is None:
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            filename = f"{template_type}_{template_data.get(f'{template_type}_name', 'unnamed')}_{timestamp}.json"
        
        # Save template
        template_path = self.templates_dir / filename
        with open(template_path, 'w') as f:
            json.dump(template_data, f, indent=2)
        
        print(f"✅ Template created: {template_path}")
        return str(template_path)
    
    def load_template(self, template_path):
        """Load a template file"""
        with open(template_path, 'r') as f:
            template_data = json.load(f)
        
        return template_data
    
    def validate_template(self, template_data, template_type=None):
        """Validate template against schema"""
        if template_type is None:
            template_type = template_data.get('template_type')
        
        if template_type not in self.schemas:
            raise ValueError(f"Unknown template type: {template_type}")
        
        # Basic validation (could use jsonschema library for full validation)
        schema = self.schemas[template_type]
        required_fields = schema.get('required', [])
        
        missing_fields = []
        for field in required_fields:
            if field not in template_data:
                missing_fields.append(field)
        
        if missing_fields:
            print(f"⚠️ Missing required fields: {missing_fields}")
            return False
        
        print("✅ Template validation passed")
        return True
    
    def list_templates(self, template_type=None):
        """List available templates"""
        templates = []
        
        for template_file in self.templates_dir.glob('*.json'):
            try:
                template_data = self.load_template(template_file)
                if template_type is None or template_data.get('template_type') == template_type:
                    templates.append({
                        'path': str(template_file),
                        'name': template_file.name,
                        'type': template_data.get('template_type'),
                        'created': template_data.get('created'),
                        'description': template_data.get('description', '')
                    })
            except:
                continue
        
        return templates

def create_example_templates(templates_dir):
    """Create example templates for common use cases"""
    manager = AnalysisTemplateManager(templates_dir)
    
    # Example project template
    project_template = {
        "project_name": "geoscan_v2",
        "project_path": "/data00/projects/geoscan_v2",
        "derivatives_path": "/data00/projects/geoscan_v2/derivatives",
        "task_name": "geoscan",
        "sessions": ["ses-t2", "ses-t3"],
        "bids_compliant": True,
        "description": "Multi-session geoscan task fMRI study"
    }
    
    project_file = manager.create_template('project', project_template, 'project_geoscan_v2.json')
    
    # Example dataset template  
    dataset_template = {
        "dataset_name": "geoscan_subjects",
        "subjects": [
            {
                "subject_id": "sub-GEO01",
                "include": True,
                "sessions": {
                    "ses-t2": {
                        "func_dir": "/data00/projects/geoscan_v2/data/bids_dataderivatives/sub-GEO001/ses-t2/func",
                        "func_files": ["sub-GEO01_ses-t2_task-geoscan_run-1_space-MNI152NLin2009cAsym_desc-preproc_bold.nii.gz"],
                        "events_files": ["sub-GEO01_ses-t2_task-geoscan_run-1_events.tsv"],
                        "confounds_files": ["sub-GEO01_ses-t2_task-geoscan_run-1_desc-confounds_timeseries.tsv"],
                        "include": True
                    },
                    "ses-t3": {
                        "func_dir": "/data00/projects/geoscan_v2/data/bids_data/derivatives/sub-GEO001/ses-t3/func",
                        "func_files": ["sub-GEO01_ses-t3_task-geoscan_run-1_space-MNI152NLin2009cAsym_desc-preproc_bold.nii.gz"],
                        "events_files": ["sub-GEO01_ses-t3_task-geoscan_run-1_events.tsv"],
                        "confounds_files": ["sub-GEO01_ses-t3_task-geoscan_run-1_desc-confounds_timeseries.tsv"],
                        "include": True
                    }
                },
                "demographics": {
                    "age": 25,
                    "sex": "F",
                    "group": "control"
                }
            }
        ],
        "exclusion_criteria": {
            "max_motion": 3.0,
            "min_runs": 1,
            "required_sessions": ["ses-t2", "ses-t3"]
        }
    }
    
    dataset_file = manager.create_template('dataset', dataset_template, 'dataset_geoscan_subjects.json')
    
    # Example analysis template
    analysis_template = {
        "analysis_name": "level1_combined_sessions",
        "analysis_type": "level1_combined",
        "description": "Combined session Level 1 analysis for geoscan task",
        "parameters": {
            "tr": 2.0,
            "hpf": 128,
            "smoothing": 6.0,
            "mask_threshold": 0.8,
            "model_basis": "hrf",
            "model_derivatives": [0, 0]
        },
        "conditions": {
            "main_conditions": ["task", "rest"],
            "parametric_modulators": [
                {
                    "condition": "task",
                    "modulator_name": "difficulty",
                    "column_name": "difficulty_rating",
                    "polynomial": 1
                }
            ]
        },
        "contrasts": [
            {
                "name": "task_vs_rest",
                "description": "Main task effect across sessions",
                "type": "t",
                "vector": [1, -1, 0]
            },
            {
                "name": "session_effect",
                "description": "Session difference (ses-t3 vs ses-t2)",
                "type": "t",
                "vector": [0, 0, 1]
            },
            {
                "name": "task_main_effect",
                "description": "F-test for any task effect",
                "type": "f",
                "matrix": [[1, -1, 0], [0, 0, 1]]
            }
        ],
        "output_dir": "/data00/projects/geoscan_v2/derivatives/level1_combined_sessions"
    }
    
    analysis_file = manager.create_template('analysis', analysis_template, 'analysis_level1_combined.json')
    
    # Example SLURM template
    slurm_template = {
        "config_name": "standard_fmri_analysis",
        "cluster_settings": {
            "partition": "normal",
            "time": "4:00:00",
            "memory": "16G",
            "cpus": 4,
            "nodes": 1,
            "exclusive": False
        },
        "software_modules": [
            "matlab/R2023a",
            "fsl/6.0.4",
            "freesurfer/7.2.0"
        ],
        "environment": {
            "matlab_path": "/shared/software/matlab/R2023a",
            "spm_path": "/shared/software/spm12",
            "fsl_path": "/shared/software/fsl/6.0.4",
            "freesurfer_home": "/shared/software/freesurfer/7.2.0"
        },
        "submission_options": {
            "array_job": True,
            "max_concurrent": 10,
            "email_notifications": True,
            "email_address": "user@university.edu"
        }
    }
    
    slurm_file = manager.create_template('slurm', slurm_template, 'slurm_standard_fmri.json')
    
    print(f"\n📋 Example templates created in: {templates_dir}")
    print(f"  📄 Project: {project_file}")
    print(f"  📄 Dataset: {dataset_file}")
    print(f"  📄 Analysis: {analysis_file}")
    print(f"  📄 SLURM: {slurm_file}")
    
    return {
        'project': project_file,
        'dataset': dataset_file,
        'analysis': analysis_file,
        'slurm': slurm_file
    }

def scan_project_for_subjects(project_template, task_name=None):
    """Automatically scan project directory and create dataset template"""
    print("🔍 Scanning project for subjects...")
    
    project_path = Path(project_template['project_path'])
    if task_name is None:
        task_name = project_template['task_name']
    sessions = project_template['sessions']
    
    # Look for subjects in various locations
    search_paths = [
        project_path / 'derivatives_nocorrection',
        project_path,
        project_path / 'derivatives_nocorrection'
    ]
    
    subjects_data = []
    
    for search_path in search_paths:
        if not search_path.exists():
            continue
        
        subject_dirs = list(search_path.glob('sub-*'))
        
        for subject_dir in subject_dirs:
            subject_id = subject_dir.name
            
            # Skip if already found this subject
            if any(s['subject_id'] == subject_id for s in subjects_data):
                continue
            
            print(f"  📊 Scanning {subject_id}...")
            
            subject_sessions = {}
            has_required_sessions = True
            
            for session in sessions:
                # Look for functional data
                func_patterns = [
                    subject_dir / session / 'func' / f'*{task_name}*bold.nii*',
                    subject_dir / session / 'func' / f'*{task_name}*preproc_bold.nii*'
                ]
                
                func_files = []
                for pattern in func_patterns:
                    func_files.extend(glob.glob(str(pattern)))
                
                if func_files:
                    func_dir = Path(func_files[0]).parent
                    
                    # Find events and confounds
                    events_files = list(func_dir.glob(f'*{task_name}*events.tsv'))
                    confounds_files = list(func_dir.glob(f'*{task_name}*confounds*.tsv'))
                    
                    subject_sessions[session] = {
                        "func_dir": str(func_dir),
                        "func_files": [str(Path(f).name) for f in func_files],
                        "events_files": [str(f.name) for f in events_files],
                        "confounds_files": [str(f.name) for f in confounds_files],
                        "include": True,
                        "notes": f"Auto-detected {len(func_files)} runs"
                    }
                    
                    print(f"    ✅ {session}: {len(func_files)} runs, {len(events_files)} events files")
                else:
                    has_required_sessions = False
                    print(f"    ❌ {session}: No functional data found")
            
            if has_required_sessions and subject_sessions:
                subjects_data.append({
                    "subject_id": subject_id,
                    "include": True,
                    "sessions": subject_sessions,
                    "notes": f"Auto-detected from {search_path}",
                    "demographics": {
                        "age": None,
                        "sex": None,
                        "group": "unknown"
                    }
                })
    
    print(f"\n📊 Found {len(subjects_data)} subjects with required sessions")
    
    # Create dataset template
    dataset_template = {
        "dataset_name": f"{project_template['project_name']}_auto_detected",
        "subjects": subjects_data,
        "exclusion_criteria": {
            "max_motion": 3.0,
            "min_runs": 1,
            "required_sessions": sessions
        },
        "scan_info": {
            "scanned_on": datetime.now().isoformat(),
            "project_path": str(project_path),
            "task_name": task_name,
            "sessions": sessions,
            "search_paths": [str(p) for p in search_paths if p.exists()]
        }
    }
    
    return dataset_template

# Utility functions for template management
def find_templates(templates_dir, template_type=None):
    """Find all templates of a given type"""
    manager = AnalysisTemplateManager(templates_dir)
    return manager.list_templates(template_type)

def load_project_config(templates_dir, project_name=None):
    """Load complete project configuration from templates"""
    manager = AnalysisTemplateManager(templates_dir)
    templates = manager.list_templates()
    
    config = {}
    
    # Find project template
    project_templates = [t for t in templates if t['type'] == 'project']
    if project_name:
        project_templates = [t for t in project_templates if project_name in t['name']]
    
    if project_templates:
        config['project'] = manager.load_template(project_templates[0]['path'])
    
    # Find matching dataset template
    dataset_templates = [t for t in templates if t['type'] == 'dataset']
    if dataset_templates:
        config['dataset'] = manager.load_template(dataset_templates[0]['path'])
    
    # Find analysis template
    analysis_templates = [t for t in templates if t['type'] == 'analysis']
    if analysis_templates:
        config['analysis'] = manager.load_template(analysis_templates[0]['path'])
    
    # Find SLURM template
    slurm_templates = [t for t in templates if t['type'] == 'slurm']
    if slurm_templates:
        config['slurm'] = manager.load_template(slurm_templates[0]['path'])
    
    return config

# Example usage and CLI functions
if __name__ == "__main__":
    print("📋 JSON Template System for fMRI Analysis")
    print("=" * 50)
    print()
    print("🎯 FEATURES:")
    print("• Flexible JSON-based configuration")
    print("• Project, dataset, analysis, and SLURM templates")
    print("• Automatic subject detection")
    print("• Template validation")
    print("• Integration with analysis pipelines")
    print()
    print("🚀 QUICK START:")
    print("1. Create example templates:")
    print("   create_example_templates('./templates')")
    print()
    print("2. Auto-detect subjects:")
    print("   dataset = scan_project_for_subjects(project_template)")
    print()
    print("3. Load complete configuration:")
    print("   config = load_project_config('./templates', 'geoscan_v2')")
    print()
    print("📋 TEMPLATE TYPES:")
    print("• project: Overall project configuration")
    print("• dataset: Subject and session specifications")
    print("• analysis: Analysis parameters and contrasts")
    print("• slurm: Cluster job configuration")

