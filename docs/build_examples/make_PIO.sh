#!/bin/bash
#SBATCH --partition=cw3e-shared
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=16
#SBATCH -t 04:00:00
#SBATCH --job-name="compile_pio"
#SBATCH --output="compile_pio.%j.%N.out"
#SBATCH --error="compile_pio.%j.%N.err"
#SBATCH --account=cwp157
#SBATCH --export=ALL

# Original code by Caroline Papadopoulos 01/18/2024
# Updated CJG 2024-05-02
# compile script for compiling PIO2_5_8  

# Root directory for software compiles
export SOFT_ROOT=/expanse/nfs/cw3e/cwp157/cgrudzien/JEDI-MPAS-Common-Case/SOFT_ROOT
export CC=mpiicc
export FC=mpiifort
export NETCDF=${SOFT_ROOT}/NETCDF
export PNETCDF=${SOFT_ROOT}/NETCDF
export PIO=${SOFT_ROOT}/ParallelIO-pio2_5_8

printf "PIO is compiled at \n"
printf "    ${PIO}"
rm -rf ${PIO}

# set up for environment for compile
# netcdf and intel
module load cpu/0.15.4
module load intel/19.1.1.217
module load intel-mpi/2019.8.254
module load netcdf-c/4.7.4
module load netcdf-fortran/4.5.3
module load netcdf-cxx/4.2
module load hdf5/1.10.6
module load parallel-netcdf/1.12.1
module load cmake/3.18.2

module list

cd ${SOFT_ROOT}
wget https://github.com/NCAR/ParallelIO/archive/refs/tags/pio2_5_8.tar.gz
tar -xf pio2_5_8.tar.gz
rm pio2_5_8.tar.gz
cd ${PIO}
mkdir build; cd build
cmake -DNetCDF_C_PATH=$NETCDF -DNetCDF_Fortran_PATH=$NETCDF -DPnetCDF_PATH=$PNETCDF -DCMAKE_INSTALL_PREFIX=${PIO} -DCMAKE_VERBOSE_MAKEFILE=1 -DPIO_ENABLE_TIMING=OFF ..
make install
make tests
ctest
