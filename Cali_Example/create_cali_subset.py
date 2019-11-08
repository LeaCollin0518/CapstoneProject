#!/usr/bin/env python

import pandas as pd
import numpy as np
import os
import pickle as pk
from collections import defaultdict

av = pd.read_csv('./Cali_Example/example/data/AV_2010_align.csv')


_SAVE_ADDR_PREFIX = "./Cali_Example/result_ca_2010_all_subsegments/calibre_2d_annual_pm25_example_ca_2010"
family_name = 'hmc'

ensemble_mean_val = []
ensemble_uncn_val = []

num_subsegs = 30

for i in range(num_subsegs):
    print (i)
    with open(os.path.join(_SAVE_ADDR_PREFIX,
                           '{}/ensemble_mean_dict_{}.pkl'.format(family_name, i)), 'rb') as file:
        ensemble_mean_val.append(pk.load(file))
        

    with open(os.path.join(_SAVE_ADDR_PREFIX,
                           '{}/ensemble_uncn_dict_{}.pkl'.format(family_name, i)), 'rb') as file:
        ensemble_uncn_val.append(pk.load(file))

num_coords = 0
mean_dict = defaultdict()
unc_dict = defaultdict()

for i in range(num_subsegs):
    num_coords += ensemble_mean_val[i]['overall'].shape[0]

post_mean_dict = {'overall': None, 'mean': None, 'resid': None}
post_uncn_dict = {'overall': None, 'mean': None, 'resid': None, 'noise': None}

for key in post_mean_dict:
    post_mean_dict[key] = np.concatenate([ensemble_mean_val[i][key] for i in range(num_subsegs)], axis = None).reshape(num_coords)

for key in post_uncn_dict:
    post_uncn_dict[key] = np.concatenate([ensemble_uncn_val[i][key] for i in range(num_subsegs)], axis = None).reshape(num_coords)

with open(os.path.join(_SAVE_ADDR_PREFIX,
                       '{}/ensemble_mean_dict.pkl'.format(family_name)), 'wb') as file:
    pk.dump(post_mean_dict, file, protocol=pk.HIGHEST_PROTOCOL)
with open(os.path.join(_SAVE_ADDR_PREFIX,
                       '{}/ensemble_uncn_dict.pkl'.format(family_name)), 'wb') as file:
    pk.dump(post_uncn_dict, file, protocol=pk.HIGHEST_PROTOCOL)

av_sub = av.iloc[:num_coords]
av_sub = av_sub.drop(['pm25'], axis = 1)

locations = av_sub[['lat', 'lon']]
locations['mean_overall'] = post_mean_dict['overall']
locations['mean_mean'] = post_mean_dict['mean']

locations.to_csv('./Cali_Example/example/data/model_predictions_sub.csv', index = False)
