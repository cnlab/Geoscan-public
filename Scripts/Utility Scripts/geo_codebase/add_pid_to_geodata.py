import os
import pandas as pd
import re

def extract_participant_id(input_string):
    match = re.search(r'(GR\d{3})', input_string)
    if match:
        participant_id = match.group(1)
        return participant_id
    else:
        return None

## Folder path containing CSV files
folder_path = "/Volumes/cnlab/GeoRemote/Data/Geodata/clean/baseline"

# Iterate over each CSV file in the folder
for filename in os.listdir(folder_path):
    if filename.endswith(".csv") and not filename.startswith("."):
        file_path = os.path.join(folder_path, filename)
        print(file_path)
        try:
            df = pd.read_csv(file_path, encoding='utf-8')
        except UnicodeDecodeError:
            print(f"UnicodeDecodeError: Could not read {filename} with 'utf-8' encoding. Trying 'latin-1' encoding.")
            df = pd.read_csv(file_path, encoding='latin-1')
        except pd.errors.EmptyDataError: 
            print(f"No columns to parse from file...skipping {filename}")
            continue

        
        # Extract pid from filename (adjust the method based on your filename structure)
        pid = extract_participant_id(filename)
        
        print("Number of rows:", df.shape[0])
        print("Number of columns:", df.shape[1])
        if 'pid' not in df.columns:
            # Add 'pid' column
            df['pid'] = pid
            print(pid)
            # Save the updated DataFrame back to the same file, overwriting the previous version
            df.to_csv(file_path, index=False)
        else:
            print(f"'pid' column already exists in {filename}. Skipped adding it.")
