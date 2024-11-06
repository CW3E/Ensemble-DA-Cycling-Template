#!/bin/bash
###############################################################################
# module loads
###############################################################################
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

###############################################################################
# EXPORT HPC STACK / WORKFLOW VARIABLES
###############################################################################
export USR_HME="/p/home/cgrudz/Ensemble-DA-Cycling-Template"
export SITE="narwhal"
export SOFT_ROOT="/p/home/cgrudz/SOFT_ROOT"
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
#
################################################################################
# BUILD HPC Stack
################################################################################
#cd ${HPC_STACK_ROOT}
#CFG="${USR_HME}/settings/sites/${SITE}/config_NOAA_HPC_STACK.sh"
#YML="${USR_HME}/settings/sites/${SITE}/config_NOAA_HPC_STACK.yaml"
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
# NOTE: THIS IS CURRENTLY SOURCING INCORRECT MODULES FOR COMPILERS / MPI
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

cd ${HPC_STACK_PATH}/GSI
mkdir build; cd build
cmake  -DGSI_MODE=Regional -DENKF_MODE=WRF ../
make -j 4

################################################################################
