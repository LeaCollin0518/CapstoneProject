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


from sys import argv
def main(argv):

  n = argv
  # n is subset number 



  os.environ['TF_CPP_MIN_LOG_LEVEL'] = '3'


  _DATA_ADDR_PREFIX = "./example/data_monthly"

  _SAVE_ADDR_PREFIX = "./result_ca_2010_monthly/modified_calibre_2d_annual_pm25_example_ca_20101"

  _MODEL_DICTIONARY = {"root": ["AV_clean", "GS_clean", 'GM_clean']}

  family_name = "hmc"+str(n)
  os.makedirs("{}/{}".format(_SAVE_ADDR_PREFIX, family_name),
              exist_ok=True)
  family_tree_dict = _MODEL_DICTIONARY
  DEFAULT_LOG_LS_WEIGHT = np.log(0.35).astype(np.float32)
  DEFAULT_LOG_LS_RESID = np.log(0.1).astype(np.float32)

  """""""""""""""""""""""""""""""""
  # 0. Prepare data
  """""""""""""""""""""""""""""""""

  """ 0. prepare training data dictionary """
  y_obs_2010 = pd.read_csv("{}/training_data_clean_2010_fake.csv".format(_DATA_ADDR_PREFIX))

  X_train = np.asarray(y_obs_2010[["lon", "lat"]].values.tolist()).astype(np.float32)

  base_train_feat = dict()

  for model_name in tail_free.get_leaf_model_names(_MODEL_DICTIONARY):
      base_train_feat[model_name] = X_train
     

  """ 1. prepare prediction data dictionary """
  base_valid_feat = dict()
  base_valid_pred = dict()
  for model_name in tail_free.get_leaf_model_names(_MODEL_DICTIONARY):
      data_pd = pd.read_csv(_DATA_ADDR_PREFIX+"/"+model_name+"_20101_align."+str(n)+".csv")
      base_valid_feat[model_name] = np.asarray(data_pd[["lon", "lat"]].values.tolist()).astype(np.float32)
      base_valid_pred[model_name] = np.asarray(data_pd["pm25"].tolist()).astype(np.float32)
   
  X_valid = base_valid_feat[model_name]

  """ 3. standardize data """
  # standardize
  X_centr = np.mean(X_valid, axis=0)
  X_scale = np.max(X_valid, axis=0) - np.min(X_valid, axis=0)

  X_valid = (X_valid - X_centr) / X_scale
  X_train = (X_train - X_centr) / X_scale


  """""""""""""""""""""""""""""""""
  # 2. Perform Model Prediction
  """""""""""""""""""""""""""""""""
  # load mcmc posterior samples
  with open(os.path.join(_SAVE_ADDR_PREFIX,
                         '{}/ensemble_posterior_train_parameter_samples_dict.pkl'.format('hmc')), 'rb') as file:
      parameter_samples_val = pk.load(file)

  # extract parameters
  sigma_sample_val = parameter_samples_val["sigma_sample"]
  resid_sample_val = parameter_samples_val["ensemble_resid_sample"]
  temp_sample_val = parameter_samples_val["temp_sample"]
  weight_sample_val = parameter_samples_val["weight_sample"]

  print(sigma_sample_val.shape) # (5000,)
  print(resid_sample_val.shape) # (5000, 80)
  print(temp_sample_val[0].shape) #(5000,)
  print(weight_sample_val[0].shape) #(5000, 80)

  # since validation data is very large, perform prediction by data into batch,
  kf = KFold(n_splits=20)

  # prepare output container
  # ensemble_sample_val = np.zeros(shape=(X_valid.shape[0], num_mcmc_steps))
  # ensemble_mean_val = np.zeros(shape=(X_valid.shape[0], num_mcmc_steps))

  # ensemble_sample_val_mean = np.zeros(shape=(X_valid.shape[0], ))
  # ensemble_mean_val_mean = np.zeros(shape=(X_valid.shape[0], ))
  # mean_resid = np.zeros(shape=(X_valid.shape[0], ))

  # ensemble_sample_val_var = np.zeros(shape=(X_valid.shape[0], ))
  # ensemble_mean_val_var = np.zeros(shape=(X_valid.shape[0], ))
  # uncn_resid = np.zeros(shape=(X_valid.shape[0], ))
  # uncn_noise =  np.zeros(shape=(X_valid.shape[0], ))

  # ensemble_weights_val = np.zeros(shape=(X_valid.shape[0], 3)) # 3 is the number of models 


  # print(ensemble_sample_val_mean.shape) #(20000, 5000)
  # print(ensemble_mean_val_var.shape) #(20000, 5000)

  #need to do something here to store all 20k rows 

  #(5000, 20000, 3)


  #cond_weights_dict_val = np.zeros(shape=(X_valid.shape[0], num_mcmc_steps))
  # the above is a dictionary where the keys are the models

  for fold_id, (_, pred_index) in enumerate(kf.split(X_valid)):
      print("Running fold {} out of {}".format(fold_id + 1, kf.n_splits))

      # prepare X_pred and base_pred_dict for each batch
      X_pred_fold = X_valid[pred_index]
      base_pred_dict_fold = {
          model_name: model_pred_val[pred_index]
          for (model_name, model_pred_val) in base_valid_pred.items()}

      # added new returned parameters here 
      # run prediction routine
      (ensemble_sample_fold, ensemble_mean_fold,
      ensemble_weights_fold, _, _) = (
          pred_util.prediction_tailfree(X_pred=X_pred_fold,
                                        base_pred_dict=base_pred_dict_fold,
                                        X_train=X_train,
                                        family_tree=family_tree_dict,
                                        weight_sample_list=weight_sample_val,
                                        resid_sample=resid_sample_val,
                                        temp_sample=temp_sample_val,
                                        default_log_ls_weight=DEFAULT_LOG_LS_WEIGHT,
                                        default_log_ls_resid=DEFAULT_LOG_LS_RESID, )
      )
      # print(ensemble_sample_fold.shape) #(5000, 200)
      # print(ensemble_mean_fold.shape) #(5000, 200)
      # print(ensemble_weights_fold.shape) #(5000, 200, 3)

      t = np.mean(np.exp(2 * sigma_sample_val))

      # save to output container
      # ensemble_sample_val_mean[pred_index] = np.mean(ensemble_sample_fold.T, axis=1)
      # ensemble_mean_val_mean[pred_index] = np.mean(ensemble_mean_fold.T, axis=1)
      # mean_resid[pred_index] = np.mean(ensemble_sample_fold.T - ensemble_mean_fold.T, axis=1)

      # ensemble_sample_val_var[pred_index] = np.var(ensemble_sample_fold.T, axis=1) + t
      # ensemble_mean_val_var[pred_index] = np.var(ensemble_mean_fold.T, axis=1)
      # uncn_resid[pred_index]= np.var(ensemble_sample_fold.T - ensemble_mean_fold.T, axis=1)
      # uncn_noise[pred_index] =  t * np.ones(shape=(ensemble_sample_fold.T.shape[0]))

      ensemble_sample_val_mean_fold = np.mean(ensemble_sample_fold.T, axis=1)
      ensemble_mean_val_mean_fold = np.mean(ensemble_mean_fold.T, axis=1)
      mean_resid_fold = np.mean(ensemble_sample_fold.T - ensemble_mean_fold.T, axis=1)

      ensemble_sample_val_var_fold = np.var(ensemble_sample_fold.T, axis=1) + t
      ensemble_mean_val_var_fold = np.var(ensemble_mean_fold.T, axis=1)
      uncn_resid_fold = np.var(ensemble_sample_fold.T - ensemble_mean_fold.T, axis=1)
      uncn_noise_fold =  t * np.ones(shape=(ensemble_sample_fold.T.shape[0]))

      #model weights 
      # ensemble_weights_val[pred_index, :] = np.mean(ensemble_weights_fold, axis=0)
      # cond_weights_dict_val[pred_index] = cond_weights_dict_fold.T

      ensemble_weights_val_fold = np.mean(ensemble_weights_fold, axis=0)

      with open(os.path.join(_SAVE_ADDR_PREFIX,
                         '{}/ensemble_posterior_sigma_sample.pkl'.format(family_name)), 'ab') as file:
          pk.dump(sigma_sample_val, file, protocol=pk.HIGHEST_PROTOCOL)

      with open(os.path.join(_SAVE_ADDR_PREFIX,
                             '{}/ensemble_sample_val_mean.pkl'.format(family_name)), 'ab') as file:
          pk.dump(ensemble_sample_val_mean_fold, file, protocol=pk.HIGHEST_PROTOCOL)
      with open(os.path.join(_SAVE_ADDR_PREFIX,
                             '{}/ensemble_mean_val_mean.pkl'.format(family_name)), 'ab') as file:
          pk.dump( ensemble_mean_val_mean_fold, file, protocol=pk.HIGHEST_PROTOCOL)
      with open(os.path.join(_SAVE_ADDR_PREFIX,
                             '{}/mean_resid.pkl'.format(family_name)), 'ab') as file:
          pk.dump(mean_resid_fold, file, protocol=pk.HIGHEST_PROTOCOL)

      with open(os.path.join(_SAVE_ADDR_PREFIX,
                             '{}/ensemble_sample_val_var.pkl'.format(family_name)), 'ab') as file:
          pk.dump(ensemble_sample_val_var_fold, file, protocol=pk.HIGHEST_PROTOCOL)


      with open(os.path.join(_SAVE_ADDR_PREFIX,
                             '{}/ensemble_mean_val_var.pkl'.format(family_name)), 'ab') as file:
          pk.dump(ensemble_mean_val_var_fold, file, protocol=pk.HIGHEST_PROTOCOL)

      with open(os.path.join(_SAVE_ADDR_PREFIX,
                             '{}/uncn_resid.pkl'.format(family_name)), 'ab') as file:
          pk.dump(uncn_resid_fold, file, protocol=pk.HIGHEST_PROTOCOL)

      with open(os.path.join(_SAVE_ADDR_PREFIX,
                             '{}/uncn_noise.pkl'.format(family_name)), 'ab') as file:
          pk.dump(uncn_noise_fold, file, protocol=pk.HIGHEST_PROTOCOL)

      with open(os.path.join(_SAVE_ADDR_PREFIX,
                             '{}/ensemble_weights_val.pkl'.format(family_name)), 'ab') as file:
          pk.dump(ensemble_weights_val_fold, file, protocol=pk.HIGHEST_PROTOCOL)




  print("Estimated ls_weight {:.4f}, ls_resid {:.4f}".format(
      np.exp(DEFAULT_LOG_LS_WEIGHT), np.exp(DEFAULT_LOG_LS_RESID)
  ))

if __name__=='__main__':
  
  main(argv[1]) # the second arguments which is the number of subset


