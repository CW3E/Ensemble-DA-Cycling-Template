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
# HPC SYSTEM PATHS
##################################################################################
# Root directory of software stacks
export SOFT_ROOT="/expanse/nfs/cw3e/cwp168/SOFT_ROOT"

# WRF / MPAS software stack name
export MOD_STACK="NETCDF_INTEL_INTELMPI"

# WRF / MPAS stack configuration file
export MOD_ENV="${HOME}/settings/sites/expanse-cwp168/${MOD_STACK}.sh"

# Root directory of WRF clean build
export WRF_ROOT="${SOFT_ROOT}/${MOD_STACK}/WRF-4.5.1"

# Root directory of WRFDA clean build
export WRFDA_ROOT="${SOFT_ROOT}/${MOD_STACK}/WRFDA-4.5.1"

# Root directory of WPS clean build
export WPS_ROOT="${SOFT_ROOT}/${MOD_STACK}/WPS-4.5"

# Root directory of MPAS clean build
export MPAS_ROOT="${SOFT_ROOT}/${MOD_STACK}/MPAS-Model-8.2.1"

# GSI software stack name
export GSI_STACK="NOAA_HPC_STACK"

# GSI stack configuration file
export GSI_ENV="${HOME}/settings/sites/expanse-cwp168/${GSI_STACK}.sh"

# Path to GSI executable
export GSI_EXE="${SOFT_ROOT}/${GSI_STACK}/GSI/build/bin/gsi.x"

# Root directory of simulation forcing data
export DATA_ROOT="/expanse/nfs/cw3e/cwp168/DATA"

# Root directory of grib data data
export GRIB_ROOT="${DATA_ROOT}/GRIB"

# Root directory of observations
export OBS_ROOT="${DATA_ROOT}/OBS"

# Root directory of static ensemble simulations used for background error
export ENS_ROOT="${DATA_ROOT}/ENSEMBLE"

# Root directory CRTM coefficients for GSI analysis
export CRTM_ROOT="${DATA_ROOT}/CRTM_v2.3.0/Big_Endian"

# Root directory of simulation_io
export WORK_ROOT="/expanse/lustre/scratch/cgrudzien/temp_project/cwp168/SIMULATION_IO"

##################################################################################
# HPC SYSTEM WORKLOAD MANAGER PARAMETERS
##################################################################################
# System scheduler
export SCHED="slurm"

# Define additional sub-cases for system platform, currently only includes penguin
# define as empty string if not needed
export SYS_TYPE=""

# MPI execute command
export MPIRUN="mpiexec"

# Project billing account
export PROJECT="cwp168"

# Compute queue for standard mpi jobs
export PART_CMP="cw3e-compute"

# Debug queue for small / rapid parallel jobs
export PART_DBG="cw3e-compute"

# Serial queue for non-mpi jobs
export PART_SRL="cw3e-shared"

##################################################################################
