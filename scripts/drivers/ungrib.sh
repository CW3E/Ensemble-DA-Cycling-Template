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
# This software is Copyright © 2024 The Regents of the University of California.
# All Rights Reserved. Permission to copy, modify, and distribute this software
# and its documentation for educational, research and non-profit purposes,
# without fee, and without a written agreement is hereby granted, provided that
# the above copyright notice, this paragraph and the following three paragraphs
# appear in all copies. Permission to make commercial use of this software may
# be obtained by contacting:
#
#     Office of Innovation and Commercialization
#     9500 Gilman Drive, Mail Code 0910
#     University of California
#     La Jolla, CA 92093-0910
#     innovation@ucsd.edu
#
# This software program and documentation are copyrighted by The Regents of the
# University of California. The software program and documentation are supplied
# "as is", without any accompanying services from The Regents. The Regents does
# not warrant that the operation of the program will be uninterrupted or
# error-free. The end-user understands that the program was developed for
# research purposes and is advised not to rely exclusively on the program for
# any reason.
#
# IN NO EVENT SHALL THE UNIVERSITY OF CALIFORNIA BE LIABLE TO ANY PARTY FOR
# DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES, INCLUDING
# LOST PROFITS, ARISING OUT OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION,
# EVEN IF THE UNIVERSITY OF CALIFORNIA HAS BEEN ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE. THE UNIVERSITY OF CALIFORNIA SPECIFICALLY DISCLAIMS ANY
# WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE SOFTWARE PROVIDED
# HEREUNDER IS ON AN “AS IS” BASIS, AND THE UNIVERSITY OF CALIFORNIA HAS NO
# OBLIGATIONS TO PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR
# MODIFICATIONS.
# 
#
# In addition to the License terms above, this software is
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
# CNST         = Full path to constants used to compile and run WRF / WPS
# IF_DBG_SCRPT = Switch YES or else, this is NOT A REQUIRED ARGUMENT. Set variable
#                IF_DBG_SCRPT=Yes within the configuration to initiate debugging,
#                script will default to normal run behavior otherwise
# SCHED        = IF_DBG_SCRPT=Yes, SCHED=SLURM or SCHED=PBS will auto-generate
#                a job submission header in the debugging script to run manually
#
##################################################################################

if [ ! -x ${CNST} ]; then
  printf "ERROR: constants file\n ${CNST}\n does not exist or is not executable.\n"
  exit 1
else
  # Read constants into the current shell
  cmd=". ${CNST}"
  printf "${cmd}\n"; eval "${cmd}"
fi

