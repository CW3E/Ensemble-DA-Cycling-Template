#!/bin/bash
##################################################################################
# Description
##################################################################################
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
##################################################################################
# COMPUTER-DEPENDENT ITEMS
##################################################################################
# Full path of framework git clone
export CLNE_ROOT="/expanse/nfs/cw3e/cwp168/Ensemble-DA-Cycling-Template"

# Root directory of software stack executables
export SOFT_ROOT="/expanse/nfs/cw3e/cwp168/SOFT_ROOT"

# Root directory of simulation forcing data
export DATA_ROOT="/expanse/nfs/cw3e/cwp168/DATA"

# Root directory of grib data data
export GRIB_ROOT="${DATA_ROOT}/GRIB"

# Root directory of simulation_io
export WORK_ROOT="/expanse/lustre/scratch/cgrudzien/temp_project/cwp168/SIMULATION_IO"

##################################################################################
# WORKFLOW SETTINGS
##################################################################################
# Root directory of Cylc installation
export CYLC_ROOT="${CLNE_ROOT}/cylc"
export PATH="${CYLC_ROOT}:${PATH}"

# Location of Micromamba cylc environment
export CYLC_HOME_ROOT_ALT="${CYLC_ROOT}/Micromamba/envs"

# Cylc environment name
export CYLC_ENV_NAME="cylc-8.3"

# Set Cylc global.cylc configuration path to template
export CYLC_CONF_PATH="${CYLC_ROOT}/global.cylc"

# Cylc auto-completion prompts
if [[ $- =~ i && -f ${CYLC_ROOT}/cylc-completion.bash ]]; then
    . ${CYLC_ROOT}/cylc-completion.bash
fi

# Root directory of experiment configuration files
export CFG_ROOT="${CLNE_ROOT}/simulation_settings"

# Root directory of workflow framework scripts
export SCRIPTS="${CLNE_ROOT}/scripts"

# Root directory of task driver scripts
export DRIVERS="${SCRIPTS}/drivers"

# Root directory of utility scripts for hacking rocoto to work
export UTILITY="${SCRIPTS}/utilities"

# Root directory of software stack environment scripts
export ENVRNMTS="${SCRIPTS}/environments"

##################################################################################
# SOFTWARE SETTINGS 
##################################################################################
# System scheduler
export SCHED="slurm"

# MPI execute command
export MPI_RUN="mpiexec"

# Full path to WRF software environment sourced file
export WRF_CNST="${ENVRNMTS}/WRF_constants.sh" 

# Full path to MPAS software environment sourced file
export MPAS_CNST="${ENVRNMTS}/MPAS_constants.sh"

# Root directory of WRF clean build
export WRF_ROOT="${SOFT_ROOT}/WRF"

# Root directory of WPS clean build
export WPS_ROOT="${SOFT_ROOT}/WPS"

# Root directory of MPAS clean build
export MPAS_ROOT="${SOFT_ROOT}/MPAS-Model"

# Micromamba settings
export MAMBA_EXE="${CYLC_ROOT}/Micromamba/micromamba"
export MAMBA_ROOT_PREFIX="${CYLC_ROOT}/Micromamba"
__mamba_setup="$("$MAMBA_EXE" shell hook --shell bash --root-prefix "$MAMBA_ROOT_PREFIX" 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__mamba_setup"
else
    alias micromamba="$MAMBA_EXE"  # Fallback on help from mamba activate
fi
unset __mamba_setup

##################################################################################
