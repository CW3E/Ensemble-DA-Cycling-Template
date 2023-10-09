#!/bin/bash
##################################################################################
# Description
##################################################################################
# This driver script is designed to dynamically propagate the
# namelist.init_amosphere and streams.init_atmosphere templates included in
# this repository to generate real data initial conditions for the MPAS-A model.
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
# Make checks for metgrid settings
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
# Define metgrid workflow dependencies
##################################################################################
# Below variables are defined in workflow variables
#
# MPAS_ROOT  = Root directory of a clean MPAS build
# EXP_CNFG   = Root directory containing sub-directories for namelists
#              vtables, static data, etc.
# CYC_HME    = Cycle YYYYMMDDHH named directory for cycling data containing
#              bkg, init_atmosphere, mpas
# MPIRUN     = MPI multiprocessing evaluation call, machine specific
# N_PROC     = The total number of processes to run init_atmosphere with MPI
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
  msg+=" of processors to run metgrid.exe.\n"
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
# Begin pre-init_atmosphere setup
##################################################################################
# The following paths are relative to workflow root paths
#
# work_root       = Working directory where init_atmosphere runs and outputs
# init_dat_files  = All file contents of clean MPAS build directory
#                   namelists and input data is linked from other sources
# init_atmos_exe  = Path and name of working executable
#
##################################################################################

ungrib_root=${CYC_HME}/ungrib/ens_${memid}
work_root=${CYC_HME}/init_atmosphere/ens_${memid}
if [ ! -d ${ungrib_root} ]; then
  printf "ERROR: \${ungrib_root} directory\n ${ungrib_root}\n does not exist.\n"
  exit 1
else
  cmd="mkdir -p ${work_root}; cd ${work_root}"
  printf "${cmd}\n"; eval "${cmd}"

  for fcst in ${fcst_seq[@]}; do
    filename="${ungrib_root}/${BKG_DATA}:`date +%Y-%m-%d_%H -d "${strt_dt} ${fcst} hours"`"
    if [ ! -s ${filename} ]; then
      printf "ERROR: ${filename} is missing.\n"
      exit 1
    else
      cmd="ln -sfr ${filename} ."
      printf "${cmd}\n"; eval "${cmd}"
    fi
  done
fi

