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
ulimit -s unlimited

# Defines expanse environment with intel / intelmpi
module purge
module restore
module load slurm
module load cpu/0.17.3b
module load intel/19.1.3.304/6pv46so
module load intel-mkl/2020.4.304/vg6aq26
module load intel-mpi/2019.10.317/ezrfjne
module load cmake/3.21.4/bpzre3q

# Sets up HPC-STACK
export HPC_OPT="${SOFT_ROOT}/${GSI_STACK}/hpc_stack_modules"
module use ${HPC_OPT}/modulefiles/core
module use ${HPC_OPT}/modulefiles/stack
module use ${HPC_OPT}/modulefiles/compiler/intel/19.1.3.304
module use ${HPC_OPT}/modulefiles/mpi/intel/19.1.3.304/intel-mpi/2019.10.317
module load hpc/1.2.0
module load hpc-intel/19.1.3.304
module load hpc-intel-mpi/2019.10.317
module load cmake/3.24.2
module load bufr/11.6.0
module load ip/3.3.3
module load sfcio/1.4.1
module load sigio/2.3.2
module load sp/2.3.3
module load w3nco/2.4.1
module load bacio/2.4.1
module load crtm/2.3.0
module load hdf5/1.10.11
module load netcdf/4.9.2
module load w3emc/2.9.2
module load nemsio/2.5.4
module load wrf_io/1.2.0
module load ncio/1.0.0
module load ncdiag/1.0.0

###############################################################################
