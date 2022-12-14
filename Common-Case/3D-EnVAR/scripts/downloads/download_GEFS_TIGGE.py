##################################################################################
# Description
##################################################################################
# This script is to automate downloading GEFS perturbation data for WRF
# initialization over arbitrary date ranges hosted in the ECMWF TIGGE repository.
# If you don't already, please register for an ECMWF account in order to download
# data from the TIGGE database. 
# 
#     https://confluence.ecmwf.int/display/WEBAPI/Access+ECMWF+Public+Datasets
# 
# Install ECMWF api key in your home area by putting api key in ~/.ecmwfapirc,
# generated by the account creatiion above.
#
# This script is based on original source shared by Rachel Weihs and Caroline
# Papadopoulos.  Dates are specified in iso format in the global parameters for
# the script below. Other options specify the frequency of forecast outputs,
# time between zero hours and the max forecast hour for any zero hour.
#
# This script is designed to download combined perturbation data for a given
# zero hour and a specified forecast horizon to be split later in a postprocessing
# script.
#
##################################################################################
# License Statement:
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
import os
from datetime import datetime as dt
from datetime import timedelta
from ecmwfapi import ECMWFDataServer
from multiprocessing import Pool
from download_utilities import PROJ_ROOT, STR_INDT, get_reqs

##################################################################################
# SET GLOBAL PARAMETERS 
##################################################################################
# starting date and zero hour of data
START_DATE = '2019-02-08T18:00:00'

# final date and zero hour of data
END_DATE = '2019-02-10T18:00:00'

# interval of forecast data outputs after zero hour
FCST_INT = 6

# number of hours between zero hours for forecast data
CYCLE_INT = 6

# max forecast lenght in hours
MAX_FCST = 6

# max ensemble size to download from perturbations
# NOTE: all ensemble members are combined in a single file to be split later
# to download data effectively from the ECMWF public queue
N_ENS = 20

# dowload control solution True / False
# NOTE: control solution is downloaded to a separate file than the perturbations
# due to differences in syntaxing with batch downloads
CTR=False

# root directory where date stamped sub-directories will collect data downloads
DATA_ROOT = PROJ_ROOT +\
    '/GSI-WRF-Cycling-Template/Valentine-Case/3D-EnVAR/data/static/gribbed/GEFS'

##################################################################################
# UTILITY METHODS
##################################################################################

