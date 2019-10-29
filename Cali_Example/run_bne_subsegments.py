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

# _SAVE_ADDR_PREFIX_SUB = "./result_ca_2010_all/calibre_2d_annual_pm25_example_ca_2010"
_SAVE_ADDR_PREFIX = "./result_ca_2010_allsubsegments/calibre_2d_annual_pm25_example_ca_2010"

_MODEL_DICTIONARY = {"root": ["AV", "GM", "GS"]}

DEFAULT_LOG_LS_WEIGHT = np.log(0.35).astype(np.float32)
DEFAULT_LOG_LS_RESID = np.log(0.1).astype(np.float32)

os.makedirs(os.path.join(_SAVE_ADDR_PREFIX, 'base'), exist_ok=True)
if not os.path.isdir(_DATA_ADDR_PREFIX):
    raise ValueError("Data diretory {} doesn't exist!".format(_DATA_ADDR_PREFIX))

""" 0. prepare training data dictionary """

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
N_pred = X_valid.shape[0]

# standardize
X_centr = np.mean(X_valid, axis=0)
X_scale = np.max(X_valid, axis=0) - np.min(X_valid, axis=0)

X_valid = (X_valid - X_centr) / X_scale
X_train = (X_train - X_centr) / X_scale



family_name = "hmc"
family_name_full = "Hamilton MC"

os.makedirs("{}/{}".format(_SAVE_ADDR_PREFIX, family_name),
            exist_ok=True)


# load mcmc posterior samples
with open(os.path.join(_SAVE_ADDR_PREFIX,
                       '{}/ensemble_posterior_train_parameter_samples_dict.pkl'.format(family_name)), 'rb') as file:
    parameter_samples_val = pk.load(file)

# extract parameters
sigma_sample_val = parameter_samples_val["sigma_sample"]
resid_sample_val = parameter_samples_val["ensemble_resid_sample"]
temp_sample_val = parameter_samples_val["temp_sample"]
weight_sample_val = parameter_samples_val["weight_sample"]

# since validation data is very large, perform prediction by data into batch,
kf = KFold(n_splits=30)
kf2 = KFold(n_splits=20)

num_mcmc_steps = 5000
num_burnin_steps = 1000

family_tree_dict = _MODEL_DICTIONARY

for fold_id, (_, pred_index) in enumerate(kf.split(X_valid)):
  print("Running fold {} out of {}".format(fold_id + 1, kf.n_splits))
  new_xval = X_valid[pred_index]
  ensemble_sample_val = np.zeros(shape=(new_xval.shape[0], num_mcmc_steps))
  ensemble_mean_val = np.zeros(shape=(new_xval.shape[0], num_mcmc_steps))

  base_pred_dict_fold = {
        model_name: model_pred_val[pred_index]
        for (model_name, model_pred_val) in base_valid_pred.items()}
  
  for sub_fold_id, (_, sub_pred_index) in enumerate(kf2.split(new_xval)):
    print("Running sub_fold {} out of {}".format(sub_fold_id + 1, kf2.n_splits))
    X_pred_fold = new_xval[sub_pred_index]
    base_pred_dict_subfold = {
        model_name: model_pred_val[sub_pred_index]
        for (model_name, model_pred_val) in base_pred_dict_fold.items()
    }

    # run prediction routine
    (ensemble_sample_fold, ensemble_mean_fold,
     _, _, _) = (
        pred_util.prediction_tailfree(X_pred=X_pred_fold,
                                      base_pred_dict=base_pred_dict_subfold,
                                      X_train=X_train,
                                      family_tree=family_tree_dict,
                                      weight_sample_list=weight_sample_val,
                                      resid_sample=resid_sample_val,
                                      temp_sample=temp_sample_val,
                                      default_log_ls_weight=DEFAULT_LOG_LS_WEIGHT,
                                      default_log_ls_resid=DEFAULT_LOG_LS_RESID, )
    )

    ensemble_sample_val[sub_pred_index] = ensemble_sample_fold.T
    ensemble_mean_val[sub_pred_index] = ensemble_mean_fold.T

  with open(os.path.join(_SAVE_ADDR_PREFIX,
                       '{}/ensemble_posterior_pred_dist_sample_{}.pkl'.format(family_name, fold_id)), 'wb') as file:
    pk.dump(ensemble_sample_val, file, protocol=pk.HIGHEST_PROTOCOL)
    
  with open(os.path.join(_SAVE_ADDR_PREFIX,
                       '{}/ensemble_posterior_pred_mean_sample_{}.pkl'.format(family_name, fold_id)), 'wb') as file:
    pk.dump(ensemble_mean_val, file, protocol=pk.HIGHEST_PROTOCOL)
    
  with open(os.path.join(_SAVE_ADDR_PREFIX,
                       '{}/ensemble_posterior_sigma_sample_{}.pkl'.format(family_name, fold_id)), 'wb') as file:
    pk.dump(sigma_sample_val, file, protocol=pk.HIGHEST_PROTOCOL)


