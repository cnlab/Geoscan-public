#!/usr/bin/env python
# coding: utf-8
"""
fMRI Results Visualization Module

This module provides functions for visualizing first-level analysis results.
"""

import os
import numpy as np
import pandas as pd
import nibabel as nib
import matplotlib.pyplot as plt
import seaborn as sns
from pathlib import Path
from scipy import stats
from nilearn import plotting, image, masking
from nilearn.glm import threshold_stats_img
import warnings
warnings.filterwarnings('ignore')


class ResultsVisualizer:
    """Visualize first-level fMRI analysis results."""
    
    def __init__(self, output_dir, subject, task, model):
        """
        Initialize visualizer with analysis parameters.
        
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
        self.figures_dir = self.subject_dir / "figures"
        self.figures_dir.mkdir(parents=True, exist_ok=True)
        
    def load_contrast_info(self):
        """Load contrast names and files."""
        try:
            import scipy.io as sio
            
            # Load contrast names from SPM.mat
            spm_file = self.subject_dir / "spm" / "SPM.mat"
            if not spm_file.exists():
                print("SPM.mat file not found")
                return None
                
            mat = sio.loadmat(str(spm_file))
            contrast_names = [str(c[0][0]) for c in mat['SPM']['xCon']['name'][0][0]]
            
            # Find contrast and T-stat images
            con_files = sorted(list((self.subject_dir / "con").glob("con_*.nii")))
            spmT_files = sorted(list((self.subject_dir / "spmT").glob("spmT_*.nii")))
            
            contrasts = []
            for i, name in enumerate(contrast_names):
                if i < len(con_files) and i < len(spmT_files):
                    contrasts.append({
                        'name': name,
                        'con_file': con_files[i],
                        'spmT_file': spmT_files[i],
                        'index': i + 1
                    })
                    
            return contrasts
            
        except Exception as e:
            print(f"Error loading contrast info: {e}")
            return None
    
    def plot_contrast_brain(self, contrast_name, threshold='auto', display_mode='ortho',
                           cmap='RdBu_r', symmetric_cbar=True, save=True):
        """
        Create brain visualization for a specific contrast.
        
        Parameters
        ----------
        contrast_name : str
            Name of the contrast to plot
        threshold : float or 'auto'
            Threshold for the visualization
        display_mode : str
            Display mode ('ortho', 'x', 'y', 'z', 'tiled', 'mosaic')
        cmap : str
            Colormap name
        symmetric_cbar : bool
            Whether to use symmetric colorbar
        save : bool
            Whether to save the figure
        """
        contrasts = self.load_contrast_info()
        if not contrasts:
            return None
            
        # Find the requested contrast
        contrast = next((c for c in contrasts if c['name'] == contrast_name), None)
        if not contrast:
            print(f"Contrast '{contrast_name}' not found")
            return None
            
        # Load the T-stat image
        img = nib.load(str(contrast['spmT_file']))
        
        # Determine threshold if auto
        if threshold == 'auto':
            # Use FDR correction
            try:
                _, threshold = threshold_stats_img(
                    img, alpha=0.05, height_control='fdr', cluster_threshold=10
                )
            except:
                # Fallback to fixed threshold
                threshold = 2.3
                
        # Create the plot
        if display_mode == 'ortho':
            fig = plotting.plot_stat_map(
                img,
                threshold=threshold,
                display_mode='ortho',
                cut_coords=[0, 0, 0],
                title=f"{contrast_name} (T > {threshold:.2f})",
                cmap=cmap,
                symmetric_cbar=symmetric_cbar,
                colorbar=True
            )
        elif display_mode == 'mosaic':
            fig = plotting.plot_stat_map(
                img,
                threshold=threshold,
                display_mode='z',
                cut_coords=8,
                title=f"{contrast_name} (T > {threshold:.2f})",
                cmap=cmap,
                symmetric_cbar=symmetric_cbar,
                colorbar=True
            )
        else:
            fig = plotting.plot_stat_map(
                img,
                threshold=threshold,
                display_mode=display_mode,
                title=f"{contrast_name} (T > {threshold:.2f})",
                cmap=cmap,
                symmetric_cbar=symmetric_cbar,
                colorbar=True
            )
            
        if save:
            output_file = self.figures_dir / f"{contrast_name.replace(' ', '_')}_{display_mode}.png"
            fig.savefig(str(output_file), dpi=300, bbox_inches='tight')
            plt.close(fig)
            return output_file
            
        return fig
    
    def plot_all_contrasts_glass_brain(self, threshold=2.3):
        """Create glass brain plots for all contrasts."""
        contrasts = self.load_contrast_info()
        if not contrasts:
            return None
            
        n_contrasts = len(contrasts)
        fig, axes = plt.subplots(n_contrasts, 1, figsize=(10, 4*n_contrasts))
        
        if n_contrasts == 1:
            axes = [axes]
            
        for i, contrast in enumerate(contrasts):
            plotting.plot_glass_brain(
                str(contrast['spmT_file']),
                threshold=threshold,
                display_mode='lyrz',
                colorbar=True,
                axes=axes[i],
                title=f"{contrast['name']} (T > {threshold})"
            )
            
        plt.tight_layout()
        output_file = self.figures_dir / 'all_contrasts_glass_brain.png'
        plt.savefig(output_file, dpi=300, bbox_inches='tight')
        plt.close()
        
        return output_file
    
    def extract_roi_values(self, roi_mask, contrast_name=None):
        """
        Extract values from ROI for all or specific contrasts.
        
        Parameters
        ----------
        roi_mask : str or nibabel image
            ROI mask file or image
        contrast_name : str, optional
            Specific contrast name (if None, extract for all)
            
        Returns
        -------
        pd.DataFrame
            ROI values for each contrast
        """
        if isinstance(roi_mask, str):
            roi_img = nib.load(roi_mask)
        else:
            roi_img = roi_mask
            
        contrasts = self.load_contrast_info()
        if not contrasts:
            return None
            
        # Filter contrasts if specific one requested
        if contrast_name:
            contrasts = [c for c in contrasts if c['name'] == contrast_name]
            
        results = []
        
        for contrast in contrasts:
            # Load contrast image
            con_img = nib.load(str(contrast['con_file']))
            
            # Resample ROI to match contrast image if needed
            if not np.array_equal(roi_img.shape, con_img.shape):
                roi_img_resampled = image.resample_to_img(roi_img, con_img)
            else:
                roi_img_resampled = roi_img
                
            # Extract values
            masked_data = masking.apply_mask(con_img, roi_img_resampled)
            
            results.append({
                'contrast': contrast['name'],
                'mean': np.mean(masked_data),
                'std': np.std(masked_data),
                'median': np.median(masked_data),
                'min': np.min(masked_data),
                'max': np.max(masked_data),
                'n_voxels': len(masked_data)
            })
            
        return pd.DataFrame(results)
    
    def create_activation_summary_table(self, threshold=2.3):
        """Create a summary table of activation extent for all contrasts."""
        contrasts = self.load_contrast_info()
        if not contrasts:
            return None
            
        results = []
        
        for contrast in contrasts:
            # Load T-stat image
            img = nib.load(str(contrast['spmT_file']))
            data = img.get_fdata()
            
            # Calculate activation extent at different thresholds
            thresholds = [2.3, 3.1, 4.0, 5.0]
            result = {'contrast': contrast['name']}
            
            for thresh in thresholds:
                pos_voxels = np.sum(data > thresh)
                neg_voxels = np.sum(data < -thresh)
                result[f'pos_voxels_T>{thresh}'] = pos_voxels
                result[f'neg_voxels_T<-{thresh}'] = neg_voxels
                
            # Find peak coordinates
            peak_val = np.max(data)
            peak_idx = np.unravel_index(np.argmax(data), data.shape)
            
            # Convert to MNI coordinates
            affine = img.affine
            peak_mni = affine.dot(list(peak_idx) + [1])[:3]
            
            result['peak_T'] = peak_val
            result['peak_x'] = peak_mni[0]
            result['peak_y'] = peak_mni[1]
            result['peak_z'] = peak_mni[2]
            
            results.append(result)
            
        df = pd.DataFrame(results)
        
        # Save table
        output_file = self.figures_dir / 'activation_summary.csv'
        df.to_csv(output_file, index=False)
        
        # Create visualization
        fig, ax = plt.subplots(figsize=(12, len(df) * 0.5 + 2))
        
        # Plot horizontal bar chart of positive activations
        y_pos = np.arange(len(df))
        ax.barh(y_pos, df['pos_voxels_T>2.3'], label='T > 2.3')
        ax.barh(y_pos, df['pos_voxels_T>3.1'], label='T > 3.1', left=0, alpha=0.7)
        ax.barh(y_pos, df['pos_voxels_T>4.0'], label='T > 4.0', left=0, alpha=0.5)
        
        ax.set_yticks(y_pos)
        ax.set_yticklabels(df['contrast'])
        ax.set_xlabel('Number of Voxels')
        ax.set_title('Activation Extent by Contrast')
        ax.legend()
        
        plt.tight_layout()
        fig_file = self.figures_dir / 'activation_extent.png'
        plt.savefig(fig_file, dpi=300, bbox_inches='tight')
        plt.close()
        
        return df
    
    def create_contrast_correlation_matrix(self):
        """Create correlation matrix between contrast images."""
        contrasts = self.load_contrast_info()
        if not contrasts:
            return None
            
        # Load all contrast images
        contrast_data = []
        contrast_names = []
        
        for contrast in contrasts:
            img = nib.load(str(contrast['con_file']))
            data = img.get_fdata().flatten()
            contrast_data.append(data)
            contrast_names.append(contrast['name'])
            
        # Calculate correlation matrix
        corr_matrix = np.corrcoef(contrast_data)
        
        # Create visualization
        plt.figure(figsize=(10, 8))
        mask = np.triu(np.ones_like(corr_matrix, dtype=bool), k=1)
        
        sns.heatmap(
            corr_matrix,
            mask=mask,
            annot=True,
            fmt='.2f',
            cmap='RdBu_r',
            center=0,
            square=True,
            xticklabels=contrast_names,
            yticklabels=contrast_names,
            cbar_kws={'label': 'Correlation'}
        )
        
        plt.title('Contrast Correlation Matrix')
        plt.tight_layout()
        
        output_file = self.figures_dir / 'contrast_correlation_matrix.png'
        plt.savefig(output_file, dpi=300, bbox_inches='tight')
        plt.close()
        
        return corr_matrix, contrast_names
    
    def generate_report_figures(self, roi_masks=None):
        """Generate all standard figures for a report."""
        print(f"Generating figures for sub-{self.subject}")
        
        # Glass brain plots for all contrasts
        self.plot_all_contrasts_glass_brain()
        
        # Individual contrast visualizations
        contrasts = self.load_contrast_info()
        if contrasts:
            for contrast in contrasts[:5]:  # Limit to first 5 contrasts
                self.plot_contrast_brain(contrast['name'], display_mode='ortho')
                self.plot_contrast_brain(contrast['name'], display_mode='mosaic')
        
        # Activation summary
        self.create_activation_summary_table()
        
        # Contrast correlation matrix
        self.create_contrast_correlation_matrix()
        
        # ROI analysis if masks provided
        if roi_masks:
            roi_results = []
            for roi_name, roi_mask in roi_masks.items():
                df = self.extract_roi_values(roi_mask)
                if df is not None:
                    df['roi'] = roi_name
                    roi_results.append(df)
                    
            if roi_results:
                all_roi_df = pd.concat(roi_results)
                all_roi_df.to_csv(self.figures_dir / 'roi_results.csv', index=False)
                
                # Plot ROI results
                self._plot_roi_results(all_roi_df)
                
        print(f"Figures saved to: {self.figures_dir}")
        
    def _plot_roi_results(self, roi_df):
        """Plot ROI extraction results."""
        n_rois = roi_df['roi'].nunique()
        fig, axes = plt.subplots(1, n_rois, figsize=(6*n_rois, 8))
        
        if n_rois == 1:
            axes = [axes]
            
        for i, (roi, roi_data) in enumerate(roi_df.groupby('roi')):
            ax = axes[i]
            
            # Sort by mean value
            roi_data = roi_data.sort_values('mean')
            
            # Create bar plot
            y_pos = np.arange(len(roi_data))
            ax.barh(y_pos, roi_data['mean'], xerr=roi_data['std'], 
                   color='skyblue', alpha=0.7)
            
            ax.set_yticks(y_pos)
            ax.set_yticklabels(roi_data['contrast'], fontsize=8)
            ax.set_xlabel('Parameter Estimate')
            ax.set_title(f'{roi} ROI')
            ax.axvline(x=0, color='k', linestyle='--', alpha=0.5)
            
        plt.tight_layout()
        plt.savefig(self.figures_dir / 'roi_bar_plots.png', dpi=300, bbox_inches='tight')
        plt.close()


if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description="Visualize fMRI first-level analysis results")
    parser.add_argument("output_dir", help="Output directory from first-level analysis")
    parser.add_argument("--subject", "-s", required=True, help="Subject ID")
    parser.add_argument("--task", "-t", required=True, help="Task name")
    parser.add_argument("--model", "-m", required=True, help="Model name")
    parser.add_argument("--contrast", "-c", help="Specific contrast to visualize")
    parser.add_argument("--threshold", type=float, default=2.3, help="Statistical threshold")
    
    args = parser.parse_args()
    
    viz = ResultsVisualizer(args.output_dir, args.subject, args.task, args.model)
    
    if args.contrast:
        viz.plot_contrast_brain(args.contrast, threshold=args.threshold)
    else:
        viz.generate_report_figures()