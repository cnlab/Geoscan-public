#!/usr/bin/env python
# coding: utf-8
"""
ROI Creation Module

This module creates ROIs from first-level contrasts and provides tools
for extracting data from these ROIs in other datasets.
"""

import os
import numpy as np
import pandas as pd
import nibabel as nib
from pathlib import Path
from scipy import ndimage
from nilearn import image, masking, regions
from nilearn.maskers import NiftiMasker, NiftiSpheresMasker
from nilearn.image import threshold_img, binarize_img
import matplotlib.pyplot as plt
from sklearn.cluster import KMeans
import warnings
warnings.filterwarnings('ignore')


class ROICreator:
    """Create and manage ROIs from contrast maps."""
    
    def __init__(self, output_dir):
        """
        Initialize ROI creator.
        
        Parameters
        ----------
        output_dir : str
            Base output directory from first-level analysis
        """
        self.output_dir = Path(output_dir)
        self.roi_dir = self.output_dir / "rois"
        self.roi_dir.mkdir(parents=True, exist_ok=True)
        
    def create_threshold_roi(self, contrast_file, threshold, min_cluster_size=10,
                           roi_name=None, save=True):
        """
        Create ROI by thresholding a contrast map.
        
        Parameters
        ----------
        contrast_file : str
            Path to contrast image (con_*.nii or spmT_*.nii)
        threshold : float
            Threshold value
        min_cluster_size : int
            Minimum cluster size in voxels
        roi_name : str
            Name for the ROI
        save : bool
            Whether to save the ROI
            
        Returns
        -------
        nibabel.Nifti1Image
            Binary ROI mask
        """
        # Load contrast image
        contrast_img = nib.load(contrast_file)
        
        # Threshold the image
        thresholded = threshold_img(contrast_img, threshold=threshold)
        
        # Binarize
        binary_mask = binarize_img(thresholded)
        
        # Remove small clusters
        data = binary_mask.get_fdata()
        labeled, n_features = ndimage.label(data)
        
        # Count voxels in each cluster
        cluster_sizes = np.bincount(labeled.ravel())
        
        # Keep only clusters above size threshold
        for i in range(1, n_features + 1):
            if cluster_sizes[i] < min_cluster_size:
                data[labeled == i] = 0
                
        # Create new image
        roi_img = nib.Nifti1Image(data.astype(np.int32), 
                                 contrast_img.affine, 
                                 contrast_img.header)
        
        if save:
            if roi_name is None:
                roi_name = f"roi_thr{threshold}_minclust{min_cluster_size}"
            output_file = self.roi_dir / f"{roi_name}.nii.gz"
            nib.save(roi_img, output_file)
            print(f"ROI saved to: {output_file}")
            
        return roi_img
    
    def create_sphere_roi(self, center_coords, radius=6, space='MNI',
                         template=None, roi_name=None, save=True):
        """
        Create spherical ROI around coordinates.
        
        Parameters
        ----------
        center_coords : tuple
            (x, y, z) coordinates for sphere center
        radius : float
            Sphere radius in mm
        space : str
            Coordinate space ('MNI' or 'native')
        template : str or nibabel image
            Template image for affine/dimensions
        roi_name : str
            Name for the ROI
        save : bool
            Whether to save the ROI
            
        Returns
        -------
        nibabel.Nifti1Image
            Spherical ROI mask
        """
        if template is None:
            # Use standard MNI template
            from nilearn import datasets
            template = datasets.load_mni152_brain_mask()
        elif isinstance(template, str):
            template = nib.load(template)
            
        # Create sphere masker
        masker = NiftiSpheresMasker(
            [center_coords], 
            radius=radius,
            mask_img=template
        )
        
        # Get the mask image
        masker.fit()
        roi_img = masker.mask_img_
        
        if save:
            if roi_name is None:
                roi_name = f"sphere_x{center_coords[0]}_y{center_coords[1]}_z{center_coords[2]}_r{radius}"
            output_file = self.roi_dir / f"{roi_name}.nii.gz"
            nib.save(roi_img, output_file)
            print(f"ROI saved to: {output_file}")
            
        return roi_img
    
    def create_atlas_roi(self, atlas_name='aal', region_names=None, 
                        combine=True, roi_name=None, save=True):
        """
        Create ROI from atlas regions.
        
        Parameters
        ----------
        atlas_name : str
            Atlas name ('aal', 'harvard_oxford', 'destrieux', etc.)
        region_names : list
            List of region names to include
        combine : bool
            Whether to combine regions into single ROI
        roi_name : str
            Name for the ROI
        save : bool
            Whether to save the ROI
            
        Returns
        -------
        nibabel.Nifti1Image or list
            ROI mask(s)
        """
        from nilearn import datasets
        
        # Load atlas
        if atlas_name == 'aal':
            atlas = datasets.fetch_atlas_aal()
        elif atlas_name == 'harvard_oxford':
            atlas = datasets.fetch_atlas_harvard_oxford('cort-maxprob-thr25-2mm')
        elif atlas_name == 'destrieux':
            atlas = datasets.fetch_atlas_destrieux_2009()
        else:
            raise ValueError(f"Unknown atlas: {atlas_name}")
            
        atlas_img = nib.load(atlas.maps)
        atlas_data = atlas_img.get_fdata()
        labels = atlas.labels
        
        # Find indices for requested regions
        if region_names is None:
            print("Available regions:")
            for i, label in enumerate(labels):
                print(f"{i}: {label}")
            return None
            
        roi_indices = []
        for region in region_names:
            # Case-insensitive search
            matches = [i for i, label in enumerate(labels) 
                      if region.lower() in label.lower()]
            if matches:
                roi_indices.extend(matches)
                print(f"Found region '{region}': {[labels[i] for i in matches]}")
            else:
                print(f"Warning: Region '{region}' not found")
                
        if not roi_indices:
            print("No matching regions found")
            return None
            
        # Create ROI mask
        if combine:
            roi_data = np.zeros_like(atlas_data)
            for idx in roi_indices:
                roi_data[atlas_data == idx] = 1
                
            roi_img = nib.Nifti1Image(roi_data.astype(np.int32),
                                     atlas_img.affine,
                                     atlas_img.header)
            
            if save:
                if roi_name is None:
                    roi_name = f"{atlas_name}_{'_'.join(region_names)}"
                output_file = self.roi_dir / f"{roi_name}.nii.gz"
                nib.save(roi_img, output_file)
                print(f"Combined ROI saved to: {output_file}")
                
            return roi_img
        else:
            # Return separate ROIs
            roi_imgs = []
            for idx in roi_indices:
                roi_data = (atlas_data == idx).astype(np.int32)
                roi_img = nib.Nifti1Image(roi_data,
                                         atlas_img.affine,
                                         atlas_img.header)
                
                if save:
                    region_name = labels[idx].replace(' ', '_').replace('/', '_')
                    output_file = self.roi_dir / f"{atlas_name}_{region_name}.nii.gz"
                    nib.save(roi_img, output_file)
                    
                roi_imgs.append(roi_img)
                
            return roi_imgs
    
    def create_cluster_rois(self, contrast_file, n_clusters=5, threshold=None,
                           min_cluster_size=10, roi_prefix=None, save=True):
        """
        Create ROIs using k-means clustering on suprathreshold voxels.
        
        Parameters
        ----------
        contrast_file : str
            Path to contrast image
        n_clusters : int
            Number of clusters
        threshold : float
            Threshold for including voxels
        min_cluster_size : int
            Minimum cluster size
        roi_prefix : str
            Prefix for ROI names
        save : bool
            Whether to save ROIs
            
        Returns
        -------
        list
            List of ROI images
        """
        # Load contrast
        contrast_img = nib.load(contrast_file)
        data = contrast_img.get_fdata()
        
        # Apply threshold if specified
        if threshold is not None:
            mask = data > threshold
        else:
            mask = data > 0
            
        # Get coordinates of suprathreshold voxels
        coords = np.array(np.where(mask)).T
        values = data[mask]
        
        if len(coords) < n_clusters:
            print(f"Not enough voxels ({len(coords)}) for {n_clusters} clusters")
            return None
            
        # Perform k-means clustering
        kmeans = KMeans(n_clusters=n_clusters, random_state=42)
        clusters = kmeans.fit_predict(coords, sample_weight=values)
        
        # Create ROI images
        roi_imgs = []
        for i in range(n_clusters):
            roi_data = np.zeros_like(data)
            cluster_coords = coords[clusters == i]
            
            if len(cluster_coords) >= min_cluster_size:
                for coord in cluster_coords:
                    roi_data[tuple(coord)] = 1
                    
                roi_img = nib.Nifti1Image(roi_data.astype(np.int32),
                                         contrast_img.affine,
                                         contrast_img.header)
                
                if save:
                    if roi_prefix is None:
                        roi_prefix = "cluster"
                    output_file = self.roi_dir / f"{roi_prefix}_{i+1}.nii.gz"
                    nib.save(roi_img, output_file)
                    
                roi_imgs.append(roi_img)
                
        return roi_imgs
    
    def create_group_roi(self, subject_dirs, contrast_name, threshold=None,
                        overlap_threshold=0.5, roi_name=None, save=True):
        """
        Create group ROI from multiple subjects' contrasts.
        
        Parameters
        ----------
        subject_dirs : list
            List of subject directories
        contrast_name : str
            Name of contrast to use
        threshold : float
            Threshold for individual subject maps
        overlap_threshold : float
            Proportion of subjects needed for inclusion (0-1)
        roi_name : str
            Name for group ROI
        save : bool
            Whether to save ROI
            
        Returns
        -------
        nibabel.Nifti1Image
            Group ROI mask
        """
        overlap_map = None
        n_subjects = len(subject_dirs)
        
        for subj_dir in subject_dirs:
            # Find contrast file
            subj_path = Path(subj_dir)
            
            # Look for T-stat image
            spmT_files = list((subj_path / "spmT").glob("spmT_*.nii"))
            
            # Load SPM.mat to get contrast names
            try:
                import scipy.io as sio
                spm_file = subj_path / "spm" / "SPM.mat"
                mat = sio.loadmat(str(spm_file))
                contrast_names = [str(c[0][0]) for c in mat['SPM']['xCon']['name'][0][0]]
                
                # Find matching contrast
                contrast_idx = None
                for i, name in enumerate(contrast_names):
                    if name == contrast_name:
                        contrast_idx = i
                        break
                        
                if contrast_idx is None:
                    print(f"Contrast '{contrast_name}' not found for {subj_path}")
                    continue
                    
                # Load corresponding image
                if contrast_idx < len(spmT_files):
                    img = nib.load(str(spmT_files[contrast_idx]))
                    
                    # Threshold if specified
                    if threshold is not None:
                        img = threshold_img(img, threshold=threshold)
                        img = binarize_img(img)
                    else:
                        # Just binarize positive values
                        data = img.get_fdata()
                        data = (data > 0).astype(float)
                        img = nib.Nifti1Image(data, img.affine, img.header)
                    
                    # Add to overlap map
                    if overlap_map is None:
                        overlap_map = img.get_fdata()
                    else:
                        overlap_map += img.get_fdata()
                        
            except Exception as e:
                print(f"Error processing {subj_path}: {e}")
                continue
                
        if overlap_map is None:
            print("No valid contrast maps found")
            return None
            
        # Create binary mask based on overlap threshold
        min_subjects = int(np.ceil(n_subjects * overlap_threshold))
        group_mask = (overlap_map >= min_subjects).astype(np.int32)
        
        # Create image
        group_roi = nib.Nifti1Image(group_mask, img.affine, img.header)
        
        if save:
            if roi_name is None:
                roi_name = f"group_{contrast_name}_thr{overlap_threshold}"
            output_file = self.roi_dir / f"{roi_name}.nii.gz"
            nib.save(group_roi, output_file)
            print(f"Group ROI saved to: {output_file}")
            
        # Also save the overlap map
        overlap_img = nib.Nifti1Image(overlap_map / n_subjects, 
                                     img.affine, img.header)
        overlap_file = self.roi_dir / f"{roi_name}_overlap.nii.gz"
        nib.save(overlap_img, overlap_file)
        
        return group_roi


