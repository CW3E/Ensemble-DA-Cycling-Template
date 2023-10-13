#!/bin/bash
##################################################################################
# Description
##################################################################################
# This driver script is designed to dynamically propagate the
# namelist.atmosphere and streams.atmosphere templates included in
# this repository to run a model integration for the MPAS-A model.
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
# DMN_NME       = MPAS domain name used to call mesh / static file name patterns
# MEMID         = Ensemble ID index, 00 for control, i > 0 for perturbation
# STRT_DT       = Simulation start time in YYMMDDHH
# IF_DYN_LEN    = If to compute forecast length dynamically (Yes / No)
# FCST_HRS      = Total length of MPAS forecast simulation in HH, IF_DYN_LEN=No
# EXP_VRF       = Verfication time for calculating forecast hours, IF_DYN_LEN=Yes
# IF_RGNL       = Equals "Yes" or "No" if MPAS regional simulation is being run
# BKG_INT       = Interval of lbc input data in HH, required IF_RGNL = Yes
# DIAG_INT      = Interval at which diagnostic fields are output (HH)
# HIST_INT      = Interval at which model history fields are output (HH)
# BCKT_INT      = Interval at which accumulation buckets are updated
# SND_INT       = Interval at which soundings are made
# RSTRT_INT     = Interval at which model restart files are output (HH)
# IF_RSTRT      = If performing a restart run initialization (Yes / No)
# IF_DA         = If peforming DA (Yes - writes out necessary fields / No)
# IF_DA_CYC     = If performing DA cycling initialization (Yes / No)
# IF_IAU        = If performing incremental assimilation update (Yes / No)
# IF_SST_UPDTE  = If updating SST with lower BC update files
# IF_SST_DIURN  = If updating SST with diurnal cycling
# IF_DEEPSOIL   = If slowly updating lower boundary deep soil temperature
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
    fcst_hrs=`printf %03d $(( 10#${FCST_HRS} ))`
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
    fcst_hrs=$(( (${exp_vrf} - `date +%s -d "${strt_dt}"`) / 3600 ))
    fcst_hrs=`printf %03d $(( 10#${fcst_hrs} ))`
  fi
else
  printf "\${IF_DYN_LEN} must be set to 'Yes' or 'No' (case insensitive).\n"
  exit 1
fi

# define the end time based on forecast length control flow above
stop_dt=`date -d "${strt_dt} ${fcst_hrs} hours"`

if [[ ${IF_RGNL} = ${NO} ]]; then 
  printf "MPAS-A is run as a global simulation.\n"
  if_rgnl="false"
elif [[ ${IF_RGNL} = ${YES} ]]; then
  printf "MPAS-A is run as a regional simulation.\n"
  if_rgnl="true"

  # check that interval for background lbc data is defined
  if [ ! ${BKG_INT} ]; then
    printf "ERROR: \${BKG_INT} is not defined.\n"
    exit 1
  elif [ ${BKG_INT} -le 0 ]; then
    printf "ERROR: \${BKG_INT} must be HH > 0 for the frequency of data inputs.\n"
    exit 1
  fi
else
  printf "\${IF_RGNL} must be set to 'Yes' or 'No' (case insensitive).\n"
  exit 1
fi

if [ ! ${DIAG_INT} ]; then
  printf "ERROR: \${DIAG_INT} is not defined.\n"
  exit 1
elif [ ${DIAG_INT} -le 0 ]; then
  printf "ERROR: \${DIAG_INT} must be HH > 0 for the frequency of data inputs.\n"
  exit 1
fi

if [ ! ${HIST_INT} ]; then
  printf "ERROR: \${HIST_INT} is not defined.\n"
  exit 1
elif [ ${HIST_INT} -le 0 ]; then
  printf "ERROR: \${HIST_INT} must be HH > 0 for the frequency of data inputs.\n"
  exit 1
fi

if [ ! ${BCKT_INT} ]; then
  printf "ERROR: \${BCKT_INT} is not defined.\n"
  exit 1
