#!/bin/bash
###############################################################################
# Compiler/MPI combination
###############################################################################
export HPC_COMPILER="intel/2022.2.1"
export HPC_MPI="cray-mpich/8.1.21"
export HPC_PYTHON="cray-python/3.9.13.1"

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

export CC=cc
export FC=ftn
export CXX=CC

export SERIAL_CC=cc
export SERIAL_FC=ftn
export SERIAL_CXX=CC

export MPI_CC=cc
export MPI_FC=ftn
export MPI_CXX=CC

# Build FMS with AVX2 flags
export STACK_fms_CFLAGS="-march=core-avx2 -lsci_intel_mpi"
export STACK_fms_FFLAGS="-march=core-avx2 -lsci_intel_mpi"
