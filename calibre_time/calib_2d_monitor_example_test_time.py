#!/usr/bin/env python
# coding: utf-8

# In[1]:


"""Run ensemble model on Annual 2011 Data.

Please open a data directory according to the directory
specified in _DATA_ADDR_PREFIX,
and place both training data and validation data there.

"""
import os
import time
import sys

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

# sys.path.extend([os.getcwd()])

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

from calib_2d_model_time import time_model

os.environ['TF_CPP_MIN_LOG_LEVEL'] = '3'

# Supress TF warnings
tf.logging.set_verbosity(tf.logging.ERROR)

_DATA_ADDR_PREFIX = "./example/data"
_SAVE_ADDR_PREFIX = "./result/calibre_2d_annual_pm25_example"

_MODEL_DICTIONARY = {"root": ["IK", "QD", "AV"]}


from sklearn.model_selection import KFold

""" 0. Read in all data"""

y_obs_2011 = pd.read_csv("{}/training_data_2010_monthly.csv".format(_DATA_ADDR_PREFIX))

X_all = np.asarray(y_obs_2011[["lon", "lat", "time"]].values.tolist()).astype(np.float32)
y_all = np.asarray(y_obs_2011["pm25_obs"].tolist()).astype(np.float32)


""" 1. standardize data """

X_centr = np.mean(X_all, axis=0)
X_scale = np.max(X_all, axis=0) - np.min(X_all, axis=0)

X_scale_dist = np.max(X_scale[0:1])
X_scale[0] = X_scale_dist
X_scale[1] = X_scale_dist

X_all = (X_all - X_centr) / X_scale

# X_all[:, 0] = 0.5 # Arbitrarily setting lon and lat to the same value should make this a 1D regression in which time is the only thing that matters
# X_all[:, 1] = 0.5 # (need to think about this a bit more)

def CV_timescale(X, y, y_obs, vals):
  kf = KFold(n_splits=5, shuffle=True, random_state=49)
  param_scores = []
  # Iterate through parameters
  count = 0
  n_vals = len(vals)
  for v in vals:
    # Set paramters
    DEFAULT_LOG_LS_WEIGHT_XY = np.log(0.35).astype(np.float32)
    DEFAULT_LOG_LS_RESID_XY = np.log(0.1).astype(np.float32)

    # TUNING THESE PARAMS
    DEFAULT_LOG_LS_WEIGHT_T = v[0].astype(np.float32)
    DEFAULT_LOG_LS_RESID_T = v[1].astype(np.float32)

    DEFAULT_LOG_LS_WEIGHT = np.array([DEFAULT_LOG_LS_WEIGHT_XY,
                                      DEFAULT_LOG_LS_WEIGHT_XY,
                                      DEFAULT_LOG_LS_WEIGHT_T])
    DEFAULT_LOG_LS_RESID = np.array([DEFAULT_LOG_LS_RESID_XY,
                                      DEFAULT_LOG_LS_RESID_XY,
                                      DEFAULT_LOG_LS_RESID_T])
    cross_val_score = []
    # Iterate through folds to prevent overfitting validation set
    for train_idx, test_idx in kf.split(X):

      X_train, X_test = X[train_idx], X[test_idx]
      y_train, y_test = y[train_idx], y[test_idx]
      y_obs_train, y_obs_test = y_obs.iloc[train_idx,], y_obs.iloc[test_idx,]

      base_train_pred = dict()
      base_test_pred = dict()
      for model_name in tail_free.get_leaf_model_names(_MODEL_DICTIONARY):
          base_train_pred[model_name] = y_obs_train["pred_{}".format(model_name)].astype(np.float32)
          base_test_pred[model_name] = y_obs_test["pred_{}".format(model_name)].astype(np.float32)

      """ run model """
      squared_loss = time_model(X_train, X_test,
                                y_train, y_test,
                                base_train_pred,
                                base_test_pred,
                                _MODEL_DICTIONARY,
                                DEFAULT_LOG_LS_WEIGHT,
                                DEFAULT_LOG_LS_RESID)
      cross_val_score.append(squared_loss)
    param_scores.append([np.sum(cross_val_score), np.mean(cross_val_score)])
    count += 1
    print("{} out of {} complete".format(count, n_vals))
  return param_scores

# param values to try
space1 = np.logspace(-4, 0, 4, base=2)
space2 = np.logspace(-1, 1, 4, base=2)
vals = np.array(np.meshgrid(space1, space2)).T.reshape(-1, 2)
val_scores = CV_timescale(X_all, y_all, y_obs_2011, vals)
print(val_scores)

