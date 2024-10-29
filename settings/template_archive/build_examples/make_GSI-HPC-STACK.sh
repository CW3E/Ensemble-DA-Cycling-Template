#!/bin/bash
###############################################################################
# module loads
###############################################################################
module purge
module restore
module load slurm
module load cpu/0.17.3b
module load intel/19.1.3.304/6pv46so
module load intel-mpi/2019.10.317/ezrfjne
module load intel-mkl/2020.4.304/vg6aq26
module load cmake/3.21.4/bpzre3q

###############################################################################
# EXPORT HPC STACK / WORKFLOW VARIABLES
###############################################################################
export USR_HME="/expanse/nfs/cw3e/cwp168/Ensemble-DA-Cycling-Template"
export SITE="expanse-cwp168"
export SOFT_ROOT="/expanse/nfs/cw3e/cwp168/SOFT_ROOT"
export HPC_STACK_PATH="${SOFT_ROOT}/NOAA_HPC_STACK"
export HPC_OPT="${HPC_STACK_PATH}/hpc_stack_modules"
export HPC_STACK_VERSION="hpc-stack-v1.2.0"
export HPC_STACK_ROOT="${HPC_STACK_PATH}/${HPC_STACK_VERSION}"

################################################################################
# SET UP HPC STACK CLONE
################################################################################
#rm -rf ${HPC_STACK_ROOT}
#mkdir -p ${HPC_OPT}
#cd ${HPC_STACK_PATH}; git clone https://github.com/NOAA-EMC/hpc-stack.git
#mv hpc-stack ${HPC_STACK_VERSION}
#cd ${HPC_STACK_ROOT}
#git checkout fa370370f912fe491a53aad26e0266ce7552eee7
#
################################################################################
# COPY LOCAL HPC STACK CONFIG AND BUILD
################################################################################
#cd ${HPC_STACK_ROOT}
#CFG="${USR_HME}/settings/sites/${SITE}/config_NOAA_HPC_STACK.sh"
#YML="${USR_HME}/settings/sites/${SITE}/config_NOAA_HPC_STACK.yaml"
#./setup_modules.sh -p ${HPC_OPT} -c ${CFG}
#./build_stack.sh -p ${HPC_OPT} -c ${CFG} -y ${YML} -m
#
################################################################################
# SET UP GSI CLONE
################################################################################
#rm -rf ${HPC_STACK_PATH}/GSI
#cd ${HPC_STACK_PATH}; git clone https://github.com/NOAA-EMC/GSI.git
#cd GSI; git checkout 8735959064c3661a85b16328cb0bfc0cd546bc09
#
################################################################################
# SET UP HPC STACK AND COMPILE GSI
################################################################################
# EDIT CMakeList BEFORE THIS STEP
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

cd ${HPC_STACK_PATH}/GSI
mkdir build; cd build
cmake  -DGSI_MODE=Regional -DENKF_MODE=WRF ../
make -j 4

################################################################################
