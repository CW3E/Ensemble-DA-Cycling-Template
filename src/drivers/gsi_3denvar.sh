#!/bin/bash
##################################################################################
# Description
##################################################################################
# This driver script is a major fork and rewrite of the standard GSI.ksh
# driver script for the GSI tutorial:
#
#   https://dtcenter.ucar.edu/com-GSI/users/tutorial/online_tutorial/index_v3.7.php
#
# The purpose of this fork is to work in a Cylc-based
# Observation-Analysis-Forecast cycle with WRF for data denial experiments.
# Naming conventions in this script have been smoothed to match a companion major
# fork of the wrf.ksh WRF driver script of Christopher Harrop.
#
# One should write machine specific options for the GSI environment
# in a GSI_constants.sh script to be sourced in the below.
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
# GSI_ENV      = Full path to environment config file used to compile and run GSI
# IF_DBG_SCRPT = Switch YES or else, this is NOT A REQUIRED ARGUMENT. Set variable
#                IF_DBG_SCRPT=Yes within the configuration to initiate debugging,
#                script will default to normal run behavior otherwise
# SCHED        = IF_DBG_SCRPT=Yes, SCHED=SLURM or SCHED=PBS will auto-generate
#                a job submission header in the debugging script to run manually
#
##################################################################################

# Read constants into the current shell
if [ ! -x ${CNST} ]; then
  printf "ERROR: constants file\n ${CNST}\n does not exist or is not executable.\n"
  exit 1
else
  # Read constants into the current shell
  cmd=". ${CNST}"
  printf "${cmd}\n"; eval "${cmd}"
fi

if [ ! -x ${GSI_ENV} ]; then
  msg="ERROR: GSI environment file\n ${GSI_ENV}\n does not exist"
  msg+=" or is not executable.\n"
  printf "${msg}"
  exit 1
else
  # Read GSI environment into the current shell
  cmd=". ${GSI_ENV}"
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
# Make checks for DA method settings
##################################################################################
# Options below are defined in control flow xml (case insensitive)
#
# EXP_NME     = Case study / config short name directory structure
# CYC_DT      = Analysis time YYYYMMDDHH
# CYC_HME     = Start time named directory for cycling data containing
# WRF_CTR_DOM = Analyze up to domain index format DD of control solution
# IF_HYBRID   = Yes : Run GSI with ensemble background covariance
# ENS_DIR     = Background ensemble located at ${ENS_DIR}/ens_${ens_n}/wrfout* 
# ENS_SIZE    = The total ensemble size including control member + perturbations
# WRF_ENS_DOM = Utilize ensemble perturbations up to domain index DD
# BETA        = Scaling float in [0,1], 0 - full ensemble, 1 - full static
# HLOC        = Homogeneous isotropic horizontal ensemble localization scale (km) 
# VLOC        = Vertical localization scale (grid units)
# MAX_BC_LOOP = Maximum number of times to iteratively generate variational bias
#               correction files, loop zero starts with GDAS defaults
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
fi

# Convert CYC_DT from 'YYYYMMDDHH' format to cyc_iso Unix date format
if [[ ! ${CYC_DT} =~ ${ISO_RE} ]]; then
  printf "ERROR: \${CYC_DT}, ${CYC_DT}, is not in 'YYYYMMDDHH' format.\n"
  exit 1
else
  # define anl date components separately
  cyc_dt=${CYC_DT:0:8}
  hh=${CYC_DT:8:2}

  # Define file path name variable cyc_iso from CYC_DT
  cyc_iso=`date +%Y-%m-%d_%H_%M_%S -d "${cyc_dt} ${hh} hours"`
fi

if [ -z ${CYC_HME} ]; then
  printf "ERROR: \${CYC_HME} is not defined.\n"
  exit 1
elif [ ! -d ${CYC_HME} ]; then
  printf "ERROR: \${CYC_HME} directory\n ${CYC_HME}\n does not exist.\n"
  exit 1
fi

if [[ ! ${WRF_CTR_DOM} =~ ${INT_RE} ]]; then
  printf "ERROR: \${WRF_CTR_DOM}\n ${WRF_CTR_DOM}\n is not an integer.\n"
  exit 1
else
  max_dom=${WRF_CTR_DOM}
fi

