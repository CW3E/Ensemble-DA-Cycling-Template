#!/bin/bash
###############################################################################
# Compiler/MPI combination
###############################################################################
export HPC_COMPILER="intel/19.1.3.304"
export HPC_MPI="intel-mpi/2019.10.317"
export HPC_PYTHON="python/3.6.8"

# Build options
export USE_SUDO=N
export PKGDIR=pkg
export LOGDIR=log
export OVERWRITE=Y
export NTHREADS=8
export MAKE_CHECK=N
export MAKE_VERBOSE=N
export MAKE_CLEAN=N
export DOWNLOAD_ONLY=N
export STACK_EXIT_ON_FAIL=Y
export WGET="wget -nv"

export CC=icc
export FC=ifort
export CXX=icpc

export SERIAL_CC=icc
export SERIAL_FC=ifort
export SERIAL_CXX=icpc

export MPI_CC=mpiicc
export MPI_FC=mpiifort
export MPI_CXX=mpiicpc

# Build FMS with AVX2 flags
export STACK_fms_CFLAGS="-march=core-avx2"
export STACK_fms_FFLAGS="-march=core-avx2"
