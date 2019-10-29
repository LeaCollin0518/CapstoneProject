import gc
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

_DATA_ADDR_PREFIX = "./example/data"

_SAVE_ADDR_PREFIX_SUB = "./result_ca_2010_run2/calibre_2d_annual_pm25_example_ca_2010"
_SAVE_ADDR_PREFIX = "./result_ca_2010_allsubsegments/calibre_2d_annual_pm25_example_ca_2010"

_MODEL_DICTIONARY = {"root": ["AV", "GM", "GS"]}

DEFAULT_LOG_LS_WEIGHT = np.log(0.35).astype(np.float32)
DEFAULT_LOG_LS_RESID = np.log(0.1).astype(np.float32)

y_obs_2010 = pd.read_csv("{}/training_data_2010.csv".format(_DATA_ADDR_PREFIX))
X_train = np.asarray(y_obs_2010[["lon", "lat"]].values.tolist()).astype(np.float32)

""" 1. prepare prediction data dictionary """
base_valid_feat = dict()
base_valid_pred = dict()
for model_name in tail_free.get_leaf_model_names(_MODEL_DICTIONARY):
    data_pd = pd.read_csv("{}/{}_2010_align.csv".format(
        _DATA_ADDR_PREFIX, model_name))
    base_valid_feat[model_name] = np.asarray(data_pd[["lon", "lat"]].values.tolist()).astype(np.float32)
    base_valid_pred[model_name] = np.asarray(data_pd["pm25"].tolist()).astype(np.float32)

X_valid = base_valid_feat[model_name]
X_valid = X_valid[:120620]
N_pred = X_valid.shape[0]

# standardize
X_centr = np.mean(X_valid, axis=0)
X_scale = np.max(X_valid, axis=0) - np.min(X_valid, axis=0)

X_valid = (X_valid - X_centr) / X_scale
X_train = (X_train - X_centr) / X_scale



family_name = "hmc"
family_name_full = "Hamilton MC"

""" 3.1. prep: load data, compute posterior mean/sd, color config """
# with open(os.path.join(_SAVE_ADDR_PREFIX,
#                        '{}/ensemble_posterior_pred_dist_sample.npy'.format(family_name)), 'rb') as file:
#     ensemble_sample_val = pk.load(file)
# with open(os.path.join(_SAVE_ADDR_PREFIX,
#                        '{}/ensemble_posterior_pred_mean_sample.npy'.format(family_name)), 'rb') as file:
#     ensemble_mean_val = pk.load(file)
# with open(os.path.join(_SAVE_ADDR_PREFIX,
#                        '{}/ensemble_posterior_sigma_sample.pkl'.format(family_name)), 'rb') as file:
#     sigma_sample_val = pk.load(file)

# post_uncn_dict = {
#     "overall": np.var(ensemble_sample_val, axis=1) + np.mean(np.exp(2 * sigma_sample_val)),
#     "mean": np.var(ensemble_mean_val, axis=1),
#     "resid": np.var(ensemble_sample_val - ensemble_mean_val, axis=1),
#     "noise": np.mean(np.exp(2 * sigma_sample_val)) * np.ones(shape=(ensemble_sample_val.shape[0]))
# }

# print (post_mean_sub_dict['overall'])

# ensemble_sample_val = np.load(_SAVE_ADDR_PREFIX + '/{}/ensemble_posterior_pred_dist_sample.npy'.format(family_name))
# ensemble_mean_val = np.load(_SAVE_ADDR_PREFIX + '/{}/ensemble_posterior_pred_mean_sample.npy'.format(family_name))

print("Loading sample")
with open(os.path.join(_SAVE_ADDR_PREFIX,
                       '{}/ensemble_posterior_pred_dist_sample.pkl'.format(family_name)), 'rb') as file:
    ensemble_sample_val = pk.load(file)

print("Loading mean")
with open(os.path.join(_SAVE_ADDR_PREFIX,
                       '{}/ensemble_posterior_pred_mean_sample.pkl'.format(family_name)), 'rb') as file:
    ensemble_mean_val = pk.load(file)

post_mean_dict = {
    "overall": np.mean(ensemble_sample_val, axis=1),
    "mean": np.mean(ensemble_mean_val, axis=1),
    "resid": np.mean(ensemble_sample_val - ensemble_mean_val, axis=1)
}


color_norm_pred = visual_util.make_color_norm(
    list(post_mean_dict.values())[:2],  # exclude "resid" vales from pal
    method="percentile")

print ("Plots")
""" 3.2. posterior predictive mean """
for mean_name, mean_value in post_mean_dict.items():
    save_name = os.path.join(_SAVE_ADDR_PREFIX,
                             '{}/ensemble_posterior_mean_{}.png'.format(
                                 family_name, mean_name))
    color_norm = visual_util.posterior_heatmap_2d(mean_value,
                                                  X=X_valid, 
                                                  cmap='RdYlGn_r',
                                                  norm=color_norm_pred,
                                                  norm_method="percentile",
                                                  save_addr=save_name)