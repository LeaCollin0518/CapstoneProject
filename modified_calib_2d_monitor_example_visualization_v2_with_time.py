"""Run ensemble model on Annual 2010 Data.

Please open a data directory according to the directory
specified in _DATA_ADDR_PREFIX,
and place both training data and validation data there.

"""
import os
import time

from importlib import reload

import pickle as pk
import pandas as pd

import numpy as np
from scipy.stats import norm as norm_dist

from sklearn.cluster import KMeans
from sklearn.isotonic import IsotonicRegression
from sklearn.model_selection import KFold

import tensorflow as tf
import tensorflow_probability as tfp
from tensorflow_probability import edward2 as ed

#sys.path.extend([os.getcwd()])

from calibre.model import gaussian_process as gp
from calibre.model import tailfree_process as tail_free
from calibre.model import gp_regression_monotone as gpr_mono
from calibre.model import adaptive_ensemble

from calibre.inference import mcmc

from calibre.calibration import score

import calibre.util.misc as misc_util
import calibre.util.metric as metric_util
import calibre.util.visual as visual_util
import calibre.util.matrix as matrix_util
import calibre.util.ensemble as ensemble_util
import calibre.util.calibration as calib_util

import calibre.util.experiment_pred as pred_util

from calibre.util.inference import make_value_setter

import matplotlib.pyplot as plt
import seaborn as sns

os.environ['TF_CPP_MIN_LOG_LEVEL'] = '3'


_DATA_ADDR_PREFIX = "./example/data_with_time"

_SAVE_ADDR_PREFIX = "./result_ca_2010_with_time/modified_calibre_2d_annual_pm25_example_ca_2005_2011"

_MODEL_DICTIONARY = {"root": ["AV", "GB", "GM"]}

family_name = "hmc"

"""""""""""""""""""""""""""""""""
# 0. Prepare data
"""""""""""""""""""""""""""""""""

""" 0. prepare training data dictionary """
y_obs_2010 = pd.read_csv("{}/training_clean_2005_2011.csv".format(_DATA_ADDR_PREFIX))

X_train = np.asarray(y_obs_2010[["lon", "lat", "time"]].values.tolist()).astype(np.float32)

base_train_feat = dict()

for model_name in tail_free.get_leaf_model_names(_MODEL_DICTIONARY):
    base_train_feat[model_name] = X_train
   

""" 1. prepare prediction data dictionary """
base_valid_feat = dict()


for model_name in tail_free.get_leaf_model_names(_MODEL_DICTIONARY):
    data_pd = pd.read_csv("{}/{}_2005_2011_align.csv".format(
        _DATA_ADDR_PREFIX, model_name))
    base_valid_feat[model_name] = np.asarray(data_pd[["lon", "lat","time"]].values.tolist()).astype(np.float32)
 
X_valid = base_valid_feat[model_name]

""" 3. standardize data """
# standardize
X_centr = np.mean(X_valid, axis=0)
X_scale = np.max(X_valid, axis=0) - np.min(X_valid, axis=0)

X_scale_dist = np.max(X_scale[0:1])
X_scale[0] = X_scale_dist
X_scale[1] = X_scale_dist

#X_valid = (X_valid - X_centr) / X_scale
X_train = (X_train - X_centr) / X_scale


"""""""""""""""""""""""""""""""""
# 3. Visualization
"""""""""""""""""""""""""""""""""

print('now in visualization!')

""" 3.1. prep: load data, compute posterior mean/sd, color config """


#To load from pickle file

def load_pk(file_name):
  data = []

  for i in range(1, 46):

    with open(_SAVE_ADDR_PREFIX+ '/hmc'+str(i)+'/'+file_name, 'rb') as f:
        try:
            while True:
                data.append(pk.load(f))
        except EOFError:
            pass
  return data 
  
def get_overlapping_average(a):
    df = pd.DataFrame(a)
    out = df.groupby([0, 1, 2]).mean().reset_index()
    return out.values

ensemble_sample_val_mean = get_overlapping_average(np.concatenate(load_pk('ensemble_sample_val_mean.pkl'), axis=0))

#print(ensemble_sample_val_mean.shape) 
#(723716, 4)
#the 3rd column should be time
#print(ensemble_sample_val_mean)


ensemble_mean_val_mean = get_overlapping_average(np.concatenate(load_pk('ensemble_mean_val_mean.pkl'), axis=0))
mean_resid = get_overlapping_average(np.concatenate(load_pk('mean_resid.pkl'), axis=0))