print("Estimated ls_weight {:.4f}, ls_resid {:.4f}".format(
    np.exp(DEFAULT_LOG_LS_WEIGHT), np.exp(DEFAULT_LOG_LS_RESID)
))



# """""""""""""""""""""""""""""""""
# # 3. Visualization
# """""""""""""""""""""""""""""""""

# print('now in visualization!')

# """ 3.1. prep: load data, compute posterior mean/sd, color config """
# with open(os.path.join(_SAVE_ADDR_PREFIX,
#                        '{}/ensemble_posterior_pred_dist_sample.pkl'.format(family_name)), 'rb') as file:
#     ensemble_sample_val = pk.load(file)
# with open(os.path.join(_SAVE_ADDR_PREFIX,
#                        '{}/ensemble_posterior_pred_mean_sample.pkl'.format(family_name)), 'rb') as file:
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

# post_mean_dict = {
#     "overall": np.mean(ensemble_sample_val, axis=1),
#     "mean": np.mean(ensemble_mean_val, axis=1),
#     "resid": np.mean(ensemble_sample_val - ensemble_mean_val, axis=1)
# }


# # prepare color norms for plt.scatter
# color_norm_unc = visual_util.make_color_norm(
#     list(post_uncn_dict.values())[:1],  # use "overall" and "mean" for pal
#     method="percentile")
# color_norm_ratio = visual_util.make_color_norm(
#     post_uncn_dict["noise"] / post_uncn_dict["overall"],
#     method="percentile")
# color_norm_pred = visual_util.make_color_norm(
#     list(post_mean_dict.values())[:2],  # exclude "resid" vales from pal
#     method="percentile")

# """ 3.1. posterior predictive uncertainty """
# for unc_name, unc_value in post_uncn_dict.items():
#     save_name = os.path.join(_SAVE_ADDR_PREFIX,
#                              '{}/ensemble_posterior_uncn_{}.png'.format(
#                                  family_name, unc_name))

#     color_norm = visual_util.posterior_heatmap_2d(unc_value,
#                                                   X=X_valid, X_monitor=X_train,
#                                                   cmap='inferno_r',
#                                                   norm=color_norm_unc,
#                                                   norm_method="percentile",
#                                                   save_addr=save_name)

# """ 3.2. posterior predictive mean """
# for mean_name, mean_value in post_mean_dict.items():
#     save_name = os.path.join(_SAVE_ADDR_PREFIX,
#                              '{}/ensemble_posterior_mean_{}.png'.format(
#                                  family_name, mean_name))
#     color_norm = visual_util.posterior_heatmap_2d(mean_value,
#                                                   X=X_valid, X_monitor=X_train,
#                                                   cmap='RdYlGn_r',
#                                                   norm=color_norm_pred,
#                                                   norm_method="percentile",
#                                                   save_addr=save_name)