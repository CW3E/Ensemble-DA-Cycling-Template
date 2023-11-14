##################################################################################
# Description
##################################################################################
# This script is to automate downloading GEFS perturbation data for WRF
# initialization over arbitrary date ranges hosted by AWS, without using a
# sign-in to an account.  This data is hosted on the AWS open data service
# sponsored by NOAA at
#
#     https://registry.opendata.aws/noaa-gefs/
#
# Dates are specified in iso format in the global parameters for the script below.
# Other options specify the frequency of forecast outputs, time between zero hours
# and the max forecast hour for any zero hour.
#
# NOTE: as of 2022-10-15 AWS api changes across date ranges, syntax switches
# for dates between:
#
#     2017-01-01 to 2018-07-26
#     2018-07-27 to 2020-09-22
#     2020-09-23 to PRESENT
#
# the exclude statements in the below are designed to handle these exceptions
# using a recurisive copy from a base path.
# 
##################################################################################
# License Statement:
##################################################################################
#
# Copyright 2023 CW3E, Contact Colin Grudzien cgrudzien@ucsd.edu
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
import os, sys, ssl
import calendar
import glob
from datetime import datetime as dt
from datetime import timedelta

##################################################################################
# SET GLOBAL PARAMETERS 
##################################################################################
# starting date and zero hour of data iso format
STRT_DT = '2022-12-27T00:00:00'

# final date and zero hour of data iso format
STOP_DT = '2022-12-27T00:00:00'

# number of hours between zero hours for forecast data
INIT_INT = 24

# min forecast hour
FCST_MIN = 0

# max forecast hour
FCST_MAX = 24

# interval of forecast data outputs after zero hour
FCST_INT = 3

# root directory where date stamped sub-directories will collect data downloads
DATA_ROOT = '/expanse/lustre/scratch/cgrudzien/temp_project/JEDI-MPAS-Common-Case/DATA/DeepDive/gribbed/GEFS'

##################################################################################
# UTILITY METHODS
##################################################################################

# standard string indentation
INDT = '    '

# base aws anonymous request
CMD = 'aws s3 cp --no-sign-request s3://noaa-gefs-pds/gefs.'

# method for generating forecast start date / forecast hour lengths
def fcst_dt_hr(strt_dt, stop_dt, init_int, fcst_min, fcst_max, fcst_int):
    """ Generates lists of forecast initial times / forecast hours

    strt_dt / stop_dt are datetime objects which are used to generate the range
    of initial times.  init_int, fcst_min, fcst_max, fcst_int are all hour values
    in integers, used to determin the interval between initial times, minimum
    forecast hour, max forecast hour, and interval between forecast hour outputs
    respectively."""

    dates = []
    fcsts = []
    dt_range = stop_dt - strt_dt
    hrs = dt_range.total_seconds() / 3600
    fcst_steps = int( (fcst_max - fcst_min) / fcst_int)

    if init_int == 0 or dt_range.total_seconds() == 0:
        # for a zero initialization interval or start date equal end date,
        # download forecasts only from strt_dt
        dates.append(strt_dt)

    else:
        # define the zero hours for forecasts over range of cycle intervals
        init_steps = int(hrs / init_int)
        for i in range(init_steps + 1):
            fcst_init = strt_dt + timedelta(hours=(i * init_int))
            dates.append(fcst_init)

    for i in range(fcst_min, fcst_max + fcst_int, fcst_int):
        # define strings of forecast hours, padd to necessary size in scripts
        fcsts.append(str(i))

    return dates, fcsts

##################################################################################
# Download data
##################################################################################
# define date range to get data
strt_dt = dt.fromisoformat(STRT_DT)
stop_dt = dt.fromisoformat(STOP_DT)

# obtain combinations
dates, fcsts = fcst_dt_hr(strt_dt, stop_dt,
                          INIT_INT, FCST_MIN, FCST_MAX, FCST_INT)

# make requests
for date in dates:
    print('Downloading GEFS Date ' + date.strftime('%Y-%m-%d') + '\n')
    print('Zero Hour ' + date.strftime('%H') + '\n')

    down_dir = DATA_ROOT + '/' + date.strftime('%Y%m%d') + '/'
    os.system('mkdir -p ' + down_dir)

    for fcst in fcsts:
        # the following are the two and three digit padding versions of the hours
        HH  = fcst.zfill(2)
        HHH = fcst.zfill(3)
        print(INDT + 'Forecast Hour ' + HH + '\n')
        cmd = CMD + date.strftime('%Y%m%d') + '/' + date.strftime('%H') + ' ' +\
              down_dir + ' ' +\
              '--recursive ' +\
              '--exclude \'*\'' + ' ' +\
              '--include \'*f' + HH + '\' '  +\
              '--include \'*f' + HHH + '\' '  +\
              '--exclude \'*chem*\'' + ' ' +\
              '--exclude \'*wave*\'' + ' ' +\
              '--exclude \'*geavg*\'' + ' ' +\
              '--exclude \'*gespr*\'' + ' ' +\
              '--exclude \'*0p25*\''

        print(INDT * 2 + 'Running command:\n')
        print(INDT * 3 + cmd + '\n')
        os.system(cmd)

    # unpack data from nested directory structure, excluding the root
    print(INDT + 'Unpacking files from nested directories')
    find_cmd = 'find ' + down_dir + ' -type f > file_list.txt'

    print(find_cmd)
    os.system(find_cmd)
              
    f = open('./file_list.txt', 'r')

    print(INDT * 2 + 'Unpacking nested directory structure into ' + down_dir)
    for line in f:
        cmd = 'mv ' + line[:-1] + ' ' + down_dir
        os.system(cmd)

    # cleanup empty directories and file list
    f.close()

    find_cmd = 'find ' + down_dir + ' -type d > dir_list.txt'
    print(find_cmd)
    os.system(find_cmd)

    f = open('./dir_list.txt', 'r')
    print(INDT * 2 + 'Removing empty nested directories')
    line_list = f.readlines()
    line_list = line_list[-1:0:-1]

    for line in line_list:
        os.system('rmdir ' + line)

    os.system('rm file_list.txt')
    os.system('rm dir_list.txt')

print('\n')
print('Script complete -- verify the downloads at root ' + DATA_ROOT + '\n')

##################################################################################
# end
