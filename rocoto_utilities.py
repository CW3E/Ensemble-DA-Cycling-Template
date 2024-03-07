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
import glob
import argparse

import time
from datetime import datetime as dt, timedelta
##################################################################################
# SET GLOBAL PARAMETERS
##################################################################################
# Launches argparse to receive arguments
parser = argparse.ArgumentParser(
                    prog='RocotoUtilities', 
                    description='', 
                    epilog='')

# Retrieves arguments from command line
# This would usually be DeepDive
parser.add_argument('cse_nme', help='Case study folder name.')

# This would be in the format of validdate_gridname_casename
parser.add_argument('exp_nme', help='Name of experiment sub-directory. Default runs all control flows in directory.')

# directory path for root of git clone of Ensemble-DA-Cycling-Template
parser.add_argument('-c', '--clne-root', required=False, 
        help='Optional, full path of framework git clone. Default set in code.', 
        default='/expanse/nfs/cw3e/cwp157/cdeciampa/Ensemble-DA-Cycling-Template')

# directory for rocoto install
parser.add_argument('-r', '--rct-nme', required=False, 
        help='Optional, full path to rocoto install. Default set in code.', 
        default='/expanse/nfs/cw3e/cwp157/cdeciampa/SOFT_ROOT/rocoto')

# Assigns supplied arguments as variables
args = parser.parse_args()

# directory path for root of git clone of Ensemble-DA-Cycling-Template
USR_HME = args.clne_root

# directory for rocoto install
RCT_HME = args.rct_nme

# directory for case study name
CSE_NME = args.cse_nme

# Experiment name
EXP_NME = args.exp_nme

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

class Rocoto:
    def __init__(self, USR_HME, RCT_HME, CSE_NME, EXP_NME):
        
        # Assigns class variables
        self.USR_HME = USR_HME
        self.RCT_HME = RCT_HME
        self.CSE_NME = CSE_NME
        self.EXP_NME = EXP_NME
        
        # name of .xml workflows (ensembles) in case study sub directories
        self.CTR_FLWS = glob.glob(f'{self.USR_HME}/**/{self.CSE_NME}/**/{self.EXP_NME}/**/ctr_flw.xml', recursive=True)
        
        # Raises exception if experiment name is wrong
        if not self.CTR_FLWS:
            raise ValueError(f'Supplied experiment directory does not exist: {self.EXP_NME}')

        # Defines where dbs dir is
        self.dbs_dir = self.USR_HME+'/workflow_status'
        
    def run_rocotorun(self):
        for ctr_path in self.CTR_FLWS:
            # Gets case name from full .xml path
            cse = self.CSE_NME
            
            # Gets ensemble/control flow name from full .xml path
            ctr_flw = self.EXP_NME
            
            # Defines (most of) output command for rocotorun/rocotostat
            stat_output = f'{self.dbs_dir}/{cse}-{ctr_flw}'
        
            # Rocotorun command
            cmd = f'{self.RCT_HME}/bin/rocotorun -w {ctr_path} -d {stat_output}.store -v 10'
            os.system(cmd)
    
            # Rocotostat command (update workflow statuses each loop)
            self.run_rocotostat(self.RCT_HME, ctr_path, stat_output)
            
    def run_rocotostat(self, RCT_HME, ctr_path, stat_output):
            
        # Rocotostat command
        # -d used to be stat_output but was throwing a "dir not found" error
        cmd = f'{RCT_HME}/bin/rocotostat -w {ctr_path} -d {stat_output}.store '\
              f'-c all > {stat_output}_workflow_status.txt'
        os.system(cmd)
    
    def run_rocoto_boot_rewind(self, RCT_HME, CTR_FLWS, cycles, tasks, boot_rewind):
        """
        Function that combines both rocotoboot and rocotorewind (cuts down
        on one function).
        
        boot_rewind :: (str), only takes 'boot' or 'rewind', determines chosen rocoto
                            command.
        """
        for ctr_path in CTR_FLWS:
            cse = ctr_path.split('/')[-3]
            ctr_flw = ctr_path.split('/')[-2]
            stat_output = f'{self.dbs_dir}/{cse}-{ctr_flw}'
            
            for cycle in cycles:
                for tasks in tasks:
                    if boot_rewind == 'boot':
                        cmd = f'{RCT_HME}/bin/rocotoboot -w {ctr_path} -d {stat_output}.store -c {cycle} -t {task}'
                    elif boot_rewind == 'rewind':
                        cmd = f'{RCT_HME}/bin/rocotoboot -w {ctr_path} -d {stat_output}.store -c {cycle} -t {task}'
                    else: raise ValueError('Must supply "boot" or "rewind" to `boot_rewind`.')
                    
                    # Submits command
                    os.system(cmd)
                    
            # Rocotostat command (update workflow statuses each loop)
            self.run_rocotostat(RCT_HME, ctr_path, stat_output)

##################################################################################
# Execute the following lines as script
##################################################################################

# Sets end date for tomorrow at midnight
END = dt.combine(dt.now().date()+timedelta(1), dt.min.time())

# monitor and advance the jobs
if __name__ == '__main__':
    # monitor and advance the jobs
    while (dt.now() < END):
        Rocoto(USR_HME, RCT_HME, CSE_NME, EXP_NME).run_rocotorun()
        time.sleep(60)

##################################################################################
# end

