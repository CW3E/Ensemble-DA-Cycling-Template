#!/bin/bash

# Original code by Caroline Papadopoulos 01/18/2024
# Updated CJG 2024-05-02

# Root directory for NETCDF dir
NETCDF_DIR=/expanse/nfs/cw3e/cwp168/SOFT_ROOT/NETCDF

printf "NETCDF lib / includ / bin will be created at \n"
printf "    ${NETCDF_DIR}"

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

# NOTE on Expanse when loading modules these environment variables get set
#NETCDF_FORTRANHOME=/cm/shared/apps/spack/cpu/opt/spack/linux-centos8-zen2/intel-19.1.1.217/netcdf-fortran-4.5.3-u7d3te2y4gdabhq2yapkiwheqh2abavy
#NETCDF_CHOME=/cm/shared/apps/spack/cpu/opt/spack/linux-centos8-zen2/intel-19.1.1.217/netcdf-c-4.7.4-4gdzlscxvyj3sawrn4itmlbh6hdgsck4
#NETCDF_CXXHOME=/cm/shared/apps/spack/cpu/opt/spack/linux-centos8-zen2/intel-19.1.1.217/netcdf-cxx-4.2-gp6vydehzi2py7dya6zp56hnvwuguovm
#PARALLEL_NETCDFHOME=/cm/shared/apps/spack/cpu/opt/spack/linux-centos8-zen2/intel-19.1.1.217/parallel-netcdf-1.12.1-wjjrfim5hzh65zfjur7crkf43qjx5deb

for directory in lib include bin; do
  mkdir -p ${NETCDF_DIR}/${directory}
  for netcdf_ver in ${NETCDF_CHOME} ${NETCDF_FORTRANHOME} ${NETCDF_CXXHOME} ${PARALLEL_NETCDFHOME} ; do
    if [ -d ${netcdf_ver}/${directory} ]; then
      for cur_file in $(ls ${netcdf_ver}/${directory}); do
        cmd="ln -sf ${netcdf_ver}/${directory}/${cur_file} ${NETCDF_DIR}/${directory}"
        printf "${cmd}\n"; eval "${cmd}"
      done
    fi
  done
done