if [[ ${IF_HYBRID} = ${YES} ]]; then
  # ensembles are required for hybrid EnVAR
  if [ -z ${ENS_DIR} ]; then
    printf "ERROR: \${ENS_DIR} is not defined.\n"
    exit 1
  elif [[ ! -d ${ENS_DIR} || ! -x ${ENS_DIR} ]]; then
    msg="ERROR: \${ENS_DIR} directory\n ${ENS_DIR}\n does not exist or"
    msg+=" is not executable.\n"
    printf "${msg}"
    exit 1
  elif [[ ! ${WRF_ENS_DOM} =~ ${INT_RE} ]]; then
    printf "ERROR: \${WRF_ENS_DOM} is not in DD format.\n"
    exit 1
  elif [[ ! ${ENS_SIZE} =~ ${INT_RE} ]]; then
    msg="ERROR: \${ENS_SIZE},\n ${ENS_SIZE}\n is not an integer, this must"
    msg+=" be specified to the total ensemble size.\n"
    printf "${msg}"
    exit 1
  elif [ ${ENS_SIZE} -lt 3 ]; then
    printf "ERROR: ensemble size \${ENS_SIZE} must be three or greater.\n"
    exit 1
  elif [[ ! ${BETA} =~ ${DEC_RE} ]]; then
    msg="ERROR: \${BETA},\n ${BETA}\n is not a positive decimal, it must"
    msg+=" be specified to the weight given to the static covariance.\n"
    printf "${msg}"
    exit 1
  elif [[ $(echo "${BETA} < 0" | bc -l ) -eq 1 || $(echo "${BETA} > 1" | bc -l ) -eq 1 ]]; then
    printf "ERROR:\n ${BETA}\n must be between 0 and 1.\n"
    exit 1
  else
    printf "GSI performs hybrid ensemble variational DA with ensemble size ${ENS_SIZE}.\n"
    printf "Background covariance weight ${BETA}.\n"
    ifhyb=".true."
    n_perts=$(( ${ENS_SIZE} - 1 ))
    # create a sequence of member ids
    mem_list=`seq -f "%02g" 1 ${n_perts}`
  fi
elif [[ ${IF_HYBRID} = ${NO} ]]; then
  printf "GSI performs variational DA without ensemble.\n"
  ifhyb=".false."
else
  printf "ERROR: \${IF_HYBRID} must equal 'Yes' or 'No' (case insensitive).\n"
  exit 1
fi

if [[ ! ${VLOC} =~ ${INT_RE} ]]; then
  msg="ERROR: \${VLOC},\n ${VLOC}\n is not an integer, it must be"
  msg+=" specified to the length of vertical localization scale in"
  msg+=" vertical levels.\n"
  printf "${msg}"
  exit 1
  if [ ${VLOC} -lt 0 ]; then
    printf "ERROR:\n ${VLOC}\n must be greater than 0.\n"
    exit 1
  fi
fi

if [[ ! ${HLOC} =~ ${INT_RE} ]]; then
  msg="ERROR: \${HLOC},\n ${HLOC} must be specified to the length of horizontal "
  msg+="localization scale in km.\n"
  printf "${msg}"
  exit 1
  if [ ${HLOC} -lt 0 ]; then
    printf "ERROR: ${HLOC} must be greater than 0.\n"
    exit 1
  fi
fi

if [[ ! ${MAX_BC_LOOP} =~ ${INT_RE} ]]; then
  msg="ERROR: \${MAX_BC_LOOP},\n ${MAX_BC_LOOP}\n is not an integer, it"
  msg+=" must be specified to the number of variational bias correction"
  msg+=" coefficient iterations.\n"
  printf "${msg}"
  exit 1
elif [ ${MAX_BC_LOOP} -lt 0 ]; then
  msg="ERROR: the number of iterations of variational bias "
  msg+="correction must be non-negative.\n"
  printf "${msg}"
  exit 1
fi

##################################################################################
# Define GSI workflow dependencies
##################################################################################
# Below variables are defined in cycling.xml workflow variables
#
# GSI_EXE   = Path of GSI executable
# CRTM_ROOT = Path of CRTM including byte order
# EXP_CNFG  = Root directory containing sub-directories for namelists
#             vtables, geogrid data, GSI fix files, etc.
# MPIRUN    = MPI Command to execute GSI
# N_NDES    = Total number of nodes
# N_PROC    = The total number of processes per node
#
# Below variables are derived from control flow variables for convenience
#
# cyc_iso   = Defined by the CYC_DT variable, to be used as path
#             name variable in iso format for wrfout
#
##################################################################################

