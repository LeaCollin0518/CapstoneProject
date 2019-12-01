#!/usr/bin/env python

import pandas as pd
import numpy as np
import math


# # Nationwide

# In[2]:


data_dir = '../Data/nationwide/'
save_dir = '../Data/nationwide_subsets_v3/'


intersecting_av_gbd_scott = pd.read_csv('{}predictions_2010_2016.csv'.format(data_dir))

one_year = intersecting_av_gbd_scott.loc[intersecting_av_gbd_scott.time == 2010]

min_lon = min(one_year.lon)
max_lon = max(one_year.lon)
min_lat = min(one_year.lat)
max_lat = max(one_year.lat)

X_valid = np.asarray(one_year[["lon", "lat"]].values.tolist()).astype(np.float32)
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

lon_range, lat_range = get_splits(X_valid, 50)


intersecting_av_gbd_scott = intersecting_av_gbd_scott[['lon', 'lat', 'time', 'pred_AV', 'pred_SC', 'pred_GS', 'pred_CM']]

full_data = pd.DataFrame(columns=['lon', 'lat', 'time', 'pred_AV', 'pred_SC', 'pred_GS', 'pred_CM'])
model = intersecting_av_gbd_scott
all_models = ['AV', 'SC', 'GS', 'CM']
subset_num = 0
subset_shapes = []

most_recent_subset = pd.DataFrame(columns=['lon', 'lat', 'pred_AV', 'pred_SC', 'pred_GS', 'pred_CM'])

for i in range(len(lat_range)):
    for j in range(len(lon_range)):
        df_subset = model.loc[(model.lon >= lon_range[j][0]) & (model.lon <= lon_range[j][1]) & (model.lat >= lat_range[i][0]) & (model.lat <= lat_range[i][1])]
        df_subset = df_subset[['lon', 'lat', 'time', 'pred_AV', 'pred_SC', 'pred_GS', 'pred_CM']]
        if (df_subset.shape[0] != 0):
            if (df_subset.shape[0] > 800):
                most_recent_subset = df_subset
                print (most_recent_subset.shape)
                full_data = full_data.append(most_recent_subset)
                subset_shapes.append(most_recent_subset.shape[0])
                subset_num += 1
                for m in all_models:
                    pred_name = 'pred_{}'.format(m)
                    pred_subset = most_recent_subset[['lon', 'lat', 'time', pred_name]]
                    print (pred_subset.columns)
                    pred_subset = pred_subset.rename(columns={pred_name: "pm25"})
                    print (pred_subset.columns)
                    new_file = '{}{}_2010_2016_align.{}.csv'.format(save_dir, m, subset_num)
                    print (new_file)
                    # print (pred_subset.head())
                    pred_subset.to_csv(new_file, index = False)
            else:
                print ("DF Subset: " + str(df_subset.shape))
                most_recent_subset = most_recent_subset.append(df_subset)
                print (most_recent_subset.shape)
                subset_shapes.pop()
                subset_shapes.append(most_recent_subset.shape[0])
                full_data = full_data.append(most_recent_subset)
                for m in all_models:
                    pred_name = 'pred_{}'.format(m)
                    pred_subset = most_recent_subset[['lon', 'lat', 'time', pred_name]]
                    pred_subset = pred_subset.rename(columns={pred_name: "pm25"})
                    print (pred_subset.columns)
                    new_file = '{}{}_2010_2016_align.{}.csv'.format(save_dir, m, subset_num)
                    print (new_file)
                    # print (pred_subset.head())
                    pred_subset.to_csv(new_file, index = False) 



print (len(subset_shapes))
print (np.min(subset_shapes))

full_data.drop_duplicates(inplace = True)
# print (av_2010_2016.shape[0]/7)
print (full_data.shape)


# # 1605 subsets or 1590?
