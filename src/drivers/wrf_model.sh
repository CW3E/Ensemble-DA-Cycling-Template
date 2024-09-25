#!/bin/bash
##################################################################################
# Description
##################################################################################
# This driver script is a major fork and rewrite of the Rocoto workflow
# WRF driver script of Christopher Harrop Licensed for modification /
# redistribution in the License Statement below.
#
# The purpose of this fork is to work in a Rocoto-based
# Observation-Analysis-Forecast cycle with GSI for data denial
# experiments. Naming conventions in this script have been smoothed
# to match a companion major fork of the standard gsi.ksh
# driver script provided in the GSI tutorials.
#
# One should write machine specific options for the WRF environment
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
#     Script Name: wrf_wps.ksh
#
#         Author: Christopher Harrop
#                 Forecast Systems Laboratory
#                 325 Broadway R/FST
#                 Boulder, CO. 80305
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
  printf "${cmd}\n"; ${cmd}
fi

if [ ! -x ${MOD_ENV} ]; then
  msg="ERROR: model environment file\n ${MOD_ENV}\n does not exist"
  msg+=" or is not executable.\n"
  printf "${msg}"
  exit 1
else
  # Read model environment into the current shell
  cmd=". ${MOD_ENV}"
  printf "${cmd}\n"; ${cmd}
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
# Make checks for WRF settings
##################################################################################
# Options below are defined in workflow variables 
#
# EXP_NME     = Case study / config short name directory structure
# MEMID       = Ensemble ID index, 00 for control, i > 00 for perturbation
# STRT_DT     = Simulation start time in YYYYMMDDHH
# IF_DYN_LEN  = "Yes" or "No" switch to compute forecast length dynamically 
# FCST_HRS    = Total length of WRF forecast simulation in HH, IF_DYN_LEN=No
# EXP_VRF     = Verfication time for calculating forecast hours, IF_DYN_LEN=Yes
# BKG_DATA    = String case variable for supported inputs: GFS, GEFS currently
# BKG_INT     = Interval of input data in HH
# MAX_DOM     = Max number of domains to use in namelist settings
# DOWN_DOM    = First domain index to downscale ICs from d01, set parameter
#               less than MAX_DOM if downscaling to be used
# HIST_INT    = Interval of wrfout in HH
# CYC_INC     = Increment in HH on which to link outputs to next cycle
# WRF_IC      = Defines where to source WRF initial and boundary conditions from
#                 WRF_IC = REALEXE : ICs / BCs from CYC_HME/wrf_real
#                 WRF_IC = CYCLING : ICs / BCs from GSI / WRFDA analysis
#                 WRF_IC = RESTART : ICs from restart file in CYC_HME/wrf_model
# IF_SST_UPDT = Yes / No: whether WRF uses dynamic SST values 
# IF_FEEBACK  = Yes / No: whether WRF domains use 1- or 2-way nesting
#
##################################################################################

if [ -z ${EXP_NME} ]; then
  printf "ERROR: Case study / config short name \${EXP_NME} is not defined.\n"
  exit 1
else
  IFS="/" read -ra exp_nme <<< ${EXP_NME}
  cse_nme=${exp_nme[0]}
  cfg_nme=${exp_nme[1]}
  printf "Setting up configuration:\n    ${cfg_nme}\n"
  printf "for:\n    ${cse_nme}\n case study.\n"
fi

if [[ ! ${MEMID} =~ ${INT_RE} ]]; then
  printf "ERROR: \${MEMID}, ${MEMID}, is not an integer.\n"
  exit 1
else
  # ensure padding to two digits is included
  memid=`printf %02d $(( 10#${MEMID} ))`
  printf "Running WRF for ensemble member ${MEMID}.\n"
fi

if [[ ! ${STRT_DT} =~ ${ISO_RE} ]]; then
  printf "ERROR: \${STRT_DT}, ${STRT_DT}, is not in 'YYYYMMDDHH' format.\n"
  exit 1
else
  # Convert STRT_DT from 'YYYYMMDDHH' format to strt_dt Unix date format
  strt_dt="${STRT_DT:0:8} ${STRT_DT:8:2}"
  strt_dt=`date -d "${strt_dt}"`
