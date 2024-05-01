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
# in a WRF_constants.sh script to be sourced in the below.
#
##################################################################################
# License Statement:
##################################################################################
# Copyright 2023 CW3E, Contact Colin Grudzien cgrudzien@ucsd.edu
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
#set -x

if [ ! -x ${CNST} ]; then
  printf "ERROR: constants file\n ${CNST}\n does not exist or is not executable.\n"
  exit 1
else
  # Read constants into the current shell
  cmd=". ${CNST}"
  printf "${cmd}\n"; eval "${cmd}"
fi

##################################################################################
# Make checks for ungrib settings
##################################################################################
# Options below are defined in workflow variables
#
# MEMID       = Ensemble ID index, 00 for control, i > 0 for perturbation
# STRT_DT     = Simulation start time in YYMMDDHH
# BKG_STRT_DT = Background data simulation start time in YYMMDDHH
# IF_DYN_LEN  = "Yes" or "No" switch to compute forecast length dynamically 
# IF_RGNL     = "Yes" or "No" switch to require grib data for forecast boundary
# FCST_HRS    = Total length of WRF forecast simulation in HH, IF_DYN_LEN=No
# EXP_VRF     = Verfication time for calculating forecast hours, IF_DYN_LEN=Yes
# BKG_INT     = Interval of background input data in HH
# BKG_DATA    = String case variable for supported inputs: GFS, GEFS currently
# IF_ECMWF_ML = "Yes" or "No" switch to compute ECMWF coefficients for
#               initializing with model level data, case insensitive
#
##################################################################################

if [ ! ${MEMID} ]; then
  printf "ERROR: ensemble index \${MEMID} is not defined.\n"
  exit 1
else
  # ensure padding to two digits is included in memid variable
  memid=`printf %02d $(( 10#${MEMID} ))`
  printf "Running ungrib for ensemble member ${MEMID}.\n"
fi

