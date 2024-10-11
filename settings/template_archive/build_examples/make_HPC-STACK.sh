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
module load cmake/3.21.4/bpzre3q

###############################################################################
# EXPORT HPC STACK / WORKFLOW VARIABLES
###############################################################################
export USR_HME="/expanse/nfs/cw3e/cwp168/Ensemble-DA-Cycling-Template"
export SITE="expanse-cwp168"
export SOFT_ROOT="/expanse/nfs/cw3e/cwp168/SOFT_ROOT"
export STACK_PATH="${SOFT_ROOT}/NOAA_HPC_STACK"
export HPC_OPT="${STACK_PATH}/hpc_stack_modules"
export HPC_STACK_VERSION="hpc-stack-v1.2.0"
export HPC_STACK_ROOT="${STACK_PATH}/${HPC_STACK_VERSION}"

################################################################################
# SET UP HPC STACK CLONE
################################################################################
rm -rf ${HPC_STACK_ROOT}
mkdir -p ${HPC_OPT}
cd ${STACK_PATH}; git clone https://github.com/NOAA-EMC/hpc-stack.git
mv hpc-stack ${HPC_STACK_VERSION}
cd ${HPC_STACK_ROOT}
git checkout fa370370f912fe491a53aad26e0266ce7552eee7

################################################################################
# COPY LOCAL CONFIG AND BUILD
################################################################################
cd ${HPC_STACK_ROOT}
CFG="${USR_HME}/settings/sites/${SITE}/config_NOAA_HPC_STACK.sh"
YML="${USR_HME}/settings/sites/${SITE}/config_NOAA_HPC_STACK.yaml"
./setup_modules.sh -p ${HPC_OPT} -c ${CFG}
./build_stack.sh -p ${HPC_OPT} -c ${CFG} -y ${YML} -m

################################################################################
