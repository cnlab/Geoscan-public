# geo_codebase
This is a folder of scripts developed by Michael Fichman to process and analyze geodata

# Redcap
To quickly pull in redcap data to your R script, do the following
```
source("YOUR_PATH_TO/geo_redcap.r")
redcap_df <- load_redcap_data()
```

You can also run get_redcap_data(download=TRUE) to download the latest copy of data from redcap. Since the files are saved with the date they were downloaded from, it will be easier to use the load function instead of loading it directly. Currently there is minimal cleaning done to the redcap data, mainly we try to remove PII using GeoRemote/Data/Redcap/include_vars.csv to only select the variables in that csv. 

# Lifedata
To quickly load the geoscan data into your script, do the following:
```
source("YOUR_PATH_TO/geo_lifedata.r")
lifedata_df <- get_clean_lifedata()
```

To create a new copy of cleaned lifedata, run 'create_master_lifedata()'. This is useful if the redcap data is updated.

## Lifedata Cleaning Steps
1. get_raw_lifedata(path="LifeData_NIS", pattern="*.csv") -> Looks into "GeoRemote/Data/LifeData/raw/{path}"
    - Will load all files that follow the pattern recursively (looks into each folder) and merges everything into a single database. Expects the files to have the same number of columns.
2. remove_lifedata_columns()
    - Removes some identifying information ("GPS Latitude", "GPS Longitude", "Device ID")
3. Separates lifepack userid and surveyid into their own columns
4. get_lifepack_info -> loads Data/Lifedata/utility/lifepack_ids.csv
5. add_pid_and_lifepack_info(lifedata, lifepack_ids, redcap)
    - Uses the lifepack info and redcap data to add pids, semantic names of lifepacks, conditions of lifepacks, and type (baseline, control, intervention) to ema data
    - Also looks through all the lifepak ids that a user might have and adds the pid to each of those lifepak userids.

- *Note* Use the commented code ```sort(unique(df$userID[df$pid==""]))``` to check if ema data is missing a pid.

6. remove_lifepack_ids() 
    - This uses Data/Lifedata/utility/lifepack_ids_to_remove.csv to remove data that matches the userid within that csv.
    - If you discover a userid missing a pid that was, for example, testing data, or a lifepak that a ppt never used, add them to this file to remove them from the cleaned data.

7. separate_reset_packs
    - This looks at reset paks and determines if they are for the baseline or control period, and updates accordingly

8. save_lifedata
    - This will not only save a new copy of cleaned lifedata with the date created, it will move the previous copy into the archive folder. 