if [ -z ${GSI_EXE} ]; then
  printf "ERROR: \${GSI_EXE} is not defined.\n"
  exit 1
elif [ ! -x ${GSI_EXE} ]; then
  printf "ERROR: GSI executable\n ${GSI_EXE}\n is not executable.\n"
  exit 1
fi

if [ -z ${CRTM_ROOT} ]; then
  printf "ERROR: \${CRTM_ROOT} is not defined.\n"
  exit 1
elif [[ ! -d ${CRTM_ROOT} || ! -x ${CRTM_ROOT} ]]; then
  msg="ERROR: CRTM_ROOT directory\n ${CRTM_ROOT}\n does not exist or"
  msg+=" is not executable.\n"
  printf "${msg}"
  exit 1
fi

if [ -z ${OBS_ROOT} ]; then
  printf "ERROR: \${OBS_ROOT} is not defined.\n"
  exit 1
elif [[ ! -d ${OBS_ROOT} || ! -x ${OBS_ROOT} ]]; then
  msg="ERROR: \${OBS_ROOT} directory\n ${OBS_ROOT}\n does not exist or"
  msg+=" is not executable.\n"
  printf "${msg}"
  exit 1
fi

if [ -z ${MPIRUN} ]; then
  printf "ERROR: \${MPIRUN} is not defined.\n"
  exit 1
fi

if [[ ! ${N_NDES} =~ ${INT_RE} ]]; then
  printf "ERROR: \${N_NDES}, ${N_NDES}, is not an integer.\n"
  exit 1
elif [ ${N_NDES} -le 0 ]; then
  msg="ERROR: The variable \${N_NDES} must be set to the number"
  msg+=" of nodes to run GSI > 0.\n"
  printf "${msg}"
  exit 1
fi

if [[ ! ${N_PROC} =~ ${INT_RE} ]]; then
  printf "ERROR: \${N_PROC}, ${N_PROC}, is not an integer.\n"
  exit 1
elif [ ${N_PROC} -le 0 ]; then
  msg="ERROR: The variable \${N_PROC} must be set to the number"
  msg+=" of processes-per-node to run GSI > 0.\n"
  printf "${msg}"
  exit 1
fi

mpiprocs=$(( ${N_NDES} * ${N_PROC} ))

##################################################################################
# The following paths are relative to the control flow supplied root paths
#
# fix_root     = Path of fix files
# gsi_namelist = Path and name of the gsi namelist constructor script
# prepbufr_tar = Path of PreBUFR conventional obs tar archive
# prepbufr_dir = Path of PreBUFR conventional obs tar archive extraction
# satlist      = Path to text file listing satellite observation prefixes used,
#                required file, if empty will skip all satellite data.
#
##################################################################################
fix_root=${CYLC_WORKFLOW_RUN_DIR}/fix
satlist=${fix_root}/satlist.txt
gsi_namelist=${CYLC_WORKFLOW_RUN_DIR}/namelists/gsi_3denvar_namelist.sh
prepbufr_tar=${OBS_ROOT}/prepbufr.${cyc_dt}.nr.tar.gz
prepbufr_dir=${OBS_ROOT}/${cyc_dt}.nr

if [[ ! -d ${fix_root} || ! -x ${fix_root} ]]; then
  msg="ERROR: fix file directory\n ${fix_root}\n does not exist"
  msg+=" or is not executable.\n"
  printf "${msg}"
  exit 1
fi

if [ ! -r ${satlist} ]; then
  printf "ERROR: satellite namelist\n ${satlist}\n is not readable.\n"
  exit 1
fi

if [ ! -x ${gsi_namelist} ]; then
  printf "ERROR:\n ${gsi_namelist}\n is not executable.\n"
  exit 1
fi

if [ ! -r ${prepbufr_tar} ]; then
  printf "ERROR: prepbufr tar file\n ${prepbufr_tar}\n is not readable.\n"
  exit 1
