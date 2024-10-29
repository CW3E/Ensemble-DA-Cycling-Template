#!/bin/bash
#SBATCH --job-name=WRF_compile
#SBATCH --time=2:00:00
#SBATCH --account=cwp168
#SBATCH --partition=cw3e-compute
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=20
###############################################################################
# module loads
###############################################################################
module purge
module restore
module load slurm
module load cpu/0.17.3b
module load intel/19.1.3.304/6pv46so
module load intel-mkl/2020.4.304/vg6aq26
module load intel-mpi/2019.10.317/ezrfjne

###############################################################################
# all libaries will be installed to PREFIX as root with library name following
###############################################################################
export SOFT_ROOT="/expanse/nfs/cw3e/cwp168/SOFT_ROOT"
export STACK="NETCDF_INTEL_INTELMPI"
export PREFIX="${SOFT_ROOT}/${STACK}"
export HDF5="${PREFIX}/HDF5"
export NETCDF="${PREFIX}/NETCDF"
export PNETCDF="${PREFIX}/PNETCDF"
export LD_LIBRARY_PATH="${PNETCDF}/lib:${NETCDF}/lib:${HDF5}/lib:${LD_LIBRARY_PATH}"
export LD_RUN_PATH="${PNETCDF}/lib:${NETCDF}/lib:${HDF5_PATH}/lib:${LD_RUN_PATH}"
export PATH="${NETCDF}/bin:${PATH}"

# set WRF version and path
export WRF_VER=4.5.1
export WRFDA_DIR="${PREFIX}/WRFDA-${WRF_VER}"
export WRF_DIR="${PREFIX}/WRF-${WRF_VER}"

# WRFDA specific
export BUFR=1
export CRTM=1

###############################################################################
# Download WRF
###############################################################################
#cd ${PREFIX}
#rm -f v${WRF_VER}.tar.gz
#rm -rf ${WRFDA_DIR}
#wget https://github.com/wrf-model/WRF/releases/download/v${WRF_VER}/v${WRF_VER}.tar.gz
#tar -xvf v${WRF_VER}.tar.gz
#rm -f v${WRF_VER}.tar.gz
#mv WRFV${WRF_VER} ${WRFDA_DIR}
#
###############################################################################
# Configure WRF
###############################################################################
## NOTE: make changes to defaults and copy configure.wrf to configure.wrf-stable
## outside of the run step
## Expanse compile uses mpiifort / mpiicc options for intelmpi
#cd ${WRFDA_DIR}
#./configure wrfda
#
###############################################################################
# Compile WRF
###############################################################################
cd ${WRFDA_DIR}
./clean -a

# copy pre-generated configuration file and compile
cp configure.wrf-stable ./configure.wrf
./compile -j 20 all_wrfvar

###############################################################################