if [[ ${IF_DBG_SCRPT} = ${YES} ]]; then 
  dbg=1
  scrpt=$(mktemp /tmp/run_dbg.XXXXXXX.sh)
  printf "Driver runs in debug mode.\n"
  printf "Producing a script and work directory for manual submission.\n"
  if [[ ${SCHED} = ${SLURM} ]]; then
    # source slurm header from environment directory
    cat `dirname ${CNST}`/slurm_header.sh >> ${scrpt}
  elif [[ ${SCHED} = ${PBS} ]]; then
    # source pbs header from environment directory
    cat `dirname ${CNST}`/pbs_header.sh >> ${scrpt}
  fi
  # Read constants and print into run script
  while read line; do
    IFS=" " read -ra parsed <<< ${line}
    char=${parsed[0]}
    if [[ ! ${char} =~ \# ]]; then
      cmd=""
      for char in ${parsed[@]}; do
        cmd="${cmd}${char} "
      done
      printf "${cmd}\n" >> ${scrpt}
    fi
  done < ${CNST}
else
  dbg=0
fi

##################################################################################
# Make checks for ungrib settings
##################################################################################
# Options below are defined in workflow variables
#
# EXP_NME     = Case study / config short name directory structure
# CFG_ROOT    = Root directory containing simulation settings
# MEMID       = Ensemble ID index, 00 for control, i > 0 for perturbation
# STRT_DT     = Simulation start time in YYYYMMDDHH
# BKG_STRT_DT = Background data simulation start time in YYYYMMDDHH
# IF_DYN_LEN  = "Yes" or "No" switch to compute forecast length dynamically 
# IF_RGNL     = "Yes" or "No" switch to require grib data for forecast boundary
# FCST_HRS    = Total length of WRF forecast simulation in HH, IF_DYN_LEN=No
# EXP_VRF     = Verfication time for calculating forecast hours, IF_DYN_LEN=Yes
# BKG_INT     = Interval of background input data in HH
# BKG_DATA    = String case variable for supported inputs: GFS, GEFS currently
# IF_ECMWF_ML = "Yes" or "No" switch to compute ECMWF model level coefficients
#
##################################################################################

if [ ! ${EXP_NME} ]; then
  printf "ERROR: Case study / config short name \${EXP_NME} is not defined.\n"
  exit 1
else
  IFS="/" read -ra exp_nme <<< ${EXP_NME}
  cse_nme=${exp_nme[0]}
  cfg_nme=${exp_nme[1]}
  printf "Setting up configuration:\n    ${cfg_nme}\n"
  printf "for:\n    ${cse_nme}\n case study.\n"
  if [ ! ${CFG_ROOT} ]; then
    printf "ERROR: \${CFG_ROOT} is not defined.\n"
    exit 1
  elif [ ! -d ${CFG_ROOT} ]; then
    printf "ERROR: \${CFG_ROOT} directory\n ${CFG_ROOT}\n does not exist.\n"
    exit 1
  fi
  cfg_dir=${CFG_ROOT}/${EXP_NME}
  if [ ! -d ${cfg_dir} ]; then
    printf "ERROR: simulation settings directory\n ${cfg_dir}\n does not exist.\n"
    exit 1
  fi
fi

if [ ! ${MEMID} ]; then
  printf "ERROR: ensemble index \${MEMID} is not defined.\n"
  exit 1
else
  # ensure padding to two digits is included in memid variable
  memid=`printf %02d $(( 10#${MEMID} ))`
  printf "Running ungrib for ensemble member ${MEMID}.\n"
fi

if [[ ! ${STRT_DT} =~ ${ISO_RE} ]]; then
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
  if [[ ! ${EXP_VRF} =~ ${ISO_RE} ]]; then
    printf "ERROR: \${EXP_VRF}, ${EXP_VRF} is not in 'YYYYMMDDHH' format.\n"
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

if [[ ! ${BKG_STRT_DT} =~ ${ISO_RE} ]]; then
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
# CYC_HME   = Cycle YYYYMMDDHH named directory for cycling data
# GRIB_ROOT = Directory for grib files, sub-directories organized by BKG_DATA name
#
##################################################################################

if [ ! ${WPS_ROOT} ]; then
  printf "ERROR: \${WPS_ROOT} is not defined.\n"
  exit 1
elif [ ! -d ${WPS_ROOT} ]; then
  printf "ERROR: WPS_ROOT directory\n ${WPS_ROOT}\n does not exist.\n"
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

if [ ! ${GRIB_ROOT} ]; then
  printf "ERROR: \${GRIB_ROOT} is not defined.\n"
  exit 1
elif [ ! -d ${GRIB_ROOT} ]; then
  printf "ERROR: \${GRIB_ROOT} directory\n ${GRIB_ROOT}\n does not exist.\n"
  exit 1
fi

##################################################################################
# Begin pre-unrib setup
##################################################################################
# The following paths are relative to workflow supplied root paths
#
# work_dir   = Work directory where ungrib_exe runs and outputs
# wps_files  = All file contents of clean WPS directory
# ungrib_exe = Path and name of working executable
# vtable     = Path and name of variable table
# grib_data  = Path to the raw data to be processed
#
##################################################################################

# define work root and change directories
work_dir=${CYC_HME}/ungrib/ens_${memid}
cmd="mkdir -p ${work_dir}; cd ${work_dir}"
if [ ${dbg} = 1 ]; then
  printf "${cmd}\n" >> ${scrpt}; eval "${cmd}"
else
  printf "${cmd}\n"; eval "${cmd}"
fi

# check that the ungrib executable exists and runs
ungrib_exe=${WPS_ROOT}/ungrib.exe
if [ ! -x ${ungrib_exe} ]; then
  printf "ERROR: ungrib.exe\n ${ungrib_exe}\n does not exist, or is not executable.\n"
  exit 1
fi

# Make links to the WPS run files
wps_files=(${WPS_ROOT}/*)
for filename in ${wps_files[@]}; do
  cmd="rm -f `basename ${filename}`"
  printf "${cmd}\n"; eval "${cmd}"
  cmd="ln -sf ${filename} ."
  if [ ${dbg} = 1 ]; then
    printf "${cmd}\n" >> ${scrpt}
  else
    printf "${cmd}\n"; eval "${cmd}"
  fi
done

# Remove any previous Vtables
cmd="rm -f Vtable"
printf "${cmd}\n"; eval "${cmd}"

# Check to make sure the variable table is available
vtable=${CFG_ROOT}/variable_tables/Vtable.${BKG_DATA}
if [ ! -r ${vtable} ]; then
  msg="ERROR: Vtable at location\n ${vtable}\n is not readable or does not "
  msg+="exist.\n"
  printf "${msg}"
  exit 1
else
  cmd="ln -sf ${vtable} Vtable"
  if [ ${dbg} = 1 ]; then
    printf "${cmd}\n" >> ${scrpt}
  else
    printf "${cmd}\n"; eval "${cmd}"
  fi
fi

# Remove any ungrib inputs
cmd="rm -f GRIBFILE.*"
printf "${cmd}\n"; eval "${cmd}"

# Remove any ungrib temp files
cmd="rm -f PFILE:*"
printf "${cmd}\n"; eval "${cmd}"

# Remove any ungrib outputs
cmd="rm -f ${BKG_DATA}:*"
printf "${cmd}\n"; eval "${cmd}"

# Remove ECMWF coefficients if processing EC model levels
if [ ${IF_ECMWF_ML} = ${YES} ]; then
  cmd="rm -f ecmwf_coeffs"
  printf "${cmd}\n"; eval "${cmd}"
  # Check for ECMWF pressure coefficients 
  cmd="rm -f PRES:*"
  printf "${cmd}\n"; eval "${cmd}"
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

# check to make sure the grib_data exists and is non-empty
grib_data=${GRIB_ROOT}/${BKG_DATA}/${bkg_strt_dt}
if [ ! -d ${grib_data} ]; then
  printf "ERROR: the directory\n ${grib_data}\n does not exist.\n"
  exit 1
elif [ `ls -l ${grib_data}/${fnames} | wc -l` -lt ${n_files} ]; then
  msg="ERROR: grib data directory\n ${grib_data}\n is "
  msg+="missing bkg input files.\n"
  printf "${msg}"
  exit 1
else
  # link the grib data to the working directory
  cmd="./link_grib.csh ${grib_data}/${fnames}"
  if [ ${dbg} = 1 ]; then
    printf "${cmd}\n" >> ${scrpt}
  else
    printf "${cmd}\n"; eval "${cmd}"
  fi
fi

##################################################################################
#  Build WPS namelist
##################################################################################

# Copy the wps namelist template, NOTE: THIS WILL BE MODIFIED DO NOT LINK TO IT
filename=${cfg_dir}/namelists/namelist.wps
if [ ! -r ${filename} ]; then 
  msg="WPS namelist template\n ${filename}\n is not readable or "
  msg+="does not exist.\n"
  printf "${msg}"
  exit 1
else
  cmd="cp -L ${filename} ."
  if [ ${dbg} = 1 ]; then
    printf "${cmd}\n" >> ${scrpt}
  else
    printf "${cmd}\n"; eval "${cmd}"
  fi
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
  out_fg_name="'${BKG_DATA}'"
fi

# generate here file for template parameter replacement
cat << EOF > replace_param.tmp
cat namelist.wps \
| sed "s/= STRT_DT,/= ${strt_iso},/" \
| sed "s/= STOP_DT,/= ${stop_iso},/" \
| sed "s/= INT_SEC,/= ${data_int_sec},/" \
| sed "s/= MAX_DOM,/= ${MAX_DOM},/" \
| sed "s/= PREFIX,/= '${BKG_DATA}',/" \
| sed "s/= FG_NAME,/= ${out_fg_name},/" \
> namelist.wps.tmp
mv namelist.wps.tmp namelist.wps
EOF

if [ ${dbg} = 1 ]; then
  # include the replacement commands in run script
  cat replace_param.tmp >> ${scrpt}
  rm replace_param.tmp
else
  # update the namelist
  chmod +x replace_param.tmp
  ./replace_param.tmp
  rm replace_param.tmp
fi

##################################################################################
# Run ungrib 
##################################################################################

# Print run parameters
printf "\n"
printf "EXP_NME     = ${EXP_NME}\n"
printf "MEMID       = ${MEMID}\n"
printf "CYC_HME     = ${CYC_HME}\n"
printf "STRT_DT     = ${strt_iso}\n"
printf "STOP_DT     = ${stop_iso}\n"
printf "BKG_DATA    = ${BKG_DATA}\n"
printf "BKG_STRT_DT = ${BKG_STRT_DT}\n"
printf "BKG_INT     = ${BKG_INT}\n"
printf "\n"

cmd="./ungrib.exe"

if [ ${dbg} = 1 ]; then
  printf "${cmd}\n" >> ${scrpt}
  mv ${scrpt} ${work_dir}/run_ungrib.sh
  printf "Setup of ungrib work directory and run script complete.\n"
  exit 0
fi

now=`date +%Y-%m-%d_%H_%M_%S`
printf "ungrib started at ${now}.\n"
printf "${cmd}\n"
./ungrib.exe

##################################################################################
# Run time error check
##################################################################################

error="$?"
printf "ungrib exited with code ${error}.\n"

# save ungrib logs
logdir=ungrib_log_${BKG_DATA}.${now}
mkdir ${logdir}
cmd="mv ungrib.log ${logdir}"
printf "${cmd}\n"; eval "${cmd}"

cmd="mv namelist.wps ${logdir}"
printf "${cmd}\n"; eval "${cmd}"

# Remove links to the WPS run files
for filename in ${wps_files[@]}; do
  cmd="rm -f `basename ${filename}`"
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
  cmd="ln -sf ${CFG_ROOT}/variable_tables/ecmwf_coeffs ."
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
