#!/bin/bash
#SBATCH --job-name=WPS_compile
#SBATCH --time=0:30:00
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

############################################################################### # all libaries will be installed to PREFIX as root with library name following
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
export WRF_DIR="${PREFIX}/WRF-${WRF_VER}"

# set WPS version and path
export WPS_VER=4.5
export WPS_DIR="${PREFIX}/WPS-${WPS_VER}"

###############################################################################
# Download WPS
###############################################################################
#cd ${PREFIX}
#rm -f v4.5.tar.gz
#wget https://github.com/wrf-model/WPS/archive/refs/tags/v4.5.tar.gz
#tar -xvf v4.5.tar.gz
#rm -f v4.5.tar.gz
#
###############################################################################
# Configure WRF
###############################################################################
## NOTE: make changes to defaults and copy configure.wps to configure.wps-stable
## outside of the run step
## Expanse compile uses mpiifort / mpiicc options for intelmpi
## ifort -qopenmp / mpiifort -qopenmp options for parallel executables with
## openmp
#cd ${WPS_DIR}
#./configure --build-grib2-libs
#
###############################################################################
# Compile WRF
###############################################################################
cd ${WPS_DIR}
./clean -a

# copy pre-generated configuration file and compile
cp configure.wps-stable ./configure.wps
./compile
