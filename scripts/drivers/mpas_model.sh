#!/bin/bash
##################################################################################
# Description
##################################################################################
# This driver script is designed to dynamically propagate the
# namelist.atmosphere and streams.atmosphere templates included in
# this repository to generate real data surface boundary conditions for the
# MPAS-A model.
#
# One should write machine specific options for the MPAS environment
# in a MPAS_constants.sh script to be sourced in the below.
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
# Make checks for atmosphere settings
##################################################################################
# Options below are defined in workflow variables
#
# DMN_NME    = MPAS domain name used to call mesh / static file name patterns
# MEMID      = Ensemble ID index, 00 for control, i > 0 for perturbation
# STRT_DT    = Simulation start time in YYMMDDHH
# IF_DYN_LEN = "Yes" or "No" switch to compute forecast length dynamically 
# FCST_HRS   = Total length of MPAS forecast simulation in HH, IF_DYN_LEN=No
# EXP_VRF    = Verfication time for calculating forecast hours, IF_DYN_LEN=Yes
# BKG_INT    = Interval of input data in HH
# BKG_DATA   = String case variable for supported inputs: GFS, GEFS currently
#
##################################################################################

if [ ! ${DMN_NME} ]; then
  printf "ERROR: \${DMN_NME} is not defined.\n"
  exit 1
fi

if [ ! ${MEMID} ]; then
  printf "ERROR: \${MEMID} is not defined.\n"
  exit 1
else
  # ensure padding to two digits is included
  memid=`printf %02d $(( 10#${MEMID} ))`
fi

