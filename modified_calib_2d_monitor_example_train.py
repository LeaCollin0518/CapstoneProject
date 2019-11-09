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

_DATA_ADDR_PREFIX = "./example/data_monthly"

_SAVE_ADDR_PREFIX = "./result_ca_2010_monthly/modified_calibre_2d_annual_pm25_example_ca_20101"

_MODEL_DICTIONARY = {"root": ["AV_clean", "GS_clean", 'GM_clean']}

DEFAULT_LOG_LS_WEIGHT = np.log(0.35).astype(np.float32)
DEFAULT_LOG_LS_RESID = np.log(0.1).astype(np.float32)

"""""""""""""""""""""""""""""""""
# 0. Prepare data
"""""""""""""""""""""""""""""""""
# TODO(jereliu): re-verify the correspondence between prediction observation
os.makedirs(os.path.join(_SAVE_ADDR_PREFIX, 'base'), exist_ok=True)
if not os.path.isdir(_DATA_ADDR_PREFIX):
    raise ValueError("Data diretory {} doesn't exist!".format(_DATA_ADDR_PREFIX))

""" 0. prepare training data dictionary """
y_obs_2010 = pd.read_csv("{}/training_data_clean_2010_fake.csv".format(_DATA_ADDR_PREFIX))

X_train = np.asarray(y_obs_2010[["lon", "lat"]].values.tolist()).astype(np.float32)
y_train = np.asarray(y_obs_2010["pm25_obs"].tolist()).astype(np.float32)

base_train_feat = dict()
base_train_pred = dict()
for model_name in tail_free.get_leaf_model_names(_MODEL_DICTIONARY):
    base_train_feat[model_name] = X_train
    base_train_pred[model_name] = y_obs_2010["pred_{}".format(model_name)].astype(np.float32)


""" 1. prepare prediction data dictionary """
base_valid_feat = dict()
base_valid_pred = dict()
for model_name in tail_free.get_leaf_model_names(_MODEL_DICTIONARY):
    data_pd = pd.read_csv("{}/{}_20101_align.csv".format(
        _DATA_ADDR_PREFIX, model_name))
    base_valid_feat[model_name] = np.asarray(data_pd[["lon", "lat"]].values.tolist()).astype(np.float32)
    base_valid_pred[model_name] = np.asarray(data_pd["pm25"].tolist()).astype(np.float32)

X_valid = base_valid_feat[model_name]
N_pred = X_valid.shape[0]

with open(os.path.join(_SAVE_ADDR_PREFIX, 'base/base_train_feat.pkl'), 'wb') as file:
    pk.dump(base_train_feat, file, protocol=pk.HIGHEST_PROTOCOL)
with open(os.path.join(_SAVE_ADDR_PREFIX, 'base/base_train_pred.pkl'), 'wb') as file:
    pk.dump(base_train_pred, file, protocol=pk.HIGHEST_PROTOCOL)

with open(os.path.join(_SAVE_ADDR_PREFIX, 'base/base_valid_feat.pkl'), 'wb') as file:
    pk.dump(base_valid_feat, file, protocol=pk.HIGHEST_PROTOCOL)
with open(os.path.join(_SAVE_ADDR_PREFIX, 'base/base_valid_pred.pkl'), 'wb') as file:
    pk.dump(base_valid_pred, file, protocol=pk.HIGHEST_PROTOCOL)

""" 3. standardize data """
# standardize
X_centr = np.mean(X_valid, axis=0)
X_scale = np.max(X_valid, axis=0) - np.min(X_valid, axis=0)

X_valid = (X_valid - X_centr) / X_scale
X_train = (X_train - X_centr) / X_scale

print(X_centr, X_scale)

#[-118.37146   38.07276] [10.2599945  9.470001 ] for 2010

"""""""""""""""""""""""""""""""""
# 1. Model Estimation using MCMC
"""""""""""""""""""""""""""""""""
family_name = "hmc"
family_name_full = "Hamilton MC"

os.makedirs("{}/{}".format(_SAVE_ADDR_PREFIX, family_name),
            exist_ok=True)

with open(os.path.join(_SAVE_ADDR_PREFIX, 'base/base_train_pred.pkl'), 'rb') as file:
    base_train_pred = pk.load(file)

with open(os.path.join(_SAVE_ADDR_PREFIX, 'base/base_valid_pred.pkl'), 'rb') as file:
    base_valid_pred = pk.load(file)

"""2.1. sampler basic config"""
family_tree_dict = _MODEL_DICTIONARY

num_mcmc_steps = 5000
num_burnin_steps = 1000

"""2.2. run mcmc estimation"""

# define mcmc computation graph
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

""" 2.2. execute sampling"""
# this will take some time
parameter_samples_val = mcmc.run_sampling(mcmc_graph,
                                          init_op,
                                          parameter_samples,
                                          is_accepted)

with open(os.path.join(_SAVE_ADDR_PREFIX,
                       '{}/ensemble_posterior_train_parameter_samples_dict.pkl'.format(family_name)), 'wb') as file:
    pk.dump(parameter_samples_val, file, protocol=pk.HIGHEST_PROTOCOL)

#need to look at the joint likelihood of the samples given all the samples
#compare the prediction with all the samples and average them 
