#!/bin/bash
##########################################################################
# Description
##########################################################################
# This script localizes several tools specific to this platform.  It
# should be called by other workflow scripts to define common
# variables.
#
##########################################################################
# License Statement:
##########################################################################
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
##########################################################################
# Using GMT time zone for time computations
export TZ="GMT"

# defines expanse environment
module purge
module restore

# intel
module purge
module restore
module load cpu/0.15.4
module load intel/19.1.1.217
module load intel-mpi/2019.8.254
module load netcdf-c/4.7.4
module load netcdf-fortran/4.5.3
module load netcdf-cxx/4.2
module load hdf5/1.10.6
module load parallel-netcdf/1.12.1
export NETCDF=/home/cpapadop/Software/MPAS/NETCDF
export PNETCDF=/home/cpapadop/Software/MPAS/NETCDF
export PIO=/home/cpapadop/Software/MPAS/PIO/ParallelIO-pio2_5_8
export MPAS_EXTERNAL_LIBS="-L${HDF5HOME}/lib -lhdf5_hl -lhdf5 -ldl -lz"
export MPAS_EXTERNAL_INCLUDES="-I${HDF5HOME}/include"

# create variables for namelist templates / switches
CYCLING=[Cc][Yy][Cc][Ll][Ii][Nn][Gg]
EQUAL=[[:blank:]]*=[[:blank:]]*
LATERAL=[Ll][Aa][Tt][Ee][Rr][Aa][Ll]
LOWER=[Ll][Oo][Ww][Ee][Rr]
RESTART=[Rr][Ee][Ss][Tt][Aa][Rr][Tt]
REALEXE=[Rr][Ee][Aa][Ll][Ee][Xx][Ee]
NO=[Nn][Oo]
YES=[Yy][Ee][Ss]
