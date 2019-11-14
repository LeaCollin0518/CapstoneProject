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

def time_model(X_train, X_test,
                y_train, y_test,
                base_train_pred,
                base_test_pred,
                _MODEL_DICTIONARY,
                DEFAULT_LOG_LS_WEIGHT,
                DEFAULT_LOG_LS_RESID):

  """ 3. Train (MCMC sampling) """

  family_name = "hmc"
  family_name_full = "Hamilton MC"
  family_tree_dict = _MODEL_DICTIONARY
  num_mcmc_steps = 5000
  num_burnin_steps = 1000

  (mcmc_graph, init_op,
   parameter_samples, is_accepted) = (
      mcmc.make_inference_graph_tailfree(
          X_train, y_train,
          base_pred=base_train_pred,
          family_tree=family_tree_dict,
          default_log_ls_weight=DEFAULT_LOG_LS_WEIGHT,
          default_log_ls_resid=DEFAULT_LOG_LS_RESID,
          num_mcmc_samples=num_mcmc_steps,
          num_burnin_steps=num_burnin_steps))

  parameter_samples_val = mcmc.run_sampling(mcmc_graph,
                                            init_op,
                                            parameter_samples,
                                            is_accepted)


  """ 4. Prediction """

  sigma_sample_val = parameter_samples_val["sigma_sample"]
  resid_sample_val = parameter_samples_val["ensemble_resid_sample"]
  temp_sample_val = parameter_samples_val["temp_sample"]
  weight_sample_val = parameter_samples_val["weight_sample"]

  ensemble_sample_val = np.zeros(shape=(X_test.shape[0], num_mcmc_steps))
  ensemble_mean_val = np.zeros(shape=(X_test.shape[0], num_mcmc_steps))

  (ensemble_sample_val, ensemble_mean_val,
       _, _, _) = (
          pred_util.prediction_tailfree(X_pred=X_test,
                                        base_pred_dict=base_test_pred,
                                        X_train=X_train,
                                        family_tree=family_tree_dict,
                                        weight_sample_list=weight_sample_val,
                                        resid_sample=resid_sample_val,
                                        temp_sample=temp_sample_val,
                                        default_log_ls_weight=DEFAULT_LOG_LS_WEIGHT,
                                        default_log_ls_resid=DEFAULT_LOG_LS_RESID, )
      )

  """ 6. Evaluate BNE predictions """

  y_pred = np.mean(ensemble_sample_val, 0)
  print("Squared Loss")
  print(np.sum((y_pred - y_test)**2))
  squared_loss = np.sum((y_pred - y_test)**2)

  return squared_loss