elif [ ${BCKT_INT} -le 0 ]; then
  printf "ERROR: \${BCKT_INT} must be HH > 0 for the accumulation reset.\n"
  exit 1
fi

if [ ! ${SND_INT} ]; then
  printf "ERROR: \${SND_INT} is not defined.\n"
  exit 1
elif [ ${SND_INT} -le 0 ]; then
  printf "ERROR: \${SND_INT} must be HH > 0 for the frequency of data inputs.\n"
  exit 1
fi

if [ ! ${RSTRT_INT} ]; then
  printf "ERROR: \${RSTRT_INT} is not defined.\n"
  exit 1
elif [ ${RSTRT_INT} -le 0 ]; then
  printf "ERROR: \${RSTRT_INT} must be HH > 0 for the frequency of data inputs.\n"
  exit 1
fi

if [[ ${IF_RSTRT} = ${NO} ]]; then 
  printf "MPAS-A is run from init_atmosphere initial conditions.\n"
  if_rstrt="false"

elif [[ ${IF_RSTRT} = ${YES} ]]; then
  printf "MPAS-A is run as a restart simulation.\n"
  if_rstrt="true"

else
  printf "\${IF_RSTRT} must be set to 'Yes' or 'No' (case insensitive).\n"
  exit 1
fi

if [[ ${IF_DA} = ${NO} ]]; then 
  printf "Data assimilation control fields are not automatically written.\n"
  if_da="false"

elif [[ ${IF_DA} = ${YES} ]]; then
  printf "MPAS-A writes out temperature and specific humidity as diagnostics.\n"
  if_da="true"

  if [[ ${IF_DA_CYC} = ${YES} ]]; then
    printf "MPAS-A recomputes coupled fields from analyzed fields in DA update.\n"
    if_dacyc="true"

  elif [[ ${IF_DA_CYC} = ${NO} ]]; then
    printf "MPAS-A does not update coupled fields from analyzed fields.\n"
    if_dacyc="false"

  else
    printf "\${IF_DA_CYC} must be set to 'Yes' or 'No' (case insensitive).\n"
    exit 1
  fi
  if [[ ${IF_IAU} = ${YES} ]]; then
    printf "MPAS-A performs the Incremental Analysis Update scheme.\n"
    if_iau="on"

  elif [[ ${IF_IAU} = ${NO} ]]; then
    printf "MPAS-A does not perform the Incremental Analysis Update scheme.\n"
    if_iau="off"

  else
    printf "\${IF_IAU} must be set to 'Yes' or 'No' (case insensitive).\n"
    exit 1
  fi
else
  printf "\${IF_DA} must be set to 'Yes' or 'No' (case insensitive).\n"
  exit 1
fi

if [[ ${IF_SST_UPDTE} = ${NO} ]]; then 
  printf "MPAS-A uses static lower boundary conditions.\n"
  if_sst_updte="false"

elif [[ ${IF_SST_UPDTE} = ${YES} ]]; then
  printf "MPAS-A updates lower boundary conditions.\n"
  if_sst_updte="true"

  if [[ ${IF_SST_DIURN} = ${YES} ]]; then
    printf "MPAS-A updates SST on diurnal cycle.\n"
    if_sst_diurn="true"

  elif [[ ${IF_SST_DIURN} = ${NO} ]]; then
    printf "MPAS-A does not update SST on diurnal cycle.\n"
    if_sst_diurn="false"

  else
    printf "\${IF_SST_DIURN} must be set to 'Yes' or 'No' (case insensitive).\n"
    exit 1
  fi
  if [[ ${IF_DEEPSOIL} = ${YES} ]]; then
    printf "MPAS-A slowly updates lower boundary deep soil temperatures.\n"
    if_deepsoil="true"

  elif [[ ${IF_DEEPSOIL} = ${NO} ]]; then
    printf "MPAS-A does not update lower boundary deep soil temperatures.\n"
    if_deepsoil="false"

  else
    printf "\${IF_DEEPSOIL} must be set to 'Yes' or 'No' (case insensitive).\n"
    exit 1
  fi
