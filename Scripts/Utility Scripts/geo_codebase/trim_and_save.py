import ijson
from datetime import datetime, timezone
import json
import os
import glob
import pandas as pd
import numpy as np
import re
from decimal import Decimal
import itertools
import pytz

def convert_to_serializable(obj):
    if isinstance(obj, Decimal):
        return float(obj)
    elif isinstance(obj, datetime):
        return obj.isoformat()
    else:
        raise TypeError(f"Type {type(obj)} not serializable")

def filter_and_write_all_geodata(json_file_path, start_date, output_file_path, chunk_size=20000):
    est_timezone = pytz.timezone('America/New_York')  # Eastern Standard Time
    
    with open(json_file_path, 'rb') as f:
        objects = ijson.items(f, 'locations.item')
        filtered_objects = []
        #[o for o in objects if datetime.fromisoformat(o.get('timestamp', '')) >= start_date]
        for o in objects:
            timestamp_str = o.get('timestamp', '')
            timestamp_utc = datetime.fromisoformat(timestamp_str).replace(tzinfo=pytz.utc)
            timestamp_est = timestamp_utc.astimezone(est_timezone)
            if timestamp_est >= start_date:
                o['timestamp'] = timestamp_est.isoformat()  # Convert timestamp to EST and replace in object
                filtered_objects.append(o)

        with open(output_file_path, 'w') as output_file:
            json.dump({"locations": filtered_objects}, output_file, separators=(',', ':'), default=convert_to_serializable)

def convert_to_decimal(coord_str):

    if coord_str[0]=='-':
        divisor = len(coord_str) - 3
    else:
        divisor = len(coord_str) - 2
    # Insert the decimal point at the appropriate position
    return float(coord_str)/(10 ** divisor)

def filter_and_write_geodata_by_study_period(geodata_file, dates, output_file,chunk_size):
    est_timezone = pytz.timezone('America/New_York')  # Eastern Standard Time



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
                start_date = datetime.fromisoformat(str(row['start_date'])).astimezone(est_timezone)
                end_date = datetime.fromisoformat(str(row['end_date'])).astimezone(est_timezone).replace(hour=23, minute=59, second=59)

                # Filter objects based on the timestamp
                filtered_chunk = [
                    o for o in chunk
                    if start_date <= datetime.fromisoformat(o.get('timestamp', '')) <= end_date
                ]                
                # Extend the filtered data list with the filtered chunk
                filtered_data.extend(filtered_chunk)

    # Create a DataFrame from the filtered data
    df = pd.DataFrame(filtered_data)
    if len(df) == 0:
        return
    # Extract the required columns
    selected_columns = ["latitudeE7", "longitudeE7", "altitude", "velocity", "accuracy", "timestamp", "heading"]
    valid_columns = df.columns.intersection(selected_columns)
    df = df[valid_columns].rename(columns={'latitudeE7': 'lat', 'longitudeE7': 'lon', "timestamp": "datetime"})
    
    # Add pID to csv. Naming it 'filename' to match with codebase...
    ppt = extract_participant_id(geodata_file)
    
    df['filename'] = ppt
    df['pid'] = ppt
    df['lat'] = df['lat'].dropna().astype(int).astype(str).apply(convert_to_decimal)
    df['lon'] = df['lon'].dropna().astype(int).astype(str).apply(convert_to_decimal)

    # Extract date part from datetime strings
    df['Notification Date'] = pd.to_datetime(df['datetime'].str[:10])
    df['accuracy'] = df['accuracy'].dropna().astype(int).astype(str)

    # Ensure start_date and end_date columns are datetime objects
    dates['start_date'] = pd.to_datetime(dates['start_date'], errors='coerce')
    dates['end_date'] = pd.to_datetime(dates['end_date'], errors='coerce')

    # Generate full date ranges excluding start_date itself
    date_ranges = []
    for _, row in dates.iterrows():
        if pd.notna(row['start_date']) and pd.notna(row['end_date']):
            # Generate range from start_date + 1 to end_date (both inclusive)
            date_range = pd.date_range(start=row['start_date'], end=row['end_date'])
            date_ranges.append(date_range)

    # Concatenate all date ranges into a single series
    all_dates = pd.concat([pd.Series(dr) for dr in date_ranges], ignore_index=True)
    
    full_dates_df = pd.DataFrame({'Notification Date': all_dates})

    # Add an incrementing 'day' column starting from 1
    full_dates_df['day'] = range(1, len(full_dates_df) + 1)
    
    # Merge the geodata with the full date range to ensure every date is represented
    df = pd.merge(full_dates_df, df, on='Notification Date', how='left')

    # Save the DataFrame as a CSV file
    df.to_csv(output_file, index=False)

