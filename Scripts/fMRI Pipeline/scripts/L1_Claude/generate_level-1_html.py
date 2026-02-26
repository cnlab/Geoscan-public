#!/usr/bin/env python3
"""
HTML Report Generator for fMRI First Level Models
Reads SPM.mat files and creates HTML reports with contrast images
"""

import os
import glob
import numpy as np
import nibabel as nib
from scipy.io import loadmat
import matplotlib.pyplot as plt
from nilearn import plotting, datasets
from nilearn.image import threshold_img
import base64
from io import BytesIO
import html
import warnings
warnings.filterwarnings('ignore')

def read_spm_mat(spm_mat_path):
    """Read SPM.mat file and extract contrast information"""
    try:
        spm_data = loadmat(spm_mat_path, struct_as_record=False, squeeze_me=True)
        spm = spm_data['SPM']
        
        # Extract contrast names and information
        contrasts = []
        if hasattr(spm, 'xCon') and spm.xCon.size > 0:
            xCon = spm.xCon
            if not isinstance(xCon, np.ndarray):
                xCon = [xCon]
            
            for i, con in enumerate(xCon):
                contrast_info = {
                    'index': i + 1,
                    'name': con.name if hasattr(con, 'name') else f'Contrast_{i+1}',
                    'type': con.STAT if hasattr(con, 'STAT') else 'T',
                    'c': con.c if hasattr(con, 'c') else None
                }
                contrasts.append(contrast_info)
        
        return contrasts, spm
    except Exception as e:
        print(f"Error reading SPM.mat: {e}")
        return [], None

def create_contrast_visualizations(con_img_path, threshold=2.0):
    """Create multiple visualizations of the contrast image using nilearn"""
    try:
        # Load the contrast image
        stat_img = nib.load(con_img_path)
        
        # Apply threshold
        thresholded_img = threshold_img(stat_img, threshold=threshold)
        
        visualizations = {}
        
        # 1. Glass brain plot
        fig = plt.figure(figsize=(12, 4))
        plotting.plot_glass_brain(thresholded_img, 
                                colorbar=True, 
                                title='Glass Brain View',
                                plot_abs=False,
                                display_mode='lyrz',
                                figure=fig)
        
        buffer = BytesIO()
        plt.savefig(buffer, format='png', dpi=150, bbox_inches='tight')
        buffer.seek(0)
        visualizations['glass_brain'] = base64.b64encode(buffer.read()).decode()
        plt.close()
        
        # 2. Statistical map overlay on anatomical template
        try:
            # Use MNI152 template
            anat_img = datasets.load_mni152_template(resolution=2)
            
            fig = plt.figure(figsize=(15, 5))
            plotting.plot_stat_map(thresholded_img,
                                 bg_img=anat_img,
                                 display_mode='ortho',
                                 colorbar=True,
                                 title='Statistical Map Overlay',
                                 cut_coords=None,
                                 figure=fig)
            
            buffer = BytesIO()
            plt.savefig(buffer, format='png', dpi=150, bbox_inches='tight')
            buffer.seek(0)
            visualizations['stat_map'] = base64.b64encode(buffer.read()).decode()
            plt.close()
            
        except Exception as e:
            print(f"Could not create stat map overlay: {e}")
        
        # 3. Mosaic view
        fig = plt.figure(figsize=(16, 10))
        plotting.plot_stat_map(thresholded_img,
                             display_mode='mosaic',
                             colorbar=True,
                             title='Mosaic View',
                             figure=fig)
        
        buffer = BytesIO()
        plt.savefig(buffer, format='png', dpi=150, bbox_inches='tight')
        buffer.seek(0)
        visualizations['mosaic'] = base64.b64encode(buffer.read()).decode()
        plt.close()
        
        # 4. Surface projection (requires volume-to-surface mapping)
        try:
            from nilearn.surface import vol_to_surf
            
            # Get surface data
            fsaverage = datasets.fetch_surf_fsaverage()
            
            # Project volume to surface (left hemisphere)
            surf_data_left = vol_to_surf(thresholded_img, fsaverage['pial_left'])
            
            # Only plot if there's significant data on surface
            if np.any(np.abs(surf_data_left) > 0):
                fig = plt.figure(figsize=(12, 8))
                plotting.plot_surf_stat_map(fsaverage['pial_left'],
                                          surf_data_left,
                                          hemi='left',
                                          title='Left Hemisphere Surface',
                                          colorbar=True,
                                          view='lateral',
                                          figure=fig)
                
                buffer = BytesIO()
                plt.savefig(buffer, format='png', dpi=150, bbox_inches='tight')
                buffer.seek(0)
                visualizations['surface_left'] = base64.b64encode(buffer.read()).decode()
                plt.close()
            
        except Exception as e:
            print(f"Surface plot not available (volume-to-surface mapping needed): {e}")
        
        return visualizations
        
    except Exception as e:
        print(f"Error creating visualizations for {con_img_path}: {e}")
        return {}