else
  printf "\${IF_SST_UPDTE} must be set to 'Yes' or 'No' (case insensitive).\n"
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
# atmos_ic_root    = Directory from which initial condition data is sourced
# atmos_sfc_root   = Directory from which surface update data is sourced
# atmos_lbc_root   = Directory from which lateral boundary data is sourced
# work_root        = Working directory where atmosphere_model runs and outputs
# model_run_files  = All file contents of clean MPAS build directory
#                    namelists and input data is linked from other sources
# atmos_model_exe  = Path and name of working executable
#
##################################################################################
# Create work root and change directory
work_root=${CYC_HME}/atmosphere_model/ens_${memid}
cmd="mkdir -p ${work_root}; cd ${work_root}"
printf "${cmd}\n"; eval "${cmd}"

# check that the init_atmosphere executable exists and can be run
atmos_model_exe=${MPAS_ROOT}/init_atmosphere_model
if [ ! -x ${atmos_model_exe} ]; then
  printf "ERROR:\n ${atmos_model_exe}\n does not exist, or is not executable.\n"
  exit 1
fi

# Make links to the model run files
model_run_files=(${MPAS_ROOT}/*)
for run_f in ${model_run_files[@]}; do
  cmd="ln -sf ${run_f} ."
  printf "${cmd}\n"; eval "${cmd}"
done

# Make links to the model physics files
model_phys_files=${MPAS_ROOT}/src/core_atmosphere/physics/physics_wrf/files/* .
for phys_f in ${model_run_files[@]}; do
  cmd="ln -sf ${phys_f} ."
  printf "${cmd}\n"; eval "${cmd}"
done

# Remove any mpas init files following ${DMN_NME}.init.nc pattern
cmd="rm -f *.init.nc"
printf "${cmd}\n"; eval "${cmd}"

# Remove any mpas partition files following ${DMN_NME}.graph.info.part.* pattern
cmd="rm -f ${DMN_NME}.graph.info.part.*"
printf "${cmd}\n"; eval "${cmd}"

# Remove any previous namelists and stream lists
cmd="rm -f namelist.*; rm -f streams.*; rm -f stream_list.*"
printf "${cmd}\n"; eval "${cmd}"

# Remove any previous lateral boundary condition files ${DMN_NME}.lbc.*.nc
cmd="rm -f *.lbc.*.nc"
printf "${cmd}\n"; eval "${cmd}"

# Define list of preprocessed data and make links
atmos_ic_root=${CYC_HME}/init_atmosphere_ic/ens_${memid}
atmos_sfc_root=${CYC_HME}/init_atmosphere_sfc/ens_${memid}
input_files=( 
             "${atmos_ic_root}/${DMN_NME}.init.nc"
	     "${atmos_sfc_root}/${DMN_NME}.sfc_update.nc"
	    )

if [[ ${IF_RGNL} = ${YES} ]]; then 
  # define a sequence of all forecast hours with background interval spacing
  bkg_seq=`seq -f "%03g" 0 ${BKG_INT} ${fcst_hrs}`
  for fcst in ${fcst_seq[@]}; do
    lbc_time="`date +%Y-%m-%d_%H_%M_%S -d "${strt_dt} ${fcst} hours"`"
    input_files+=( "${atmos_lbs_root}/${DMN}.lbc.${lbc_time}.nc" )
  done
fi

for input_f in ${input_files[@]}; do
  if [ ! -r ${input_f} ]; then
    printf "ERROR: ${input_f} is missing or is not readable.\n"
    exit 1
  elif [ ! -s ${input_f} ]; then
    printf "ERROR: ${input_f} is missing or emtpy.\n"
    exit 1
  else
    cmd="ln -sfr ${input_f} ."
    printf "${cmd}\n"; eval "${cmd}"
  fi
done

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
# Copy the atmosphere namelist / streams templates,
# NOTE: THESE WILL BE MODIFIED DO NOT LINK TO THEM
namelist_temp=${EXP_CNFG}/namelists/namelist.atmosphere.${DMN_NME}
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
stop_iso=`date +%Y-%m-%d_%H:%M:%S -d "${stop_dt}"`

# Update background data interval in namelist
(( data_interval_sec = BKG_INT * 3600 ))

# Update the atmosphere namelist / streams for surface boundary conditions
cat namelist.atmosphere \
  | sed "s/= STRT_DT,/= '${strt_iso}'/" \
  | sed "s/= FCST_HRS,/= '${fcst_hrs}'/" \
  | sed "s/= IF_RGNL,/= '${if_rgnl}'/" \
  | sed "s/= IF_RSTRT,/= '${if_rstrt}'/" \
  | sed "s/= IF_DA,/= '${if_da}'/" \
  | sed "s/= IF_IAU,/= '${if_iau}'/" \
  | sed "s/= IF_DACYC,/= '${if_dacyc}'/" \
  | sed "s/= IF_SST_UPDT,/= '${if_sst_updt}'/" \
  | sed "s/= IF_SST_DIURN,/= '${if_sst_diurn}'/" \
  | sed "s/= IF_DEEPSOIL,/= '${if_deepsoil}'/" \
  | sed "s/= BCKT_INT,/= '${bckt_updt_int}'/" \
  | sed "s/= SND_INT,/= '${snd_int}'/" \
  | sed "s/= PIO_NUM,/= ${PIO_NUM}/" \
  | sed "s/= PIO_STRIDE,/= ${PIO_STRIDE}/" \
  | sed "s/DMN_NME/${DMN_NME}/" \
  > streams.atmosphere.tmp
mv streams.atmosphere.tmp streams.atmosphere

cat streams.atmosphere \
  | sed "s/DMN_NME/${DMN_NME}/" \
  | sed "s/=RSTRT_INT,/=\"${rstrt_int}:00:00\"/" \
  | sed "s/=HIST_INT,/=\"${hist_int}:00:00\"/" \
  | sed "s/=DIAG_INT,/=\"${diag_int}:00:00\"/" \
  > streams.init_atmosphere.tmp
mv streams.init_atmosphere.tmp streams.init_atmosphere

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
printf "STOP_DT  = ${stop_iso}\n"
printf "BKG_INT  = ${BKG_INT}\n"
printf "\n"
now=`date +%Y-%m-%d_%H_%M_%S`
printf "atmosphere_model started at ${now}.\n"
cmd="${MPIRUN} -n ${N_PROC} ${atmos_model_exe}"
printf "${cmd}\n"
${MPIRUN} -n ${N_PROC} ${atmos_model_exe}

##################################################################################
# Run time error check
##################################################################################
error="$?"
printf "atmosphere_model exited with code ${error}.\n"

# save mpas_sfc logs
log_dir=atmosphere_model_log.${now}
mkdir ${log_dir}
cmd="mv log.atmosphere.* ${log_dir}"
printf "${cmd}\n"; eval "${cmd}"

cmd="mv namelist.atmosphere ${log_dir}"
printf "${cmd}\n"; eval "${cmd}"

cmd="mv streams.atmosphere ${log_dir}"
printf "${cmd}\n"; eval "${cmd}"

# Remove links to the model run files
for run_f in ${model_run_files[@]}; do
  cmd="rm -f `basename ${run_f}`"
  printf "${cmd}\n"; eval "${cmd}"
done

# Remove links to the model physics files
for phys_f in ${model_phys_files[@]}; do
  cmd="rm -f `basename ${phys_f}`"
  printf "${cmd}\n"; eval "${cmd}"
done

# remove links to input files
for input_f in ${input_files[@]}; do
  cmd="rm -f `basename ${input_f}`"
  printf "${cmd}\n"; eval "${cmd}"
done

if [ ${error} -ne 0 ]; then
  printf "ERROR:\n ${atmos_model_exe}\n exited with status ${error}.\n"
  exit ${error}
fi

# Check to see if atmosphere outputs are generated
if [ ! -s "${out_name}" ]; then
  printf "ERROR:\n ${atmos_model_exe}\n failed to complete writing ${out_name}.\n"
  exit 1
fi

printf "mpas_model.sh completed successfully at `date +%Y-%m-%d_%H_%M_%S`.\n"

##################################################################################
# end

exit 0
