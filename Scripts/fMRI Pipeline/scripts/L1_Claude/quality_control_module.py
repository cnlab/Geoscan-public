#!/usr/bin/env python
# coding: utf-8
"""
fMRI Quality Control Module

This module provides quality control functions for first-level fMRI analysis results.
"""

import os
import json
import numpy as np
import pandas as pd
import nibabel as nib
import matplotlib.pyplot as plt
import seaborn as sns
from scipy import stats
from pathlib import Path
import warnings
warnings.filterwarnings('ignore')


class QualityControl:
    """Quality control for first-level fMRI analysis results."""
    
    def __init__(self, output_dir, subject, task, model):
        """
        Initialize QC with analysis parameters.
        
        Parameters
        ----------
        output_dir : str
            Base output directory
        subject : str
            Subject ID
        task : str
            Task name
        model : str
            Model name
        """
        self.output_dir = Path(output_dir)
        self.subject = subject
        self.task = task
        self.model = model
        
        # Set up paths
        self.subject_dir = self.output_dir / f"task-{task}_model-{model}" / f"sub-{subject}"
        self.qc_dir = self.subject_dir / "qc"
        self.qc_dir.mkdir(parents=True, exist_ok=True)
        
    def check_outputs(self):
        """Check if all expected outputs exist."""
        expected_files = {
            "SPM.mat": self.subject_dir / "spm" / "SPM.mat",
            "mask": self.subject_dir / "mask" / "mask.nii",
        }
        
        # Check beta images
        beta_dir = self.subject_dir / "betas"
        if beta_dir.exists():
            beta_files = list(beta_dir.glob("beta_*.nii"))
            expected_files["beta_count"] = len(beta_files)
        else:
            expected_files["beta_count"] = 0
            
        # Check contrast images
        con_dir = self.subject_dir / "con"
        if con_dir.exists():
            con_files = list(con_dir.glob("con_*.nii"))
            expected_files["contrast_count"] = len(con_files)
        else:
            expected_files["contrast_count"] = 0
            
        # Check T-stat images
        spmT_dir = self.subject_dir / "spmT"
        if spmT_dir.exists():
            spmT_files = list(spmT_dir.glob("spmT_*.nii"))
            expected_files["spmT_count"] = len(spmT_files)
        else:
            expected_files["spmT_count"] = 0
            
        # Create report
        report = {}
        missing = []
        
        for name, path in expected_files.items():
            if isinstance(path, int):
                report[name] = path
                if path == 0:
                    missing.append(name)
            else:
                report[name] = path.exists()
                if not path.exists():
                    missing.append(name)
                    
        return report, missing
    
    def load_spm_info(self):
        """Load information from SPM.mat file."""
        try:
            import scipy.io as sio
            spm_file = self.subject_dir / "spm" / "SPM.mat"
            
            if not spm_file.exists():
                return None
                
            mat = sio.loadmat(str(spm_file))
            spm = mat['SPM'][0, 0]
            
            info = {
                'n_scans': len(spm['xY']['VY'][0]),
                'n_sessions': len(spm['Sess'][0]),
                'tr': float(spm['xY']['RT'][0, 0]),
                'design_matrix_rank': int(spm['xX']['rk'][0, 0]),
                'n_regressors': spm['xX']['X'].shape[1],
                'contrast_names': [str(c[0][0]) for c in spm['xCon']['name'][0]]
            }
            
            return info
            
        except Exception as e:
            print(f"Error loading SPM.mat: {e}")
            return None
    
    def check_design_matrix(self):
        """Check design matrix properties."""
        try:
            import scipy.io as sio
            spm_file = self.subject_dir / "spm" / "SPM.mat"
            
            if not spm_file.exists():
                return None
                
            mat = sio.loadmat(str(spm_file))
            design_matrix = mat['SPM']['xX'][0, 0]['X'][0, 0]
            
            # Calculate correlation matrix
            corr_matrix = np.corrcoef(design_matrix.T)
            
            # Find high correlations (excluding diagonal)
            high_corr_threshold = 0.9
            high_corr_indices = np.where(
                (np.abs(corr_matrix) > high_corr_threshold) & 
                (np.eye(corr_matrix.shape[0]) == 0)
            )
            
            # Calculate condition numbers
            condition_number = np.linalg.cond(design_matrix)
            
            # Create visualization
            fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(15, 6))
            
            # Plot design matrix
            ax1.imshow(design_matrix, aspect='auto', cmap='RdBu_r', 
                      interpolation='nearest')
            ax1.set_xlabel('Regressors')
            ax1.set_ylabel('Scans')
            ax1.set_title('Design Matrix')
            
            # Plot correlation matrix
            sns.heatmap(corr_matrix, cmap='RdBu_r', center=0, 
                       square=True, ax=ax2,
                       cbar_kws={'label': 'Correlation'})
            ax2.set_title('Regressor Correlation Matrix')
            
            plt.tight_layout()
            plt.savefig(self.qc_dir / 'design_matrix_qc.png', dpi=150, bbox_inches='tight')
            plt.close()
            
            return {
                'condition_number': condition_number,
                'high_correlations': len(high_corr_indices[0]) // 2,
                'max_correlation': np.max(np.abs(corr_matrix[np.eye(corr_matrix.shape[0]) == 0]))
            }
            
        except Exception as e:
            print(f"Error checking design matrix: {e}")
            return None
    
    def check_motion_parameters(self, confound_file):
        """Check motion parameters from confound file."""
        try:
            confounds = pd.read_csv(confound_file, sep='\t')
            
            motion_params = ['trans_x', 'trans_y', 'trans_z', 'rot_x', 'rot_y', 'rot_z']
            
            if not all(param in confounds.columns for param in motion_params):
                print("Motion parameters not found in confound file")
                return None
                
            # Calculate framewise displacement
            if 'framewise_displacement' in confounds.columns:
                fd = confounds['framewise_displacement'].fillna(0)
            else:
                # Calculate FD manually
                trans = confounds[['trans_x', 'trans_y', 'trans_z']].values
                rot = confounds[['rot_x', 'rot_y', 'rot_z']].values
                
                # Convert rotations to mm (assuming 50mm radius)
                rot_mm = rot * 50
                
                # Calculate differences
                diff_trans = np.abs(np.diff(trans, axis=0))
                diff_rot = np.abs(np.diff(rot_mm, axis=0))
                
                # Sum absolute differences
                fd = np.sum(diff_trans, axis=1) + np.sum(diff_rot, axis=1)
                fd = np.concatenate([[0], fd])  # First frame has no FD
            
            # Create motion plot
            fig, axes = plt.subplots(3, 1, figsize=(12, 10))
            
            # Plot translations
            ax = axes[0]
            for i, param in enumerate(['trans_x', 'trans_y', 'trans_z']):
                ax.plot(confounds[param], label=param)
            ax.set_ylabel('Translation (mm)')
            ax.set_title('Head Motion Parameters')
            ax.legend()
            ax.grid(True, alpha=0.3)
            
            # Plot rotations
            ax = axes[1]
            for i, param in enumerate(['rot_x', 'rot_y', 'rot_z']):
                ax.plot(confounds[param], label=param)
            ax.set_ylabel('Rotation (rad)')
            ax.legend()
            ax.grid(True, alpha=0.3)
            
            # Plot FD
            ax = axes[2]
            ax.plot(fd, 'k-', linewidth=2)
            ax.axhline(y=0.5, color='orange', linestyle='--', label='0.5mm threshold')
            ax.axhline(y=0.9, color='red', linestyle='--', label='0.9mm threshold')
            ax.set_xlabel('Volume')
            ax.set_ylabel('Framewise Displacement (mm)')
            ax.legend()
            ax.grid(True, alpha=0.3)
            
            plt.tight_layout()
            plt.savefig(self.qc_dir / 'motion_parameters.png', dpi=150, bbox_inches='tight')
            plt.close()
            
            # Calculate summary statistics
            motion_summary = {
                'mean_fd': np.mean(fd),
                'max_fd': np.max(fd),
                'percent_fd_above_0.5': np.sum(fd > 0.5) / len(fd) * 100,
                'percent_fd_above_0.9': np.sum(fd > 0.9) / len(fd) * 100,
                'max_translation': np.max(np.abs(confounds[['trans_x', 'trans_y', 'trans_z']].values)),
                'max_rotation': np.max(np.abs(confounds[['rot_x', 'rot_y', 'rot_z']].values))
            }
            
            return motion_summary
            
        except Exception as e:
            print(f"Error checking motion parameters: {e}")
            return None
    
    def check_contrast_maps(self):
        """Generate visualizations of contrast maps."""
        try:
            import scipy.io as sio
            from nilearn import plotting
            
            # Load contrast names from SPM.mat
            spm_file = self.subject_dir / "spm" / "SPM.mat"
            mat = sio.loadmat(str(spm_file))
            contrast_names = [str(c[0][0]) for c in mat['SPM']['xCon']['name'][0][0]]
            
            # Find T-stat images
            spmT_dir = self.subject_dir / "spmT"
            spmT_files = sorted(list(spmT_dir.glob("spmT_*.nii")))
            
            if not spmT_files:
                print("No T-stat images found")
                return None
                
            # Create glass brain plots for each contrast
            n_contrasts = min(len(spmT_files), len(contrast_names))
            fig, axes = plt.subplots(n_contrasts, 1, figsize=(10, 4*n_contrasts))
            
            if n_contrasts == 1:
                axes = [axes]
                
            for i, (spmT_file, contrast_name) in enumerate(zip(spmT_files[:n_contrasts], 
                                                               contrast_names[:n_contrasts])):
                plotting.plot_glass_brain(
                    str(spmT_file),
                    threshold=2.3,
                    display_mode='lyrz',
                    colorbar=True,
                    axes=axes[i],
                    title=f"{contrast_name} (thresholded at T>2.3)"
                )
                
            plt.tight_layout()
            plt.savefig(self.qc_dir / 'contrast_maps.png', dpi=150, bbox_inches='tight')
            plt.close()
            
            # Calculate activation statistics
            activation_stats = []
            
            for spmT_file, contrast_name in zip(spmT_files, contrast_names):
                img = nib.load(str(spmT_file))
                data = img.get_fdata()
                
                # Threshold at different levels
                thresholds = [2.3, 3.1, 4.0]
                stats = {'contrast': contrast_name}
                
                for thresh in thresholds:
                    n_voxels = np.sum(data > thresh)
                    stats[f'voxels_T>{thresh}'] = int(n_voxels)
                
                # Calculate peak T-value
                stats['peak_T'] = float(np.max(data))
                stats['min_T'] = float(np.min(data))
                
                activation_stats.append(stats)
            
            # Save activation statistics
            stats_df = pd.DataFrame(activation_stats)
            stats_df.to_csv(self.qc_dir / 'activation_statistics.csv', index=False)
            
            return stats_df
            
        except Exception as e:
            print(f"Error checking contrast maps: {e}")
            return None
    
    def generate_report(self, confound_files=None):
        """Generate a comprehensive QC report."""
        print(f"Generating QC report for sub-{self.subject}")
        
        report = {
            'subject': self.subject,
            'task': self.task,
            'model': self.model,
            'qc_date': pd.Timestamp.now().strftime('%Y-%m-%d %H:%M:%S')
        }
        
        # Check outputs
        output_check, missing = self.check_outputs()
        report['outputs'] = output_check
        report['missing_outputs'] = missing
        
        # Load SPM info
        spm_info = self.load_spm_info()
        if spm_info:
            report['spm_info'] = spm_info
        
        # Check design matrix
        design_check = self.check_design_matrix()
        if design_check:
            report['design_matrix'] = design_check
        
        # Check motion if confound files provided
        if confound_files:
            motion_reports = []
            for i, confound_file in enumerate(confound_files):
                motion_summary = self.check_motion_parameters(confound_file)
                if motion_summary:
                    motion_summary['run'] = i + 1
                    motion_reports.append(motion_summary)
            
            if motion_reports:
                report['motion'] = motion_reports
        
        # Check contrast maps
        contrast_stats = self.check_contrast_maps()
        if contrast_stats is not None:
            report['contrasts'] = contrast_stats.to_dict('records')
        
        # Save report as JSON
        with open(self.qc_dir / 'qc_report.json', 'w') as f:
            json.dump(report, f, indent=2)
        
        # Generate HTML report
        self._generate_html_report(report)
        
        return report
    
    def _generate_html_report(self, report):
        """Generate an HTML report from the QC data."""
        html_content = f"""
        <!DOCTYPE html>
        <html>
        <head>
            <title>QC Report - {self.subject}</title>
            <style>
                body {{ font-family: Arial, sans-serif; margin: 20px; }}
                h1, h2, h3 {{ color: #333; }}
                table {{ border-collapse: collapse; margin: 20px 0; }}
                th, td {{ border: 1px solid #ddd; padding: 8px; text-align: left; }}
                th {{ background-color: #f2f2f2; }}
                .warning {{ color: orange; font-weight: bold; }}
                .error {{ color: red; font-weight: bold; }}
                .success {{ color: green; font-weight: bold; }}
                img {{ max-width: 100%; height: auto; margin: 10px 0; }}
                .metric {{ background-color: #f8f9fa; padding: 10px; margin: 10px 0; border-radius: 5px; }}
            </style>
        </head>
        <body>
            <h1>Quality Control Report</h1>
            <div class="metric">
                <p><strong>Subject:</strong> {report['subject']}</p>
                <p><strong>Task:</strong> {report['task']}</p>
                <p><strong>Model:</strong> {report['model']}</p>
                <p><strong>Generated:</strong> {report['qc_date']}</p>
            </div>
        """
        
        # Output check section
        html_content += "<h2>Output Files</h2>"
        if report['missing_outputs']:
            html_content += f"<p class='error'>Missing outputs: {', '.join(report['missing_outputs'])}</p>"
        else:
            html_content += "<p class='success'>All expected outputs found!</p>"
        
        html_content += "<table>"
        html_content += "<tr><th>Output</th><th>Status</th></tr>"
        for output, status in report['outputs'].items():
            status_str = str(status) if isinstance(status, int) else ('✓' if status else '✗')
            status_class = 'success' if (isinstance(status, bool) and status) or (isinstance(status, int) and status > 0) else 'error'
            html_content += f"<tr><td>{output}</td><td class='{status_class}'>{status_str}</td></tr>"
        html_content += "</table>"
        
        # SPM info section
        if 'spm_info' in report:
            html_content += "<h2>SPM Model Information</h2>"
            html_content += "<div class='metric'>"
            for key, value in report['spm_info'].items():
                html_content += f"<p><strong>{key.replace('_', ' ').title()}:</strong> {value}</p>"
            html_content += "</div>"
        
        # Design matrix section
        if 'design_matrix' in report:
            html_content += "<h2>Design Matrix Quality</h2>"
            dm = report['design_matrix']
            
            cond_class = 'error' if dm['condition_number'] > 30 else ('warning' if dm['condition_number'] > 15 else 'success')
            html_content += f"<p>Condition Number: <span class='{cond_class}'>{dm['condition_number']:.2f}</span></p>"
            
            if dm['high_correlations'] > 0:
                html_content += f"<p class='warning'>Found {dm['high_correlations']} high correlations (>0.9) between regressors</p>"
            
            if os.path.exists(self.qc_dir / 'design_matrix_qc.png'):
                html_content += "<img src='design_matrix_qc.png' alt='Design Matrix QC'>"
        
        # Motion section
        if 'motion' in report:
            html_content += "<h2>Motion Parameters</h2>"
            
            for run_motion in report['motion']:
                html_content += f"<h3>Run {run_motion['run']}</h3>"
                html_content += "<div class='metric'>"
                
                fd_class = 'error' if run_motion['mean_fd'] > 0.5 else ('warning' if run_motion['mean_fd'] > 0.2 else 'success')
                html_content += f"<p>Mean FD: <span class='{fd_class}'>{run_motion['mean_fd']:.3f} mm</span></p>"
                html_content += f"<p>Max FD: {run_motion['max_fd']:.3f} mm</p>"
                html_content += f"<p>Volumes with FD > 0.5mm: {run_motion['percent_fd_above_0.5']:.1f}%</p>"
                
                html_content += "</div>"
            
            if os.path.exists(self.qc_dir / 'motion_parameters.png'):
                html_content += "<img src='motion_parameters.png' alt='Motion Parameters'>"
        
        # Contrasts section
        if 'contrasts' in report:
            html_content += "<h2>Contrast Activation Statistics</h2>"
            html_content += "<table>"
            html_content += "<tr><th>Contrast</th><th>Peak T</th><th>Voxels (T>2.3)</th><th>Voxels (T>3.1)</th></tr>"
            
            for contrast in report['contrasts']:
                html_content += f"<tr><td>{contrast['contrast']}</td>"
                html_content += f"<td>{contrast['peak_T']:.2f}</td>"
                html_content += f"<td>{contrast['voxels_T>2.3']}</td>"
                html_content += f"<td>{contrast['voxels_T>3.1']}</td></tr>"
            html_content += "</table>"
            
            if os.path.exists(self.qc_dir / 'contrast_maps.png'):
                html_content += "<img src='contrast_maps.png' alt='Contrast Maps'>"
        
        html_content += """
        </body>
        </html>
        """
        
        with open(self.qc_dir / 'qc_report.html', 'w') as f:
            f.write(html_content)
        
        print(f"HTML report saved to: {self.qc_dir / 'qc_report.html'}")


