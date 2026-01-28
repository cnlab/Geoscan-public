import ijson
from datetime import datetime, timezone
import os
import glob
import pandas as pd
import numpy as np
import re
from decimal import Decimal
import itertools

def filter_and_write_geodata_by_study_period(geodata_file, dates, output_file,chunk_size):
    filtered_data = []
    with open(geodata_file, 'rb') as file:
        objects = ijson.items(file, 'locations.item')

        # Process the file in chunks
        while True:
            chunk = list(itertools.islice(objects, chunk_size))
            if not chunk:
                break  # Break if there are no more objects
            
            for index, row in dates.iterrows():
                # Accessing values in the current row
                if pd.isna(row['start_date']):
                    continue
                start_date = datetime.fromisoformat(str(row['start_date'])).replace(tzinfo=timezone.utc)
                end_date = datetime.fromisoformat(str(row['end_date'])).replace(tzinfo=timezone.utc).replace(hour=23, minute=59, second=59)

                # Filter objects based on the timestamp
                filtered_chunk = [
                    o for o in chunk
                    if start_date <= datetime.fromisoformat(o.get('timestamp', '')) <= end_date
                ]                
                # Extend the filtered data list with the filtered chunk
                filtered_data.extend(filtered_chunk)

    # Create a DataFrame from the filtered data
    df = pd.DataFrame(filtered_data)

    # Extract the required columns
    selected_columns = ["latitudeE7", "longitudeE7", "altitude", "velocity", "timestamp", "heading"]
    valid_columns = df.columns.intersection(selected_columns)
    df = df[valid_columns].rename(columns={'latitudeE7': 'latitude', 'longitudeE7': 'longitude'})

    # Add pID to csv. Naming it 'filename' to match with codebase...
    ppt = extract_participant_id(geodata_file)
    
    df['filename'] = ppt
    df['pid'] = ppt

    # Save the DataFrame as a CSV file
    df.to_csv(output_file, index=False)

def convert_to_serializable(obj):
    if isinstance(obj, Decimal):
        return float(obj)
    elif isinstance(obj, datetime):
        return obj.isoformat()
    else:
        raise TypeError(f"Type {type(obj)} not serializable")
    
def loadData(directory, pattern):
 
    # Join the directory and pattern to create a full path
    search_path = os.path.join(directory, pattern)

    # Use glob to get a list of matching files
    matching_files = glob.glob(search_path)

    if not matching_files:
        return None

    # Find the most recently modified file
    most_recent_file = max(matching_files, key=os.path.getmtime)
    if most_recent_file != None:
        with open(most_recent_file, 'r') as openfile:
    
        # Reading from json file
            return pd.read_csv(openfile)

def extract_participant_id(input_string):
    match = re.search(r'(GR\d{3})', input_string)
    if match:
        participant_id = match.group(1)
        return participant_id
    else:
        return None
    
def find_file(start_dir, file_name):
    for root, dirs, files in os.walk(start_dir):
        if file_name in files:
            return os.path.join(root, file_name)

    # File not found
    return None

def get_dates(redcap, ppt, type):
    if type == "baseline":
        start_date_names = ["lifedata_pak1a_start", "lifedata_pak1b_start","lifedata_pak1c_start"]
        end_date_names = ["lifedata_pak1a_end","lifedata_pak1b_end","lifedata_pak1c_end"]
    elif type == "intervention":
        start_date_names = ["lifedata_pak2a_start","lifedata_pak2b_start","lifedata_pak2c_start"]
        end_date_names = ["lifedata_pak2a_end","lifedata_pak2b_end","lifedata_pak2c_end"]

    filtereddates = (redcap[redcap['pid'] == ppt])
    dates = pd.melt(filtereddates, id_vars=['pid'], value_vars = start_date_names + end_date_names, var_name='date_type', value_name='date')

    df = pd.DataFrame(dates)

    # Pivot the DataFrame
    dates_pivot = dates.pivot(index='pid', columns='date_type', values='date').reset_index()

    # Create a new DataFrame with the desired format
    result_dates = pd.DataFrame({
        'pid': np.tile(dates_pivot['pid'].values, len(start_date_names)),
        'start_date': dates_pivot[start_date_names].values.flatten(),
        'end_date': dates_pivot[end_date_names].values.flatten()
    })

    return(result_dates)

def create_directory(directory_path):
    if not os.path.exists(directory_path):
        os.makedirs(directory_path)
        print(f"Directory '{directory_path}' created.")
    else:
        print(f"Directory '{directory_path}' already exists.")

def trim_and_save_by_study_period(study_period):
    if study_period not in ['baseline', 'intervention']:
        raise ValueError("Invalid argument. It must be either 'baseline' or 'intervention'.")

    timeline_directory = "/Volumes/cnlab/GeoRemote/Data/Geodata/clean/"
    output_file_path = os.path.join("/Volumes/cnlab/GeoRemote/Data/Geodata/clean/",study_period)
    create_directory(output_file_path)
    print("Loading redcap")
    redcap = loadData("/Volumes/cnlab/GeoRemote/Data/Redcap/clean/","redcap_clean*.csv")
    print("Loaded!")
    list_files_in_folder = lambda folder_path: [item for item in os.listdir(folder_path) if os.path.isfile(os.path.join(folder_path, item)) and item.endswith('.json') and not item.startswith('.')]
    files_in_folder = sorted(list_files_in_folder(timeline_directory))    

    for timeline_folder in files_in_folder:
        ppt = extract_participant_id(timeline_folder)
        output_file = os.path.join(output_file_path, ppt + "_" + study_period + "_geodata.csv")
        # Check if folder is already trimmed
        if ppt is not None:
            if os.path.exists(output_file):
                print(ppt + " already completed...")
                continue
            # If not, let's make sure Record.json exists, and the ppt start_date exists in redcap
            geodata_file = find_file(timeline_directory,ppt + "_geodata.json")

            if geodata_file is not None and os.path.exists(geodata_file):
                dates = get_dates(redcap,ppt, study_period)
                if dates is not None:
                    # set the output path:
                    print(ppt + " started")
                    filter_and_write_geodata_by_study_period(geodata_file, dates, output_file,chunk_size=20000)
                    print(ppt + " complete")

if __name__ == "__main__":
    # You can call any function you want to execute when the script is run
    trim_and_save_by_study_period('intervention')


                    