def get_call(date, fcst_hrs, data_type, n_ens=None):
    """Defines call for request based on above arguments

    Data request runs on 'data_type' switch with pre-defined templates for
    requests based on data types.  Ensemble index n_ens is only needed
    for gep data, not control solution.
    """

    down_dir = DATA_ROOT + '/' + date.strftime('%Y%m%d')
    os.system('mkdir -p ' + down_dir)

    # create string list of perturbations if n_ens is given
    if n_ens:
        ens_list = ''
        for i in range(1, n_ens):
            ens_list += str(i) + '/'

        # append the last ensemble index without trailing slash
        ens_list += str(n_ens)

    # create string list of combined forecast hours
    steps = ''
    num_hrs = len(fcst_hrs)
    for i in range(num_hrs - 1):
        steps += str(fcst_hrs[i]) + '/'

    # append the last forecast hour without trailing slash
    steps += str(fcst_hrs[-1])

    if data_type == 'gep_pl':
        # perturbation pressure level data
        target = down_dir + '/TIGGE_geps_1-' + str(n_ens) +\
                 '_pl_zh_' + date.strftime('%Y-%m-%d_%H') +\
                 '_fcst_hrs_0-' + str(fcst_hrs[-1]) + '.grib'  

        req = {
               'class': 'ti',
               'dataset': 'tigge',
               'date': date.strftime('%Y-%m-%d'),
               'expver': 'prod',
               'grid': '0.5/0.5',
               'levelist': '200/250/300/500/700/850/925/1000',
               'levtype': 'pl',
               'number': ens_list,
               'origin': 'kwbc',
               'param': '130/131/132/133/156',
               'step': steps,
               'target': target,
               'time': date.strftime('%H:%M:%S'),
               'type': 'pf',
              }

        return req
    
    elif data_type == 'gep_sl': 
        # perturbation surface level data
        target = down_dir + '/TIGGE_geps_1-' + str(n_ens) +\
                 '_sl_zh_' + date.strftime('%Y-%m-%d_%H') +\
                 '_fcst_hrs_0-' + str(fcst_hrs[-1]) + '.grib'  

        req = {
               'class': 'ti',
               'dataset': 'tigge',
               'date': date.strftime('%Y-%m-%d'),
               'expver': 'prod',
               'grid': '0.5/0.5',
               'levtype': 'sfc',
               'number': ens_list,
               'origin': 'kwbc',
               'param': '134/151/165/166/167/168/172/235/228039/228139/228144',
               'step': steps,
               'target': target,
               'time': date.strftime('%H:%M:%S'),
               'type': 'pf',
              }

        return req

    elif data_type == 'gep_st':
        # perturbation static data
        target = down_dir + '/TIGGE_geps_1-' + str(n_ens) +\
                 '_st_zh_' + date.strftime('%Y-%m-%d_%H') +\
                 '_fcst_hrs_0-' + str(fcst_hrs[-1]) + '.grib'  

        req = {
               'class': 'ti',
               'dataset': 'tigge',
               'date': date.strftime('%Y-%m-%d'),
               'expver': 'prod',
               'grid': '0.5/0.5',
               'levtype': 'sfc',
               'number': ens_list,
               'origin': 'kwbc',
               'param': '228002',
               'step': '0',
               'time': date.strftime('%H:%M:%S'),
               'type': 'pf',
               'target': target,
              }

        return req

    elif data_type == 'gec_pl':
        # control pressure level
        target = down_dir + '/TIGGE_gec'+\
                 '_pl_zh_' + date.strftime('%Y-%m-%d_%H') +\
                 '_fcst_hrs_0-' + str(fcst_hrs[-1]) + '.grib'  

        req = {
               'class': 'ti',
               'dataset': 'tigge',
               'date': date.strftime('%Y-%m-%d'),
               'expver': 'prod',
               'grid': '0.5/0.5',
               'levelist': '200/250/300/500/700/850/925/1000',
               'levtype': 'pl',
               'origin': 'kwbc',
               'param': '130/131/132/133/156',
               'step': steps,
               'target': target,
               'time': date.strftime('%H:%M:%S'),
               'type': 'cf',
              }
 
    elif data_type == 'gec_sl':
        # control surface level
        target = down_dir + '/TIGGE_gec'+\
                 '_sl_zh_' + date.strftime('%Y-%m-%d_%H') +\
                 '_fcst_hrs_0-' + str(fcst_hrs[-1]) + '.grib'  

        req = {
               'class': 'ti',
               'dataset': 'tigge',
               'date': date.strftime('%Y-%m-%d'),
               'expver': 'prod',
               'grid': '0.5/0.5',
               'levtype': 'sfc',
               'origin': 'kwbc',
               'param': '134/151/165/166/167/168/235/228039/228139/228144',
               'step': steps,
               'target': target,
               'time': date.strftime('%H:%M:%S'),
               'type': 'cf',
              }

        return req
 
##################################################################################
# Download data
##################################################################################
# define date range to get data
start_date = dt.fromisoformat(START_DATE)
end_date = dt.fromisoformat(END_DATE)

# initialize the server for ecmwf
server = ECMWFDataServer()
 
# obtain combinations
date_reqs, fcst_reqs = get_reqs(start_date, end_date, FCST_INT,
                                CYCLE_INT, MAX_FCST)

req_list = []

# make requests
for date in date_reqs:
    req_list.append(get_call(date, fcst_reqs, 'gep_pl', n_ens=N_ENS))
    req_list.append(get_call(date, fcst_reqs, 'gep_sl', n_ens=N_ENS))
    req_list.append(get_call(date, fcst_reqs, 'gep_st', n_ens=N_ENS))
    
    if CTR:
        req_list.append(get_call(date, fcst_reqs, 'gec_pl'))
        req_list.append(get_call(date, fcst_reqs, 'gec_sl'))
            
print('Generating requests:')
for req in req_list:
    print(req)
    print('\n')

# map requests to asynchronous workers for download
with Pool(23) as pool:
    print(pool.map(server.retrieve, req_list))

print('Completed Python script')