if [ ${#STRT_DT} -ne 10 ]; then
  printf "ERROR: \${STRT_DT}, '${STRT_DT}', is not in 'YYYYMMDDHH' format.\n"
  exit 1
else
  # Convert STRT_DT from 'YYYYMMDDHH' format to strt_dt Unix date format
  strt_dt="${STRT_DT:0:8} ${STRT_DT:8:2}"
  strt_dt=`date -d "${strt_dt}"`
fi

if [[ ${IF_DYN_LEN} = ${NO} ]]; then 
  printf "Generating fixed length forecast forcing data.\n"
  if [ ! ${FCST_HRS} ]; then
    printf "ERROR: \${FCST_HRS} is not defined.\n"
    exit 1
  else
    # parse forecast hours as base 10 padded
    fcst_len=`printf %03d $(( 10#${FCST_HRS} ))`
  fi
elif [[ ${IF_DYN_LEN} = ${YES} ]]; then
  printf "Generating forecast forcing data until experiment validation time.\n"
  if [ ${#EXP_VRF} -ne 10 ]; then
    printf "ERROR: \${EXP_VRF}, ${EXP_VRF} is not in 'YYYMMDDHH' format.\n"
    exit 1
  else
    # compute forecast length relative to start time and verification time
    exp_vrf="${EXP_VRF:0:8} ${EXP_VRF:8:2}"
    exp_vrf=`date +%s -d "${exp_vrf}"`
    fcst_len=$(( (${exp_vrf} - `date +%s -d "${strt_dt}"`) / 3600 ))
    fcst_len=`printf %03d $(( 10#${fcst_len} ))`
  fi
else
  printf "\${IF_DYN_LEN} must be set to 'Yes' or 'No' (case insensitive).\n"
  exit 1
fi

# define the end time based on forecast length control flow above
end_dt=`date -d "${strt_dt} ${fcst_len} hours"`

# define a sequence of all forecast hours with background interval spacing
fcst_seq=`seq -f "%03g" 0 ${BKG_INT} ${fcst_len}`

if [ ! ${BKG_INT} ]; then
  printf "ERROR: \${BKG_INT} is not defined.\n"
  exit 1
elif [ ${BKG_INT} -le 0 ]; then
  printf "ERROR: \${BKG_INT} must be HH > 0 for the frequency of data inputs.\n"
  exit 1
fi

if [[ ${BKG_DATA} != GFS && ${BKG_DATA} != GEFS ]]; then
  msg="ERROR: \${BKG_DATA} must equal 'GFS' or 'GEFS'"
  msg+=" as currently supported inputs.\n"
  printf "${msg}"
  exit 1
fi

##################################################################################
# Define atmosphere workflow dependencies
##################################################################################
# Below variables are defined in workflow variables
#
# MPAS_ROOT  = Root directory of a clean MPAS build
# EXP_CNFG   = Root directory containing sub-directories for namelists
#              vtables, static data, etc.
# CYC_HME    = Cycle YYYYMMDDHH named directory for cycling data containing
#              bkg, init_atmosphere, atmosphere_model
# MPIRUN     = MPI multiprocessing evaluation call, machine specific
# N_PROC     = The total number of processes to run atmosphere_model with MPI
# PIO_NUM    = Number of tasks to perform file I/O
# PIO_STRIDE = Stride between file I/O tasks
#
##################################################################################

if [ ! ${MPAS_ROOT} ]; then
  printf "ERROR: \${MPAS_ROOT} is not defined.\n"
  exit 1
elif [ ! -d ${MPAS_ROOT} ]; then
  printf "ERROR: \${MPAS_ROOT} directory\n ${MPAS_ROOT}\n does not exist.\n"
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
elif [ ! -d ${CYC_HME} ]; then
  printf "ERROR: \${CYC_HME} directory\n ${CYC_HME}\n does not exist.\n"
  exit 1
fi

if [ ! ${MPIRUN} ]; then
  printf "ERROR: \${MPIRUN} is not defined.\n"
  exit 1
fi

if [ ! ${N_PROC} ]; then
  printf "ERROR: \${N_PROC} is not defined.\n"
  exit 1
elif [ ${N_PROC} -le 0 ]; then
  msg="ERROR: The variable \${N_PROC} must be set to the number"
  msg+=" of processors to run atmosphere_model.\n"
  printf "${msg}"
  exit 1
fi

if [ ! ${PIO_NUM} ]; then
  printf "ERROR: \${PIO_NUM} is not defined.\n"
  exit 1
elif [ ${PIO_NUM} -lt 0 ]; then
  msg="ERROR: \${PIO_NUM} must be >= 0 for the number of IO tasks, with equal to"
  msg+=" 0 corresponding to all tasks performing IO.\n"
  printf ${msg}
  exit 1
elif [ ${PIO_NUM} -gt ${N_PROC} ]; then
  msg="ERROR: \${PIO_NUM} must be <= \${NUM_PROC}, ${NUM_PROC}, the number of"
  msg+=" MPI processes.\n"
  printf ${msg}
  exit 1
fi

if [ ! ${PIO_STRIDE} ]; then
  printf "ERROR: \${PIO_STRIDE} is not defined.\n"
  exit 1
fi

##################################################################################
# Begin pre-atmosphere_model setup
##################################################################################
# The following paths are relative to workflow root paths
#
# init_atmos_root  = Directory from which ic / bc data is sourced
# work_root        = Working directory where atmosphere_model runs and outputs
# atmos_dat_files  = All file contents of clean MPAS build directory
#                   namelists and input data is linked from other sources
# atmos_model_exe  = Path and name of working executable
#
##################################################################################

init_atmos_root=${CYC_HME}/init_atmosphere/ens_${memid}
work_root=${CYC_HME}/atmosphere_model/ens_${memid}

input_files=( "${DMN_NME}.init.nc" "${DMN_NME}.sfc_update.nc" )
if [ ! -d ${init_atmos_root} ]; then
  msg="ERROR: \${init_atmos_root} directory\n ${init_atmos_root}\n"
  msg+=" does not exist.\n"
  printf 
  exit 1
else
  cmd="mkdir -p ${work_root}; cd ${work_root}"
  printf "${cmd}\n"; eval "${cmd}"

  for input_f in ${input_files[@]}; do
    if [ ! -s ${init_atmos_root}/${filename} ]; then
      printf "ERROR: ${filename} is missing.\n"
      exit 1
    else
      cmd="ln -sfr ${init_atmos_root}/${filename} ."
      printf "${cmd}\n"; eval "${cmd}"
    fi
  done
fi

atmos_dat_files=(${MPAS_ROOT}/*)
atmos_model_exe=${MPAS_ROOT}/atmosphere_model

if [ ! -x ${atmos_model_exe} ]; then
  printf "ERROR:\n ${atmos_model_exe}\n does not exist, or is not executable.\n"
  exit 1
fi

# Make links to the INIT_ATMOS DAT files
for file in ${atmos_dat_files[@]}; do
  cmd="ln -sf ${file} ."
  printf "${cmd}\n"; eval "${cmd}"
done

# Remove any previous mpas static files following ${DMN_NME}.static.nc pattern
cmd="rm -f *.static.nc"
printf "${cmd}\n"; eval "${cmd}"

# Check to make sure the static terrestrial input file is available and link
static_input_name=${EXP_CNFG}/static_files/${DMN_NME}.static.nc
if [ ! -r "${static_input_name}" ]; then
  printf "ERROR: Input file\n ${static_input_name}\n is missing.\n"
  exit 1
else
  cmd="ln -sf ${static_input_name} ."
  printf "${cmd}\n"; eval "${cmd}"
fi

# Check to make sure the graph partitioning file is available and link
# NOTE: ${N_PROC} must match the number of MPI processes
graph_part_name=${EXP_CNFG}/static_files/${DMN_NME}.graph.info.part.${N_PROC}
if [ ! -r "${graph_part_name}" ]; then
  printf "ERROR: Input file\n ${graph_part_name}\n is missing.\n"
  exit 1
else
  cmd="ln -sf ${graph_part_name} ."
  printf "${cmd}\n"; eval "${cmd}"
fi

##################################################################################
#  Build atmosphere namelist
##################################################################################
# Remove any previous namelists and stream lists
cmd="rm -f namelist.*; rm -f streams.*; rm -f stream_list.*"
printf "${cmd}\n"; eval "${cmd}"

# Copy the atmosphere namelist / streams templates,
# NOTE: THESE WILL BE MODIFIED DO NOT LINK TO THEM
namelist_temp=${EXP_CNFG}/namelists/namelist.atmosphere.${BKG_DATA}
if [ ! -r ${namelist_temp} ]; then 
  msg="atmosphere namelist template\n ${namelist_temp}\n is not readable or "
  msg+="does not exist.\n"
  printf "${msg}"
  exit 1
else
  cmd="cp -L ${namelist_temp} ./namelist.atmosphere"
  printf "${cmd}\n"; eval "${cmd}"
fi

streams_temp=${EXP_CNFG}/streamlists/streams.atmosphere
if [ ! -r ${streams_temp} ]; then 
  msg="atmosphere streams template\n ${streams_temp}\n is not readable or "
  msg+="does not exist.\n"
  printf "${msg}"
  exit 1
else
  cmd="cp -L ${streams_temp} ./streams.atmosphere"
  printf "${cmd}\n"; eval "${cmd}"
fi

# define start / end time patterns for namelist.atmosphere
strt_iso=`date +%Y-%m-%d_%H:%M:%S -d "${strt_dt}"`
end_iso=`date +%Y-%m-%d_%H:%M:%S -d "${end_dt}"`

# Update background data interval in namelist
(( data_interval_sec = BKG_INT * 3600 ))

# Update the atmosphere namelist / streams for surface boundary conditions
cat namelist.atmosphere \
  | sed "s/= CONFIG_INIT_CASE,/= 8/" \
  | sed "s/= CONFIG_START_TIME,/= '${strt_iso}'/" \
  | sed "s/= CONFIG_STOP_TIME,/= '${end_iso}'/" \
  | sed "s/= CONFIG_MET_PREFIX,/= '${BKG_DATA}'/" \
  | sed "s/= CONFIG_SFC_PREFIX,/= '${BKG_DATA}'/" \
  | sed "s/= CONFIG_FG_INTERVAL,/= ${data_interval_sec}/" \
  | sed "s/= CONFIG_STATIC_INTERP,/= false/" \
  | sed "s/= CONFIG_NATIVE_GWD_STATIC,/= false/" \
  | sed "s/= CONFIG_VERTICAL_GRID,/= false/" \
  | sed "s/= CONFIG_MET_INTERP,/= false/" \
  | sed "s/= CONFIG_INPUT_SST,/= true/" \
  | sed "s/= CONFIG_FRAC_SEAICE,/= true/" \
  | sed "s/= CONFIG_PIO_NUM_IOTASKS,/= ${PIO_NUM}/" \
  | sed "s/= CONFIG_PIO_STRIDE,/= ${PIO_STRIDE}/" \
  | sed "s/= CONFIG_BLOCK_DECOMP_FILE_PREFIX,/= '${DMN_NME}.graph.info.part.'/" \
  > namelist.atmosphere.tmp
mv namelist.atmosphere.tmp namelist.atmosphere

# define initial conditions output name
out_name=${DMN_NME}.init.nc

cat streams.atmosphere \
  | sed "s/=INPUT_FILE_NAME,/=\"${DMN_NME}.static.nc\"/" \
  | sed "s/=OUTPUT_FILE_NAME,/=\"${out_name}\"/" \
  | sed "s/=SURFACE_FILE_NAME,/=\"${DMN_NME}.sfc_update.nc\"/" \
  | sed "s/=SFC_OUTPUT_INTERVAL,/=\"${BKG_INT}:00:00\"/" \
  | sed "s/=LBC_OUTPUT_INTERVAL,/=\"${BKG_INT}:00:00\"/" \
  > streams.atmosphere.tmp
mv streams.atmosphere.tmp streams.atmosphere

##################################################################################
# Run atmosphere
##################################################################################
# Print run parameters
printf "\n"
printf "EXP_CNFG = ${EXP_CNFG}\n"
printf "DMN_NME  = ${DMN_NME}\n"
printf "MEMID    = ${MEMID}\n"
printf "CYC_HME  = ${CYC_HME}\n"
printf "STRT_DT  = ${strt_iso}\n"
printf "END_DT   = ${end_iso}\n"
printf "BKG_INT  = ${BKG_INT}\n"
printf "\n"
now=`date +%Y-%m-%d_%H_%M_%S`
printf "atmosphere started at ${now}.\n"
cmd="${MPIRUN} -n ${N_PROC} ${atmos_model_exe}"
printf "${cmd}\n"
${MPIRUN} -n ${N_PROC} ${atmos_model_exe}

##################################################################################
# Run time error check
##################################################################################
error="$?"
printf "atmosphere exited with code ${error}.\n"

# save mpas_sfc logs
log_dir=atmosphere_sfc_log.${now}
mkdir ${log_dir}
cmd="mv log.atmosphere.* ${log_dir}"
printf "${cmd}\n"; eval "${cmd}"

cmd="mv namelist.atmosphere ${log_dir}"
printf "${cmd}\n"; eval "${cmd}"

cmd="mv streams.atmosphere ${log_dir}"
printf "${cmd}\n"; eval "${cmd}"

# Remove links to the INIT_ATMOS DAT files
for file in ${atmos_dat_files[@]}; do
  cmd="rm -f `basename ${file}`"
  printf "${cmd}\n"; eval "${cmd}"
done

# remove links to ungrib data
for fcst in ${fcst_seq[@]}; do
  filename="./${BKG_DATA}:`date +%Y-%m-%d_%H -d "${strt_dt} ${fcst} hours"`"
  cmd="rm -f ${filename} ."
  printf "${cmd}\n"; eval "${cmd}"
done

# remove links to static and partition data
cmd="rm -f ${DMN_NME}.static.nc"
printf "${cmd}\n"; eval "${cmd}"

cmd="rm -f ${DMN_NME}.graph.info.part.${N_PROC}"
printf "${cmd}\n"; eval "${cmd}"

if [ ${error} -ne 0 ]; then
  printf "ERROR:\n ${atmos_model_exe}\n exited with status ${error}.\n"
  exit ${error}
fi

# Check to see if atmosphere outputs are generated
if [ ! -s "${out_name}" ]; then
  printf "ERROR:\n ${atmos_model_exe}\n failed to complete writing ${out_name}.\n"
  exit 1
fi

printf "mpas_ic.sh completed successfully at `date +%Y-%m-%d_%H_%M_%S`.\n"

##################################################################################
# end

exit 0
