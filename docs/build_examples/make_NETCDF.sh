#!/bin/bash
#SBATCH --job-name=make_NETCDF
#SBATCH --time=1:00:00
#SBATCH --account=cwp168
#SBATCH --partition=cw3e-compute
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=128
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
export STACK="NETCDF_INTEL_INTELMPI"
export PREFIX="/expanse/nfs/cw3e/cwp168/SOFT_ROOT/${STACK}"
export HDF5="${PREFIX}/HDF5"
export NETCDF="${PREFIX}/NETCDF"
export NETCDFC="${PREFIX}/NETCDFC"
export NETCDFF="${PREFIX}/NETCDFF"
export PNETCDF="${PREFIX}/PNETCDF"
export LD_LIBRARY_PATH="${NETCDF}/lib:${HDF5}/lib:${LD_LIBRARY_PATH}"
export CPPFLAGS="-I${NETCDF}/include -I${HDF5}/include"
export LDFLAGS="-L${NETCDF}/lib -L${HDF5}/lib"

# make the NetCDF install directory
mkdir -p ${NETCDF}

################################################################################
# HDF5
################################################################################
## move to PREFIX and download HDF5
#cd ${PREFIX}
#wget https://github.com/HDFGroup/hdf5/releases/download/hdf5-1_10_11/hdf5-1_10_11.tar.gz
#rm -rf ${PREFIX}/hdf5-1.10.11
#tar -xvf hdf5-1_10_11.tar.gz
#mv hdfsrc hdf5-1.10.11
#rm -f hdf5-1_10_11.tar.gz
#
## configure / build HDF5
#export CC=icc
#export FC=ifort
#rm -rf ${HDF5}
#mkdir -p ${HDF5}
#cd ${PREFIX}/hdf5-1.10.11
#./configure --prefix=${HDF5} --enable-fortran --enable-shared
#make -j 8
#make install
#make check
#
################################################################################
# NetCDF C libs
################################################################################
## move to PREFIX and download NetCDF C libs
#cd ${PREFIX}
#wget https://github.com/Unidata/netcdf-c/archive/refs/tags/v4.9.2.tar.gz
#rm -rf ${PREFIX}/netcdf-c-4.9.2
#tar -xvf v4.9.2.tar.gz
#rm -f v4.9.2.tar.gz
#
## set compilers for NetCDF-C
#export CC=mpicc
#export FC=mpif77
#export F77=mpif77
#export F90=mpif90
#
## configure / build NetCDF4 C libs 
#rm -rf ${NETCDFC}
#mkdir -p ${NETCDFC}
#cd ${PREFIX}/netcdf-c-4.9.2
#./configure --prefix=${NETCDFC} --enable-netcdf4 --enable-shared
#make -j 8
#make install 
#make check
#
#for subdir in lib include bin; do
#  mkdir -p ${NETCDF}/${subdir}
#  for fname in $(ls ${NETCDFC}/${subdir} ); do
#    if [[ -f ${NETCDFC}/${subdir}/${fname} ]]; then
#      cmd="ln -sfr ${NETCDFC}/${subdir}/${fname} ${NETCDF}/${subdir}"
#    fi
#    printf "${cmd}\n"; eval "${cmd}"
#  done
#done
#
################################################################################
# NetCDF F libs
################################################################################
## move to PREFIX and download NetCDF F libs
#cd ${PREFIX}
#wget https://github.com/Unidata/netcdf-fortran/archive/refs/tags/v4.6.1.tar.gz
#rm -rf ${PREFIX}/netcdf-fortran-4.6.1
#tar -xvf v4.6.1.tar.gz
#rm -f v4.6.1.tar.gz
#
## set compilers for NetCDF-F
#export CC=mpicc
#export FC=mpif77
#export F77=mpif77
#export F90=mpif90
#
## configure and build NetCDF F libs
#rm -rf ${NETCDFF}
#mkdir -p ${NETCDFF}
#cd ${PREFIX}/netcdf-fortran-4.6.1
#./configure --prefix=${NETCDFF} --enable-shared
#make -j 4
#make install
#make check
#
#for subdir in lib include bin; do
#  mkdir -p ${NETCDF}/${subdir}
#  for fname in $(ls ${NETCDFF}/${subdir} ); do
#    if [[ -f ${NETCDFF}/${subdir}/${fname} ]]; then
#      cmd="ln -sfr ${NETCDFF}/${subdir}/${fname} ${NETCDF}/${subdir}"
#    fi
#    printf "${cmd}\n"; eval "${cmd}"
#  done
#done
#
################################################################################
# PNetCDF
################################################################################
## move to PREFIX and download PNetCDF
#cd ${PREFIX}
#wget https://parallel-netcdf.github.io/Release/pnetcdf-1.12.3.tar.gz
#rm -rf ${PREFIX}/pnetcdf-1.12.3
#tar -xvf pnetcdf-1.12.3.tar.gz 
#rm -f pnetcdf-1.12.3.tar.gz
#
## set compilers for PNetCDF
#export CC=icc
#export CXX=icpc
#export F77=ifort
#export FC=ifort
#export MPICC=mpicc
#export MPICXX=mpicxx
#export MPIF77=mpif77
#export MPIF90=mpif90
#
## configure and build PNetCDF
#rm -rf -p ${PNETCDF}
#mkdir -p ${PNETCDF}
#cd ${PREFIX}/pnetcdf-1.12.3
#./configure --prefix=${PNETCDF} --enable-shared 
#make -j 4
#make install
#make tests
#
# perform tests
#cd ${PREFIX}/pnetcdf-1.12.3
#make check
#make ptest
#make ptests