class ROIAnalyzer:
    """Extract and analyze data from ROIs."""
    
    def __init__(self, roi_file):
        """
        Initialize ROI analyzer.
        
        Parameters
        ----------
        roi_file : str or nibabel image
            ROI mask file or image
        """
        if isinstance(roi_file, str):
            self.roi_img = nib.load(roi_file)
            self.roi_name = Path(roi_file).stem
        else:
            self.roi_img = roi_file
            self.roi_name = "roi"
            
        self.masker = NiftiMasker(mask_img=self.roi_img)
        self.masker.fit()
        
    def extract_timeseries(self, func_files, confounds=None, standardize=True,
                          detrend=True, low_pass=None, high_pass=None, t_r=None):
        """
        Extract timeseries from functional files.
        
        Parameters
        ----------
        func_files : str or list
            Functional file(s)
        confounds : array-like or list
            Confound regressors
        standardize : bool
            Whether to standardize timeseries
        detrend : bool
            Whether to detrend
        low_pass : float
            Low-pass filter cutoff (Hz)
        high_pass : float
            High-pass filter cutoff (Hz)
        t_r : float
            Repetition time (required for filtering)
            
        Returns
        -------
        array
            Extracted timeseries (n_timepoints x n_voxels)
        """
        if isinstance(func_files, str):
            func_files = [func_files]
            
        all_timeseries = []
        
        for i, func_file in enumerate(func_files):
            conf = confounds[i] if isinstance(confounds, list) else confounds
            
            # Extract timeseries
            ts = self.masker.transform(
                func_file,
                confounds=conf,
                standardize=standardize,
                detrend=detrend,
                low_pass=low_pass,
                high_pass=high_pass,
                t_r=t_r
            )
            
            all_timeseries.append(ts)
            
        if len(all_timeseries) == 1:
            return all_timeseries[0]
        else:
            return np.concatenate(all_timeseries, axis=0)
    
    def extract_contrast_values(self, contrast_files):
        """
        Extract values from contrast images.
        
        Parameters
        ----------
        contrast_files : str, list, or dict
            Contrast file(s) or dict mapping names to files
            
        Returns
        -------
        dict or array
            Extracted values
        """
        if isinstance(contrast_files, str):
            values = self.masker.transform(contrast_files)
            return values.ravel()
            
        elif isinstance(contrast_files, list):
            return {f: self.masker.transform(f).ravel() 
                   for f in contrast_files}
                   
        elif isinstance(contrast_files, dict):
            return {name: self.masker.transform(f).ravel() 
                   for name, f in contrast_files.items()}
    
    def compute_connectivity(self, timeseries, method='correlation'):
        """
        Compute functional connectivity within ROI.
        
        Parameters
        ----------
        timeseries : array
            Timeseries data (n_timepoints x n_voxels)
        method : str
            Connectivity method ('correlation', 'partial', 'covariance')
            
        Returns
        -------
        array
            Connectivity matrix
        """
        from sklearn.covariance import LedoitWolf
        from nilearn.connectome import ConnectivityMeasure
        
        # Ensure 3D array (n_subjects x n_timepoints x n_voxels)
        if timeseries.ndim == 2:
            timeseries = timeseries[np.newaxis, ...]
            
        # Compute connectivity
        conn_measure = ConnectivityMeasure(kind=method)
        connectivity = conn_measure.fit_transform(timeseries)
        
        if connectivity.shape[0] == 1:
            return connectivity[0]
        else:
            return connectivity
    
    def compute_summary_stats(self, data):
        """
        Compute summary statistics for ROI data.
        
        Parameters
        ----------
        data : array
            Data values
            
        Returns
        -------
        dict
            Summary statistics
        """
        return {
            'mean': np.mean(data),
            'std': np.std(data),
            'median': np.median(data),
            'min': np.min(data),
            'max': np.max(data),
            'q25': np.percentile(data, 25),
            'q75': np.percentile(data, 75),
            'n_voxels': len(data),
            'n_active': np.sum(data > 0),
            'pct_active': np.sum(data > 0) / len(data) * 100
        }
    
    def visualize_roi(self, background='MNI152', display_mode='ortho',
                     cut_coords=None, output_file=None):
        """
        Visualize ROI on brain.
        
        Parameters
        ----------
        background : str or nibabel image
            Background image
        display_mode : str
            Display mode
        cut_coords : tuple
            Cut coordinates
        output_file : str
            Output file path
            
        Returns
        -------
        matplotlib figure
            ROI visualization
        """
        from nilearn import plotting, datasets
        
        if background == 'MNI152':
            background = datasets.load_mni152_template()
            
        if cut_coords is None:
            # Find ROI center of mass
            roi_data = self.roi_img.get_fdata()
            coords = np.array(np.where(roi_data > 0))
            cut_coords = self.roi_img.affine.dot(
                np.append(coords.mean(axis=1), 1))[:3]
            
        display = plotting.plot_roi(
            self.roi_img,
            bg_img=background,
            display_mode=display_mode,
            cut_coords=cut_coords,
            title=self.roi_name
        )
        
        if output_file:
            display.savefig(output_file, dpi=300)
            
        return display


