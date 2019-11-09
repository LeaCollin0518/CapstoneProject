import pandas as pd
import numpy as np

models = ['AV', 'GS', 'GM']
models_dir = 'Data/cali_pred_data_2010_monthly/'

for month in range(1,13):
    monthly_pred = pd.DataFrame(columns=['time', 'x', 'y', 'pred_AV_clean', 'pred_GS_clean', 'pred_GM_clean'])
    for model in models:
        model_dir = '{}{}_clean_2010{}_align.csv'.format(models_dir, model, month)
        model_df = pd.read_csv(model_dir)
        model_df = model_df.sort_values(by=['lon', 'lat'])
        if model == 'AV':
            monthly_pred['x'] = model_df['lon']
            monthly_pred['y'] = model_df['lat']
            monthly_pred['pred_AV_clean'] = model_df['pm25']
        elif model == 'GS':
            monthly_pred['pred_GS_clean'] = model_df['pm25']
        elif model == 'GM':
            monthly_pred['pred_GM_clean'] = model_df['pm25']
    monthly_pred['time'] = np.repeat(month, monthly_pred.shape[0])
    save_file = models_dir + 'predictions_monthly_2010{}.csv'.format(month)
    monthly_pred.to_csv(save_file, index = False)