##################################################################################
# Description
##################################################################################
# This module is designed to centralize the path definitions and assignment of
# different possible control flows for the rocoto workflow manager.  One
# should define the appropriate paths for their system in the GLOBAL PARAMETERS
# below, and specify the appropriate control flows for the tasks to be run and
# monitored. Methods in this module can be used in other scripts for automating
# rocoto actions, used stand alone by calling actions in the bottom script
# section, or directly as functions in a Python session by importing the module.
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
import os
import time
from datetime import datetime as dt

##################################################################################
# SET GLOBAL WORKFLOW PARAMETERS
##################################################################################
# standard string indentation
INDT = '    '

# directory path for root of git clone of Ensemble-DA-Cycling-Template
USR_HME = '/expanse/nfs/cw3e/cwp157/cgrudzien/JEDI-MPAS-Common-Case/Ensemble-DA-Cycling-Template'
print('Clone location:\n' + USR_HME)

# path to .xml control flows 
SETTINGS = USR_HME + '/simulation_settings'
print('Settings directory:\n' + INDT + SETTINGS)

# path to database
DBS = USR_HME + '/workflow_status'
print('Database directory:\n' + INDT + DBS)

# path to rocoto singularity image
RCT = '/expanse/nfs/cw3e/cwp157/cgrudzien/JEDI-MPAS-Common-Case/SOFT_ROOT/rocoto'
print('Rocoto build path:\n' + INDT + RCT)

# Case study sub directories
CSES = [
        'DeepDive',
       ]

# name of .xml workflows to execute and monitor WITHOUT the extension of file
CTR_FLWS = [
            '2022122800_valid_date_x1.10242_mpas_ensemble',
            #'2022122800_valid_date_x1.10242_mpas_ensemble_lower_bnd',
            #'2022122800_valid_date_wrf_ensemble',
           ]

# Set END to a specific date for running as a background process such as
#
#    nohup python -u rocoto_utilities.py &
#
# with a specified end date.  If running on a scheduler, set this out to an
# arbitrary far end date and let the wall clock limit terminate the process.
END = dt(2025, 1, 1, 0)

##################################################################################
# Derived paths
##################################################################################
# path to .xml control flows 
settings =  USR_HME + '/simulation_settings'

# path to database
dbs = USR_HME + '/workflow_status'

##################################################################################
# Rocoto utility commands
##################################################################################
# The following commands are wrappers for the native rocoto functions described
# in its documentation:
#
#     http://christopherwharrop.github.io/rocoto/
#
# The rocoto run and stat commands require no arguments and are defined by the
# global parameters in the above sections. For the boot and rewind commands, one
# should supply a list of strings corresponding to the control flow, cycle date
# time and the corresponding task names to boot or rewind.  One can, e.g., loop
# through ensemble indexed tasks this way with an iterator of the form:
#
#    run_rocotoboot(
#                   ['3denvar_test_run'],
#                   ['201902081800'],
#                   ['ungrib_ens_' + str(i).zfill(2) for i in range(21)]
#                  )
#
# to boot all tasks in a range for a specified date and control flow.
#
##################################################################################

def run_rocotorun():
    for cse in CSES:
        for ctr_flw in CTR_FLWS:
            cmd = RCT + '/bin/rocotorun -w ' +\
                  settings + '/' + cse + '/' + ctr_flw + '/ctr_flw.xml' +\
                  ' -d ' + dbs + '/' + cse + '-' + ctr_flw + '.store -v 10'  

            print(cmd)
            os.system(cmd)

        # update workflow statuses after loops
        run_rocotostat()

def run_rocotostat():
    for cse in CSES:
        for ctr_flw in CTR_FLWS:
            cmd = RCT + '/bin/rocotostat -w ' +\
                  settings + '/' + cse + '/' + ctr_flw + '/ctr_flw.xml' +\
                  ' -d ' + dbs + '/' + cse + '-' + ctr_flw + '.store -c all'+\
                  ' > ' + DBS + '/' +\
                  cse + '-' + ctr_flw + '_workflow_status.txt'

            print(cmd)
            os.system(cmd) 

def run_rocotoboot(cses, flows, cycles, tasks):
    for cse in cses:
        for ctr_flw in flows:
            for cycle in cycles:
                for task in tasks:
                    cmd = RCT + '/bin/rocotoboot -w ' +\
                          settings + '/' + cse + '/' + ctr_flw + '/ctr_flw.xml' +\
                          ' -d ' + dbs + '/' + cse + '-' + ctr_flw + '.store' +\
                          ' -c ' + cycle + ' -t ' + task

                    print(cmd)
                    os.system(cmd) 

        # update workflow statuses after loops
        run_rocotostat()

def run_rocotorewind(cses, flows, cycles, tasks):
    for cse in cses:
        for ctr_flw in flows:
            for cycle in cycles:
                for task in tasks:
                    cmd = RCT + '/bin/rocotorewind -w ' +\
                          settings + '/' + cse + '/' + ctr_flw + '/ctr_flw.xml' +\
                          ' -d ' + dbs + '/' + cse + '-' + ctr_flw + '.store' +\
                          ' -c ' + cycle + ' -t ' + task

                    print(cmd)
                    os.system(cmd) 

        # update workflow statuses after loops
        run_rocotostat()

##################################################################################
# Execute the following lines as script
##################################################################################

if __name__ == '__main__':
    # monitor and advance the jobs, will loop run_rocotorun() until END
    while (dt.now() < END):
        run_rocotorun()
        time.sleep(60)

##################################################################################
# end
