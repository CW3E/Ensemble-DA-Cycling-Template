#!/bin/bash

# set compiler and NETCDF definitions
export NETCDF="/expanse/nfs/cw3e/cwp168/SOFT_ROOT/NETCDF"

# netcdf and intel
module purge
module restore
module load cpu/0.15.4
module load intel/19.1.1.217
module load intel-mpi/2019.8.254
module load netcdf-c/4.7.4
module load netcdf-fortran/4.5.3
module load netcdf-cxx/4.2

# Set log report
export log_file="compile_expanse_2024-05-06.log"

# Set up WRF directory / configure
echo "setting up compile directory" > $log_file 2>&1
./clean -a >> $log_file  2>&1

# uncomment for fresh configuration file
#./configure 

# copy pre-generated configuration file
module list >> $log_file
cp configure.wrf-4.5.1_expanse_2024-05-06 ./configure.wrf >> $log_file 2>&1

echo "Begin wrf compile" >> $log_file 2>&1
# Uncomment to run compile, can be tested to this point
# for debugging without this step
./compile -j 20 em_real >> $log_file 2>&1

echo "End of wrf compile" `date` >> $log_file 2>&1