def loadData(directory, pattern):
 
    # Join the directory and pattern to create a full path
    search_path = os.path.join(directory, pattern)

    # Use glob to get a list of matching files
    matching_files = glob.glob(search_path)

    if not matching_files:
        return None

    # Find the most recently modified file
    most_recent_file = max(matching_files, key=os.path.getmtime)
    print(most_recent_file)
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

def get_start_date(redcap, ppt):
    dates = ["screenb_date", "s1_delivery","consent_date"]
    start_date = None
    idx=1
    while(start_date is None):
        start_date = redcap.loc[redcap['pid'] == ppt, dates[idx]].values[0]
        idx += 1
    return(start_date)

def get_dates(redcap, ppt, type, exclude_userIDs):
    exclude_userIDs_list = exclude_userIDs['id'].astype(str).str.strip().str.strip('"').str.replace('.0', '')

    if type == "baseline":
        start_date_names = ["lifedata_pak1a_start", "lifedata_pak1b_start","lifedata_pak1c_start"]
        end_date_names = ["lifedata_pak1a_end","lifedata_pak1b_end","lifedata_pak1c_end"]
        user_id_names = ["lifedata_id1", "lifedata_id1b", "lifedata_id1c"]
    elif type == "intervention":
        start_date_names = ["lifedata_pak2a_start","lifedata_pak2b_start","lifedata_pak2c_start"]
        end_date_names = ["lifedata_pak2a_end","lifedata_pak2b_end","lifedata_pak2c_end"]
        user_id_names = ["lifedata_id2", "lifedata_id2b", "lifedata_id2c_3"]


    filtereddates = (redcap[redcap['pid'] == ppt])

    # Convert userIDs in the filtered DataFrame to strings, remove decimals
    for user_id in user_id_names:
        filtereddates[user_id] = filtereddates[user_id].astype(str).str.replace('.0', '')

    # Remove dates associated with the excluded userIDs
    for i, user_id in enumerate(user_id_names):
        if filtereddates[user_id].iloc[0].strip() in exclude_userIDs_list.values:
            filtereddates[start_date_names[i]] = np.nan
            filtereddates[end_date_names[i]] = np.nan

    # Melt the DataFrame to long format
    dates = pd.melt(filtereddates, id_vars=['pid'], value_vars=start_date_names + end_date_names, var_name='date_type', value_name='date')

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

def merge_geodata(study_period):
    if study_period not in ['baseline', 'intervention']:
        raise ValueError("Invalid argument. It must be either 'baseline' or 'intervention'.")
    
    
    # Specify the folder containing the CSV files
    folder_path = os.path.join("/Volumes/cnlab/GeoRemote/Data/Geodata/clean/",study_period)
    output_path = os.path.join("/Volumes/cnlab/GeoRemote/Data/Geodata/clean/")

    # Initialize an empty DataFrame to store the concatenated data
    all_data = pd.DataFrame()
    filenames = [f for f in os.listdir(folder_path) if not f.startswith('.')]

    # Loop through each file in the folder
    for filename in filenames:
        if filename.endswith('.csv'):
            file_path = os.path.join(folder_path, filename)

            print(extract_participant_id(filename))
            # Read the CSV file into a DataFrame
            try:
                current_data = pd.read_csv(file_path)
                if not current_data.empty:
                    # Concatenate the data to the main DataFrame
                    all_data = pd.concat([all_data, current_data], ignore_index=True)
            except pd.errors.EmptyDataError:
                print(f"The CSV file '{file_path}' is empty or has no columns to parse.")
                continue

    # Output the combined DataFrame to a new CSV file
    output_file = os.path.join(output_path,'merged_' + study_period + '.csv')
    all_data.to_csv(output_file, index=False)

    print(f"Combined data saved to: {output_path}")

