#!/bin/bash
##################################################################################
# Description
##################################################################################
# This driver script is a major fork and rewrite of the Rocoto workflow
# metgrid.exe driver script of Christopher Harrop Licensed for modification /
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
#     Script Name: metgrid.ksh
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
# CNST         = Full path to BASH constants used in driver scripts
# MOD_ENV      = Full path to environment used to compile and run WPS / WRF / MPAS
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

if [ ! -x ${MOD_ENV} ]; then
  msg="ERROR: model environment file\n ${MOD_ENV}\n does not exist"
  msg+=" or is not executable.\n"
  printf "${msg}"
  exit 1
else
  # Read model environment into the current shell
  cmd=". ${MOD_ENV}"
  printf "${cmd}\n"; eval "${cmd}"
fi

if [[ ${IF_DBG_SCRPT} = ${YES} ]]; then 
  dbg=1
  scrpt=$(mktemp /tmp/run_dbg.XXXXXXX.sh)
  printf "Driver runs in debug mode.\n"
  printf "Producing a script and work directory for manual submission.\n"

  if [[ ${SCHED} = ${SLURM} ]]; then
    # source slurm header from environment directory
    cat `dirname ${MOD_ENV}`/slurm_header.sh >> ${scrpt}
  elif [[ ${SCHED} = ${PBS} ]]; then
    # source pbs header from environment directory
    cat `dirname ${MOD_ENV}`/pbs_header.sh >> ${scrpt}
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
  done < ${MOD_ENV}
else
  dbg=0
fi

##################################################################################
# Make checks for metgrid settings
##################################################################################
# Options below are defined in workflow variables
#
# EXP_NME    = Case study / config short name directory structure
# MEMID      = Ensemble ID index, 00 for control, i > 0 for perturbation
# STRT_DT    = Simulation start time in YYYYMMDDHH
# IF_DYN_LEN = "Yes" or "No" switch to compute forecast length dynamically 
# FCST_HRS   = Total length of WRF forecast simulation in HH, IF_DYN_LEN=No
# EXP_VRF    = Verfication time for calculating forecast hours, IF_DYN_LEN=Yes
# BKG_DATA   = String case variable for supported inputs: GFS, GEFS currently
# BKG_INT    = Interval of input data in HH
# MAX_DOM    = Max number of domains to use in namelist settings
#
##################################################################################

if [ -z ${EXP_NME} ]; then
  printf "ERROR: Case study / config short name \${EXP_NME} is not defined.\n"
  exit 1
