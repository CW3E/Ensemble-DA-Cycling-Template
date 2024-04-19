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
            #'2022122800_valid_date_x20.835586.WestCoast_mpas_ensemble',
            '2022122800_valid_date_x1.10242_mpas_ensemble',
            #'2022122800_valid_date_wrf_ensemble',
            #'first_forecast',
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