def trim_and_save(participant="", overwrite=False):
    timeline_directory = "/Volumes/cnlab/GeoRemote/Timeline/3_S3"
    output_file_path = "/Volumes/cnlab/GeoRemote/Data/Geodata/clean/trimmed_geodata/"

    redcap = loadData("/Volumes/cnlab/GeoRemote/Data/Redcap/clean/","redcap_clean*.csv")
    # Loop through s3 files, use redcap dates to trim the files
    matching_timeline_folders = sorted([folder for folder in os.listdir(timeline_directory) if os.path.isdir(os.path.join(timeline_directory, folder))],reverse=True)
        
    
    for timeline_folder in matching_timeline_folders:
        ppt = extract_participant_id(timeline_folder)

        if participant != "":
            if ppt==participant:
                print(ppt + " started")
                records_file = find_file(os.path.join(timeline_directory,timeline_folder), "Records.json")
                if records_file is not None and os.path.exists(records_file):
                    start_date = datetime.fromisoformat(get_start_date(redcap,ppt)).replace(tzinfo=timezone.utc)
                    if start_date is not None:
                        # set the output path:
                        output_file = os.path.join(output_file_path, ppt + "_geodata.json")
                        filter_and_write_all_geodata(records_file, start_date, output_file)
                        print(ppt + " complete")
                break
            else:
                continue
        # Check if folder is already trimmed
        if ppt is not None:
            if overwrite is False and os.path.exists(output_file_path + ppt + "_geodata.json"):
                    print(ppt + " already completed...")
                    continue
            print(ppt + " started")
            # If not, let's make sure Record.json exists, and the ppt start_date exists in redcap
            records_file = find_file(os.path.join(timeline_directory,timeline_folder), "Records.json")
            if records_file is not None and os.path.exists(records_file):
                start_date = datetime.fromisoformat(get_start_date(redcap,ppt)).replace(tzinfo=timezone.utc)
                if start_date is not None:
                    # set the output path:
                    output_file = os.path.join(output_file_path, ppt + "_geodata.json")
                    filter_and_write_all_geodata(records_file, start_date, output_file)
                    print(ppt + " complete")

    # Loop through s2 files, if status is complete, use redcap dates to trim the files
    timeline_directory = "/Volumes/cnlab/GeoRemote/Timeline/2_S2"
    matching_timeline_folders = sorted([folder for folder in os.listdir(timeline_directory) if os.path.isdir(os.path.join(timeline_directory, folder))],reverse=True)
    
    # skipped_statuses = ['0','1','2','3','4','-1','5.1','5.2','6','8.1','8.2']
    for timeline_folder in matching_timeline_folders:
        ppt = extract_participant_id(timeline_folder)

        # Check if folder is already trimmed
        if ppt is not None:
            if os.path.exists(output_file_path + ppt + "_geodata.json"):
                print(ppt + " already completed...")
                continue
            #   if redcap.loc[redcap['pid'] == ppt, 'study_info_complete'].values[0] != '2':
            #       continue
            print(ppt + " started")
            # If not, let's make sure Record.json exists, and the ppt start_date exists in redcap
            records_file = find_file(os.path.join(timeline_directory,timeline_folder), "Records.json")
            if records_file is not None and os.path.exists(records_file):
                start_date = datetime.fromisoformat(get_start_date(redcap,ppt)).replace(tzinfo=timezone.utc)
                if start_date is not None:
                    # set the output path:
                    output_file = os.path.join(output_file_path, ppt + "_geodata.json")
                    filter_and_write_all_geodata(records_file, start_date, output_file)
                    print(ppt + " complete")
def trim_and_save_by_study_period(study_period, participant = ""):
    if study_period not in ['baseline', 'intervention']:
        raise ValueError("Invalid argument. It must be either 'baseline' or 'intervention'.")

    timeline_directory = "/Volumes/cnlab/GeoRemote/Data/Geodata/clean/trimmed_geodata/"
    output_file_path = os.path.join("/Volumes/cnlab/GeoRemote/Data/Geodata/clean/",study_period)
    create_directory(output_file_path)
    print("Loading redcap")
    redcap = loadData("/Volumes/cnlab/GeoRemote/Data/Redcap/clean/","redcap_clean*.csv")
    print("Loaded!")
    list_files_in_folder = lambda folder_path: [item for item in os.listdir(folder_path) if os.path.isfile(os.path.join(folder_path, item)) and item.endswith('.json') and not item.startswith('.')]
    files_in_folder = sorted(list_files_in_folder(timeline_directory))    
    exclude_userIDs = loadData("/Volumes/cnlab/GeoRemote/Data/Lifedata/utility", "lifepack_ids_to_remove.csv")

    if participant != "":
        ppt = participant
        output_file = os.path.join(output_file_path, ppt + "_" + study_period + "_geodata.csv")
        geodata_file = find_file(timeline_directory,ppt + "_geodata.json")
        if geodata_file is not None and os.path.exists(geodata_file):
            dates = get_dates(redcap,ppt, study_period, exclude_userIDs)
            if dates is not None:
                # set the output path:
                print(ppt + " started")
                filter_and_write_geodata_by_study_period(geodata_file, dates, output_file,chunk_size=20000)
                print(ppt + " complete")
    else:
        for timeline_folder in files_in_folder:
            ppt = extract_participant_id(timeline_folder)
            output_file = os.path.join(output_file_path, ppt + "_" + study_period + "_geodata.csv")
            # Check if folder is already trimmed
            if ppt is not None:
                # if os.path.exists(output_file):
                #     print(ppt + " already completed...")
                #     continue
                # If not, let's make sure Record.json exists, and the ppt start_date exists in redcap
                geodata_file = find_file(timeline_directory,ppt + "_geodata.json")

                if geodata_file is not None and os.path.exists(geodata_file):
                    dates = get_dates(redcap,ppt, study_period, exclude_userIDs)
                    if dates is not None:
                        # set the output path:
                        print(ppt + " started")
                        filter_and_write_geodata_by_study_period(geodata_file, dates, output_file,chunk_size=20000)
                        print(ppt + " complete")