else
  IFS="/" read -ra exp_nme <<< ${EXP_NME}
  if [ ${#exp_nme[@]} -ne 2 ]; then
    printf "ERROR: \${EXP_NME} variable:\n ${EXP_NME}\n"
    printf "should define case study / config short name directory nesting.\n"
    exit 1
  fi
  cse_nme=${exp_nme[0]}
  cfg_nme=${exp_nme[1]}
  printf "Setting up configuration:\n    ${cfg_nme}\n"
  printf "for:\n    ${cse_nme}\n case study.\n"
  cfg_dir=${HOME}/cylc-src/${EXP_NME}
  if [ ! -d ${cfg_dir} ]; then
    printf "ERROR: simulation settings directory\n ${cfg_dir}\n does not exist.\n"
    exit 1
  fi
fi

if [[ ! ${MEMID} =~ ${INT_RE} ]]; then
  printf "ERROR: \${MEMID}, ${MEMID}, is not an integer.\n"
  exit 1
else
  # ensure padding to two digits is included
  memid=`printf %02d $(( 10#${MEMID} ))`
  printf "Running metgrid for ensemble member ${MEMID}.\n"
fi

if [[ ! ${STRT_DT} =~ ${ISO_RE} ]]; then
  printf "ERROR: \${STRT_DT}, '${STRT_DT}', is not in 'YYYYMMDDHH' format.\n"
  exit 1
else
  # Convert STRT_DT from 'YYYYMMDDHH' format to strt_dt Unix date format
  strt_dt="${STRT_DT:0:8} ${STRT_DT:8:2}"
  strt_dt=`date -d "${strt_dt}"`
fi

if [[ ${IF_DYN_LEN} = ${NO} ]]; then 
  printf "Generating fixed length forecast forcing data.\n"
  if [[ ! ${FCST_HRS} =~ ${INT_RE} ]]; then
    printf "ERROR: \${FCST_HRS}, ${FCST_HRS}, is not an integer.\n"
    exit 1
  else
    # parse forecast hours as base 10 padded
    fcst_hrs=`printf %03d $(( 10#${FCST_HRS} ))`
  fi
elif [[ ${IF_DYN_LEN} = ${YES} ]]; then
  printf "Generating forecast forcing data until experiment validation time.\n"
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

# define a sequence of all forecast hours with background interval spacing
fcst_seq=`seq -f "%03g" 0 ${BKG_INT} ${fcst_hrs}`

if [[ ${BKG_DATA} != GFS && ${BKG_DATA} != GEFS ]]; then
  msg="ERROR: \${BKG_DATA} must equal 'GFS' or 'GEFS'"
  msg+=" as currently supported inputs.\n"
  printf "${msg}"
  exit 1
else
  printf "Background data is ${BKG_DATA}.\n"
fi

if [[ ! ${BKG_INT} =~ ${INT_RE} ]]; then
  printf "ERROR: \${BKG_INT}, ${BKG_INT}, is not an integer.\n"
  exit 1
elif [ ${BKG_INT} -le 0 ]; then
  printf "ERROR: \${BKG_INT} must be HH > 0 for the frequency of data inputs.\n"
  exit 1
else
  printf "Background data forcing interval is ${BKG_INT}\n"
fi

if [[ ! ${MAX_DOM} =~ ${INT_RE} ]]; then
  printf "ERROR: \${MAX_DOM}, ${MAX_DOM}, is not an integer.\n"
  exit 1
elif [[ ${#MAX_DOM} -ne 2 ]]; then
  printf "ERROR: \${MAX_DOM}, ${MAX_DOM} is not in DD format.\n"
  exit 1
elif [ ${MAX_DOM} -le 00 ]; then
  printf "ERROR: \${MAX_DOM} must be an integer for the max WRF domain index > 00.\n"
  exit 1
fi

# define a sequence of all domains in padded syntax
dmns=`seq -f "%02g" 1 ${MAX_DOM}`

##################################################################################
# Define metgrid workflow dependencies
##################################################################################
# Below variables are defined in workflow variables
#
# WPS_ROOT  = Root directory of a clean WPS build
# CYC_HME   = Cycle YYYYMMDDHH named directory for cycling data
# MPIRUN    = MPI multiprocessing evaluation call, machine specific
# N_NDES    = Total number of nodes
# N_PROC    = The total number of processes-per-node
#
##################################################################################

if [ -z ${WPS_ROOT} ]; then
  printf "ERROR: \${WPS_ROOT} is not defined.\n"
  exit 1
elif [ ! -d ${WPS_ROOT} ]; then
  printf "ERROR: \${WPS_ROOT} directory\n ${WPS_ROOT}\n does not exist.\n"
  exit 1
fi

if [ -z ${CYC_HME} ]; then
  printf "ERROR: \${CYC_HME} is not defined.\n"
  exit 1
elif [ ! -d ${CYC_HME} ]; then
  printf "ERROR: \${CYC_HME} directory\n ${CYC_HME}\n does not exist.\n"
  exit 1
fi

if [[ ! ${N_NDES} =~ ${INT_RE} ]]; then
  printf "ERROR: \${N_NDES}, ${N_NDES}, is not an integer.\n"
  exit 1
elif [ ${N_NDES} -le 0 ]; then
  msg="ERROR: The variable \${N_NDES} must be set to the number"
  msg+=" of nodes to run metgrid.exe > 0.\n"
  printf "${msg}"
  exit 1
fi

if [[ ! ${N_PROC} =~ ${INT_RE} ]]; then
  printf "ERROR: \${N_PROC}, ${N_PROC}, is not an integer.\n"
  exit 1
elif [ ${N_PROC} -le 0 ]; then
  msg="ERROR: The variable \${N_PROC} must be set to the number"
  msg+=" of processes-per-node to run metgrid.exe > 0.\n"
  printf "${msg}"
  exit 1
fi

mpiprocs=$(( ${N_NDES} * ${N_PROC} ))

if [ -z ${MPIRUN} ]; then
  printf "ERROR: \${MPIRUN} is not defined.\n"
  exit 1
elif [ ${MPIRUN} = 'srun' ]; then
  par_run=${MPIRUN}
else
  par_run="${MPIRUN} -n ${mpiprocs}"
fi

printf "MPI run command is ${par_run}.\n"

##################################################################################
# Begin pre-metgrid setup
##################################################################################
# The following paths are relative to workflow root paths
#
# ungrib_dir  = Directory from which ungrib data is sourced
# work_dir    = Work directory where metgrid_exe runs and outputs
# wps_files   = All file contents of clean WPS directory
# metgrid_exe = Path and name of working executable
#
##################################################################################

# define work root and change directories
work_dir=${CYC_HME}/wrf_metgrid/ens_${memid}
cmd="mkdir -p ${work_dir}; cd ${work_dir}"
if [ ${dbg} = 1 ]; then
  printf "${cmd}\n" >> ${scrpt}; eval "${cmd}"
else
  printf "${cmd}\n"; eval "${cmd}"
fi

# Check that metgrid executable exists and runs
metgrid_exe=${WPS_ROOT}/metgrid.exe
if [ ! -x ${metgrid_exe} ]; then
  printf "ERROR:\n ${metgrid_exe}\n does not exist, or is not executable.\n"
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

# Remove any previous namelists
cmd="rm -f namelist.wps"
if [ ${dbg} = 1 ]; then
  printf "${cmd}\n" >> ${scrpt}; eval "${cmd}"
else
  printf "${cmd}\n"; eval "${cmd}"
fi

# Remove any previous geogrid static files
cmd="rm -f geo_em.*"
if [ ${dbg} = 1 ]; then
  printf "${cmd}\n" >> ${scrpt}; eval "${cmd}"
else
  printf "${cmd}\n"; eval "${cmd}"
fi

# Remove pre-existing metgrid files
cmd="rm -f met_em.*.nc"
if [ ${dbg} = 1 ]; then
  printf "${cmd}\n" >> ${scrpt}; eval "${cmd}"
else
  printf "${cmd}\n"; eval "${cmd}"
fi

# Move existing log files to a subdir if there are any
printf "Checking for pre-existing log files.\n"
if [ -f metgrid.log.0000 ]; then
  logdir=metgrid_log.`ls -l --time-style=+%Y-%m-%d_%H_%M%_S metgrid.log.0000 | cut -d" " -f 6`
  mkdir ${logdir}
  printf "Moving pre-existing log files to ${logdir}.\n"
  cmd="mv metgrid.log.* ${logdir}"
  if [ ${dbg} = 1 ]; then
    printf "${cmd}\n" >> ${scrpt}; eval "${cmd}"
  else
    printf "${cmd}\n"; eval "${cmd}"
  fi
else
  printf "No pre-existing log files were found.\n"
fi

# Remove any ungrib outputs
cmd="rm -f ${BKG_DATA}:*"
if [ ${dbg} = 1 ]; then
  printf "${cmd}\n" >> ${scrpt}; eval "${cmd}"
else
  printf "${cmd}\n"; eval "${cmd}"
fi

# check for the ungrib case products and link to them
ungrib_dir=${CYC_HME}/ungrib/ens_${memid}
if [ ! -d ${ungrib_dir} ]; then
  printf "ERROR: \${ungrib_dir} directory\n ${ungrib_dir}\n does not exist.\n"
  exit 1
else
  for fcst in ${fcst_seq[@]}; do
    filename="${ungrib_dir}/${BKG_DATA}:`date +%Y-%m-%d_%H -d "${strt_dt} ${fcst} hours"`"
    if [ ! -s ${filename} ]; then
      printf "ERROR: ${filename} is missing.\n"
      exit 1
    else
      cmd="ln -sfr ${filename} ."
      if [ ${dbg} = 1 ]; then
        printf "${cmd}\n" >> ${scrpt}
      else
        printf "${cmd}\n"; eval "${cmd}"
      fi
    fi
  done
fi

# Check to make sure the geogrid input files (e.g. geo_em.d01.nc)
# are available and make links to them
for dmn in ${dmns[@]}; do
  filename=${cfg_dir}/static/geo_em.d${dmn}.nc
  if [ ! -r "${filename}" ]; then
    printf "ERROR: Input file\n ${filename}\n is missing.\n"
    exit 1
  else
    cmd="ln -sf ${filename} ."
    if [ ${dbg} = 1 ]; then
      printf "${cmd}\n" >> ${scrpt}
    else
      printf "${cmd}\n"; eval "${cmd}"
    fi
  fi
done

##################################################################################
#  Build WPS namelist
##################################################################################
# Copy the wps namelist template, from the Cylc installation of workflow
filename=${CYLC_WORKFLOW_RUN_DIR}/namelists/namelist.wps
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

# propagate settings to three domains
out_sd="'${strt_iso}','${strt_iso}','${strt_iso}'"
out_ed="'${stop_iso}','${stop_iso}','${stop_iso}'"

# Update interval in namelist
data_int_sec=$(( 3600 * 10#${BKG_INT}))

# Update fg_name to name of background data
if [ ${IF_ECMWF_ML} = ${YES} ]; then
  out_fg_name="'${BKG_DATA}', 'PRES'"
else
  out_fg_name="'${BKG_DATA}'"
fi

# generate here file for template parameter replacement
cat << EOF > replace_param.tmp
cat namelist.wps \
| sed "s/= STRT_DT,/= ${out_sd},/" \
| sed "s/= STOP_DT,/= ${out_ed},/" \
| sed "s/= MAX_DOM,/= ${MAX_DOM},/" \
| sed "s/= INT_SEC,/= ${data_int_sec},/" \
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
# Run metgrid 
##################################################################################

# Print run parameters
printf "\n"
printf "EXP_NME  = ${EXP_NME}\n"
printf "MEMID    = ${MEMID}\n"
printf "CYC_HME  = ${CYC_HME}\n"
printf "STRT_DT  = ${strt_iso}\n"
printf "STOP_DT  = ${stop_iso}\n"
printf "BKG_DATA = ${BKG_DATA}\n"
printf "BKG_INT  = ${BKG_INT}\n"
printf "MAX_DOM  = ${MAX_DOM}\n"
printf "\n"

cmd="${par_run} ${metgrid_exe}; error=\$?"

if [ ${dbg} = 1 ]; then
  printf "${cmd}\n" >> ${scrpt}
  mv ${scrpt} ${work_dir}/run_metgrid.sh
  printf "Setup of metgrid work directory and run script complete.\n"
  exit 0
fi

now=`date +%Y-%m-%d_%H_%M_%S`
printf "metgrid started at ${now}.\n"
printf "${cmd}\n"; eval "${cmd}"

##################################################################################
# Run time error check
##################################################################################
printf "metgrid exited with code ${error}.\n"

# save metgrid logs
log_dir=metgrid_log.${now}
mkdir ${log_dir}
cmd="mv metgrid.log* ${log_dir}"
printf "${cmd}\n"; eval "${cmd}"

cmd="mv namelist.wps ${log_dir}"
printf "${cmd}\n"; eval "${cmd}"

# Remove links to the WPS run files
for filename in ${wps_files[@]}; do
  cmd="rm -f `basename ${filename}`"
  printf "${cmd}\n"; eval "${cmd}"
done

# Remove ungrib outputs
cmd="rm -f ${BKG_DATA}:*"
printf "${cmd}\n"; eval "${cmd}"

# Remove any previous geogrid static files
cmd="rm -f geo_em.d*"
printf "${cmd}\n"; eval "${cmd}"

# check run error code
if [ ${error} -ne 0 ]; then
  printf "ERROR:\n ${metgrid_exe}\n exited with status ${error}.\n"
  exit ${error}
fi

# Check to see if metgrid outputs are generated
for dmn in ${dmns[@]}; do
  for fcst in ${fcst_seq[@]}; do
    dt_str=`date +%Y-%m-%d_%H_%M_%S -d "${strt_dt} ${fcst} hours"`
    out_name="met_em.d${dmn}.${dt_str}.nc"
    error=0
    if [ ! -s "${out_name}" ]; then
      printf "ERROR:\n ${metgrid_exe}\n failed to complete ${out_name}.\n"
      error=1
    else
      printf "${metgrid}\n generated ${out_name}.\n"
    fi
    if [ ${error} = 1 ]; then
      exit 1
    fi
  done
done

printf "wrf_metgrid.sh completed successfully at `date +%Y-%m-%d_%H_%M_%S`.\n"

##################################################################################
# end

exit 0