else
  # untar prepbufr data to predefined directory
  # define prepbufr directory
  mkdir -p ${prepbufr_dir}
  cmd="tar -xvf ${prepbufr_tar} -C ${prepbufr_dir}"
  printf "${cmd}\n"; eval "${cmd}"

  # unpack nested directory structure
  prepbufr_nest=(`find ${prepbufr_dir} -type f`)
  for file in ${prepbufr_nest[@]}; do
    cmd="mv ${file} ${prepbufr_dir}"
    printf "${cmd}\n"; eval "${cmd}"
  done
  cmd="rmdir ${prepbufr_dir}/*"
  printf "${cmd}\n"; eval "${cmd}"

  prepbufr=${prepbufr_dir}/prepbufr.gdas.${cyc_dt}.t${hh}z.nr
  if [ ! -r ${prepbufr} ]; then
    printf "ERROR: file\n ${prepbufr}\n is not readable.\n"
    exit 1
  fi
fi

##################################################################################
# Begin pre-GSI setup, running one domain at a time
##################################################################################
# Create the work directory organized by domain analyzed and cd into it
work_dir=${CYC_HME}/gsi

for dmn in `seq -f "%02g" 1 ${max_dom}`; do
  # NOTE: Hybrid DA uses the control forecast as the EnKF forecast mean, not the
  # control analysis. Work directory for GSI is sub-divided based on domain index
  dmndir=${work_dir}/d${dmn}
  printf "Create work root directory\n ${dmndir}.\n"

  if [ -d "${dmndir}" ]; then
    printf "Existing GSI work root\n ${dmndir}\n removing old data for new run.\n"
    cmd="rm -rf ${dmndir}"
    printf "${cmd}\n"; eval "${cmd}"
  fi
  mkdir -p ${dmndir}

  for bc_loop in `seq -f "%02g" 0 ${MAX_BC_LOOP}`; do
    # each domain will generated a variational bias correction file iteratively
    # starting with GDAS defaults
    cd ${dmndir}

    if [ ! ${bc_loop} = ${MAX_BC_LOOP} ]; then
      # create storage for the outputs indexed on bc_loop except for final loop
      workdir=${dmndir}/bc_loop_${bc_loop}
      mkdir ${workdir}
      cmd="cd ${workdir}"
      printf "${cmd}\n"; eval "${cmd}"

    else
      workdir=${dmndir}
    fi

    printf "Variational bias correction update loop ${bc_loop}.\n"
    printf "Working directory\n ${workdir}\n"
    printf "Linking observation bufrs to working directory.\n"

    # Link to the prepbufr conventional data
    cmd="ln -s ${prepbufr} prepbufr"
    printf "${cmd}\n"; eval "${cmd}"

    # Link to satellite data -- note satlist is assumed two column with prefix
    # for GDAS and GSI conventions in first and second column respectively
    # leave file empty for no satellite assimilation
    srcobsfile=()
    gsiobsfile=()

    satlines=$(cat ${satlist})
    line_indx=0
    for line in ${satlines}; do
      if [ $(( ${line_indx} % 2 )) -eq 0 ]; then
        srcobsfile+=(${line})
      else
        gsiobsfile+=(${line})      
      fi
      line_indx=$(( ${line_indx} + 1 ))
    done

    # loop over obs types
    for (( ii=0; ii < ${#srcobsfile[@]}; ii++ )); do 
      cmd="cd ${OBS_ROOT}"
      printf "${cmd}\n"; eval "${cmd}"

      tar_file=${OBS_ROOT}/${srcobsfile[$ii]}.${cyc_dt}.tar.gz
      obs_dir=${OBS_ROOT}/${cyc_dt}.${srcobsfile[$ii]}
      mkdir -p ${obs_dir}
      if [ ! -r "${tar_file}" ]; then
        printf "ERROR: file\n ${tar_file}\n not found.\n"
        exit 1
      else
        # untar to specified directory
        cmd="tar -xvf ${tar_file} -C ${obs_dir}"
        printf "${cmd}\n"; eval "${cmd}"

        # unpack nested directory structure, if exists
        obs_nest=(`find ${obs_dir} -type f`)
        for file in ${obs_nest[@]}; do
          cmd="mv ${file} ${obs_dir}"
          printf "${cmd}\n"; eval "${cmd}"
        done

        cmd="rmdir ${obs_dir}/*"
        printf "${cmd}\n"; eval "${cmd}"

        # NOTE: differences in data file types for "satwnd"
        if [ ${srcobsfile[$ii]} = satwnd ]; then
          obs_file=${obs_dir}/gdas.${srcobsfile[$ii]}.t${hh}z.${cyc_dt}.txt
        else
          obs_file=${obs_dir}/gdas.${srcobsfile[$ii]}.t${hh}z.${cyc_dt}.bufr
        fi

        if [ ! -r "${obs_file}" ]; then
           printf "ERROR: obs file\n ${srcobsfile[$ii]}\n not found.\n"
           exit 1
        else
           printf "Link source obs file\n ${obs_file}\n"
           cmd="cd ${workdir}"
           printf "${cmd}\n"; eval "${cmd}"
           cmd="ln -sf ${obs_file} ./${gsiobsfile[$ii]}"
           printf "${cmd}\n"; eval "${cmd}"
        fi
      fi
      cd ${workdir}
    done

    #############################################################################
    # Set fix files in the order below:
    #
    #  berror             = Forecast model background error statistics
    #  oberror            = Conventional obs error file
    #  anavinfo           = Information file to set control and analysis variables
    #  specoef            = CRTM spectral coefficients
    #  trncoef            = CRTM transmittance coefficients
    #  emiscoef           = CRTM coefficients for IR sea surface emissivity model
    #  aerocoef           = CRTM coefficients for aerosol effects
    #  cldcoef            = CRTM coefficients for cloud effects
    #  satinfo            = Text file with information about assimilation of brightness temperatures
    #  satangl            = Angle dependent bias correction file (fixed in time)
    #  pcpinfo            = Text file with information about assimilation of prepcipitation rates
    #  ozinfo             = Text file with information about assimilation of ozone data
    #  errtable           = Text file with obs error for conventional data (regional only)
    #  convinfo           = Text file with information about assimilation of conventional data
    #  lightinfo          = Text file with information about assimilation of GLM lightning data
    #  atms_beamwidth.txt = Text file with information about assimilation of ATMS data
    #  bufrtable          = Text file ONLY needed for single obs test (oneobstest=.true.)
    #  bftab_sst          = Bufr table for sst ONLY needed for sst retrieval (retrieval=.true.)
    #
    ############################################################################

    srcfixfile=()
    gsifixfile=()

    printf "Copy fix files from\n ${fix_root}\n"
    # files should be named the following in ${fix_root}, can be linked to these names
    # from various source files / background error options
    srcfixfile+=( ${fix_root}/berror_stats )
    srcfixfile+=( ${fix_root}/errtable )
    srcfixfile+=( ${fix_root}/anavinfo )
    srcfixfile+=( ${fix_root}/satangbias.txt )
    srcfixfile+=( ${fix_root}/satinfo.txt )
    srcfixfile+=( ${fix_root}/convinfo.txt )
    srcfixfile+=( ${fix_root}/ozinfo.txt )
    srcfixfile+=( ${fix_root}/pcpinfo.txt )
    srcfixfile+=( ${fix_root}/lightinfo.txt )
    srcfixfile+=( ${fix_root}/atms_beamwidth.txt )

    # linked names for GSI to read in
    gsifixfile+=( berror_stats )
    gsifixfile+=( errtable )
    gsifixfile+=( anavinfo )
    gsifixfile+=( satbias_angle )
    gsifixfile+=( satinfo )
    gsifixfile+=( convinfo )
    gsifixfile+=( ozinfo )
    gsifixfile+=( pcpinfo )
    gsifixfile+=( lightinfo )
    gsifixfile+=( atms_beamwidth.txt )

    # loop over fix files
    printf "Copy fix files to working directory:\n"
    for (( ii=0; ii < ${#srcfixfile[@]}; ii++ )); do
      if [ ! -r ${srcfixfile[$ii]} ]; then
        printf "ERROR: GSI fix file\n ${srcfixfile[$ii]}\n not readable.\n"
        exit 1
      else
        cmd="cp -L ${srcfixfile[$ii]} ./${gsifixfile[$ii]}"
        printf "${cmd}\n"; eval "${cmd}"
      fi
    done

    # CRTM Spectral and Transmittance coefficients
    coeffs=()
    coeffs+=( Nalli.IRwater.EmisCoeff.bin )
    coeffs+=( NPOESS.IRice.EmisCoeff.bin )
    coeffs+=( NPOESS.IRland.EmisCoeff.bin )
    coeffs+=( NPOESS.IRsnow.EmisCoeff.bin )
    coeffs+=( NPOESS.VISice.EmisCoeff.bin )
    coeffs+=( NPOESS.VISland.EmisCoeff.bin )
    coeffs+=( NPOESS.VISsnow.EmisCoeff.bin )
    coeffs+=( NPOESS.VISwater.EmisCoeff.bin )
    coeffs+=( FASTEM6.MWwater.EmisCoeff.bin )
    coeffs+=( AerosolCoeff.bin )
    coeffs+=( CloudCoeff.bin )

    # loop over coeffs 
    printf "Link CRTM coefficient files:\n"
    for (( ii=0; ii < ${#coeffs[@]}; ii++ )); do
      coeff_file=${CRTM_ROOT}/${coeffs[$ii]}
      if [ ! -r ${coeff_file} ]; then
        printf "ERROR: CRTM coefficient file\n ${coeff_file}\n not readable.\n"
        exit 1
      else
        cmd="ln -s ${coeff_file} ."
        printf "${cmd}\n"; eval "${cmd}"
      fi
    done

    # Copy CRTM coefficient files based on entries in satinfo file
    for file in `awk '{if($1!~"!"){print $1}}' ./satinfo | sort | uniq` ;do
     satinfo_coeffs=()
     satinfo_coeffs+=( ${CRTM_ROOT}/${file}.SpcCoeff.bin )
     satinfo_coeffs+=( ${CRTM_ROOT}/${file}.TauCoeff.bin )
     for coeff_file in ${satinfo_coeffs[@]}; do
       if [ ! -r ${coeff_file} ]; then
         printf "ERROR: CRTM coefficient file\n ${coeff_file}\n not readable.\n"
       else
         cmd="ln -s ${coeff_file} ."
         printf "${cmd}\n"; eval "${cmd}"
       fi
     done
    done

    if [ ${bc_loop} = 00 ]; then
      # first bias correction loop uses combined bias correction files from GDAS
      tar_files=()
      tar_files+=(${OBS_ROOT}/abias.${cyc_dt}.tar.gz)
      tar_files+=(${OBS_ROOT}/abiaspc.${cyc_dt}.tar.gz)

      bias_dirs=()
      bias_dirs+=(${OBS_ROOT}/${cyc_dt}.abias)
      bias_dirs+=(${OBS_ROOT}/${cyc_dt}.abiaspc)

      bias_files=()
      bias_files+=(${bias_dirs[0]}/gdas.abias.t${hh}z.${cyc_dt}.txt)
      bias_files+=(${bias_dirs[1]}/gdas.abiaspc.t${hh}z.${cyc_dt}.txt)

      bias_in_files=()
      bias_in_files+=(satbias_in)
      bias_in_files+=(satbias_pc_in)

      # loop over bias files
      for ii in {0..1}; do
        tar_file=${tar_files[$ii]}
        bias_dir=${bias_dirs[$ii]}
        bias_file=${bias_files[$ii]}
        if [ ! -r ${tar_file} ]; then
          printf "Tar\n ${tar_file}\n of GDAS bias corrections not readable.\n"
          exit 1
        else
          # untar to specified directory
          mkdir -p ${bias_dir}
          cmd="tar -xvf ${tar_file} -C ${bias_dir}"
          printf "${cmd}\n"; eval "${cmd}"
        
          # unpack nested directory structure
          bias_nest=(`find ${bias_dir} -type f`)
          for file in ${bias_nest[@]}; do
            cmd="mv ${file} ${bias_dir}"
            printf "${cmd}\n"; eval "${cmd}"
          done

          cmd="rmdir ${bias_dir}/*"
          printf "${cmd}\n"; eval "${cmd}"
        
          if [ ! -r ${bias_file} ]; then
           printf "GDAS bias correction file not readable at\n ${bias_file}\n"
           exit 1
          else
            msg="Link the GDAS bias correction file ${bias_file} "
            msg+="for loop zero of analysis.\n"
            printf "${msg}"
                  
            cmd="ln -sf ${bias_file} ./${bias_in_files[$ii]}"
            printf "${cmd}\n"; eval "${cmd}"
          fi
        fi
      done
    else
      # use the bias correction file generated on the last GSI loop 
      bias_files=()
      lag_loop=$(( ${bc_loop} - 1 ))
      lag_loop=`printf %02d ${lag_loop}`
      bias_files+=(${dmndir}/bc_loop_${lag_loop}/satbias_out)
      bias_files+=(${dmndir}/bc_loop_${lag_loop}/satbias_pc.out)

      bias_in_files=()
      bias_in_files+=(satbias_in)
      bias_in_files+=(satbias_pc_in)

      # loop over bias files
      for (( ii=0; ii < ${#tar_files[@]}; ii++ )); do
	      bias_file=${bias_files[$ii]}
        if [ ! -r "${bias_file}" ]; then
          printf "Bias file\n ${bias_file}\n variational bias corrections not readable.\n"
          exit 1
        else
          msg="Linking variational bias correction file "
	        msg+="${bias_file} from last analysis.\n"
	        printf "${msg}"

          cmd="ln -sf ${bias_file} ./${bias_in_files[$ii]}"
	        printf "${cmd}\n"; eval "${cmd}"
        fi
      done
    fi

    ##################################################################################
    # Prep GSI background 
    ##################################################################################
    # Below are defined depending on the ${dmn} -le ${max_dom}
    #
    # bkg_file = Path and name of background file
    #
    ##################################################################################
    bkg_dir=${CYC_HME}/wrfda_bc/lower_bdy_updt/ens_00
    bkg_file=${bkg_dir}/wrfout_d${dmn}_${cyc_iso}

    if [ ! -r ${bkg_file} ]; then
      printf "ERROR: background file\n ${bkg_file}\n does not exist.\n"
      exit 1
    else
      printf "Copy background file to working directory.\n"
      # Copy over background field -- THIS IS MODIFIED BY GSI DO NOT LINK TO IT
      cmd="cp -L ${bkg_file} wrf_inout"
      printf "${cmd}\n"; eval "${cmd}"
    fi

    ##################################################################################
    # Prep GSI ensemble 
    ##################################################################################

    if [[ ${IF_HYBRID} = ${YES} ]]; then
      if [ ${dmn} -le ${WRF_ENS_DOM} ]; then
        # copy WRF ensemble members
        printf " Copy ensemble perturbations to working directory.\n"
        for memid in ${mem_list[@]}; do
          ens_file=${ENS_DIR}/bkg/ens_${memid}/wrfout_d${dmn}_${cyc_iso}
          if [ !-r ${ens_file} ]; then
            printf "ERROR: ensemble file\n ${ens_file}\n does not exist.\n"
            exit 1
          else
            cmd="ln -sfr ${ens_file} ./wrf_ens_${memid}"
            printf "${cmd}\n"; eval "${cmd}"
          fi
        done
        
        cmd="ls ./wrf_ens_* > filelist02"
        printf "${cmd}\n"; eval "${cmd}"

      else
        # run simple 3D-VAR without an ensemble 
        printf "WARNING:\n"
        printf "Dual resolution ensemble perturbations and control are not an option.\n"
        printf "Running nested domain d${dmn} as simple 3D-VAR update.\n"
        ifhyb=".false."
      fi

      # define namelist ensemble size
      nummem=${n_perts}
    fi

    ##################################################################################
    # Build GSI namelist
    ##################################################################################
    printf "Build the namelist with parameters for NAM-ARW.\n"

    # default static background error localization parameters taken from NAM
    # ensemble component localization is propagated by the workflow settings
    cmd=". ${gsi_namelist}"
    printf "${cmd}\n"; eval "${cmd}"

    # modify the anavinfo vertical levels based on wrf_inout for WRF ARW and NMM
    bklevels=`ncdump -h wrf_inout | grep "bottom_top =" | awk '{print $3}' `
    bklevels_stag=`ncdump -h wrf_inout | grep "bottom_top_stag =" | awk '{print $3}' `
    anavlevels=`cat anavinfo | grep ' sf ' | tail -1 | awk '{print $2}' ` # levels of sf, vp, u, v, t...
    anavlevels_stag=`cat anavinfo | grep ' prse ' | tail -1 | awk '{print $2}' `  # levels of prse
    sed -i 's/ '${anavlevels}'/ '${bklevels}'/g' anavinfo
    sed -i 's/ '${anavlevels_stag}'/ '${bklevels_stag}'/g' anavinfo

    ##################################################################################
    # Run GSI
    ##################################################################################
    # Print run parameters
    printf "\n"
    printf "CYC_DT    = ${CYC_DT}\n"
    printf "BKG       = ${bkg_file}\n"
    printf "IF_HYBRID = ${IF_HYBRID}\n"
    printf "ENS_DIR   = ${ENS_DIR}\n"
    printf "BETA      = ${BETA}\n"
    printf "VLOC      = ${VLOC}\n"
    printf "HLOC      = ${HLOC}\n"
    printf "\n"
    now=`date +%Y-%m-%d_%H_%M_%S`
    printf "gsi analysis started at ${now} on domain d${dmn}.\n"
    cmd="${MPIRUN} -n ${mpiprocs} ${GSI_EXE} > stdout.anl.${cyc_iso} 2>&1; error=\$?"
    printf "${cmd}\n"; eval "${cmd}"

    ##################################################################################
    # Run time error check
    ##################################################################################
    error="$?"

    if [ ${error} -ne 0 ]; then
      printf "ERROR:\n ${GSI_EXE}\n exited with code ${error}.\n"
      exit ${error}
    else
      printf "${GSI_EXE} exited with code ${error}.\n"
    fi

    # Copy the output to cycling naming convention
    cmd="mv wrf_inout wrfanl_ens_00_${cyc_iso}"
    printf "${cmd}\n"; eval "${cmd}"

    ##################################################################################
    # Loop over first and last outer loops to generate innovation
    # diagnostic files for indicated observation types (groups)
    #
    # NOTE:  Since we set miter=2 in GSI namelist SETUP, outer
    #        loop 03 will contain innovations with respect to
    #        the analysis.  Creation of o-a innovation files
    #        is triggered by write_diag(3)=.true.  The setting
    #        write_diag(1)=.true. turns on creation of o-g
    #        innovation files.
    #
    ##################################################################################

    loops="01 03"
    for loop in ${loops}; do
      case ${loop} in
        01) string=ges;;
        03) string=anl;;
         *) string=${loop};;
      esac

      ##################################################################################
      #  Collect diagnostic files for obs types (groups) below
      #   listall="conv amsua_metop-a mhs_metop-a hirs4_metop-a hirs2_n14 msu_n14 \
      #          sndr_g08 sndr_g10 sndr_g12 sndr_g08_prep sndr_g10_prep sndr_g12_prep \
      #          sndrd1_g08 sndrd2_g08 sndrd3_g08 sndrd4_g08 sndrd1_g10 sndrd2_g10 \
      #          sndrd3_g10 sndrd4_g10 sndrd1_g12 sndrd2_g12 sndrd3_g12 sndrd4_g12 \
      #          hirs3_n15 hirs3_n16 hirs3_n17 amsua_n15 amsua_n16 amsua_n17 \
      #          amsub_n15 amsub_n16 amsub_n17 hsb_aqua airs_aqua amsua_aqua \
      #          goes_img_g08 goes_img_g10 goes_img_g11 goes_img_g12 \
      #          pcp_ssmi_dmsp pcp_tmi_trmm sbuv2_n16 sbuv2_n17 sbuv2_n18 \
      #          omi_aura ssmi_f13 ssmi_f14 ssmi_f15 hirs4_n18 amsua_n18 mhs_n18 \
      #          amsre_low_aqua amsre_mid_aqua amsre_hig_aqua ssmis_las_f16 \
      #          ssmis_uas_f16 ssmis_img_f16 ssmis_env_f16 mhs_metop_b \
      #          hirs4_metop_b hirs4_n19 amusa_n19 mhs_n19 goes_glm_16"
      ##################################################################################

      listall=`ls pe* | cut -f2 -d"." | awk '{print substr($0, 0, length($0)-3)}' | sort | uniq `
      for type in ${listall}; do
         count=`ls pe*${type}_${loop}* | wc -l`
         if [[ ${count} -gt 0 ]]; then
            cat pe*${type}_${loop}* > diag_${type}_${string}.${cyc_iso}
         fi
      done
    done

    #  Clean working directory to save only important files
    ls -l * > list_run_directory

    printf "Clean working directory after GSI run.\n"
    rm -f *Coeff.bin     # all CRTM coefficient files
    rm -f pe0*           # diag files on each processor
    rm -f obs_input.*    # observation middle files
    rm -f siganl sigf0?  # background middle files
    rm -f fsize_*        # delete temporal file for bufr size
  done 
done

printf "gsi_3denvar.sh completed successfully at `date +%Y-%m-%d_%H_%M_%S`.\n"

##################################################################################

exit 0
