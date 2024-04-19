##################################################################################
# Description
##################################################################################
# This is a fork and re-write of the ERA5 reanalysis download scripts
# written by Patrick Mulrooney, Daniel Steinhoff, Matthew Simpson, Caroline
# Papadopoulos, et al.  This has been revised to include more flexible methods
# and centralized global variables.
#
# When calling this script one should provide one of the following arguments as
# the script CALL = sys.argv[1]:
#    'model_levels' -- the script will download model level data
#    'surf_levels'  -- the script will download surface level data
#    'pres_levels'  -- the script will download pressure level data
# 
# The following arguments should be set in the SET PARAMETERS section:
#
#    AUTHS     -- List of authorization credentials for download access at
#                 https://cds.climate.copernicus.eu/
#    STRT_DT   -- Beginning date for data downloaded
#    STOP_DT   -- Inclusive end date for data downloaded
#    DT_INT    -- Maximum number of dates to combine to a single download file
#    STRT_HR   -- First hour in each day to pull data
#    HR_INT    -- Interval on which to pull data throughout the day
#    DATA_ROOT -- Directory to which the combined grib files will be downloaded
#                  default behavior is to download to directory based on CALL
#
##################################################################################
# License Statement:
##################################################################################
# This software is Copyright © 2024 The Regents of the University of California.
# All Rights Reserved. Permission to copy, modify, and distribute this software
# and its documentation for educational, research and non-profit purposes,
# without fee, and without a written agreement is hereby granted, provided that
# the above copyright notice, this paragraph and the following three paragraphs
# appear in all copies. Permission to make commercial use of this software may
# be obtained by contacting:
#
#     Office of Innovation and Commercialization
#     9500 Gilman Drive, Mail Code 0910
#     University of California
#     La Jolla, CA 92093-0910
#     innovation@ucsd.edu
#
# This software program and documentation are copyrighted by The Regents of the
# University of California. The software program and documentation are supplied
# "as is", without any accompanying services from The Regents. The Regents does
# not warrant that the operation of the program will be uninterrupted or
# error-free. The end-user understands that the program was developed for
# research purposes and is advised not to rely exclusively on the program for
# any reason.
#
# IN NO EVENT SHALL THE UNIVERSITY OF CALIFORNIA BE LIABLE TO ANY PARTY FOR
# DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES, INCLUDING
# LOST PROFITS, ARISING OUT OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION,
# EVEN IF THE UNIVERSITY OF CALIFORNIA HAS BEEN ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE. THE UNIVERSITY OF CALIFORNIA SPECIFICALLY DISCLAIMS ANY
# WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE SOFTWARE PROVIDED
# HEREUNDER IS ON AN “AS IS” BASIS, AND THE UNIVERSITY OF CALIFORNIA HAS NO
# OBLIGATIONS TO PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR
# MODIFICATIONS.
# 
# 
##################################################################################
# Imports
##################################################################################
import cdsapi
import signal, time, random
import os, sys, ssl
import urllib3
from http.client import HTTPSConnection
from base64 import b64encode
import concurrent.futures
import json
import pprint
import calendar
from datetime import date, timedelta

##################################################################################
# SET PARAMETERS 
##################################################################################
# Set the below to equal the uid & key from ECMWF for personal account, this can
# include multiple accounts in the list for more downloads simulataneously
AUTHS = [b'xxxxxx:xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx']

# which type of data to download, defined in script call
CALL = sys.argv[1]

# root directory where date stamped sub-directories will collect data downloads
DATA_ROOT = '/cw3e/mead/projects/cwp106/scratch' +\
    '/DATA/ERA5/' + CALL + '/'

# define the start and end year / month / day in YYYY-MM-DD formated string values
STRT_DT = '2019-02-08'
STOP_DT = '2019-02-08'

# interval over which to combine days into single files for download, format Int
DT_INT = 1

# first hour to get data, format Int
STRT_HR = 11

# interval on which to get additional data
HR_INT = 1

##################################################################################
# UTILITY METHODS
##################################################################################

def get_creds_to_use():
    random.shuffle(AUTHS)
    for auth in AUTHS:
        #Rotate the list
        print(auth)
        c = HTTPSConnection('cds.climate.copernicus.eu')
        c
        userAndPass = b64encode(auth).decode('ascii')
        headers = { 'Authorization' : 'Basic %s' %  userAndPass }
        c.request('GET', '/api/v2/tasks/', headers=headers)
        res = c.getresponse()
        result = res.read()
        data = json.loads(result)
        count = 0
        tcount = 0
        for res in data:
            tcount += 1
            if res['state'] in ['queued','running']:
                count += 1
        print('%s had %s in process, %s were queued or running'%(auth, tcount, count))
        if count < 5:
            return auth

    return None