fi

if [[ ! ${CYC_DT} =~ ${ISO_RE} ]]; then
  printf "ERROR: \${CYC_DT}, ${CYC_DT}, is not in 'YYYYMMDDHH' format.\n"
  exit 1
else
  # Convert CYC_DT from 'YYYYMMDDHH' format to cyc_dt Unix date format
  cyc_dt="${CYC_DT:0:8} ${CYC_DT:8:2}"
  cyc_dt=`date -d "${cyc_dt}"`
fi

if [[ ${IF_DYN_LEN} = ${NO} ]]; then 
  printf "Generating fixed length forecast forcing data.\n"
  if [[ ! ${FCST_HRS} =~ ${INT_RE} ]]; then
    printf "ERROR: \${FCST_HRS}, ${FCST_HRS}, is not an integer.\n"
    exit 1
  else
    # parse forecast hours as base 10 padded
    fcst_hrs=`printf %03d $(( 10#${FCST_HRS} ))`
    printf "Forecast length is ${fcst_hrs} hours.\n"
  fi
elif [[ ${IF_DYN_LEN} = ${YES} ]]; then
  printf "Forecast runs until data until experiment validation time.\n"
  if [[ ! ${EXP_VRF} =~ ${ISO_RE} ]]; then
    printf "ERROR: \${EXP_VRF}, ${EXP_VRF}, is not in 'YYYYMMDDHH' format.\n"
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

# define the end time based on forecast length control flow above
stop_dt=`date -d "${strt_dt} ${fcst_hrs} hours"`

if [[ ! ${BKG_INT} =~ ${INT_RE} ]]; then
  printf "ERROR: \${BKG_INT}, ${BKG_INT}, is not an integer.\n"
  exit 1
elif [ ! ${BKG_INT} -gt 0 ]; then
  printf "ERROR: \${BKG_INT} must be HH > 0 for the frequency of data inputs.\n"
  exit 1
else
  printf "Background data forcing interval is ${BKG_INT}\n"
fi

if [[ ${BKG_DATA} != GFS && ${BKG_DATA} != GEFS ]]; then
  msg="ERROR: \${BKG_DATA} must equal 'GFS' or 'GEFS'"
  msg+=" as currently supported inputs.\n"
  printf "${msg}"
  exit 1
else
  printf "Background data is ${BKG_DATA}.\n"
fi

if [[ ! ${MAX_DOM} =~ ${INT_RE} ]]; then
  printf "ERROR: \${MAX_DOM}, ${MAX_DOM}, is not an integer.\n"
  exit 1
