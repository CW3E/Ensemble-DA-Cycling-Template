#!/bin/bash
##################################################################################
# Description
##################################################################################
# This driver script is a major fork and rewrite of the Rocoto workflow
# ungrib driver script of Christopher Harrop Licensed for modification /
# redistribution in the License Statement below.
#
# The purpose of this fork is to work in a Rocoto-based
# Observation-Analysis-Forecast cycle with GSI for data denial
# experiments. Naming conventions in this script have been smoothed
# to match a companion major fork of the standard gsi.ksh
# driver script provided in the GSI tutorials.
#
# One should write machine specific options for the WPS environment
# in a WPS_constants.sh script to be sourced in the below.  Variable
# aliases in this script are based on conventions defined in the
# WPS_constants.sh and the control flow .xml driving this script.
#
##################################################################################
# License Statement:
##################################################################################
# Copyright 2022 Colin Grudzien, cgrudzien@ucsd.edu
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
#     Unless required by applicable law or agreed to in writing, software
#     distributed under the License is distributed on an "AS IS" BASIS,
#     WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#     See the License for the specific language governing permissions and
#     limitations under the License.
#
# In addition to the Apache 2.0 License terms above, this software is
# furthermore licensed under the conditions of the source software from
# which this fork was derived.  This License statement is included
# in the following:
#
#     Open Source License/Disclaimer, Forecast Systems Laboratory
#     NOAA/OAR/FSL, 325 Broadway Boulder, CO 80305
#
#     This software is distributed under the Open Source Definition,
#     which may be found at http://www.opensource.org/osd.html.
#
#     In particular, redistribution and use in source and binary forms,
#     with or without modification, are permitted provided that the
#     following conditions are met:
#
#     - Redistributions of source code must retain this notice, this
#     list of conditions and the following disclaimer.
#
#     - Redistributions in binary form must provide access to this
#     notice, this list of conditions and the following disclaimer, and
#     the underlying source code.
#
#     - All modifications to this software must be clearly documented,
#     and are solely the responsibility of the agent making the
#     modifications.
#
#     - If significant modifications or enhancements are made to this
#     software, the FSL Software Policy Manager
#     (softwaremgr@fsl.noaa.gov) should be notified.
#
#     THIS SOFTWARE AND ITS DOCUMENTATION ARE IN THE PUBLIC DOMAIN
#     AND ARE FURNISHED "AS IS."  THE AUTHORS, THE UNITED STATES
#     GOVERNMENT, ITS INSTRUMENTALITIES, OFFICERS, EMPLOYEES, AND
#     AGENTS MAKE NO WARRANTY, EXPRESS OR IMPLIED, AS TO THE USEFULNESS
#     OF THE SOFTWARE AND DOCUMENTATION FOR ANY PURPOSE.  THEY ASSUME
#     NO RESPONSIBILITY (1) FOR THE USE OF THE SOFTWARE AND
#     DOCUMENTATION; OR (2) TO PROVIDE TECHNICAL SUPPORT TO USERS.
#
#     Script Name: ungrib.ksh
#
#          Author: Christopher Harrop
#                  Forecast Systems Laboratory
#                  325 Broadway R/FST
#                  Boulder, CO. 80305
#
#        Released: 10/30/2003
#         Version: 1.0
#         Changes: None
#
##################################################################################
# Preamble
##################################################################################
# uncomment to run verbose for debugging / testing
set -x

if [ ! -x "${CNST}" ]; then
  echo "ERROR: constants file ${CNST} does not exist or is not executable."
  exit 1
fi

# Read constants into the current shell
. ${CNST}

##################################################################################
# Make checks for ungrib settings
##################################################################################
# Options below are defined in workflow variables
#
# MEMID         = Ensemble ID index, 00 for control, i > 0 for perturbation
# BKG_DATA      = String case variable for supported inputs: GFS, GEFS currently
# FCST_LEN      = Total length of WRF forecast simulation in HH
# DATA_INT      = Interval of input data in HH
# STRT_TIME     = Simulation start time in YYMMDDHH
# BKG_STRT_TIME = Background simulation start time in YYMMDDHH
# IF_ECMWF_ML   = "Yes" or "No" switch to compute ECMWF coefficients for
#                 initializing with model level data, case insensitive
#
##################################################################################

if [ ! "${MEMID}"  ]; then
  echo "ERROR: ensemble index \${MEMID} is not defined."
  exit 1
fi

# ensure padding to two digits is included
memid=`printf %02d $(( 10#${MEMID} ))`

if [ ! "${BKG_DATA}"  ]; then
  echo "ERROR: \${BKG_DATA} is not defined."
  exit 1
fi

if [[ "${BKG_DATA}" != "GFS" &&  "${BKG_DATA}" != "GEFS" ]]; then
  msg="ERROR: \${BKG_DATA} must equal 'GFS' or 'GEFS'"
  msg+=" as currently supported inputs."
  echo ${msg}
  exit 1
fi

