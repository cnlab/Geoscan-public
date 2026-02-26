import os
import glob
import json
from pathlib import Path
from IPython.display import display, HTML, clear_output
import pandas as pd
import numpy as np

# Try to import optional packages
try:
    import nibabel as nib
    NIBABEL_AVAILABLE = True
except ImportError:
    NIBABEL_AVAILABLE = False
    print("Warning: nibabel not available. NIfTI viewing will be limited.")

try:
    from bids import BIDSLayout
    PYBIDS_AVAILABLE = True
except ImportError:
    PYBIDS_AVAILABLE = False
    print("Warning: pybids not available. Using basic file scanning instead.")

try:
    import matplotlib.pyplot as plt
    import matplotlib.patches as patches
    MATPLOTLIB_AVAILABLE = True
except ImportError:
    MATPLOTLIB_AVAILABLE = False
    print("Warning: matplotlib not available. Plotting features disabled.")


class BIDSInteractiveViewer:
    """
    Interactive BIDS data viewer for exploring participants, files, and derivatives.
    Designed to work in VSCode over a server connection.
    """
    
    def __init__(self, bids_root=None):
        """
        Initialize the BIDS viewer.
        
        Parameters:
        -----------
        bids_root : str, optional
            Path to the BIDS dataset root directory.
        """
        self.bids_root = bids_root or "/data00/projects/georemote_fmri/data/bids_data/"
        self.current_participant = None
        self.current_file_type = None
        self.current_file = None
        
        # Initialize BIDS layout if available
        if PYBIDS_AVAILABLE and os.path.exists(self.bids_root):
            try:
                self.layout = BIDSLayout(self.bids_root, validate=False)
                self.use_pybids = True
                print("✓ PyBIDS layout initialized successfully")
            except Exception as e:
                print(f"Warning: PyBIDS layout failed, using file scanning: {e}")
                self.layout = None
                self.use_pybids = False
        else:
            self.layout = None
            self.use_pybids = False
    
    def get_participants(self):
        """Get list of all participants."""
        if self.use_pybids and self.layout:
            return sorted(self.layout.get_subjects())
        else:
            # Fallback: scan for sub-* directories
            sub_dirs = glob.glob(os.path.join(self.bids_root, 'sub-*'))
            participants = []
            for sub_dir in sub_dirs:
                if os.path.isdir(sub_dir):
                    participant = os.path.basename(sub_dir).replace('sub-', '')
                    participants.append(participant)
            return sorted(participants)
    
    def display_participant_buttons(self):
        """Display buttons for selecting participants."""
        participants = self.get_participants()
        
        if not participants:
            print(f"No participants found in {self.bids_root}")
            return
        
        print(f"✓ Found {len(participants)} participants")
        print("\n" + "="*50)
        print("PARTICIPANT SELECTION")
        print("="*50)
        
        for i, participant in enumerate(participants):
            print(f"select_participant('{participant}')  # {participant}")
            if (i + 1) % 5 == 0:  # Add spacing every 5 participants
                print()
    
    def select_participant(self, participant_id):
        """Select a participant and display file type options."""
        self.current_participant = participant_id
        print(f"\n✓ Selected participant: {participant_id}")
        
        # Display file type selection
        self.display_file_type_buttons()
    
    def display_file_type_buttons(self):
        """Display buttons for selecting file types."""
        if not self.current_participant:
            print("No participant selected. Please select a participant first.")
            return
        
        print("\n" + "="*50)
        print(f"FILE TYPE SELECTION - Participant: {self.current_participant}")
        print("="*50)
        
        print("# Raw BIDS data:")
        print(f"view_nifti_files('{self.current_participant}')")
        print(f"view_events_files('{self.current_participant}')")
        print(f"view_json_files('{self.current_participant}')")
        print()
        print("# Derivatives:")
        print(f"view_derivatives('{self.current_participant}')")
        print()
        print("# File browser:")
        print(f"browse_all_files('{self.current_participant}')")
    
    def get_participant_files(self, participant_id, extension=None, suffix=None):
        """Get files for a specific participant."""
        if self.use_pybids and self.layout:
            try:
                files = self.layout.get(subject=participant_id, 
                                      extension=extension, 
                                      suffix=suffix,
                                      return_type='filename')
                return sorted(files)
            except Exception as e:
                print(f"PyBIDS error: {e}, falling back to file scanning")
        
        # Fallback: manual file scanning
        participant_dir = os.path.join(self.bids_root, f'sub-{participant_id}')
        if not os.path.exists(participant_dir):
            return []
        
        files = []
        if extension:
            pattern = f"**/*{extension}"
        else:
            pattern = "**/*"
        
        for file_path in Path(participant_dir).rglob(pattern):
            if file_path.is_file():
                if suffix and suffix not in file_path.name:
                    continue
                files.append(str(file_path))
        
        return sorted(files)
    
    def view_nifti_files(self, participant_id=None):
        """Display NIfTI files for a participant."""
        participant_id = participant_id or self.current_participant
        if not participant_id:
            print("No participant specified.")
            return
        
        files = self.get_participant_files(participant_id, extension='.nii.gz')
        files.extend(self.get_participant_files(participant_id, extension='.nii'))
        
        self._display_file_list("NIfTI Files", files, "load_nifti")
    
    def view_events_files(self, participant_id=None):
        """Display events files for a participant."""
        participant_id = participant_id or self.current_participant
        if not participant_id:
            print("No participant specified.")
            return
        
        files = self.get_participant_files(participant_id, extension='.tsv')
        # Filter for events files
        events_files = [f for f in files if 'events' in os.path.basename(f)]
        
        self._display_file_list("Events Files", events_files, "load_events")
    
    def view_json_files(self, participant_id=None):
        """Display JSON files for a participant."""
        participant_id = participant_id or self.current_participant
        if not participant_id:
            print("No participant specified.")
            return
        
        files = self.get_participant_files(participant_id, extension='.json')
        self._display_file_list("JSON Files", files, "load_json")
    
    def view_derivatives(self, participant_id=None):
        """Display derivatives for a participant."""
        participant_id = participant_id or self.current_participant
        if not participant_id:
            print("No participant specified.")
            return
        
        # Find all derivatives directories
        derivatives_dirs = []
        
        # Look in the main BIDS directory
        for item in os.listdir(self.bids_root):
            item_path = os.path.join(self.bids_root, item)
            if os.path.isdir(item_path) and 'derivatives' in item.lower():
                derivatives_dirs.append(item_path)
        
        # Also look for a derivatives subdirectory
        derivatives_path = os.path.join(self.bids_root, 'derivatives')
        if os.path.exists(derivatives_path):
            for item in os.listdir(derivatives_path):
                item_path = os.path.join(derivatives_path, item)
                if os.path.isdir(item_path):
                    derivatives_dirs.append(item_path)
        
        print(f"\n✓ Derivatives for participant: {participant_id}")
        print("="*50)
        
        if not derivatives_dirs:
            print("No derivatives directories found.")
            return
        
        for deriv_dir in derivatives_dirs:
            print(f"\n📁 {os.path.basename(deriv_dir)}:")
            print(f"browse_derivatives_folder('{participant_id}', '{deriv_dir}')")
    
    def browse_derivatives_folder(self, participant_id, derivatives_path):
        """Browse files in a specific derivatives folder."""
        participant_pattern = f"sub-{participant_id}"
        files = []
        
        # Look for files containing the participant ID
        for root, dirs, filenames in os.walk(derivatives_path):
            for filename in filenames:
                if participant_pattern in filename:
                    files.append(os.path.join(root, filename))
        
        self._display_file_list(f"Derivatives - {os.path.basename(derivatives_path)}", 
                               files, "load_file")
    
    def browse_all_files(self, participant_id=None):
        """Browse all files for a participant."""
        participant_id = participant_id or self.current_participant
        if not participant_id:
            print("No participant specified.")
            return
        
        participant_dir = os.path.join(self.bids_root, f'sub-{participant_id}')
        if not os.path.exists(participant_dir):
            print(f"Participant directory not found: {participant_dir}")
            return
        
        files = []
        for root, dirs, filenames in os.walk(participant_dir):
            for filename in filenames:
                files.append(os.path.join(root, filename))
        
        self._display_file_list(f"All Files - {participant_id}", files, "load_file")
    
    def _display_file_list(self, title, files, load_function):
        """Display a list of files with load commands."""
        print(f"\n✓ {title}")
        print("="*50)
        
        if not files:
            print("No files found.")
            return
        
        print(f"Found {len(files)} files:\n")
        
        for i, file_path in enumerate(files):
            file_name = os.path.basename(file_path)
            print(f"{load_function}('{file_path}')  # {file_name}")
            
            if (i + 1) % 10 == 0:  # Add spacing every 10 files
                print()
    
    def load_nifti(self, file_path):
        """Load and display information about a NIfTI file."""
        if not NIBABEL_AVAILABLE:
            print("nibabel not available. Showing file info only.")
            self.load_file(file_path)
            return
        
        try:
            img = nib.load(file_path)
            header = img.header
            
            print(f"\n✓ Loaded NIfTI: {os.path.basename(file_path)}")
            print("="*50)
            print(f"Shape: {img.shape}")
            print(f"Data type: {header.get_data_dtype()}")
            print(f"Voxel size: {header.get_zooms()}")
            print(f"Affine matrix:\n{img.affine}")
            
            # Basic statistics if it's 3D/4D
            data = img.get_fdata()
            print(f"\nData statistics:")
            print(f"Min: {np.min(data):.4f}")
            print(f"Max: {np.max(data):.4f}")
            print(f"Mean: {np.mean(data):.4f}")
            print(f"Std: {np.std(data):.4f}")
            
            self.current_file = file_path
            
        except Exception as e:
            print(f"Error loading NIfTI file: {e}")
    
    def load_events(self, file_path):
        """Load and display events file."""
        try:
            events_df = pd.read_csv(file_path, sep='\\t')
            
            print(f"\n✓ Loaded Events: {os.path.basename(file_path)}")
            print("="*50)
            print(f"Shape: {events_df.shape}")
            print(f"Columns: {list(events_df.columns)}")
            print(f"\nFirst 10 rows:")
            print(events_df.head(10))
            
            if 'trial_type' in events_df.columns:
                print(f"\nTrial types: {events_df['trial_type'].unique()}")
            
            self.current_file = file_path
            
        except Exception as e:
            print(f"Error loading events file: {e}")
    
    def load_json(self, file_path):
        """Load and display JSON file."""
        try:
            with open(file_path, 'r') as f:
                json_data = json.load(f)
            
            print(f"\n✓ Loaded JSON: {os.path.basename(file_path)}")
            print("="*50)
            print(json.dumps(json_data, indent=2))
            
            self.current_file = file_path
            
        except Exception as e:
            print(f"Error loading JSON file: {e}")
    
    def load_file(self, file_path):
        """Generic file loader."""
        file_ext = os.path.splitext(file_path)[1].lower()
        
        if file_ext in ['.nii', '.gz']:
            if file_path.endswith('.nii.gz'):
                self.load_nifti(file_path)
            else:
                self._show_file_info(file_path)
        elif file_ext == '.tsv':
            if 'events' in os.path.basename(file_path):
                self.load_events(file_path)
            else:
                self._load_tsv(file_path)
        elif file_ext == '.json':
            self.load_json(file_path)
        else:
            self._show_file_info(file_path)
    
    def _load_tsv(self, file_path):
        """Load a TSV file."""
        try:
            df = pd.read_csv(file_path, sep='\\t')
            print(f"\n✓ Loaded TSV: {os.path.basename(file_path)}")
            print("="*50)
            print(f"Shape: {df.shape}")
            print(f"Columns: {list(df.columns)}")
            print(f"\nFirst 10 rows:")
            print(df.head(10))
            
            self.current_file = file_path
            
        except Exception as e:
            print(f"Error loading TSV file: {e}")
    
    def _show_file_info(self, file_path):
        """Show basic file information."""
        try:
            stat_info = os.stat(file_path)
            
            print(f"\n✓ File Info: {os.path.basename(file_path)}")
            print("="*50)
            print(f"Full path: {file_path}")
            print(f"Size: {stat_info.st_size / (1024*1024):.2f} MB")
            print(f"Modified: {pd.to_datetime(stat_info.st_mtime, unit='s')}")
            
            self.current_file = file_path
            
        except Exception as e:
            print(f"Error getting file info: {e}")
    
    def set_bids_root(self, new_path):
        """Change the BIDS root directory."""
        if os.path.exists(new_path):
            self.bids_root = new_path
            print(f"✓ Updated BIDS root to: {new_path}")
            
            # Reinitialize PyBIDS layout if available
            if PYBIDS_AVAILABLE:
                try:
                    self.layout = BIDSLayout(self.bids_root, validate=False)
                    self.use_pybids = True
                    print("✓ PyBIDS layout reinitialized")
                except Exception as e:
                    print(f"Warning: PyBIDS layout failed: {e}")
                    self.layout = None
                    self.use_pybids = False
            
            self.display_participant_buttons()
        else:
            print(f"Directory does not exist: {new_path}")


