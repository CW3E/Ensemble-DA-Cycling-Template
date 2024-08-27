#!/bin/bash
#SBATCH --job-name=make_PIO
#SBATCH --time=2:00:00
#SBATCH --account=cwp168
#SBATCH --partition=cw3e-shared
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=8
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
module load cmake/3.21.4/bpzre3q

###############################################################################
# libaries are installed wth PREFIX as root and library name following
###############################################################################
export STACK="NETCDF_INTEL_INTELMPI"
export PREFIX="/expanse/nfs/cw3e/cwp168/SOFT_ROOT/${STACK}"
export HDF5="${PREFIX}/HDF5"
export NETCDF="${PREFIX}/NETCDF"
export PNETCDF="${PREFIX}/PNETCDF"
export LD_LIBRARY_PATH="${PNETCDF}/lib:${NETCDF}/lib:${HDF5}/lib:${LD_LIBRARY_PATH}"
export LD_RUN_PATH="${PNETCDF}/lib:${NETCDF}/lib:${HDF5_PATH}/lib:${LD_RUN_PATH}"
export PATH="${NETCDF}/bin:${PATH}"
export PIO="${PREFIX}/PIO"

###############################################################################
# Download PIO
###############################################################################
cd ${PREFIX}
rm -rf ${PIO}
rm -rf ParallelIO-pio2_5_8
rm -f pio2_5_8.tar.gz
wget https://github.com/NCAR/ParallelIO/archive/refs/tags/pio2_5_8.tar.gz
tar -xvf pio2_5_8.tar.gz
rm pio2_5_8.tar.gz

###############################################################################
# Compile / Test PIO
###############################################################################
cd ${PREFIX}/ParallelIO-pio2_5_8
mkdir build; cd build

# set compilers
export CC=mpicc
export FC=mpif90

cmake -DNetCDF_C_PATH=$NETCDF -DNetCDF_Fortran_PATH=$NETCDF \
  -DPnetCDF_PATH=$PNETCDF -DCMAKE_INSTALL_PREFIX=${PIO} \
  -DCMAKE_VERBOSE_MAKEFILE=1 -DPIO_ENABLE_TIMING=OFF ..
make -j 4
make install
make tests

cd ${PREFIX}/ParallelIO-pio2_5_8/build
ctest