def generate_html_report(subject_path, base_nipype_dir):
    """Generate HTML report for a single subject's first-level model"""
    
    # Extract subject ID from path
    subject_id = os.path.basename(subject_path.rstrip('/'))
    
    # Set output path in nipype directory
    output_path = os.path.join(base_nipype_dir, f"{subject_id}-level-1_report.html")
    
    # Find SPM.mat file
    spm_mat_path = os.path.join(subject_path, 'SPM.mat')
    if not os.path.exists(spm_mat_path):
        print(f"SPM.mat not found in {subject_path}")
        return None
    
    # Read contrast information
    contrasts, spm = read_spm_mat(spm_mat_path)
    if not contrasts:
        print("No contrasts found in SPM.mat")
        return None
    
    # Start HTML content with enhanced styling
    html_content = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <title>fMRI First Level Model Report - {subject_id}</title>
        <style>
            body {{ 
                font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; 
                margin: 0; 
                padding: 20px; 
                background-color: #f5f5f5;
            }}
            .container {{ max-width: 1200px; margin: 0 auto; background: white; }}
            .header {{ 
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); 
                color: white; 
                padding: 30px; 
                border-radius: 10px 10px 0 0;
            }}
            .header h1 {{ margin: 0; font-size: 28px; }}
            .info-grid {{ 
                display: grid; 
                grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); 
                gap: 15px; 
                margin-top: 20px; 
            }}
            .info-item {{ background: rgba(255,255,255,0.1); padding: 15px; border-radius: 5px; }}
            .contrast-section {{ 
                margin: 30px; 
                padding: 25px; 
                border: 1px solid #e0e0e0; 
                border-radius: 10px; 
                background: white;
                box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            }}
            .contrast-title {{ 
                font-size: 22px; 
                font-weight: bold; 
                color: #333; 
                margin-bottom: 15px;
                padding-bottom: 10px;
                border-bottom: 2px solid #667eea;
            }}
            .stats {{ 
                background: #f8f9fa; 
                padding: 15px; 
                border-radius: 5px; 
                margin-bottom: 20px;
                border-left: 4px solid #667eea;
            }}
            .visualization-section {{ margin: 25px 0; }}
            .viz-title {{ 
                font-size: 18px; 
                font-weight: 600; 
                margin: 20px 0 10px 0; 
                color: #495057;
            }}
            .image-container {{ 
                text-align: center; 
                margin: 20px 0; 
                padding: 15px;
                background: #fafafa;
                border-radius: 8px;
            }}
            .image-container img {{ 
                max-width: 100%; 
                height: auto; 
                border-radius: 5px;
                box-shadow: 0 4px 8px rgba(0,0,0,0.1);
            }}
            .error {{ 
                color: #dc3545; 
                font-style: italic; 
                padding: 15px;
                background: #f8d7da;
                border-radius: 5px;
                border: 1px solid #f5c6cb;
            }}
            .summary {{ 
                background: #e3f2fd; 
                padding: 20px; 
                margin: 20px 30px; 
                border-radius: 8px;
                border-left: 4px solid #2196f3;
            }}
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h1>fMRI First Level Model Report</h1>
                <div class="info-grid">
                    <div class="info-item">
                        <strong>Subject:</strong> {html.escape(subject_id)}
                    </div>
                    <div class="info-item">
                        <strong>Model Path:</strong> {html.escape(subject_path)}
                    </div>
                    <div class="info-item">
                        <strong>Generated:</strong> {html.escape(str(np.datetime64('now')))}
                    </div>
                    <div class="info-item">
                        <strong>Contrasts:</strong> {len(contrasts)}
                    </div>
                </div>
            </div>
            
            <div class="summary">
                <h3>Report Summary</h3>
                <p>This report shows statistical maps for each contrast using multiple visualization methods:</p>
                <ul>
                    <li><strong>Glass Brain:</strong> Transparent brain view showing all significant activations</li>
                    <li><strong>Statistical Overlay:</strong> Activations overlaid on anatomical template</li>
                    <li><strong>Mosaic View:</strong> Multiple axial slices for comprehensive coverage</li>
                    <li><strong>Surface View:</strong> Cortical surface projection (when available)</li>
                </ul>
                <p><em>Default threshold: t > 2.0</em></p>
            </div>
    """
    
    # Process each contrast
    for contrast in contrasts:
        html_content += f"""
        <div class="contrast-section">
            <div class="contrast-title">Contrast {contrast['index']}: {html.escape(contrast['name'])}</div>
            <div class="stats">
                <strong>Statistic Type:</strong> {contrast['type']}<br>
            </div>
        """
        
        # Look for contrast images (prioritize statistical maps)
        con_patterns = [
            (f"spmT_{contrast['index']:04d}.nii", "T-statistic map"),
            (f"con_{contrast['index']:04d}.nii", "Contrast estimate"),
            (f"spmT_{contrast['index']:04d}.img", "T-statistic map"),
            (f"con_{contrast['index']:04d}.img", "Contrast estimate")
        ]
        
        contrast_found = False
        for pattern, description in con_patterns:
            con_path = os.path.join(subject_path, pattern)
            if os.path.exists(con_path):
                print(f"Processing {pattern} for contrast {contrast['index']}")
                
                # Create visualizations using nilearn
                visualizations = create_contrast_visualizations(con_path)
                
                if visualizations:
                    html_content += f"""
                    <div class="visualization-section">
                        <p><strong>Image:</strong> {pattern} ({description})</p>
                    """
                    
                    # Add each visualization
                    viz_titles = {
                        'glass_brain': 'Glass Brain View',
                        'stat_map': 'Statistical Map Overlay',
                        'mosaic': 'Mosaic View',
                        'surface_left': 'Left Hemisphere Surface'
                    }
                    
                    for viz_key, viz_title in viz_titles.items():
                        if viz_key in visualizations:
                            html_content += f"""
                            <div class="viz-title">{viz_title}</div>
                            <div class="image-container">
                                <img src="data:image/png;base64,{visualizations[viz_key]}" alt="{viz_title}">
                            </div>
                            """
                    
                    html_content += "</div>"
                    contrast_found = True
                    break
        
        if not contrast_found:
            html_content += """
            <div class="error">
                <p>⚠️ Contrast image files not found</p>
                <p>Expected files: spmT_XXXX.nii or con_XXXX.nii</p>
            </div>
            """
        
        html_content += "</div>"
    
    # Close HTML
    html_content += """
        </div>
    </body>
    </html>
    """
    
    # Save HTML report
    with open(output_path, 'w') as f:
        f.write(html_content)
    
    print(f"HTML report saved to: {output_path}")
    return output_path

def process_all_subjects(base_path):
    """Process all subjects in the derivatives directory"""
    # Get the base nipype directory (parent of the model directory)
    base_nipype_dir = os.path.dirname(base_path.rstrip('/'))
    
    subject_dirs = glob.glob(os.path.join(base_path, "sub-*"))
    
    print(f"Found {len(subject_dirs)} subjects to process")
    print(f"Reports will be saved in: {base_nipype_dir}")
    
    for subject_dir in subject_dirs:
        subject_id = os.path.basename(subject_dir)
        print(f"\nProcessing {subject_id}...")
        try:
            generate_html_report(subject_dir, base_nipype_dir)
        except Exception as e:
            print(f"Error processing {subject_id}: {e}")

if __name__ == "__main__":
    # Base path to your model outputs
    base_path = "/data00/projects/geoscan_v2/data/bids_data/derivatives_nocorrection/nipype/task-image_model-GEO-condition/"
    
    # Process all subjects
    process_all_subjects(base_path)
    
    # Or process a single subject
    # subject_path = os.path.join(base_path, "sub-GEO04")  # Replace with actual subject ID
    # base_nipype_dir = os.path.dirname(base_path.rstrip('/'))
    # generate_html_report(subject_path, base_nipype_dir)