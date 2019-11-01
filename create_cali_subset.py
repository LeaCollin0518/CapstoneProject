#!/usr/bin/env python
# coding: utf-8

import gc
import pandas as pd
import numpy as np
import os
import pickle as pk

training_data = pd.read_csv('./Data/cali_example/training_data_2010.csv', usecols = [1, 2, 3, 4, 5, 6])
av = pd.read_csv('./Data/cali_example/AV_2010_align.csv', usecols = [1,2,3])
gm = pd.read_csv('./Data/cali_example/GM_2010_align.csv', usecols = [1,2,3])
gs = pd.read_csv('./Data/cali_example/GS_2010_align.csv', usecols = [1,2,3])

training_data = training_data[~training_data['pred_GS'].isnull()]

av_ = av[~av['pm25'].isnull()]
gs_ = gs[~gs['pm25'].isnull()]

indices = list(set(av_.index) & set(gs_.index))

av = av.loc[indices]
gm = gm.loc[indices]
gs = gs.loc[indices]

print(av.shape)

# training_data.to_csv('./Cali_Example/example/data/training_data_2010.csv', index = False)
# av.to_csv('./Cali_Example/example/data/AV_2010_align.csv')
# gm.to_csv('./Cali_Example/example/data/GM_2010_align.csv')
# gs.to_csv('./Cali_Example/example/data/GS_2010_align.csv')


### Create file to visualize BNE predictions
num_mcmc = 5000

_SAVE_ADDR_PREFIX = "./Cali_Example/result_ca_2010_allsubsegments/calibre_2d_annual_pm25_example_ca_2010"
family_name = 'hmc'

ensemble_mean_val = []
ensemble_sample_val = []

sub_segs = 4

for i in range(sub_segs):
    print (i)
    with open(os.path.join(_SAVE_ADDR_PREFIX,
                           '{}/ensemble_posterior_pred_mean_sample_{}.pkl'.format(family_name, i)), 'rb') as file:
        ensemble_mean_val.append(pk.load(file))

    with open(os.path.join(_SAVE_ADDR_PREFIX,
                           '{}/ensemble_posterior_pred_dist_sample_{}.pkl'.format(family_name, i)), 'rb') as file:
        ensemble_sample_val.append(pk.load(file))


num_coords = ensemble_sample_val[0].shape[0]*sub_segs

sample_val = np.stack(ensemble_sample_val, axis = 0).reshape(num_coords, num_mcmc)
mean_val = np.stack(ensemble_mean_val, axis = 0).reshape(num_coords, num_mcmc)

print(sample_val.shape)

# with open(os.path.join(_SAVE_ADDR_PREFIX,
#                        '{}/ensemble_posterior_pred_dist_sample.pkl'.format(family_name)), 'wb') as file:
#     pk.dump(sample_val, file, protocol=pk.HIGHEST_PROTOCOL)
# with open(os.path.join(_SAVE_ADDR_PREFIX,
#                        '{}/ensemble_posterior_pred_mean_sample.pkl'.format(family_name)), 'wb') as file:
#     pk.dump(mean_val, file, protocol=pk.HIGHEST_PROTOCOL)


# post_mean_dict = {
#     "overall": np.mean(sample_val, axis=1),
#     "mean": np.mean(mean_val, axis=1)
#     "resid": np.mean(sample_val - mean_val, axis=1)
# }

# av_sub = av.iloc[:sample_val.shape[0]]
# av_sub = av_sub.drop(['pm25'], axis = 1)

# av_sub['mean_overall'] = post_mean_dict['overall']
# av_sub['mean_mean'] = post_mean_dict['mean']

# del sample_val
# del mean_val

# av_sub.to_csv('./Data/cali_example/model_predictions_subseg.csv', index = False)