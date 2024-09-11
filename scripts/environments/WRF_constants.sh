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
##########################################################################
# Using GMT time zone for time computations
export TZ="GMT"
ulimit -s unlimited

# Defines expanse environment with intel / intelmpi
module purge
module restore
module load slurm
module load cpu/0.17.3b
module load intel/19.1.3.304/6pv46so
module load intel-mkl/2020.4.304/vg6aq26
module load intel-mpi/2019.10.317/ezrfjne

export SOFT_ROOT="/expanse/nfs/cw3e/cwp168/SOFT_ROOT"
export STACK="NETCDF_INTEL_INTELMPI"
export PREFIX="${SOFT_ROOT}/${STACK}"
export HDF5="${PREFIX}/HDF5"
export NETCDF="${PREFIX}/NETCDF"
export PNETCDF="${PREFIX}/PNETCDF"
export LD_LIBRARY_PATH="${PNETCDF}/lib:${NETCDF}/lib:${HDF5}/lib:${LD_LIBRARY_PATH}"
export LD_RUN_PATH="${PNETCDF}/lib:${NETCDF}/lib:${HDF5_PATH}/lib:${LD_RUN_PATH}"
export PATH="${NETCDF}/bin:${PATH}"

# create variables for namelist templates / switches
export CYCLING=[Cc][Yy][Cc][Ll][Ii][Nn][Gg]
export LATERAL=[Ll][Aa][Tt][Ee][Rr][Aa][Ll]
export LOWER=[Ll][Oo][Ww][Ee][Rr]
export RESTART=[Rr][Ee][Ss][Tt][Aa][Rr][Tt]
export REALEXE=[Rr][Ee][Aa][Ll][Ee][Xx][Ee]
export NO=[Nn][Oo]
export YES=[Yy][Ee][Ss]
export END=[Ee][Nn][Dd]
export SLURM=[Ss][Ll][Uu][Rr][Mm]
export PBS=[Pp][Bb][Ss]

# Defines YYYYMMDDHH iso regular expression
export ISO_RE=^[0-9]{10}$

# Defines regular expression for arbitrary integers
export INT_RE=^[0-9]+$