def run_batch_qc(output_dir, task, model, subjects, sessions=None):
    """Run QC for multiple subjects."""
    qc_reports = []
    
    for i, subject in enumerate(subjects):
        session = sessions[i] if sessions else None
        
        try:
            qc = QualityControl(output_dir, subject, task, model)
            
            # Find confound files if available
            confound_pattern = f"**/sub-{subject}"
            if session:
                confound_pattern += f"_ses-{session}"
            confound_pattern += f"_task-{task}_*_desc-confounds_timeseries.tsv"
            
            confound_files = list(Path(output_dir).parent.glob(confound_pattern))
            
            report = qc.generate_report(confound_files if confound_files else None)
            qc_reports.append(report)
            
        except Exception as e:
            print(f"Error running QC for sub-{subject}: {e}")
    
    # Generate summary report
    if qc_reports:
        summary_df = pd.DataFrame([
            {
                'subject': r['subject'],
                'n_missing': len(r['missing_outputs']),
                'mean_fd': np.mean([m['mean_fd'] for m in r.get('motion', [])]) if 'motion' in r else np.nan,
                'max_activation': max([c['peak_T'] for c in r.get('contrasts', [])]) if 'contrasts' in r else np.nan
            }
            for r in qc_reports
        ])
        
        summary_path = Path(output_dir) / f"task-{task}_model-{model}" / "qc_summary.csv"
        summary_df.to_csv(summary_path, index=False)
        print(f"QC summary saved to: {summary_path}")
        
    return qc_reports


if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description="Quality control for fMRI first-level analysis")
    parser.add_argument("output_dir", help="Output directory from first-level analysis")
    parser.add_argument("--subject", "-s", required=True, help="Subject ID")
    parser.add_argument("--task", "-t", required=True, help="Task name")
    parser.add_argument("--model", "-m", required=True, help="Model name")
    parser.add_argument("--confounds", nargs="+", help="Confound files")
    
    args = parser.parse_args()
    
    qc = QualityControl(args.output_dir, args.subject, args.task, args.model)
    report = qc.generate_report(args.confounds)