elif [[ ${#MAX_DOM} -ne 2 ]]; then
  printf "ERROR: \${MAX_DOM}, ${MAX_DOM}, is not in DD format.\n"
  exit 1
elif [ ! ${MAX_DOM} -gt 00 ]; then
  printf "ERROR: \${MAX_DOM} must be an integer for the max WRF domain index > 00.\n"
  exit 1
else
  printf "The maximum simulation domain for WRF is d${MAX_DOM}.\n"
fi

# define a sequence of all domains in padded syntax
dmns=`seq -f "%02g" 1 ${MAX_DOM}`

if [[ ! ${DOWN_DOM} =~ ${INT_RE} ]]; then
  printf "ERROR: \${DOWN_DOM}, ${DOWN_DOM}, is not an integer.\n"
  exit 1
elif [ ${#DOWN_DOM} -ne 2 ]; then
  printf "ERROR: \${DOWN_DOM}, ${DOWN_DOM}, is not in DD format.\n"
  exit 1
elif [ ! ${DOWN_DOM} -gt 01 ]; then
  msg="ERROR: \${DOWN_DOM} must be an integer for the first WRF domain index "
  msg+=" to be downscaled from parent ( > 01 ).\n" 
  printf "${msg}"
  exit 1
else
  printf "The first nested downscaled domain for WRF is d${DOWN_DOM}.\n"
fi

if [[ ! ${HIST_INT} =~ ${INT_RE} ]]; then
  printf "ERROR: \${HIST_INT}, ${HIST_INT}, is not an integer.\n"
  exit 1
elif [ ! ${HIST_INT} -gt 00 ]; then
  printf "ERROR: \${HIST_INT} must be HH > 0 for the frequency of data inputs.\n"
  exit 1
else
  printf "The WRF history interval is ${HIST_INT} hours.\n"
  # define a sequence of all forecast hours with background interval spacing
  hist_seq=`seq -f "%03g" 0 ${HIST_INT} ${fcst_hrs}`
fi

if [[ ${RSTRT_INT} =~ ${END} ]]; then
  printf "WRF restart files written at end of forcast: ${fcst_hrs} hours.\n"
  rstrt_seq=`seq -f "%03g" ${fcst_hrs} ${fcst_hrs} ${fcst_hrs}`
  rstrt_int=${fcst_hrs}
elif [[ ! ${RSTRT_INT} =~ ${INT_RE} ]]; then
  printf "ERROR: \${RSTRT_INT}, ${RSTRT_INT}, is not in HH format.\n"
  exit 1
elif [ ${RSTRT_INT} -lt 00 ]; then
  printf "ERROR: \${RSTRT_INT} must be HH >= 0 for the frequency of data inputs.\n"
  exit 1
elif [ ${RSTRT_INT} -gt 00 ]; then
  printf "The WRF restart interval is ${RSTRT_INT} hours.\n"
  # define a sequence of all forecast hours with background interval spacing
  rstrt_seq=`seq -f "%03g" ${RSTRT_INT} ${RSTRT_INT} ${fcst_hrs}`
  rstrt_int=${RSTRT_INT}
else
  # define an empty list
  rstrt_seq=()
  rstrt_int=${RSTRT_INT}
fi

if [[ ! ${CYC_INC} =~ ${INT_RE} ]]; then
  printf "ERROR: \${CYC_INC}, ${CYC_INC}, is not an integer.\n"
  exit 1
elif [ ${CYC_INC} -lt 0 ]; then
  printf "ERROR: \${CYC_INC} must be an integer for the number of cycle hours >= 0.\n"
fi

if [[ ${WRF_IC} = ${REALEXE} ]]; then
  printf "WRF initial and boundary conditions sourced from real.exe.\n"
elif [[ ${WRF_IC} = ${CYCLING} ]]; then
  msg="WRF initial conditions and boundary conditions sourced from GSI / WRFDA "
  msg+=" analysis.\n"
  printf "${msg}"
elif [[ ${WRF_IC} = ${RESTART} ]]; then
  printf "WRF initial conditions sourced from restart files.\n"
else
  msg="ERROR: \${WRF_IC}, ${WRF_IC}, must equal REALEXE, CYCLING or RESTART "
  msg+=" (case insensitive).\n"
  printf "${msg}"
  exit 1
fi

if [[ ${IF_SST_UPDT} = ${YES} ]]; then
  printf "SST Update turned on.\n"
  sst_updt=1
elif [[ ${IF_SST_UPDT} = ${NO} ]]; then
  printf "SST Update turned off.\n"
  sst_updt=0
else
  printf "ERROR: \${IF_SST_UPDT} must equal 'Yes' or 'No' (case insensitive).\n"
  exit 1
fi

if [[ ${IF_FEEDBACK} = ${YES} ]]; then
  printf "Two-way WRF nesting is turned on.\n"
  feedback=1
elif [[ ${IF_FEEDBACK} = ${NO} ]]; then
  printf "One-way WRF nesting is turned on.\n"
  feedback=0
else
  printf "ERROR: \${IF_FEEDBACK} must equal 'Yes' or 'No' (case insensitive).\n"
  exit 1
fi

##################################################################################
# Define WRF workflow dependencies
##################################################################################
# Below variables are defined in workflow variables
#
# WRF_ROOT = Root directory of a clean WRF build WRF/run directory
# CYC_HME  = Cycle YYYYMMDDHH named directory for cycling data
# MPIRUN   = MPI multiprocessing evaluation call, machine specific
# N_NDES   = Total number of nodes
# N_PROC   = The total number of processes-per-node
# NIO_GRPS = Number of Quilting groups -- only used for NIO_TPG > 0
# NIO_TPG  = Quilting tasks per group, set=0 if no quilting IO is to be used
#
##################################################################################

if [ -z ${WRF_ROOT} ]; then
  printf "ERROR: \${WRF_ROOT} is not defined.\n"
  exit 1
elif [ ! -d ${WRF_ROOT} ]; then
  printf "ERROR: \${WRF_ROOT} directory\n ${WRF_ROOT}\n does not exist.\n"
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
  msg+=" of nodes to run wrf.exe > 0.\n"
  printf "${msg}"
  exit 1
fi

if [[ ! ${N_PROC} =~ ${INT_RE} ]]; then
  printf "ERROR: \${N_PROC}, ${N_PROC}, is not an integer.\n"
  exit 1
elif [ ${N_PROC} -le 0 ]; then
  msg="ERROR: The variable \${N_PROC} must be set to the number"
  msg+=" of processes-per-node to run wrf.exe > 0.\n"
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
# Begin pre-WRF setup
##################################################################################
# The following paths are relative to workflow supplied root paths
#
# work_dir   = Work directory where WRF runs
# wrf_in_dir = Directory of previous wrf run for restart runs
# wrf_files  = All file contents of clean WRF/run directory
# wrf_exe    = Path and name of working executable
#
##################################################################################

# define work root and change directories
if [[ ${WRF_IC} = ${RESTART} ]]; then
  work_dir=${CYC_HME}/wrf_model_restart/ens_${memid}
  wrf_in_dir=${CYC_HME}/wrf_model/ens_${memid}
  if [[ ! -d ${wrf_in_dir} ]]; then
    printf "ERROR: \${wrf_in_dir} directory\n ${wrf_in_dir}\n does not exist.\n"
    exit 1
  fi
else
  work_dir=${CYC_HME}/wrf_model/ens_${memid}
fi

cmd="mkdir -p ${work_dir}; cd ${work_dir}"
if [ ${dbg} = 1 ]; then
  printf "${cmd}\n" >> ${scrpt}; ${cmd}
else
  printf "${cmd}\n"; ${cmd}
fi

# Check that the wrf executable exists and runs
wrf_exe=${WRF_ROOT}/main/wrf.exe
if [ ! -x ${wrf_exe} ]; then
  printf "ERROR:\n ${wrf_exe}\n does not exist, or is not executable.\n"
  exit 1
fi

# Make links to the WRF run files
wrf_files=(${WRF_ROOT}/run/*)
for filename in ${wrf_files[@]}; do
  cmd="rm -f `basename ${filename}`"
  printf "${cmd}\n"; ${cmd}

  cmd="ln -sf ${filename} ."
  if [ ${dbg} = 0 ]; then
    printf "${cmd}\n"; ${cmd}
  else
    printf "${cmd}\n" >> ${scrpt}
  fi
done

# Remove IC/BC in the directory if old data present
cmd="rm -f wrfinput_*; rm -f wrfbdy_d01"
if [ ${dbg} = 1 ]; then
  printf "${cmd}\n" >> ${scrpt}; ${cmd}
else
  printf "${cmd}\n"; ${cmd}
fi

# Remove any previous namelists
cmd="rm -f namelist.input"
if [ ${dbg} = 1 ]; then
  printf "${cmd}\n" >> ${scrpt}; ${cmd}
else
  printf "${cmd}\n"; ${cmd}
fi

# Remove any old WRF outputs in the directory from failed runs
cmd="rm -f wrfout_*; rm -f wrfrst_*; rm -f auxhist*"
if [ ${dbg} = 1 ]; then
  printf "${cmd}\n" >> ${scrpt}; ${cmd}
else
  printf "${cmd}\n"; ${cmd}
fi

# Link WRF initial conditions
for dmn in ${dmns[@]}; do
  wrfinput=wrfinput_d${dmn}
  dt_str=`date +%Y-%m-%d_%H_%M_%S -d "${strt_dt}"`
  # if cycling AND analyzing this domain, get initial conditions from last analysis
  if [[ ${WRF_IC} = ${CYCLING} && ${dmn} -lt ${DOWN_DOM} ]]; then
    if [[ ${dmn} = 01 ]]; then
      # obtain the boundary files from the lateral boundary update by WRFDA 
      wrfanlroot=${CYC_HME}/wrfda_bc/lateral_bdy_updt/ens_${memid}
      wrfbdy=${wrfanlroot}/wrfbdy_d01
      if [ ! -r "${wrfbdy}" ]; then
        printf "ERROR: wrfinput\n ${wrfbdy}\n does not exist or is not readable.\n"
        exit 1
      fi
      cmd="ln -sfr ${wrfbdy} wrfbdy_d01"
      if [ ${dbg} = 0 ]; then
        printf "${cmd}\n"; ${cmd}
      else
        printf "${cmd}\n" >> ${scrpt}
      fi

    else
      # Nested domains have boundary conditions defined by parent
      if [ ${memid} -eq 00 ]; then
        # control solution is indexed 00, analyzed with GSI
        wrfanl_root=${CYC_HME}/gsi/d${dmn}
      else
        # ensemble perturbations are updated with EnKF step
        wrfanl_root=${CYC_HME}/enkf/d${dmn}
      fi
    fi

    # link the wrf inputs
    wrfanl=${wrfanlroot}/wrfanl_ens_${memid}_${dt_str}
    if [ ! -r ${wrfanl} ]; then
      printf "ERROR: wrfinput source\n ${wrfanl}\n does not exist or is not readable.\n"
      exit 1
    fi

    cmd="ln -sfr ${wrfanl} ${wrfinput}"
    if [ ${dbg} = 1 ]; then
      printf "${cmd}\n" >> ${scrpt}
    else
      printf "${cmd}\n"; ${cmd}
    fi

  elif [[ ${WRF_IC} = ${RESTART} ]]; then
    # check for restart files at valid start time for each domain
    wrfrst=${wrf_in_dir}/wrfrst_d${dmn}_${dt_str}
    if [ ! -r ${wrfrst} ]; then
      printf "ERROR: wrfrst source\n ${wrfrst}\n does not exist or is not readable.\n"
      exit 1
    fi

    cmd="ln -sfr ${wrfrst} ./"
    if [ ${dbg} = 1 ]; then
      printf "${cmd}\n" >> ${scrpt}
    else
      printf "${cmd}\n"; ${cmd}
    fi

    if [[ ${dmn} = 01 ]]; then
      # obtain the boundary files from the lateral boundary update by WRFDA step
      # included for possible re-generation of BCs for longer extended forecast
      wrfanlroot=${CYC_HME}/wrfda_bc/lateral_bdy_updt/ens_${memid}
      wrfbdy=${wrfanlroot}/wrfbdy_d01
      if [ ! -r "${wrfbdy}" ]; then
        printf "ERROR: wrfinput\n ${wrfbdy}\n does not exist or is not readable.\n"
        exit 1
      fi
      cmd="ln -sfr ${wrfbdy} wrfbdy_d01"
      if [ ${dbg} = 1 ]; then
        printf "${cmd}\n" >> ${scrpt}
      else
        printf "${cmd}\n"; ${cmd}
      fi
    fi

  else
    # else get initial and boundary conditions from real for downscaled domains
    realroot=${CYC_HME}/wrf_real/ens_${memid}
    if [ ${dmn} = 01 ]; then
      # Link the wrfbdy_d01 file from real
      wrfbdy=${realroot}/wrfbdy_d01
      if [ ! -r ${wrfbdy} ]; then
        printf "ERROR:\n ${wrfbdy}\n does not exist or is not readable.\n"
        exit 1
      fi

      cmd="ln -sfr ${wrfbdy} wrfbdy_d01"
      if [ ${dbg} = 1 ]; then
        printf "${cmd}\n" >> ${scrpt}
      else
        printf "${cmd}\n"; ${cmd}
      fi

    fi
    realname=${realroot}/${wrfinput}
    if [ ! -r ${realname} ]; then
      printf "ERROR: wrfinput\n ${realname}\n does not exist or is not readable.\n"
      exit 1
    fi

    cmd="ln -sfr ${realname} ."
    if [ ${dbg} = 1 ]; then
      printf "${cmd}\n" >> ${scrpt}
    else
      printf "${cmd}\n"; ${cmd}
    fi
  fi

  # NOTE: THIS LINKS SST UPDATE FILES FROM REAL OUTPUTS REGARDLESS OF GSI CYCLING
  if [[ ${IF_SST_UPDT} = ${YES} ]]; then
    wrflowinp=wrflowinp_d${dmn}
    realname=${CYC_HME}/wrf_real/ens_${memid}/${wrflowinp}
    if [ ! -r ${realname} ]; then
      printf "ERROR: wrflwinp\n ${realname}\n does not exist or is not readable.\n"
      exit 1
    fi

    cmd="ln -sfr ${realname} ."
    if [ ${dbg} = 1 ]; then
      printf "${cmd}\n" >> ${scrpt}
    else
      printf "${cmd}\n"; ${cmd}
    fi
  fi
done

# Move existing rsl files to a subdir if there are any
printf "Checking for pre-existing rsl files.\n"
if [ -f rsl.out.0000 ]; then
  logdir=rsl.wrf.`ls -l --time-style=+%Y-%m-%d_%H_%M%_S rsl.out.0000 | cut -d" " -f 6`
  mkdir ${logdir}
  printf "Moving pre-existing rsl files to ${logdir}.\n"
  cmd="mv rsl.out.* ${logdir}"
  printf "${cmd}\n"; ${cmd}
  cmd="mv rsl.error.* ${logdir}"
  printf "${cmd}\n"; ${cmd}
else
  printf "No pre-existing rsl files were found.\n"
fi

##################################################################################
#  Build WRF namelist
##################################################################################
# Copy the wps namelist template, from the Cylc installation of workflow
filename=${CYLC_WORKFLOW_RUN_DIR}/namelists/namelist.${BKG_DATA}
if [ ! -r ${filename} ]; then 
  msg="WRF namelist template\n ${filename}\n is not readable or "
  msg+="does not exist.\n"
  printf "${msg}"
  exit 1
else
  cmd="cp -L ${filename} ./namelist.input"
  if [ ${dbg} = 0 ]; then
    printf "${cmd}\n"; ${cmd}
  else
    printf "${cmd}\n" >> ${scrpt}
  fi
fi

# Get the start and stop time components
s_Y=`date +%Y -d "${strt_dt}"`
s_m=`date +%m -d "${strt_dt}"`
s_d=`date +%d -d "${strt_dt}"`
s_H=`date +%H -d "${strt_dt}"`
s_M=`date +%M -d "${strt_dt}"`
s_S=`date +%S -d "${strt_dt}"`
e_Y=`date +%Y -d "${stop_dt}"`
e_m=`date +%m -d "${stop_dt}"`
e_d=`date +%d -d "${stop_dt}"`
e_H=`date +%H -d "${stop_dt}"`
e_M=`date +%M -d "${stop_dt}"`
e_S=`date +%S -d "${stop_dt}"`

# define start / stop time iso patterns
strt_iso=`date +%Y-%m-%d_%H_%M_%S -d "${strt_dt}"`
stop_iso=`date +%Y-%m-%d_%H_%M_%S -d "${stop_dt}"`

# Update interval in namelist
data_int_sec=$(( 3600 * 10#${BKG_INT} ))

# update auxinput4 interval
auxinput4_minutes=$(( 60 * 10#${BKG_INT} ))
aux_out="${auxinput4_minutes}, ${auxinput4_minutes}, ${auxinput4_minutes}"

# update history interval and aux2hist interval in minutes
hist_int=$(( 60 * 10#${HIST_INT} ))
out_hist="${hist_int}, ${hist_int}, ${hist_int}"

# update restart interval to minutes
rstrt_int=$(( 60 * 10#${rstrt_int} ))

# Update the restart setting in wrf namelist depending on switch
if [[ ${WRF_IC} = ${RESTART} ]]; then
  wrf_restart=".true."
else
  wrf_restart=".false."
fi

# Update the wrf namelist (propagates settings to three domains)
cat << EOF > replace_param.tmp
cat namelist.input \
| sed "s/= STRT_Y,/= ${s_Y}, ${s_Y}, ${s_Y},/" \
| sed "s/= STRT_m,/= ${s_m}, ${s_m}, ${s_m},/" \
| sed "s/= STRT_d,/= ${s_d}, ${s_d}, ${s_d},/" \
| sed "s/= STRT_H,/= ${s_H}, ${s_H}, ${s_H},/" \
| sed "s/= STRT_M,/= ${s_M}, ${s_M}, ${s_M},/" \
| sed "s/= STRT_S,/= ${s_S}, ${s_S}, ${s_S},/" \
| sed "s/= STOP_Y,/= ${e_Y}, ${e_Y}, ${e_Y},/" \
| sed "s/= STOP_m,/= ${e_m}, ${e_m}, ${e_m},/" \
| sed "s/= STOP_d,/= ${e_d}, ${e_d}, ${e_d},/" \
| sed "s/= STOP_H,/= ${e_H}, ${e_H}, ${e_H},/" \
| sed "s/= STOP_M,/= ${e_M}, ${e_M}, ${e_M},/" \
| sed "s/= STOP_S,/= ${e_S}, ${e_S}, ${e_S},/" \
| sed "s/= MAX_DOM,/= ${MAX_DOM},/" \
| sed "s/= INT_SEC,/= ${data_int_sec},/" \
| sed "s/= IF_SST_UPDT,/= ${sst_updt},/"\
| sed "s/= AUXINPUT4_INT,/= ${aux_out},/" \
| sed "s/= AUXHIST2_INT,/= ${out_hist},/" \
| sed "s/= HIST_INT,/= ${out_hist},/" \
| sed "s/= RSTRT,/= ${wrf_restart},/" \
| sed "s/= RSTRT_INT,/= ${rstrt_int},/" \
| sed "s/= IF_FEEDBACK,/= ${feedback},/"\
| sed "s/= NIO_TPG,/= ${NIO_TPG},/" \
| sed "s/= NIO_GRPS,/= ${NIO_GRPS},/" \
> namelist.input.tmp
mv namelist.input.tmp namelist.input
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
# Run WRF
##################################################################################

# Print run parameters
printf "\n"
printf "EXP_NME     = ${EXP_NME}\n"
printf "MEMID       = ${MEMID}\n"
printf "CYC_HME     = ${CYC_HME}\n"
printf "STRT_DT     = ${strt_iso}\n"
printf "STOP_DT     = ${stop_iso}\n"
printf "HIST_INT    = ${HIST_INT}\n"
printf "BKG_DATA    = ${BKG_DATA}\n"
printf "MAX_DOM     = ${MAX_DOM}\n"
printf "WRF_IC      = ${WRF_IC}\n"
printf "IF_SST_UPDT = ${IF_SST_UPDT}\n"
printf "IF_FEEDBACK = ${IF_FEEDBACK}\n"
printf "\n"

cmd="${par_run} ${wrf_exe}"

if [ ${dbg} = 1 ]; then
  printf "${cmd}\n" >> ${scrpt}
  mv ${scrpt} ${work_dir}/run_wrf.sh
  printf "Setup of wrf work directory and run script complete.\n"
  exit 0
fi

now=`date +%Y-%m-%d_%H_%M_%S`
printf "wrf started at ${now}.\n"
printf "${cmd}\n"; ${cmd}

##################################################################################
# Run time error check
##################################################################################

error="$?"
printf "wrf exited with code ${error}.\n"

# Save a copy of the RSL files
logdir=rsl.wrf.${now}
mkdir ${logdir}
cmd="mv rsl.out.* ${logdir}"
printf "${cmd}\n"; ${cmd}
cmd="mv rsl.error.* ${logdir}"
printf "${cmd}\n"; ${cmd}
cmd="mv namelist.* ${logdir}"
printf "${cmd}\n"; ${cmd}

# Remove links to the WRF run files
for filename in ${wrf_files[@]}; do
    cmd="rm -f `basename ${filename}`"
    printf "${cmd}\n"; ${cmd}
done

# remove links to input / boundary condition data
cmd="rm -f wrfinput_*; rm -f wrfbdy_*; rm -f wrflowinp_*"
printf "${cmd}\n"; ${cmd}

# remove Thompson MP dat files generated by executable
cmd="rm -f *.dat"
printf "${cmd}\n"; ${cmd}

# check run error code
if [ ${error} -ne 0 ]; then
  printf "ERROR:\n ${wrf_exe}\n exited with status ${error}.\n"
  exit ${error}
fi

# Look for successful completion messages adjusted for quilting processes
nsuccess=`cat ${logdir}/rsl.* | awk '/SUCCESS COMPLETE WRF/' | wc -l`
ntotal=$(( (${mpiprocs} - ${NIO_GRPS} * ${NIO_TPG} ) * 2 ))
printf "Found ${nsuccess} of ${ntotal} completion messages.\n"
if [ ${nsuccess} -ne ${ntotal} ]; then
  msg="ERROR: ${wrf_exe} did not complete successfully, missing completion "
  msg+="messages in rsl.* files.\n"
  printf "${msg}"
fi

if [ ${CYC_INC} -gt 0 ]; then
  # ensure that the bkg directory exists in next ${CYC_HME}
  dt_str=`date +%Y%m%d%H -d "${cyc_dt} ${CYC_INC} hours"`
  new_bkg=${dt_str}/bkg/ens_${memid}
  cmd="mkdir -p ${CYC_HME}/../${new_bkg}"
  printf "${cmd}\n"; ${cmd}
fi

# Check for all wrfout files on HIST_INT and link files to
# the appropriate bkg directory
error=0
for dmn in ${dmns[@]}; do
  for fcst in ${hist_seq[@]}; do
    dt_str=`date +%Y-%m-%d_%H_%M_%S -d "${strt_dt} ${fcst} hours"`
    if [ ! -s wrfout_d${dmn}_${dt_str} ]; then
      msg="ERROR:\n ${wrf_exe}\n failed to complete, wrfout_d${dmn}_${dt_str} "
      msg+="is missing or empty.\n"
      printf "${msg}"
      error=1
    elif [ ${CYC_INC} -gt 0 ]; then
      cmd="ln -sfr wrfout_d${dmn}_${dt_str} ${CYC_HME}/../${new_bkg}"
      printf "${cmd}\n"; ${cmd}

      # if performing a restart run, link the outputs back to the original
      # run directory for sake of easy post-processing
      if [[ ${WRF_IC} = ${RESTART} ]]; then
        cmd="ln -sfr wrfout_d${dmn}_${dt_str} ${wrf_in_dir}"
        printf "${cmd}\n"; ${cmd}
      fi
    fi
  done
  if [ ${rstrt_int} -gt 0 ]; then
    for fcst in ${rstrt_seq[@]}; do
      # Check for all wrfrst files for each domain at 
      # the appropriate bkg directory
      dt_str=`date +%Y-%m-%d_%H_%M_%S -d "${strt_dt} ${fcst} hours"`
      if [ ! -s wrfrst_d${dmn}_${dt_str} ]; then
        msg="ERROR:\n ${wrf_exe}\n failed to complete, wrfrst_d${dmn}_${dt_str} is "
        msg+="missing or empty.\n"
        printf "${msg}"
        error=1
      elif [ ${CYC_INC} -gt 0 ]; then
        cmd="ln -sfr wrfrst_d${dmn}_${dt_str} ${CYC_HME}/../${new_bkg}"
        printf "${cmd}\n"; ${cmd}

        # if performing a restart run, link the outputs back to the original
        # run directory for sake of easy post-processing
        if [[ ${WRF_IC} = ${RESTART} ]]; then
          cmd="ln -sfr wrfrst_d${dmn}_${dt_str} ${wrf_in_dir}"
          printf "${cmd}\n"; ${cmd}
        fi
      fi
      if [ ${error} = 1 ]; then
        exit 1	
      fi
    done
  fi
done

printf "wrf_model.sh completed successfully at `date +%Y-%m-%d_%H_%M_%S`.\n"

##################################################################################
# end

exit 0
