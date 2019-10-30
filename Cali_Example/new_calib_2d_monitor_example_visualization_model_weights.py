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


_DATA_ADDR_PREFIX = "./example/data"

_SAVE_ADDR_PREFIX = "./result_ca_2010/new_calibre_2d_annual_pm25_example_ca_2010"

_MODEL_DICTIONARY = {"root": ["AV_subset", "GS_subset", 'GM_subset']}

family_name = "hmc"

"""""""""""""""""""""""""""""""""
# 0. Prepare data
"""""""""""""""""""""""""""""""""

""" 0. prepare training data dictionary """
y_obs_2010 = pd.read_csv("{}/training_data_subset_2010.csv".format(_DATA_ADDR_PREFIX))

X_train = np.asarray(y_obs_2010[["lon", "lat"]].values.tolist()).astype(np.float32)

base_train_feat = dict()

for model_name in tail_free.get_leaf_model_names(_MODEL_DICTIONARY):
    base_train_feat[model_name] = X_train
   

""" 1. prepare prediction data dictionary """
base_valid_feat = dict()


for model_name in tail_free.get_leaf_model_names(_MODEL_DICTIONARY):
    data_pd = pd.read_csv("{}/{}_2010_align.csv".format(
        _DATA_ADDR_PREFIX, model_name))
    base_valid_feat[model_name] = np.asarray(data_pd[["lon", "lat"]].values.tolist()).astype(np.float32)
 
X_valid = base_valid_feat[model_name]

""" 3. standardize data """
# standardize
X_centr = np.mean(X_valid, axis=0)
X_scale = np.max(X_valid, axis=0) - np.min(X_valid, axis=0)

X_valid = (X_valid - X_centr) / X_scale
X_train = (X_train - X_centr) / X_scale


"""""""""""""""""""""""""""""""""
# 3. Visualization
"""""""""""""""""""""""""""""""""

#get weights
with open('result_ca_2010/new_calibre_2d_annual_pm25_example_ca_2010/hmc/'+ \
'ensemble_weights_val.pkl', 'rb') as f:
    ensemble_weights = pk.load(f)

weights = np.mean(ensemble_weights, axis=0)


weights_dict = {
    "AV": weights[:, 0],
    "GS": weights[:, 1],
    "GM": weights[:, 2],
}


# prepare color norms for plt.scatter
color_norm_weights = visual_util.make_color_norm(
    list(weights_dict.values())[:1],  
    method="percentile")

for model_name, model_weight in weights_dict.items():
    save_name = os.path.join(_SAVE_ADDR_PREFIX,
                             '{}/ensemble_weights_val_{}.png'.format(
                                 family_name, model_name))

    color_norm = visual_util.posterior_heatmap_2d(model_weight,
                                                  X=X_valid, X_monitor=X_train,
                                                  cmap='viridis',
                                                  norm=color_norm_weights,
                                                  norm_method="percentile",
                                                  save_addr=save_name)