ensemble_sample_val_var = get_overlapping_average(np.concatenate(load_pk('ensemble_sample_val_var.pkl'), axis=0))
ensemble_mean_val_var = get_overlapping_average(np.concatenate(load_pk('ensemble_mean_val_var.pkl'), axis=0))
uncn_resid = get_overlapping_average(np.concatenate(load_pk('uncn_resid.pkl'), axis=0))
uncn_noise = get_overlapping_average(np.concatenate(load_pk('uncn_noise.pkl'), axis=0))

ensemble_weights_val = get_overlapping_average(np.concatenate(load_pk('ensemble_weights_val.pkl'), axis=0))


def filter_year(df, year):
    return df[np.where(df[:, 2]==year)]

#get unique years 
years = set(ensemble_sample_val_mean[:, 2])

for year in years:
    
    _SAVE_ADDR_PREFIX_curr = _SAVE_ADDR_PREFIX +'/'+str(int(year))
    
    #getting the re-ordered lat and lon
    X_valid_reordered = filter_year(ensemble_sample_val_mean, year)[:, :3]
    X_valid_reordered = (X_valid_reordered - X_centr) / X_scale
    X_valid_reordered_locations = X_valid_reordered[:, :2]
    #(723716, 2)

    print(X_valid_reordered_locations.shape)

    
    post_mean_dict = {
        "overall": filter_year(ensemble_sample_val_mean, year)[:, 3],
        "mean": filter_year(ensemble_mean_val_mean, year)[:, 3],
        "resid": filter_year(mean_resid, year)[:, 3]
    }

    post_uncn_dict = {
        "overall": filter_year(ensemble_sample_val_var, year)[:, 3],
        "mean": filter_year(ensemble_mean_val_var, year)[:, 3],
        "resid": filter_year(uncn_resid, year)[:, 3],
        "noise": filter_year(uncn_noise, year)[:, 3]
    }


    weights_dict = {}
    model_names = _MODEL_DICTIONARY['root']
    
    for i in range(len(model_names)): 
      weights_dict[model_names[i]] = filter_year(ensemble_weights_val, year)[:, i+3]
        


    # prepare color norms for plt.scatter
    color_norm_unc = visual_util.make_color_norm(
        list(post_uncn_dict.values())[:1],  # use "overall" and "mean" for pal
        method="percentile")

    #print(color_norm_unc)

    color_norm_ratio = visual_util.make_color_norm(
        post_uncn_dict["noise"] / post_uncn_dict["overall"],
        method="percentile")
    color_norm_pred = visual_util.make_color_norm(
        list(post_mean_dict.values())[:2],  # exclude "resid" vales from pal
        method="percentile")

    """ 3.1. posterior predictive uncertainty """
    for unc_name, unc_value in post_uncn_dict.items():
        save_name = os.path.join(_SAVE_ADDR_PREFIX_curr,
                                 '{}/ensemble_posterior_uncn_{}.png'.format(
                                     family_name, unc_name))

        color_norm = visual_util.posterior_heatmap_2d(unc_value,
                                                      X=X_valid_reordered_locations, X_monitor=X_train,
                                                      cmap='inferno_r',
                                                      norm=color_norm_unc,
                                                      norm_method="percentile",
                                                      save_addr=save_name)

    """ 3.2. posterior predictive mean """
    for mean_name, mean_value in post_mean_dict.items():
        save_name = os.path.join(_SAVE_ADDR_PREFIX_curr,
                                 '{}/ensemble_posterior_mean_{}.png'.format(
                                     family_name, mean_name))
        color_norm = visual_util.posterior_heatmap_2d(mean_value,
                                                      X=X_valid_reordered_locations, X_monitor=X_train,
                                                      cmap='RdYlGn_r',
                                                      norm=color_norm_pred,
                                                      norm_method="percentile",
                                                      save_addr=save_name)



    """ 3.3. model weights """
    # prepare color norms for plt.scatter
    color_norm_weights = visual_util.make_color_norm(
        list(weights_dict.values())[:1],  
        method="percentile")

    for model_name, model_weight in weights_dict.items():
        save_name = os.path.join(_SAVE_ADDR_PREFIX_curr,
                                 '{}/ensemble_weights_val_{}.png'.format(
                                     family_name, model_name))

        color_norm = visual_util.posterior_heatmap_2d(model_weight,
                                                      X=X_valid_reordered_locations, X_monitor=X_train,
                                                      cmap='viridis',
                                                      norm=color_norm_weights,
                                                      norm_method="percentile",
                                                      save_addr=save_name)