def batch_create_rois(output_dir, subjects, task, model, contrasts,
                     threshold=2.3, min_cluster_size=10):
    """
    Create ROIs from contrasts across multiple subjects.
    
    Parameters
    ----------
    output_dir : str
        Base output directory
    subjects : list
        List of subject IDs
    task : str
        Task name
    model : str
        Model name
    contrasts : list
        List of contrast names
    threshold : float
        Statistical threshold
    min_cluster_size : int
        Minimum cluster size
        
    Returns
    -------
    dict
        Dictionary of created ROIs
    """
    roi_creator = ROICreator(output_dir)
    created_rois = {}
    
    # Create individual subject ROIs
    for subject in subjects:
        subj_dir = Path(output_dir) / f"task-{task}_model-{model}" / f"sub-{subject}"
        
        for contrast in contrasts:
            # Find contrast file
            spmT_files = list((subj_dir / "spmT").glob("spmT_*.nii"))
            
            # Load contrast names
            try:
                import scipy.io as sio
                spm_file = subj_dir / "spm" / "SPM.mat"
                mat = sio.loadmat(str(spm_file))
                contrast_names = [str(c[0][0]) for c in mat['SPM']['xCon']['name'][0][0]]
                
                # Find matching contrast
                contrast_idx = contrast_names.index(contrast)
                
                if contrast_idx < len(spmT_files):
                    roi_name = f"sub-{subject}_{contrast}_thr{threshold}"
                    roi = roi_creator.create_threshold_roi(
                        str(spmT_files[contrast_idx]),
                        threshold=threshold,
                        min_cluster_size=min_cluster_size,
                        roi_name=roi_name
                    )
                    created_rois[roi_name] = roi
                    
            except Exception as e:
                print(f"Error creating ROI for {subject}, {contrast}: {e}")
    
    # Create group ROIs
    subject_dirs = [Path(output_dir) / f"task-{task}_model-{model}" / f"sub-{s}" 
                   for s in subjects]
    
    for contrast in contrasts:
        group_roi = roi_creator.create_group_roi(
            subject_dirs,
            contrast,
            threshold=threshold,
            overlap_threshold=0.5,
            roi_name=f"group_{contrast}"
        )
        if group_roi:
            created_rois[f"group_{contrast}"] = group_roi
            
    return created_rois


if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description="Create ROIs from contrast maps")
    parser.add_argument("output_dir", help="Output directory from first-level analysis")
    parser.add_argument("--subjects", "-s", nargs="+", required=True, help="Subject IDs")
    parser.add_argument("--task", "-t", required=True, help="Task name")
    parser.add_argument("--model", "-m", required=True, help="Model name")
    parser.add_argument("--contrasts", "-c", nargs="+", required=True, help="Contrast names")
    parser.add_argument("--threshold", type=float, default=2.3, help="Statistical threshold")
    parser.add_argument("--min-cluster", type=int, default=10, help="Minimum cluster size")
    
    args = parser.parse_args()
    
    batch_create_rois(
        args.output_dir,
        args.subjects,
        args.task,
        args.model,
        args.contrasts,
        threshold=args.threshold,
        min_cluster_size=args.min_cluster
    )