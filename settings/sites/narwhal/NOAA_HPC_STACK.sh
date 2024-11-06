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

module swap PrgEnv-cray PrgEnv-intel/8.3.3
module load cray-python/3.9.13.1
export MAMBA_EXE='/p/home/cgrudz/SOFT_ROOT/Micromamba/micromamba';
export MAMBA_ROOT_PREFIX='/p/home/cgrudz/SOFT_ROOT/Micromamba';
__mamba_setup="$("$MAMBA_EXE" shell hook --shell bash --root-prefix "$MAMBA_ROOT_PREFIX" 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__mamba_setup"
else
    alias micromamba="$MAMBA_EXE"  # Fallback on help from mamba activate
fi
unset __mamba_setup
# <<< mamba initialize <<<

alias mm="micromamba"
micromamba activate lmod

# Sets up HPC-STACK
export HPC_OPT="${SOFT_ROOT}/${GSI_STACK}/hpc_stack_modules"
module use ${HPC_OPT}/modulefiles/core
module use ${HPC_OPT}/modulefiles/stack
module use ${HPC_OPT}/modulefiles/compiler/intel/2022.2.1
module use ${HPC_OPT}/modulefiles/mpi/intel/2022.2.1/cray-mpich/8.1.21
module load hpc/1.2.0
module load hpc-intel/2022.2.1 
module load hpc-cray-mpich/8.1.21
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