def get_call(call, date1, date2, hours):
    # defines calls for cdsapi downloads in pre-set forms
    if call == 'model_levels':
        return {'reanalysis-era5-complete' : 
                {
                 'class'    : 'ea',
                 'date'     : '%s/to/%s'%(date1,date2),
                 'expver'   : '1',
                 'grid'     : '0.25/0.25',
                 'format'   : 'grib',
                 'levelist' : '1/to/137',
                 'levtype'  : 'ml',
                 'param'    : '129/130/131/132/133/152',
                 'stream'   : 'oper',
                 'time'     : hours, 
                 'type'     : 'an'
                }
               }

    elif call == 'pres_levels':
        return {'reanalysis-era5-pressure-levels' : 
                {
                 'date'          : '%s/%s'%(date1,date2),
                 'time'          : hours, 
                 'product_type'  : 'reanalysis',
                 'variable'      : [
                                    'divergence', 'fraction_of_cloud_cover',
                                    'geopotential', 'ozone_mass_mixing_ratio',
                                    'potential_vorticity', 'relative_humidity',
                                    'specific_cloud_ice_water_content',
                                    'specific_cloud_liquid_water_content',
                                    'specific_humidity', 'specific_rain_water_content',
                                    'specific_snow_water_content',
                                    'temperature', 'u_component_of_wind',
                                    'v_component_of_wind', 'vertical_velocity',
                                    'vorticity',
                                   ],
                 'pressure_level': [
                                    '1/2/3/5/7/10/20/30/50/70/100/125/150/175/200/' +
                                    '225/250/300/350/400/450/500/550/600/650/700/' +
                                    '750/775/800/825/850/875/900/925/950/975/1000'
                                   ],
                 'time': hours,
                 'format': 'grib'
                 }
                }

    elif call == 'surf_levels':
        return {'reanalysis-era5-single-levels':
                {
                 'date'          : '%s/%s'%(date1,date2),
                 'time'          : hours, 
                 'product_type': 'reanalysis',
                 'format'      : 'grib',
                 'grid'        : '0.25/0.25',
                 'variable'    : [
                                  '10m_u_component_of_wind', '10m_v_component_of_wind',
                                  '2m_dewpoint_temperature', '2m_temperature',
                                  'land_sea_mask', 'mean_sea_level_pressure',
                                  'sea_ice_cover', 'sea_surface_temperature',
                                  'skin_temperature', 'snow_depth',
                                  'soil_temperature_level_1', 'soil_temperature_level_2',
                                  'soil_temperature_level_3', 'soil_temperature_level_4',
                                  'surface_pressure',
                                  'volumetric_soil_water_layer_1',
                                  'volumetric_soil_water_layer_2',
                                  'volumetric_soil_water_layer_3',
                                  'volumetric_soil_water_layer_4',
                                  'zero_degree_level'
                                 ],
                }
               }

def get_file(req, key, call):
    # starts and monitors download
    req[0] = cdsapi.Client(
                           key=key,
                           url='https://cds.climate.copernicus.eu/api/v2',
                           wait_until_complete=True,
                           full_stack=True
                          )
    req[0].info('Download client started')
    req[0].info('Saving file to using key (%s): %s' %(key, req[4]))
    
    retrieve_call = get_call(call, req[1], req[2], req[3])
    retrieve_key = [*retrieve_call][0]
    req[5] = req[0].retrieve(retrieve_key, retrieve_call[retrieve_key], req[4])
    req[0].info('Download complete!')
    del req[5]
    req[0].info('Done')

def get_reqs(strt_dt, stop_dt, interval, hours):
    # generates requests based on script parameters, appending reqs with
    # [client, date0, date1, hours, output file, running download])
    reqs = []
    dates_range = max([int((stop_dt - strt_dt).days) + 1])

    for n in range(0, dates_range, interval):
        # this will automatically save the last sequence of days less than or equal to
        # interval to a single file
        if n + interval >= dates_range:
            d0 = (strt_dt + timedelta(n)).strftime('%Y-%m-%d')
            d1 = stop_dt.strftime('%Y-%m-%d')
            path = DATA_ROOT + '%s--%s_'%(d0, d1) + CALL + '.grib'
            reqs.append([None, d0, d1, hours, path, None])
            break
        else:
            # all other sequences of days are saved as adjacent time windows of
            # length interval
            d0 = (strt_dt + timedelta(n)).strftime('%Y-%m-%d')
            d1 = (strt_dt + timedelta(n + interval - 1)).strftime('%Y-%m-%d') 
            path = DATA_ROOT + '%s--%s_'%(d0, d1) + CALL + '.grib'
            reqs.append([None, d0, d1, hours, path, None])
    
    return reqs

##################################################################################
# Download data
##################################################################################
# make sure download directory exists
print('Creating download directory ' + DATA_ROOT)
os.system('mkdir -p ' + DATA_ROOT)

# disable warnings
urllib3.disable_warnings()

# define date range to get data
strt_dt = date.fromisoformat(STRT_DT)
stop_dt = date.fromisoformat(STOP_DT)

# define all hours to download data
hours = str(STRT_HR).zfill(2) + ':00:00'
for i in range(STRT_HR + HR_INT, 24, HR_INT):
    hours += '/' + str(i).zfill(2) + ':00:00'

# define all requests based on script parameters
reqs = get_reqs(strt_dt, stop_dt, DT_INT, hours)

# storage for outsanding requests
outstanding_reqs = []

print('Download date range: ' + STRT_DT + ' -- ' + STOP_DT)
print('Download hours ' + hours)
print('Download directory ' + DATA_ROOT)
print('Checking requests for duplicates')

# check for existing files corresponding to request in case of restart
for req in reqs:
    if os.path.isfile(req[4]):
        print('Skipping %s file already found'%(req[4]))
        continue
    outstanding_reqs.append(req)

print('+------------------------------------------+')
for req in outstanding_reqs:
    print('Requesting download ' + req[4])

print('+------------------------------------------+')
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as e:
    for req in outstanding_reqs:
        time.sleep(15)
        print(req[4])
        auth = None
        while auth == None:
            auth = get_creds_to_use()
            if auth == None:
                print('Did not get auth, sleep for an hour')
                time.sleep(60*60*1)
            else:
                print('Got auth: %s'%(auth))

        e.submit(get_file, req, auth.decode('ascii'), CALL)


##################################################################################
# end