init_dat_files=(${MPAS_ROOT}/*)
init_atmos_exe=${MPAS_ROOT}/init_atmosphere_model

if [ ! -x ${init_atmos_exe} ]; then
  printf "ERROR:\n ${init_atmos_exe}\n does not exist, or is not executable.\n"
  exit 1
fi

# Make links to the INIT_ATMOS DAT files
for file in ${init_dat_files[@]}; do
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
#  Build init_atmosphere namelist
##################################################################################
# Remove any previous namelists and stream lists
cmd="rm -f namelist.*; rm -f streams.*; rm -f stream_list.*"
printf "${cmd}\n"; eval "${cmd}"

# Copy the init_atmosphere namelist / streams templates,
# NOTE: THESE WILL BE MODIFIED DO NOT LINK TO THEM
namelist_temp=${EXP_CNFG}/namelists/namelist.init_atmosphere.${BKG_DATA}
if [ ! -r ${namelist_temp} ]; then 
  msg="init_atmosphere namelist template\n ${namelist_temp}\n is not readable or "
  msg+="does not exist.\n"
  printf "${msg}"
  exit 1
else
  cmd="cp -L ${namelist_temp} ./namelist.init_atmosphere"
  printf "${cmd}\n"; eval "${cmd}"
fi

streams_temp=${EXP_CNFG}/streamlists/streams.init_atmosphere
if [ ! -r ${streams_temp} ]; then 
  msg="init_atmosphere streams template\n ${streams_temp}\n is not readable or "
  msg+="does not exist.\n"
  printf "${msg}"
  exit 1
else
  cmd="cp -L ${streams_temp} ./streams.init_atmosphere"
  printf "${cmd}\n"; eval "${cmd}"
fi

# define start / end time patterns for namelist.init_atmosphere
strt_iso=`date +%Y-%m-%d_%H_%M_%S -d "${strt_dt}"`
end_iso=`date +%Y-%m-%d_%H_%M_%S -d "${end_dt}"`

# Update background data interval in namelist
(( data_interval_sec = BKG_INT * 3600 ))

# Update the init_atmosphere namelist / streams for real initial conditions
cat namelist.init_atmosphere \
  | sed "s/= CONFIG_INIT_CASE,/= 7/" \
  | sed "s/= CONFIG_START_TIME,/= '${strt_iso}'/" \
  | sed "s/= CONFIG_STOP_TIME,/= '${end_iso}'/" \
  | sed "s/= CONFIG_MET_PREFIX,/= '${BKG_DATA}'/" \
  | sed "s/= CONFIG_MET_SFC,/= '${BKG_DATA}'/" \
  | sed "s/= CONFIG_FG_INTERVAL,/= ${data_interval_sec}/" \
  | sed "s/= CONFIG_STATIC_INTERP,/= false/" \
  | sed "s/= CONFIG_NATIVE_GWD_STATIC,/= false/" \
  | sed "s/= CONFIG_VERTICAL_GRID,/= true/" \
  | sed "s/= CONFIG_MET_INTERP,/= true/" \
  | sed "s/= CONFIG_INPUT_SST,/= false/" \
  | sed "s/= CONFIG_FRAC_SEAICE,/= true/" \
  | sed "s/= CONFIG_PIO_NUM_IOTASKS,/= ${PIO_NUM}/" \
  | sed "s/= CONFIG_PIO_STRIDE,/= ${PIO_STRIDE}/" \
  | sed "s/CONFIG_BLOCK_DECOMP_FILE_PREFIX,/= '${DMN_NME}.graph.info.part.'/" \
  > namelist.init_atmosphere.tmp
mv namelist.init_atmosphere.tmp namelist.init_atmosphere

cat streams.init_atmosphere \
  | sed "s/=INPUT_FILE_NAME,/=\"${DMN_NME}.static.nc\"/" \
  | sed "s/=OUTPUT_FILE_NAME,/=\"${DMN_NME}.init.nc\"/" \
  | sed "s/=SURFACE_FILE_NAME,/=\"${DMN_NME}.sfc_update.nc\"/" \
  | sed "s/=SFC_OUTPUT_INTERVAL,/=\"${BKG_INT}:00:00\"/" \
  | sed "s/=LBC_OUTPUT_INTERVAL,/=\"${BKG_INT}:00:00\"/" \
  > streams.init_atmosphere.tmp
mv streams.init_atmosphere.tmp streams.init_atmosphere

##################################################################################
# Run init_atmosphere
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
printf "metgrid started at ${now}.\n"
cmd="${MPIRUN} -n ${N_PROC} ${init_atmos_exe}"
printf "${cmd}\n"; eval "${cmd}"

##################################################################################
# Run time error check
##################################################################################
error=$?

# save mpas_real_ic logs
log_dir=init_atmosphere_log.${now}
mkdir ${log_dir}
cmd="mv log.init_atmosphere.* ${log_dir}"
printf "${cmd}\n"; eval "${cmd}"

cmd="mv namelist.init_atmosphere ${log_dir}"
printf "${cmd}\n"; eval "${cmd}"

cmd="mv streams.init_atmosphere ${log_dir}"
printf "${cmd}\n"; eval "${cmd}"

# Remove links to the INIT_ATMOS DAT files
for file in ${init_dat_files[@]}; do
  cmd="rm -f `basename ${file}`"
  printf "${cmd}\n"; eval "${cmd}"
done

if [ ${error} -ne 0 ]; then
  printf "ERROR:\n ${init_atmos_exe}\n exited with status ${error}.\n"
  exit ${error}
fi

## Check to see if metgrid outputs are generated
#for dmn in ${dmns[@]}; do
#  for fcst in ${fcst_seq[@]}; do
#    dt_str=`date +%Y-%m-%d_%H:%M:%S -d "${strt_dt} ${fcst} hours"`
#    out_name="met_em.d${dmn}.${dt_str}.nc"
#    if [ ! -s "${out_name}" ]; then
#      printf "ERROR:\n ${init_atmos_exe}\n failed to complete for d${dmn}.\n"
#      exit 1
#    else
#      # rename to no-colon style for WRF
#      dt_str=`date +%Y-%m-%d_%H_%M_%S -d "${strt_dt} ${fcst} hours"`
#      re_name="met_em.d${dmn}.${dt_str}.nc"
#      cmd="mv ${out_name} ${re_name}"
#      printf "${cmd}\n"; eval "${cmd}"
#    fi
#  done
#done

printf "mpas_real_ic.sh completed successfully at `date +%Y-%m-%d_%H_%M_%S`.\n"

##################################################################################
# end

exit 0
