#!/bin/bash
#SBATCH --job-name=make_MPAS
#SBATCH --time=1:00:00
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
# libaries are installed wth PREFIX as root and library name following
###############################################################################
export SOFT_ROOT="/expanse/nfs/cw3e/cwp168/SOFT_ROOT"
export STACK="NETCDF_INTEL_INTELMPI"
export PREFIX="${SOFT_ROOT}/${STACK}"
export HDF5="${PREFIX}/HDF5"
export NETCDF="${PREFIX}/NETCDF"
export PNETCDF="${PREFIX}/PNETCDF"
export PIO="${PREFIX}/PIO"
export LD_LIBRARY_PATH="${PIO}/lib:${PNETCDF}/lib:${NETCDF}/lib:${HDF5}/lib:${LD_LIBRARY_PATH}"
export LD_RUN_PATH="${PIO}/lib:${PNETCDF}/lib:${NETCDF}/lib:${HDF5_PATH}/lib:${LD_RUN_PATH}"
export PATH="${NETCDF}/bin:${PATH}"

# set up for environment for compile
export MPAS_VER="8.0.1"
export MPAS_DIR="${PREFIX}/MPAS-Model-${MPAS_VER}"
export TARGET="intel-mpi"
export CC=mpiicc
export FC=mpiifort

###############################################################################
# Download MPAS
###############################################################################
cd ${PREFIX}
rm -rf ${MPAS_DIR}
rm -f v${MPAS_VER}.tar.gz
wget https://github.com/MPAS-Dev/MPAS-Model/archive/refs/tags/v${MPAS_VER}.tar.gz
tar -xvf v${MPAS_VER}.tar.gz
rm -f v${MPAS_VER}.tar.gz

###############################################################################
# Compile / Test PIO
###############################################################################
# make executables
cd ${MPAS_DIR}
make clean CORE=init_atmosphere
make ${TARGET} CORE=init_atmosphere PRECISION=single
make clean CORE=atmosphere
make ${TARGET} CORE=atmosphere PRECISION=single

# build MP tables
./build_tables
mv MP_THOMPSON_QRacrQG_DATA.DBL   src/core_atmosphere/physics/physics_wrf/files/
mv MP_THOMPSON_QRacrQS_DATA.DBL   src/core_atmosphere/physics/physics_wrf/files/
mv MP_THOMPSON_freezeH2O_DATA.DBL src/core_atmosphere/physics/physics_wrf/files/
mv MP_THOMPSON_QIautQS_DATA.DBL   src/core_atmosphere/physics/physics_wrf/files/

###############################################################################