# Create the viewer instance
viewer = BIDSInteractiveViewer()

# Display initial interface
print("="*60)
print("        BIDS INTERACTIVE DATA VIEWER")
print("="*60)
print(f"BIDS Root: {viewer.bids_root}")
print(f"PyBIDS Available: {PYBIDS_AVAILABLE}")
print(f"NiBabel Available: {NIBABEL_AVAILABLE}")
print(f"Matplotlib Available: {MATPLOTLIB_AVAILABLE}")

print("\n" + "-"*60)
print("QUICK START:")
print("-"*60)
print("1. Select a participant using: select_participant('PARTICIPANT_ID')")
print("2. Browse file types using the displayed commands")
print("3. Load specific files using the generated commands")
print("\nTo change BIDS directory: viewer.set_bids_root('/path/to/bids')")
print("-"*60)

# Display participant selection
viewer.display_participant_buttons()

# Create convenience functions in global scope
def select_participant(participant_id):
    """Convenience function for selecting participants."""
    return viewer.select_participant(participant_id)

def view_nifti_files(participant_id):
    """Convenience function for viewing NIfTI files."""
    return viewer.view_nifti_files(participant_id)

def view_events_files(participant_id):
    """Convenience function for viewing events files."""
    return viewer.view_events_files(participant_id)

def view_json_files(participant_id):
    """Convenience function for viewing JSON files."""
    return viewer.view_json_files(participant_id)

def view_derivatives(participant_id):
    """Convenience function for viewing derivatives."""
    return viewer.view_derivatives(participant_id)

def browse_derivatives_folder(participant_id, derivatives_path):
    """Convenience function for browsing derivatives folders."""
    return viewer.browse_derivatives_folder(participant_id, derivatives_path)

def browse_all_files(participant_id):
    """Convenience function for browsing all files."""
    return viewer.browse_all_files(participant_id)

def load_nifti(file_path):
    """Convenience function for loading NIfTI files."""
    return viewer.load_nifti(file_path)

def load_events(file_path):
    """Convenience function for loading events files."""
    return viewer.load_events(file_path)

def load_json(file_path):
    """Convenience function for loading JSON files."""
    return viewer.load_json(file_path)

def load_file(file_path):
    """Convenience function for loading any file."""
    return viewer.load_file(file_path)