#!/bin/bash
##################################################################################
# Description
##################################################################################
# This driver script utilizes WRFDA to update lower and lateral boundary
# conditions in conjunction with GSI updating the initial conditions.
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
# Make checks for WRFDA settings
##################################################################################
# Options below are defined in workflow
#
# EXP_NME     = Case study / config short name directory structure
# CYC_DT      = Analysis time YYYYMMDDHH
# BOUNDARY    = 'LOWER' if updating lower boundary conditions 
#               'LATERAL' if updating lateral boundary conditions
# WRF_CTR_DOM = Max domain index of control forecast to update BOUNDARY=LOWER
# IF_ENS_UPDT = Skip lower / lateral BC updates if 'No'
# ENS_SIZE    = Total ensemble size to loop updates IF_ENS_UPDATE='Yes'
# ENS_DIR     = Forecast ensemble located at ${ENS_DIR}/ens_${memid}/wrfout* 
# WRF_ENS_DOM = Max domain index of ensemble perturbations
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
  # configuration name is separated on '.' to denote sub-config, leading part
  # is used for the mpas static file naming
  IFS="." read -ra tmp_nme <<< ${cfg_nme}
  stc_nme=${tmp_nme[0]}
  printf "Setting up configuration:\n    ${stc_nme}\n"
  if [ ${#tmp_nme[@]} -eq 2 ]; then
    printf "sub-configuration:\n    ${tmp_nme[1]}\n"
  fi
  printf "for:\n    ${cse_nme}\n case study.\n"
  cfg_dir=${HOME}/cylc-src/${EXP_NME}
  if [ ! -d ${cfg_dir} ]; then
    printf "ERROR: simulation settings directory\n ${cfg_dir}\n does not exist.\n"
    exit 1
  fi
fi

# Convert CYC_DT from 'YYYYMMDDHH' format to cyc_dt iso format
if [[ ${CYC_DT} =~ ${ISO_RE} ]]; then
  printf "ERROR: \${CYC_DT}, ${CYC_DT}, is not in 'YYYYMMDDHH' format.\n"
  exit 1
else
  cyc_dt=${CYC_DT:0:8}
  hh=${CYC_DT:8:2}
  cyc_dt=`date +%Y-%m-%d_%H_%M_%S -d "${cyc_dt} ${hh} hours"`
fi

if [[ ${BOUNDARY} = ${LOWER} ]]; then
  if [[ ! ${WRF_CTR_DOM} =~ ${INT_RE} ]]; then
    msg="ERROR: \${WRF_CTR_DOM},\n ${WRF_CTR_DOM}\n is not an integer, it"
    msg+=" must equal the max domain to update lower boundary conditions.\n"
    printf "${msg}"
    exit 1
  elif [ ${#WRF_CTR_DOM} -ne 2 ]; then
    printf "ERROR: \${WRF_CTR_DOM}, ${WRF_CTR_DOM}, is not in DD format.\n"
    exit 1
  fi
  msg="Updating lower boundary conditions for WRF control domains "
  msg+="d01 through d${WRF_CTR_DOM}.\n"
  printf "${msg}"
elif [[ ${BOUNDARY} = ${LATERAL} ]]; then
  printf "Updating WRF control lateral boundary conditions.\n"
else
  msg="ERROR: \${BOUNDARY}, ${BOUNDARY}, must equal 'LOWER' or 'LATERAL'"
  msg+="(case insensitive).\n"
  printf "${msg}"
  exit 1
fi

if [[ ${IF_ENS_UPDT} = ${NO} ]]; then
  # skip the boundary updates for the ensemble, perform on control alone
  ens_max=0
elif [[ ${IF_ENS_UPDT} = ${YES} ]]; then
  if [[ ! ${ENS_SIZE} =~ ${INT_RE} ]]; then
    printf "ERROR: \${ENS_SIZE}\n ${ENS_SIZE}\n is not an integer.\n"
    exit 1
  fi
  if [ -z ${ENS_DIR} ]; then
    printf "ERROR: \${ENS_DIR} is not defined.\n"
    exit 1
  elif [[ ! -d ${ENS_DIR} || ! -x ${ENS_DIR} ]]; then
    msg="ERROR: \${ENS_DIR} directory\n ${ENS_DIR}\n does not exist"
    msg+=" or is not executable.\n"
    printf "${msg}"
    exit 1
  elif [[ ${BOUNDARY} = LOWER && ! ${WRF_ENS_DOM} ~= ${INT_RE} ]]; then
    printf "ERROR: \${WRF_ENS_DOM}, ${WRF_ENS_DOM}, is not an integer.\n"
    exit 1
  elif [[ ${BOUNDARY} = LOWER && ${#WRF_ENS_DOM} -ne 2 ]]; then
    printf "ERROR: \${WRF_ENS_DOM}, ${WRF_ENS_DOM}, is not in DD format.\n"
    exit 1
  else
    # perform over the entire ensemble
    ens_max=$(( ${ENS_SIZE} - 1 ))
    msg="Updating lower boundary conditions for WRF perturbation domains "
    msg+="d01 through d${WRF_ENS_DMN}."
    printf "${msg}"
  fi
else
  printf "ERROR: \${IF_ENS_UPDT} must equal 'Yes' or 'No' (case insensitive).\n"
  exit 1
fi

##################################################################################
# Define wrfda dependencies
##################################################################################
# Below variables are defined in control flow variables
#
# WRFDA_ROOT = Root directory of a WRFDA build 
# CYC_HME    = Start date ISO named directory for cycling data
#
##################################################################################

if [ -z ${WRFDA_ROOT} ]; then
  printf "ERROR: \${WRFDA_ROOT} is not defined.\n"
  exit 1
elif [[ ! -d ${WRFDA_ROOT} || ! -x ${WRFDA_ROOT} ]]; then
  msg="ERROR: \${WRFDA_ROOT} directory\n ${WRFDA_ROOT}\n does not exist"
  msg+=" or is not executable.\n"
  printf "${msg}"
  exit 1
fi

if [ ! ${CYC_HME} ]; then
  printf "ERROR: \${CYC_HME} is not defined.\n"
  exit 1
elif [ ! -d "${CYC_HME}" ]; then
  printf "ERROR: \${CYC_HME} directory\n ${CYC_HME}\n does not exist.\n"
  exit 1
fi

##################################################################################
# Begin pre-WRFDA setup
##################################################################################
# The following paths are relative to control flow supplied root paths
#
# work_dir     = Directory where da_update_bc.exe runs
# real_dir     = Directory real.exe runs and outputs IC and BC files for cycle
# ctr_dir      = Directory with control WRF forecast for lower boundary update 
# ens_dir      = Directory with ensemble WRF forecast for lower boundary update 
# gsi_dir      = Directory with GSI control analysis for lateral update
# enkf_dir     = Directory with EnKF analysis for ensemble lateral update
# updt_bc_exe  = Path and name of the update executable
#
##################################################################################

for memid in `seq -f "%02g" 0 ${ens_max}`; do
  work_dir=${CYC_HME}/wrfda_bc
  real_dir=${CYC_HME}/real/ens_${memid}
  gsi_dir=${CYC_HME}/gsi
  enkf_dir=${CYC_HME}/enkf
  updt_bc_exe=${WRFDA_ROOT}/var/da/da_update_bc.exe
  
  if [[ ! -d ${real_dir} || ! -x ${real_dir} ]]; then
    msg="ERROR: \${real_dir} directory\n ${real_dir}\n does not exist"
    msg=+" or is not executable.\n"
    printf "${msg}"
    exit 1
  fi
  
  if [ ! -x ${updt_bc_exe} ]; then
    printf "ERROR:\n ${updt_bc_exe}\n does not exist, or is not executable.\n"
    exit 1
  fi
  
  if [[ ${BOUNDARY} = ${LOWER} ]]; then 
    # create working directory and cd into it
    work_dir=${work_dir}/lower_bdy_updt/ens_${memid}
    mkdir -p ${work_dir}
    cmd="cd ${work_dir}"
    printf "${cmd}\n"; eval "${cmd}"
    
    # Remove IC/BC in the directory if old data present
    cmd="rm -f wrfout_*"
    printf "${cmd}\n"; eval "${cmd}"
    
    cmd="rm -f wrfinput_d*"
    printf "${cmd}\n"; eval "${cmd}"
  
    if [ ${memid} = 00 ]; then 
      # control background sourced from last cycle background
      bkg_dir=${CYC_HME}/bkg/ens_${memid}
      max_dom=${WRF_CTR_DOM}
    else
      # perturbation background sourced from ensemble dir
      bkg_dir=${ENS_DIR}/bkg/ens_${memid}
      max_dom=${WRF_ENS_DOM}
    fi

    # verify forecast data root
    if [[ ! -d ${bkg_dir} || ! -x ${bkg_dir} ]]; then
      msg="ERROR: \${bkg_dir} directory\n ${bkg_dir}\n does not exist"
      msg+=" or is not executable.\n"
      printf "${msg}"
      exit 1
    fi
    
    # Check to make sure the input files are available and copy them
    printf "Copying background and input files.\n"
    for dmn in `seq -f "%02g" 01 ${max_dom}`; do
      # update the lower BC for the output file to pass to GSI
      wrfout=wrfout_d${dmn}_${cyc_dt}

      # wrfinput is always drawn from real step
      wrfinput=wrfinput_d${dmn}
  
      if [ ! -r "${bkg_dir}/${wrfout}" ]; then
        printf "ERROR: Input file\n ${bkg_dir}/${wrfout}\n is missing.\n"
        exit 1
      else
        cmd="cp -L ${bkg_dir}/${wrfout} ."
        printf "${cmd}\n"; eval "${cmd}"
      fi
  
      if [ ! -r "${real_dir}/${wrfinput}" ]; then
        printf "ERROR: Input file\n ${real_dir}/${wrfinput}\n is missing.\n"
        exit 1
      else
        cmd="cp -L ${real_dir}/${wrfinput} ."
        printf "${cmd}\n"; eval "${cmd}"
      fi
  
      ##################################################################################
      #  Build da_update_bc namelist
      ##################################################################################
      # Copy the namelist from the static dir -- THIS WILL BE MODIFIED DO NOT LINK TO IT
      cmd="cp -L ${cfg_dir}/namelists/parame.in ."
      printf "${cmd}\n"; eval "${cmd}"
  
      # Update the namelist
      cat parame.in \
        | sed "s/= DA_FILE/= '\.\/${wrfout}'/" \
        | sed "s/= WRF_INPUT/= '\.\/${wrfinput}'/" \
        | sed "s/= DOMAIN_ID/= ${dmn}/" \
        | sed "s/= UPDATE_LOW_BDY/= \.true\./" \
        | sed "s/= UPDATE_LATERAL_BDY/= \.false\./" \
        > parame.in.tmp
      mv parame.in.tmp parame.in
  
      ##################################################################################
      # Run update_bc_exe
      ##################################################################################
      # Print run parameters
      printf "\n"
      printf "MEM_ID   = ${memid}\n"
      printf "BOUNDARY = ${BOUNDARY}\n"
      printf "DOMAIN   = ${dmn}\n"
      printf "CYC_DT   = ${cyc_dt}\n"
      printf "EXP_NME  = ${EXP_NME}\n"
      printf "CYC_HME  = ${CYC_HME}\n"
      printf "ENS_DIR = ${ENS_DIR}\n"
      printf "\n"
      now=`date +%Y-%m-%d_%H_%M_%S`
      printf "da_update_bc.exe started at ${now}.\n"
      cmd="${updt_bc_exe}; error=\$?"
      printf "${cmd}\n"; eval "${cmd}"

      ##################################################################################
      # Run time error check
      ##################################################################################
      error="$?"
      
      # NOTE: THIS CHECK NEEDS IMPROVEMENT, DOESN'T CATCH ERRORS IN THE PROGRAM LOG
      if [ ${error} -ne 0 ]; then
        printf "ERROR:\n ${updt_bc_exe}\n exited with code ${error}.\n"
        exit ${error}
      else
        printf "${updt_bc_exe} exited with code ${error}.\n"
      fi
    done
  
  else
    # create working directory and cd into it
    work_dir=${work_dir}/lateral_bdy_updt/ens_${memid}
    mkdir -p ${work_dir}
    cmd="cd ${work_dir}"
    printf "${cmd}\n"; eval "${cmd}"
    
    # Remove IC/BC in the directory if old data present
    cmd="rm -f wrfout_*"
    printf "${cmd}\n"; eval "${cmd}"

    cmd="rm -f wrfinput_d0*"
    printf "${cmd}\n"; eval "${cmd}"

    cmd="rm -f wrfbdy_d01"
    printf "${cmd}\n"; eval "${cmd}"

    if [ ${memid} = 00 ]; then
      if [[ ! -d ${gsi_dir} || ! -x ${gsi_dir} ]]; then
        msg="ERROR: \${gsi_dir} directory\n ${gsi_dir}\n does not exist"
        msg+=" or is not executable.\n"
        printf "${msg}"
        exit 1
      else
        wrfanl="${gsi_dir}/d01/wrfanl_ens_${memid}_${cyc_dt}"
      fi
    else
      if [[ ! -d ${enkf_dir} || ! -x ${enkf_dir} ]]; then
        msg="ERROR: \${enkf_dir} directory\n ${enkf_dir}\n does not exist"
        msg+=" or is not executable.\n"
        printf "${msg}"
        exit 1
      else
        wrfanl=${enkf_dir}/d01/wrfanl_ens_${memid}_${cyc_dt}
      fi
    fi

    wrfbdy=${real_dir}/wrfbdy_d01
    wrfvar_outname=wrfanl_ens_${memid}_${cyc_dt}
  
    if [ ! -r "${wrfanl}" ]; then
      printf "ERROR: Input file\n ${wrfanl}\n is missing.\n"
      exit 1
    else
      cmd="cp -L ${wrfanl} ${wrfvar_outname}"
      printf "${cmd}\n"; eval "${cmd}"
    fi
  
    if [ ! -r "${wrfbdy}" ]; then
      printf "ERROR: Input file \n${wrfbdy}\n is missing.\n"
      exit 1
    else
      cmd="cp -L ${wrfbdy} ."
      printf "${cmd}\n"; eval "${cmd}"
    fi
  
    ##################################################################################
    #  Build da_update_bc namelist
    ##################################################################################
    # Copy the namelist from the static dir -- THIS WILL BE MODIFIED DO NOT LINK TO IT
    cmd="cp -L ${cfg_dir}/namelists/parame.in ."
    printf "${cmd}\n"; eval "${cmd}"
  
    # Update the namelist for lateral boundary update 
    cat parame.in \
      | sed "s/= DA_FILE/= '\.\/${wrfvar_outname}'/" \
      | sed "s/= DOMAIN_ID/= 01/" \
      | sed "s/= UPDATE_LOW_BDY/= \.false\./" \
      | sed "s/= UPDATE_LATERAL_BDY/= \.true\./" \
      | sed "s/= WRF_BDY_FILE/= '\.\/${wrfbdy_name}'/" \
      | sed "s/= WRF_INPUT/= '\.\/wrfinput_d01'/" \
      > parame.in.tmp
    mv parame.in.tmp parame.in
  
    ##################################################################################
    # Run update_bc_exe
    ##################################################################################
    # Print run parameters
    printf "\n"
    printf "MEM_ID   = ${memid}\n"
    printf "BOUNDARY = ${BOUNDARY}\n"
    printf "DOMAIN   = ${dmn}\n"
    printf "CYC_DT   = ${cyc_dt}\n"
    printf "EXP_NME  = ${EXP_NME}\n"
    printf "CYC_HME  = ${CYC_HME}\n"
    printf "ENS_DIR  = ${ENS_DIR}\n"
    printf "\n"
    now=`date +%Y-%m-%d_%H_%M_%S`
    printf "da_update_bc.exe started at ${now}.\n"
    cmd="${updt_bc_exe}; error=\$?"
    printf "${cmd}\n"; eval "${cmd}"

    ##################################################################################
    # Run time error check
    ##################################################################################
    error="$?"
    
    # NOTE: THIS CHECK NEEDS IMPROVEMENT, DOESN'T CATCH ERRORS IN THE PROGRAM LOG
    if [ ${error} -ne 0 ]; then
      printf "ERROR:\n ${updt_bc_exe}\n exited with code ${error}.\n"
      exit ${error}
    else
      printf "${updt_bc_exe} exited with code ${error}.\n"
    fi
  fi
done

printf "wrfda.sh completed successfully at `date +%Y-%m-%d_%H_%M_%S`.\n"

##################################################################################

exit 0
