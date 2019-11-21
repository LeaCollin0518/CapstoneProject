#!/usr/bin/env python
# coding: utf-8

import pandas as pd
import numpy as np
import math

# Nationwide

data_dir = '../Data/nationwide/'
save_dir = '../Data/nationwide_subsets/'

av_2004 = pd.read_csv(data_dir + 'AV_2004_align.csv')

min_lon = min(av_2004.lon)
max_lon = max(av_2004.lon)
min_lat = min(av_2004.lat)
max_lat = max(av_2004.lat)

X_valid = np.asarray(av_2004[["lon", "lat"]].values.tolist()).astype(np.float32)
X_scale = np.max(X_valid, axis=0) - np.min(X_valid, axis=0)

def round_nearest(x, a):
    return round(round(x / a) * a, -int(math.floor(math.log10(a))))

def round_location(locations):
    round_loc = [round_nearest(x, 0.005) for x in locations]
    round_loc = [x + 0.005 if (str(x)[-1] != '5' or len(str(x).split('.')[1]) !=  3) else x for x in round_loc]
    round_loc =  [round(x, -int(math.floor(math.log10(0.005)))) for x in round_loc]
    return round_loc

def get_splits(X_val, num_splits):
    split_range = [X_scale[0]/num_splits, X_scale[1]/num_splits]
    split_range = [round(elem, 4) for elem in split_range ]
    split_lon_range = split_range[0]
    split_lat_range = split_range[1]

    start_split_lon = []
    for i in range(num_splits):
        start_split_lon.append(min_lon + i*split_lon_range)

    start_split_lat = []
    for i in range(num_splits):
        start_split_lat.append(min_lat + i*split_lat_range)

    start_split_lon = round_location(start_split_lon)
    start_split_lat = round_location(start_split_lat)
    
    end_split_lon = start_split_lon[1:]
    end_split_lon.append(max_lon)
    start_split_lon = [x - 0.5 for x in start_split_lon[1:]]
    start_split_lon.insert(0, min_lon)

    end_split_lat = start_split_lat[1:]
    end_split_lat.append(max_lat)
    start_split_lat = [x - 0.5 for x in start_split_lat[1:]]
    start_split_lat.insert(0, min_lat)
    
    lon_range = list(zip(start_split_lon, end_split_lon))
    lat_range = list(zip(start_split_lat, end_split_lat))
    
    return lon_range, lat_range

lon_range, lat_range = get_splits(X_valid, 49)

av_2010_2016 = pd.DataFrame(columns=['lon', 'lat', 'pm25', 'time'])
for i in range(2010, 2017):
    av_file_name = '{}AV_{}_align.csv'.format(data_dir, i)
    av_i = pd.read_csv(av_file_name)
    time_i = np.repeat(i, av_i.shape[0])
    av_i['time'] = time_i
    av_2010_2016 = av_2010_2016.append(av_i)

av_2010_2016 = av_2010_2016.loc[av_2010_2016.pm25 != -999.99]

full_data = pd.DataFrame(columns=['lon', 'lat', 'pm25', 'time'])
model = av_2010_2016
subset_num = 0

for i in range(len(lat_range)):
    for j in range(len(lon_range)):
        df_subset = model.loc[(model.lon >= lon_range[j][0]) & (model.lon <= lon_range[j][1]) & (model.lat >= lat_range[i][0]) & (model.lat <= lat_range[i][1])]
        df_subset = df_subset[['lon', 'lat', 'pm25', 'time']]
        if (df_subset.shape[0] != 0):
            full_data = full_data.append(df_subset)
            subset_num += 1
            new_file = '{}AV_2010_2016_align.{}.csv'.format(save_dir, subset_num)
            print (new_file)
            df_subset.to_csv(new_file, index = False)


full_data.drop_duplicates(inplace = True)
print (av_2010_2016.shape[0]/7)
print (full_data.shape[0]/7)

# 1605 subsets