if [ ! "${FCST_LEN}" ]; then
  echo "ERROR: \${FCST_LEN} is not defined."
  exit 1
fi

if [ ! "${DATA_INT}" ]; then
  echo "ERROR: \${DATA_INT} is not defined."
  exit 1
fi

if [ ! "${STRT_TIME}" ]; then
  echo "ERROR: \${STRT_TIME} is not defined."
  exit 1
fi

if [ ! "${BKG_STRT_TIME}" ]; then
  echo "ERROR: \${BKG_STRT_TIME} is not defined."
  exit 1
fi

# Convert STRT_TIME from 'YYYYMMDDHH' format to strt_time Unix date format
if [ ${#STRT_TIME} -ne 10 ]; then
  echo "ERROR: \${STRT_TIME}, '${STRT_TIME}', is not in 'YYYYMMDDHH' format." 
  exit 1
else
  strt_time="${STRT_TIME:0:8} ${STRT_TIME:8:2}"
fi
strt_time=`date -d "${strt_time}"`
end_time=`date -d "${strt_time} ${FCST_LEN} hours"`

# define BKG_STRT_TIME date string wihtout HH
bkg_strt_date=${BKG_STRT_TIME:0:8}
bkg_strt_hh=${BKG_STRT_TIME:8:2}

if [[ ${IF_ECMWF_ML} != ${YES} && ${IF_ECMWF_ML} != ${NO} ]]; then
  echo "ERROR: \$IF_ECMWF_ML must equal 'Yes' or 'No' (case insensitive)."
  exit 1
fi

##################################################################################
# Define ungrib workflow dependencies
##################################################################################
# Below variables are defined in workflow variables
#
# WPS_ROOT  = Root directory of a "clean" WPS build
# EXP_CNFG  = Root directory containing sub-directories for namelists
#             vtables, geogrid data, GSI fix files, etc.
# CYCLE_HME = Start time named directory for cycling data containing
#             bkg, wpsprd, realprd, wrfprd, wrfdaprd, gsiprd, enkfprd
# DATA_ROOT = Directory for all forcing data files, including grib files,
#             obs files, etc.
#
##################################################################################

if [ ! "${WPS_ROOT}" ]; then
  echo "ERROR: \${WPS_ROOT} is not defined."
  exit 1
fi

if [ ! -d "${WPS_ROOT}" ]; then
  echo "ERROR: WPS_ROOT directory ${WPS_ROOT} does not exist."
  exit 1
fi

if [ ! -d ${EXP_CNFG} ]; then
  echo "ERROR: \${EXP_CNFG} directory ${EXP_CNFG} does not exist."
  exit 1
fi

if [ -z ${CYCLE_HME} ]; then
  echo "ERROR: \${CYCLE_HME} directory name is not defined."
  exit 1
fi

if [ ! -d ${DATA_ROOT} ]; then
  echo "ERROR: \${DATA_ROOT} directory ${DATA_ROOT} does not exist."
  exit 1
fi

##################################################################################
# Begin pre-unrib setup
##################################################################################
# The following paths are relative to workflow supplied root paths
#
# work_root     = Working directory where ungrib_exe runs and outputs
# wps_dat_files = All file contents of clean WPS directory
#                 namelists and input data will be linked from other sources
# ungrib_exe    = Path and name of working executable
# vtable        = Path and name of variable table
# grib_dataroot = Path to the raw data to be processed
#
##################################################################################

work_root=${CYCLE_HME}/wpsprd/ens_${memid}
mkdir -p ${work_root}
cd ${work_root}

wps_dat_files=(${WPS_ROOT}/*)
ungrib_exe=${WPS_ROOT}/ungrib.exe

if [ ! -x ${ungrib_exe} ]; then
  echo "ERROR: ${ungrib_exe} does not exist, or is not executable."
  exit 1
fi

# Make links to the WPS DAT files
for file in ${wps_dat_files[@]}; do
  ln -sf ${file} ./
done

# Remove any previous Vtables
rm -f Vtable

# Check to make sure the variable table is available
vtable=${EXP_CNFG}/variable_tables/Vtable.${BKG_DATA}
if [ ! -r ${vtable} ]; then
  msg="ERROR: a 'Vtable' should be provided at location ${vtable},"
  msg+=" Vtable not found."
  echo ${msg}
  exit 1
else
  ln -sf ${vtable} ./Vtable
fi

# check to make sure the grib_dataroot exists and is non-empty
grib_dataroot=${DATA_ROOT}/gribbed/${BKG_DATA}
if [! -d ${grib_dataroot} ]; then
  echo "ERROR: the directory ${grib_dataroot} does not exist."
  exit 1
fi

if [ `ls -l ${grib_dataroot} | wc -l` -lt 2 ]; then
  msg="ERROR: ${grib_dataroot} is emtpy, put grib data in this location"
  msg+=" for preprocessing."
  echo ${msg}
  exit 1
fi

# link the grib data to the working directory
link_cmnd="./link_grib.csh ${grib_dataroot}/${bkg_strt_date}"
if [[ ${BKG_DATA} = "GFS" ]]; then
  # GFS has single control trajectory
  fnames="gfs.0p25.${BKG_STRT_TIME}.f*"
elif [[ ${BKG_DATA} = "GEFS" ]]; then
  if [[ ${memid} = "00" ]]; then
    # 00 perturbation is the control forecast
    fnames="gec${memid}.t${bkg_strt_hh}z.pgrb*"
  else
    # all other are control forecast perturbations
    fnames="gep${memid}.t${bkg_strt_hh}z.pgrb*"
  fi
fi

# link gribbed forecast data
eval ${link_cmnd}/${fnames}

##################################################################################
#  Build WPS namelist
##################################################################################
# Copy the wrf namelist from the static dir
# NOTE: THIS WILL BE MODIFIED DO NOT LINK TO IT
cp ${EXP_CNFG}/namelists/namelist.wps ./

# define start / end time patterns for namelist.wps
strt_dt=`date +%Y-%m-%d_%H:%M:%S -d "${strt_time}"`
end_dt=`date +%Y-%m-%d_%H:%M:%S -d "${end_time}"`

in_sd="\(${START}_${DATE}\)${EQUAL}'${YYYYMMDD_HHMMSS}'.*"
out_sd="\1 = '${strt_dt}','${strt_dt}','${strt_dt}'"
in_ed="\(${END}_${DATE}\)${EQUAL}'${YYYYMMDD_HHMMSS}'.*"
out_ed="\1 = '${end_dt}','${end_dt}','${end_dt}'"

# Update the start and end date in namelist (propagates settings to three domains)
cat namelist.wps \
  | sed "s/${in_sd}/${out_sd}/" \
  | sed "s/${in_ed}/${out_ed}/" \
  > namelist.wps.new
mv namelist.wps.new namelist.wps

# Update interval in namelist
(( data_interval_sec = DATA_INT * 3600 ))
in_int="\(${INTERVAL}_${SECOND}[Ss]\)${EQUAL}[[:digit:]]\{1,\}"
out_int="\1 = ${data_interval_sec}"
cat namelist.wps \
  | sed "s/${in_int}/${out_int}/" \
  > namelist.wps.new
mv namelist.wps.new namelist.wps

##################################################################################
# Run ungrib 
##################################################################################
# Print run parameters
echo
echo "EXP_CNFG      = ${EXP_CNFG}"
echo "MEMID         = ${MEMID}"
echo "CYCLE_HME     = ${CYCLE_HME}"
echo "DATA_INT      = ${DATA_INT}"
echo "FCST_LEN      = ${FCST_LEN}"
echo
echo "BKG_DATA      = ${BKG_DATA}"
echo "STRT_TIME     = "`date +"%Y/%m/%d %H:%M:%S" -d "${strt_time}"`
echo "END_TIME      = "`date +"%Y/%m/%d %H:%M:%S" -d "${end_time}"`
echo "BKG_STRT_TIME = ${BKG_STRT_TIME}"
echo
now=`date +%Y%m%d%H%M%S`
echo "ungrib started at ${now}."
./ungrib.exe

##################################################################################
# Run time error check
##################################################################################
error=$?

if [ ${error} -ne 0 ]; then
  echo "ERROR: ${ungrib_exe} exited with status ${error}."
  exit ${error}
fi

# save ungrib logs
log_dir=ungrib_log.${now}
mkdir ${log_dir}
mv ungrib.log ${log_dir}

# save a copy of namelist
cp namelist.wps ${log_dir}

# verify all file outputs
fcst=0
while [ ${fcst} -le ${FCST_LEN} ]; do
  filename=FILE:`date +%Y-%m-%d_%H -d "${strt_time} ${fcst} hours"`
  if [ ! -s ${filename} ]; then
    echo "ERROR: ${filename} is missing."
    exit 1
  fi
  (( fcst += DATA_INT ))
done

# If ungribbing ECMWF model level data, calculate additional coefficients
# NOTE: namelist.wps should account for the "PRES" file prefixes in fg_names
if [[ ${IF_ECMWF_ML} = ${YES} ]]; then
  ln -sf ${EXP_CNFG}/variable_tables/ecmwf_coeffs ./
  ./util/calc_ecmwf_p.exe
  # Check to see if we've got all the files we're expecting
  fcst=0
  while [ ${fcst} -le ${FCST_LEN} ]; do
    filename=PRES:`date +%Y-%m-%d_%H -d "${strt_time} ${fcst} hours"`
    if [ ! -s ${filename} ]; then
      echo "ERROR: ${filename} is missing."
      exit 1
    fi
    (( fcst += DATA_INT ))
  done
fi

# Remove links to the WPS DAT files
for file in ${wps_dat_files[@]}; do
    rm -f `basename ${file}`
done

# remove links to grib files
rm -f GRIBFILE.*

# Remove namelist
rm -f namelist.wps

echo "ungrib.sh completed successfully at `date`."

##################################################################################
# end

exit 0
