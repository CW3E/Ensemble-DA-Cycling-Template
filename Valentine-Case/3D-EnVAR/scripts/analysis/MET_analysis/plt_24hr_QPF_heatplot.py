##################################################################################
# Description
##################################################################################
# This script is designed to generate heat plots in Matplotlib from MET grid_stat
# output files, preprocessed with the companion script proc_24hr_QPF.py.  This
# plotting scheme is designed to plot precipitation threshold level in the
# vertical axis and the number of lead hours to the valid time for verification
# from the forecast initialization in the horizontal axis. The global parameters
# for the script below control the initial times for the forecast initializations,
# as well as the valid date of the verification. Stats to compare can be reset 
# in the global parameters with heat map color bar changing scale dynamically.
#
##################################################################################
# License Statement
##################################################################################
#
# Copyright 2022 Colin Grudzien, cgrudzien@ucsd.edu
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
#     Unless required by applicable law or agreed to in writing, software
#     distributed under the License is distributed on an "AS IS" BASIS,
#     WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#     See the License for the specific language governing permissions and
#     limitations under the License.
# 
##################################################################################
# Imports
##################################################################################
import matplotlib
# use this setting on COMET / Skyriver for x forwarding
matplotlib.use('TkAgg')
from datetime import datetime as dt
import matplotlib.pyplot as plt
from matplotlib.colors import Normalize as nrm
from matplotlib.cm import get_cmap
from matplotlib.colorbar import Colorbar as cb
import seaborn as sns
import numpy as np
import pickle
import os
from py_plt_utilities import PROJ_ROOT

##################################################################################
# SET GLOBAL PARAMETERS 
##################################################################################
# define control flow to analyze 
CTR_FLW = 'deterministic_forecast_vbc_early_start_date_test'

# starting date and zero hour of forecast cycles
START_DATE = '2019-02-11T00:00:00'

# final date and zero hour of data of forecast cycles
END_DATE = '2019-02-14T00:00:00'

# valid date for the verification
VALID_DATE = '2019-02-15T00:00:00'

# number of hours between zero hours for forecast data
CYCLE_INT = 24

# MET stat column names to be made to heat plots / labels
STATS = ['PODY', 'POFD']

# landmask for verification region -- need to be set in earlier preprocessing
LND_MSK = 'CALatLonPoints'

##################################################################################
# Begin plotting
##################################################################################
# define derived data paths 
data_root = PROJ_ROOT + '/data/analysis/' + CTR_FLW + '/MET_analysis'
stat1 = STATS[0]
stat2 = STATS[1]

# convert to date times
start_date = dt.fromisoformat(START_DATE)
end_date = dt.fromisoformat(END_DATE)
valid_date = dt.fromisoformat(VALID_DATE)

# define the output name
in_path = data_root + '/grid_stats_lead_' + START_DATE +\
          '_to_' + END_DATE + '_valid_' + VALID_DATE +\
          '.bin'

out_path = data_root + '/' + VALID_DATE + '_' + LND_MSK + '_' + stat1 + '_' +\
           stat2 + '_heatplot.png'

f = open(in_path, 'rb')
data = pickle.load(f)
f.close()

# all values below are taken from the raw data frame, some may be set
# in the above STATS as valid heat plot options
vals = [
        'VX_MASK',
        'FCST_LEAD',
        'FCST_THRESH',
        'PODY',
        'PODY_NCL',
        'PODY_NCU',
        'PODN',
        'PODN_NCL',
        'PODN_NCU',
        'POFD',
        'POFD_NCL',
        'POFD_NCU',
        'GSS',
        'BAGSS',
        'CSI',
        'CSI_NCL',
        'CSI_NCU',
       ]

# cut down df to CA region and obtain levels of data 
level_data = data['cts'][vals]
level_data = level_data.loc[(level_data['VX_MASK'] == LND_MSK)]
data_levels =  sorted(list(set(level_data['FCST_THRESH'].values)))
data_leads = sorted(list(set(level_data['FCST_LEAD'].values)))[::-1]
num_levels = len(data_levels)
num_leads = len(data_leads)

# create array storage for probs
tmp = np.zeros([num_levels, num_leads, 2])

for k in range(2):
    for i in range(num_levels):
        for j in range(num_leads):
            val = level_data.loc[(level_data['FCST_THRESH'] == data_levels[i]) &
                                 (level_data['FCST_LEAD'] == data_leads[j])]
            
            tmp[i, j, k] = val[STATS[k]]

# Create a figure
fig = plt.figure(figsize=(11.25,8.63))

# Set the axes
ax0 = fig.add_axes([.89, .10, .05, .8])
ax1 = fig.add_axes([.08, .10, .39, .8])
ax2 = fig.add_axes([.49, .10, .39, .8])

# define the color bar scale depending on the stat
if (stat1 == 'GSS') or\
   (stat1 == 'BAGSS') or\
   (stat2 == 'GSS') or\
   (stat2 == 'BAGSS'):
    min_scale = -1/3
    max_scale = 1.0

else:
    max_scale = 1.0
    min_scale = 0.0

color_map = sns.cubehelix_palette(20, start=.75, rot=1.50, as_cmap=True,
                                  reverse=True, dark=0.25)
sns.heatmap(tmp[:,:,0], linewidth=0.5, ax=ax1, cbar_ax=ax0, vmin=min_scale,
            vmax=max_scale, cmap=color_map)
sns.heatmap(tmp[:,:,1], linewidth=0.5, ax=ax2, cbar_ax=ax0, vmin=min_scale,
            vmax=max_scale, cmap=color_map)

##################################################################################
# define display parameters

# generate tic labels based on hour values
for i in range(num_leads):
    data_leads[i] = data_leads[i][:2]

ax1.set_xticklabels(data_leads)
ax1.set_yticklabels(data_levels)
ax2.set_xticklabels(data_leads)
ax2.set_yticklabels(data_levels)

# tick parameters
ax0.tick_params(
        labelsize=18
        )

ax1.tick_params(
        labelsize=18
        )

ax2.tick_params(
        labelsize=18,
        left=False,
        labelleft=False,
        right=False,
        labelright=False,
        )

title1='24hr accumulated precip at ' + VALID_DATE
title2='Verification region -- ' + LND_MSK
lab1='Forecast lead hrs'
lab2='Precip Thresh mm'
lab3=STATS[0]
lab4=STATS[1]
plt.figtext(.5, .02, lab1, horizontalalignment='center',
            verticalalignment='center', fontsize=22)

plt.figtext(.02, .5, lab2, horizontalalignment='center',
            verticalalignment='center', fontsize=22, rotation='90')

plt.figtext(.5, .98, title1, horizontalalignment='center',
            verticalalignment='center', fontsize=22)

plt.figtext(.5, .93, title2, horizontalalignment='center',
            verticalalignment='center', fontsize=22)

plt.figtext(.08, .92, lab3, horizontalalignment='left',
            verticalalignment='center', fontsize=22)

plt.figtext(.88, .92, lab4, horizontalalignment='right',
            verticalalignment='center', fontsize=22)

# save figure and display
plt.savefig(out_path)
plt.show()

##################################################################################
# end