if [ ${#STRT_DT} -ne 10 ]; then
  printf "ERROR: \${STRT_DT}, ${STRT_DT}, is not in 'YYYYMMDDHH' format.\n"
  exit 1
else
  # Convert STRT_DT from 'YYYYMMDDHH' format to strt_dt Unix date format
  strt_dt="${STRT_DT:0:8} ${STRT_DT:8:2}"
  strt_dt=`date -d "${strt_dt}"`
fi

if [[ ${IF_DYN_LEN} = ${NO} ]]; then 
  printf "Fixed length forecast.\n"
  if [ ! ${FCST_HRS} ]; then
    printf "ERROR: \${FCST_HRS} is not defined.\n"
    exit 1
  else
    # parse forecast hours as base 10 padded
    fcst_hrs=`printf %03d $(( 10#${FCST_HRS} ))`
  fi
elif [[ ${IF_DYN_LEN} = ${YES} ]]; then
  printf "Forecast runs until experiment validation time.\n"
  if [ ${#EXP_VRF} -ne 10 ]; then
    printf "ERROR: \${EXP_VRF}, ${EXP_VRF} is not in 'YYYMMDDHH' format.\n"
    exit 1
  else
    # compute forecast length relative to start time and verification time
    exp_vrf="${EXP_VRF:0:8} ${EXP_VRF:8:2}"
    exp_vrf=`date +%s -d "${exp_vrf}"`
    fcst_hrs=$(( (${exp_vrf} - `date +%s -d "${strt_dt}"`) / 3600 ))
    fcst_hrs=`printf %03d $(( 10#${fcst_hrs} ))`
  fi
else
  printf "\${IF_DYN_LEN} must be set to 'Yes' or 'No' (case insensitive).\n"
  exit 1
fi

# define the stop time based on forecast length control flow above
stop_dt=`date -d "${strt_dt} ${fcst_hrs} hours"`

if [ ${#BKG_STRT_DT} -ne 10 ]; then
  printf "ERROR: \${BKG_STRT_DT}, '${BKG_STRT_DT}', is not in 'YYYYMMDDHH' format.\n"
  exit 1
else
  # define BKG_STRT_DT date string wihtout HH
  bkg_strt_dt=${BKG_STRT_DT:0:8}
  bkg_strt_hh=${BKG_STRT_DT:8:2}
fi

if [[ ${IF_RGNL} != ${YES} && ${IF_RGNL} != ${NO} ]]; then
  printf "\${IF_RGNL} must be set to 'Yes' or 'No' (case insensitive).\n"
  exit 1
fi

if [[ ${IF_SST_UPDT} != ${YES} && ${IF_SST_UPDT} != ${NO} ]]; then
  printf "\${IF_SFC} must be set to 'Yes' or 'No' (case insensitive).\n"
  exit 1
fi

if [[ ${IF_RGNL} = ${NO} && ${IF_SST_UPDT} = ${NO} ]]; then 
  printf "Ungribbing only initial condition data data.\n"
  # create a multiplier for the file count
  rgnl=0

  # define a sequence containing only the formatted initial conditions hour
  fcst_seq=`seq -f "%03g" 0 1 0`

elif [[ ${IF_RGNL} = ${YES} || ${IF_SST_UPDT} = ${YES} ]]; then
  printf "Ungribbing data for initial and boundary conditions.\n"
  # create a multiplier for the file count
  rgnl=1

  # define a sequence of all forecast hours with background interval spacing
  fcst_seq=`seq -f "%03g" 0 ${BKG_INT} ${fcst_hrs}`
fi

if [ ! ${BKG_INT} ]; then
  printf "ERROR: \${BKG_INT} is not defined.\n"
  exit 1
elif [ ${BKG_INT} -le 0 ]; then
  printf "ERROR: \${BKG_INT} must be HH > 0 for the frequency of data inputs.\n"
  exit 1
fi

if [ ${BKG_DATA} = GFS ]; then
  # GFS has single control trajectory
  fnames="gfs.0p25.${BKG_STRT_DT}.f*"

  # compute the number of input files to ungrib (incld. first/last times)
  n_files=$(( (${fcst_hrs} / ${BKG_INT}) * ${rgnl} + 1 ))

elif [ ${BKG_DATA} = GEFS ]; then
  if [ ${memid} = 00 ]; then
    # 00 perturbation is the control forecast
    fnames="gec${memid}.t${bkg_strt_hh}z.pgrb*"
  else
    # all other are control forecast perturbations
    fnames="gep${memid}.t${bkg_strt_hh}z.pgrb*"
  fi
  # GEFS comes in a/b files for each valid time, AWS 0p50 supports initialization
  n_files=$(( (2 * ${fcst_hrs} / ${BKG_INT}) * ${rgnl} + 2 ))

else
  msg="ERROR: \${BKG_DATA} must equal 'GFS' or 'GEFS'"
  msg+=" as currently supported inputs.\n"
  printf "${msg}"
  exit 1
fi

if [[ ${IF_ECMWF_ML} != ${YES} && ${IF_ECMWF_ML} != ${NO} ]]; then
  printf "ERROR: \${IF_ECMWF_ML} must equal 'Yes' or 'No' (case insensitive).\n"
  exit 1
fi

##################################################################################
# Define ungrib workflow dependencies
##################################################################################
# Below variables are defined in workflow variables
#
# WPS_ROOT  = Root directory of clean WPS build
# EXP_CNFG  = Root directory containing sub-directories for namelists
#             vtables, geogrid data, GSI fix files, etc.
# CYC_HME   = Cycle YYYYMMDDHH named directory for cycling data containing
#             bkg, ungrib, metgrid, real, wrf, wrfda, gsi, enkf
# DATA_ROOT = Directory for all forcing data files, including grib files,
#             obs files, etc.
#
##################################################################################

if [ ! ${WPS_ROOT} ]; then
  printf "ERROR: \${WPS_ROOT} is not defined.\n"
  exit 1
elif [ ! -d ${WPS_ROOT} ]; then
  printf "ERROR: WPS_ROOT directory\n ${WPS_ROOT}\n does not exist.\n"
  exit 1
fi

if [ ! ${EXP_CNFG} ]; then
  printf "ERROR: \${EXP_CNFG} is not defined.\n"
  exit 1
elif [ ! -d ${EXP_CNFG} ]; then
  printf "ERROR: \${EXP_CNFG} directory\n ${EXP_CNFG}\n does not exist.\n"
  exit 1
fi

if [ ! ${CYC_HME} ]; then
  printf "ERROR: \${CYC_HME} is not defined.\n"
  exit 1
else
  cmd="mkdir -p ${CYC_HME}"
  printf "${cmd}\n"; eval "${cmd}"
fi

if [ ! -d ${CYC_HME} ]; then
  printf "ERROR: \${CYC_HME} directory\n ${CYC_HME}\n does not exist.\n"
  exit 1
fi

if [ ! ${DATA_ROOT} ]; then
  printf "ERROR: \${DATA_ROOT} is not defined.\n"
  exit 1
elif [ ! -d ${DATA_ROOT} ]; then
  printf "ERROR: \${DATA_ROOT} directory\n ${DATA_ROOT}\n does not exist.\n"
  exit 1
fi

##################################################################################
# Begin pre-unrib setup
##################################################################################
# The following paths are relative to workflow supplied root paths
#
# work_root     = Working directory where ungrib_exe runs and outputs
# wps_run_files = All file contents of clean WPS directory
#                 namelists and input data will be linked from other sources
# ungrib_exe    = Path and name of working executable
# vtable        = Path and name of variable table
# grib_dataroot = Path to the raw data to be processed
#
##################################################################################
# define work root and change directories
work_root=${CYC_HME}/ungrib/ens_${memid}
cmd="mkdir -p ${work_root}; cd ${work_root}"
printf "${cmd}\n"; eval "${cmd}"

# check that the ungrib executable exists and runs
ungrib_exe=${WPS_ROOT}/ungrib.exe
if [ ! -x ${ungrib_exe} ]; then
  printf "ERROR: ungrib.exe\n ${ungrib_exe}\n does not exist, or is not executable.\n"
  exit 1
fi

# Make links to the WPS run files
wps_run_files=(${WPS_ROOT}/*)
for file in ${wps_run_files[@]}; do
  cmd="ln -sf ${file} ."
  printf "${cmd}\n"; eval "${cmd}"
done

# Remove any previous Vtables
cmd="rm -f Vtable"
printf "${cmd}\n"; eval "${cmd}"

# Check to make sure the variable table is available
vtable=${EXP_CNFG}/variable_tables/Vtable.${BKG_DATA}
if [ ! -r ${vtable} ]; then
  msg="ERROR: Vtable at location\n ${vtable}\n is not readable or does not "
  msg+="exist.\n"
  printf "${msg}"
  exit 1
else
  cmd="ln -sf ${vtable} Vtable"
  printf "${cmd}\n"; eval "${cmd}"
fi

# Remove any ungrib inputs
cmd="rm -f GRIBFILE.*"
printf "${cmd}\n"; eval "${cmd}"

# Remove any ungrib outputs
for fcst in ${fcst_seq[@]}; do
  filename="${BKG_DATA}:`date +%Y-%m-%d_%H -d "${strt_dt} ${fcst} hours"`"
  cmd="rm -f ${filename}"
  printf "${cmd}\n"; eval "${cmd}"
done

# Remove ECMWF coefficients if processing EC model levels
if [ ${IF_ECMWF_ML} = ${YES} ]; then
  cmd="rm -f ecmwf_coeffs"
  printf "${cmd}\n"; eval "${cmd}"

  # Check for ECMWF pressure coefficients 
  for fcst in ${fcst_seq[@]}; do
    filename=PRES:`date +%Y-%m-%d_%H -d "${strt_dt} ${fcst} hours"`
    cmd="rm -f ${filename}"
    printf "${cmd}\n"; eval "${cmd}"
  done
fi

# Move existing log files to a subdir if there are any
printf "Checking for pre-existing log files.\n"
if [ -f ungrib.log ]; then
  logdir=ungrib_log.`ls -l --time-style=+%Y-%m-%d_%H_%M%_S ungrib.log | cut -d" " -f 6`
  mkdir ${logdir}
  printf "Moving pre-existing log files to ${logdir}.\n"
  cmd="mv ungrib.log ${logdir}"
  printf "${cmd}\n"; eval "${cmd}"
else
  printf "No pre-existing log files were found.\n"
fi

# Remove any namelists
cmd="rm -f namelist.wps"
printf "${cmd}\n"; eval "${cmd}"

# check to make sure the grib_dataroot exists and is non-empty
grib_dataroot=${DATA_ROOT}/gribbed/${BKG_DATA}/${bkg_strt_dt}
if [ ! -d ${grib_dataroot} ]; then
  printf "ERROR: the directory\n ${grib_dataroot}\n does not exist.\n"
  exit 1
elif [ `ls -l ${grib_dataroot}/${fnames} | wc -l` -lt ${n_files} ]; then
  msg="ERROR: grib data directory\n ${grib_dataroot}\n is "
  msg+="missing bkg input files.\n"
  printf "${msg}"
  exit 1
else
  # link the grib data to the working directory
  cmd="./link_grib.csh ${grib_dataroot}/${fnames}"
  printf "${cmd}\n"; eval "${cmd}"
fi

##################################################################################
#  Build WPS namelist
##################################################################################
# Copy the wps namelist template, NOTE: THIS WILL BE MODIFIED DO NOT LINK TO IT
namelist_temp=${EXP_CNFG}/namelists/namelist.wps
if [ ! -r ${namelist_temp} ]; then 
  msg="WPS namelist template\n ${namelist_temp}\n is not readable or "
  msg+="does not exist.\n"
  printf "${msg}"
  exit 1
else
  cmd="cp -L ${namelist_temp} ."
  printf "${cmd}\n"; eval "${cmd}"
fi

# define start / stop time patterns for namelist.wps
strt_iso=`date +%Y-%m-%d_%H_%M_%S -d "${strt_dt}"`
stop_iso=`date +%Y-%m-%d_%H_%M_%S -d "${stop_dt}"`

# Update interval in namelist
data_int_sec=$(( ${BKG_INT} * 3600 ))

# Update max_dom in namelist to dummy value
# domains not needed for ungrib but throws error
MAX_DOM="01"

# Update fg_name to name of background data
if [ ${IF_ECMWF_ML} = ${YES} ]; then
  out_fg_name="'${BKG_DATA}', 'PRES'"
else
  out_fg_name="'${BKG_DATA}',"
fi

# apply updates
cat namelist.wps \
  | sed "s/= STRT_DT,/= ${strt_iso},/" \
  | sed "s/= STOP_DT,/= ${stop_iso},/" \
  | sed "s/= INT_SEC,/= ${data_int_sec},/" \
  | sed "s/= MAX_DOM,/= ${MAX_DOM},/" \
  | sed "s/= PREFIX,/= '${BKG_DATA}',/" \
  | sed "s/= FG_NAME,/= ${out_fg_name},/" \
  > namelist.wps.tmp
mv namelist.wps.tmp namelist.wps

##################################################################################
# Run ungrib 
##################################################################################
# Print run parameters
printf "\n"
printf "EXP_CNFG    = ${EXP_CNFG}\n"
printf "MEMID       = ${MEMID}\n"
printf "CYC_HME     = ${CYC_HME}\n"
printf "STRT_DT     = ${strt_iso}\n"
printf "STOP_DT     = ${stop_iso}\n"
printf "BKG_DATA    = ${BKG_DATA}\n"
printf "BKG_STRT_DT = ${BKG_STRT_DT}\n"
printf "BKG_INT     = ${BKG_INT}\n"
printf "\n"
now=`date +%Y-%m-%d_%H_%M_%S`
printf "ungrib started at ${now}.\n"
cmd="./ungrib.exe"
printf "${cmd}\n"
./ungrib.exe

##################################################################################
# Run time error check
##################################################################################
error="$?"
printf "ungrib exited with code ${error}.\n"

# save ungrib logs
log_dir=ungrib_log_${BKG_DATA}.${now}
mkdir ${log_dir}
cmd="mv ungrib.log ${log_dir}"
printf "${cmd}\n"; eval "${cmd}"

cmd="mv namelist.wps ${log_dir}"
printf "${cmd}\n"; eval "${cmd}"

# Remove links to the WPS run files
for file in ${wps_run_files[@]}; do
    cmd="rm -f `basename ${file}`"
    printf "${cmd}\n"; eval "${cmd}"
done

# remove links to grib files
cmd="rm -f GRIBFILE.*"
printf "${cmd}\n"; eval "${cmd}"

# remove link to vtable
cmd="rm -f Vtable"
printf "${cmd}\n"; eval "${cmd}"

# check run error code
if [ ${error} -ne 0 ]; then
  printf "ERROR: \n${ungrib_exe}\n exited with status ${error}.\n"
  exit ${error}
fi

# verify all file outputs
for fcst in ${fcst_seq[@]}; do
  filename="${BKG_DATA}:`date +%Y-%m-%d_%H -d "${strt_dt} ${fcst} hours"`"
  if [ ! -s ${filename} ]; then
    printf "ERROR: ${filename} is missing.\n"
    exit 1
  fi
done

# If ungribbing ECMWF model level data, calculate additional coefficients
# NOTE: namelist.wps should account for the "PRES" file prefixes in fg_names
if [ ${IF_ECMWF_ML} = ${YES} ]; then
  cmd="ln -sf ${EXP_CNFG}/variable_tables/ecmwf_coeffs ."
  printf "${cmd}\n"; eval "${cmd}"
  cmd="./util/calc_ecmwf_p.exe"
  printf "${cmd}\n"; eval "${cmd}"

  # Check for ECMWF pressure coefficients 
  for fcst in ${fcst_seq[@]}; do
    filename=PRES:`date +%Y-%m-%d_%H -d "${strt_dt} ${fcst} hours"`
    if [ ! -s ${filename} ]; then
      printf "ERROR: ${filename} is missing.\n"
      exit 1
    fi
  done
fi

printf "ungrib.sh completed successfully at `date +%Y-%m-%d_%H_%M_%S`.\n"

##################################################################################
# end

exit 0
