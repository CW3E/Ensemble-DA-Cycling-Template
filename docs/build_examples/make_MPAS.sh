#!/bin/bash
#SBATCH --partition=cw3e-shared
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=16
#SBATCH -t 04:00:00
#SBATCH --job-name="compile_mpas"
#SBATCH --output="compile_mpas.%j.%N.out"
#SBATCH --error="compile_pmpas.%j.%N.err"
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
export MPAS_DIR=${SOFT_ROOT}/MPAS-Model
export LD_LIBRARY_PATH=${PIO}/lib:${LD_LIBRARY_PATH}

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

cd ${MPAS_DIR}
make clean CORE=init_atmosphere
make intel-mpi CORE=init_atmosphere PRECISION=single >& Make_init_atmosphere.out
make clean CORE=atmosphere
make intel-mpi CORE=atmosphere PRECISION=single >& Make_atmosphere.out

./build_tables

mv MP_THOMPSON_QRacrQG_DATA.DBL   src/core_atmosphere/physics/physics_wrf/files/
mv MP_THOMPSON_QRacrQS_DATA.DBL   src/core_atmosphere/physics/physics_wrf/files/
mv MP_THOMPSON_freezeH2O_DATA.DBL src/core_atmosphere/physics/physics_wrf/files/
mv MP_THOMPSON_QIautQS_DATA.DBL   src/core_atmosphere/physics/physics_wrf/files/
