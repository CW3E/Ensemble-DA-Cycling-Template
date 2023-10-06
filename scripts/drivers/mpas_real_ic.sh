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
# FCST_HRS   = Total length of WRF forecast simulation in HH, IF_DYN_LEN=No
# EXP_VRF    = Verfication time for calculating forecast hours, IF_DYN_LEN=Yes
# BKG_INT    = Interval of input data in HH
# BKG_DATA   = String case variable for supported inputs: GFS, GEFS currently
# PIO_NUM    = Number of tasks to perform file I/O
# PIO_STRIDE = Stride between file I/O tasks
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

if [ ! ${PIO_NUM} ]; then
  printf "ERROR: \${PIO_NUM} is not defined.\n"
  exit 1
elif [ ${PIO_NUM} -lt 0 ]; then
  msg="ERROR: \${PIO_NUM} must be >= 0 for the number of IO tasks, with equal to"
  msg+=" 0 corresponding to all tasks performing IO.\n"
  printf ${msg}
  exit 1
elif [ ${PIO_NUM} -gt ${N_PROC}]; then
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
# Define metgrid workflow dependencies
##################################################################################
# Below variables are defined in workflow variables
#
# MPAS_ROOT  = Root directory of a clean MPAS build
# EXP_CNFG   = Root directory containing sub-directories for namelists
#              vtables, static data, etc.
# CYC_HME    = Cycle YYYYMMDDHH named directory for cycling data containing
#              bkg, init_atmos_prd, mpasprd 
# MPIRUN     = MPI multiprocessing evaluation call, machine specific
# N_PROC     = The total number of processes to run metgrid.exe with MPI
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

##################################################################################
# Begin pre-metgrid setup
##################################################################################
# The following paths are relative to workflow root paths
#
# work_root     = Working directory where init_atmosphere_exe runs and outputs
# init_atmosphere_dat_files = All file contents of clean WPS directory
#                 namelists and input data will be linked from other sources
# init_atmosphere_exe   = Path and name of working executable
#
##################################################################################

work_root=${CYC_HME}/init_atmos_prd/ens_${memid}
if [ ! -d ${work_root} ]; then
  printf "ERROR: \${work_root} directory\n ${work_root}\n does not exist.\n"
  exit 1
else
  cmd="cd ${work_root}"
  printf "${cmd}\n"; eval "${cmd}"
fi

init_atmosphere_dat_files=(${MPAS_ROOT}/*)
init_atmosphere_exe=${MPAS_ROOT}/init_atmosphere

if [ ! -x ${init_atmosphere_exe} ]; then
  printf "ERROR:\n ${init_atmosphere_exe}\n does not exist, or is not executable.\n"
  exit 1
fi

# Make links to the INIT_ATMOS DAT files
for file in ${init_atmosphere_dat_files[@]}; do
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
# Remove any previous namelists
cmd="rm -f namelist.init_atmosphere"
printf "${cmd}\n"; eval "${cmd}"

# Copy the init_atmosphere namelist template,
# NOTE: THIS WILL BE MODIFIED DO NOT LINK TO IT
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

# Update the init_atmosphere config_init_case to 7 for real initial conditions
cat namelist.init_atmosphere \
  | sed "s/CONFIG_INIT_CASE/7/" \
  > namelist.init_atmosphere.tmp
mv namelist.init_atmosphere.tmp namelist.init_atmosphere

# define start / end time patterns for namelist.init_atmosphere
strt_iso=`date +%Y-%m-%d_%H_%M_%S -d "${strt_dt}"`
end_iso=`date +%Y-%m-%d_%H_%M_%S -d "${end_dt}"`

in_sd="\(config_start_time\)${EQUAL}CONFIG_START_TIME"
out_sd="\1 = '${strt_iso}'"
in_ed="\(config_stop_time\)${EQUAL}CONFIG_STOP_TIME"
out_ed="\1 = '${end_iso}'"

# Update the start and end date in namelist
cat namelist.init_atmosphere \
  | sed "s/${in_sd}/${out_sd}/" \
  | sed "s/${in_ed}/${out_ed}/" \
  > namelist.init_atmosphere.tmp
mv namelist.init_atmosphere.tmp namelist.init_atmosphere

# Update the met data prefix to the background data
in_met_prfx="\(config_met_prefix\)${EQUAL}CONFIG_MET_PREFIX"
out_met_prfx="\1 = '${BKG_DATA}"
cat namelist.init_atmosphere \
  | sed "s/${in_met_prfx}/${out_met_prfx}/" \
  > namelist.init_atmosphere.tmp
mv namelist.init_atmosphere.tmp namelist.init_atmosphere

# Update background data interval in namelist
(( data_interval_sec = BKG_INT * 3600 ))
in_int="\(config_fg_interval\)${EQUAL}CONFIG_FG_INTERVAL"
out_int="\1 = ${data_interval_sec}"
cat namelist.init_atmosphere \
  | sed "s/${in_int}/${out_int}/" \
  > namelist.init_atmosphere.tmp
mv namelist.init_atmosphere.tmp namelist.init_atmosphere

# update static data interpolation setting
in_static_interp="\(config_static_interp\)${EQUAL}CONFIG_STATIC_INTERP"
out_static_interp="\1 = false"
cat namelist.init_atmosphere \
  | sed "s/${in_static_interp}/${out_static_interp}/" \
  > namelist.init_atmosphere.tmp
mv namelist.init_atmosphere.tmp namelist.init_atmosphere

# update subgridscale statistics setting
in_gwd_static="\(config_native_gwd_static\)${EQUAL}CONFIG_NATIVE_GWD_STATIC"
out_gwd_static="\1 = false"
cat namelist.init_atmosphere \
  | sed "s/${in_gwd_static}/${out_gwd_static}/" \
  > namelist.init_atmosphere.tmp
mv namelist.init_atmosphere.tmp namelist.init_atmosphere

# update generate vertical grid or no
in_vertical_grid="\(config_vertical_grid\)${EQUAL}CONFIG_VERTICAL_GRID"
out_vertical_grid="\1 = true"
cat namelist.init_atmosphere \
  | sed "s/${in_vertical_grid}/${out_vertical_grid}/" \
  > namelist.init_atmosphere.tmp
mv namelist.init_atmosphere.tmp namelist.init_atmosphere

# update whether to interpolate background to intermediate file
in_met_interp="\(config_met_interp\)${EQUAL}CONFIG_MET_INTERP"
out_met_interp="\1 = true"
cat namelist.init_atmosphere \
  | sed "s/${in_met_interp}/${out_met_interp}/" \
  > namelist.init_atmosphere.tmp
mv namelist.init_atmosphere.tmp namelist.init_atmosphere

# update whether to compute SST update
in_input_sst="\(config_input_sst\)${EQUAL}CONFIG_INPUT_SST"
out_input_sst="\1 = false"
cat namelist.init_atmosphere \
  | sed "s/${in_input_sst}/${out_input_sst}/" \
  > namelist.init_atmosphere.tmp
mv namelist.init_atmosphere.tmp namelist.init_atmosphere

# update whether to switch sea ice fraction threshold
in_frac_seaice="\(config_frac_seaice\)${EQUAL}CONFIG_FRAC_SEAICE"
out_frac_seaice="\1 = true"
cat namelist.init_atmosphere \
  | sed "s/${in_frac_seaice}/${out_frac_seaice}/" \
  > namelist.init_atmosphere.tmp
mv namelist.init_atmosphere.tmp namelist.init_atmosphere


# update whether to switch sea ice fraction threshold
in_pio_num="\(config_pio_num_iotasks\)${EQUAL}CONFIG_PIO_NUM_IOTASKS"
out_pio_num="\1 = ${PIO_NUM}"
cat namelist.init_atmosphere \
  | sed "s/${in_pio_num}/${out_pio_num}/" \
  > namelist.init_atmosphere.tmp
mv namelist.init_atmosphere.tmp namelist.init_atmosphere

# update whether to switch sea ice fraction threshold
in_pio_stride="\(config_pio_stride\)${EQUAL}CONFIG_PIO_STRIDE"
out_pio_stride="\1 = ${PIO_STRIDE}"
cat namelist.init_atmosphere \
  | sed "s/${in_pio_stride}/${out_pio_stride}/" \
  > namelist.init_atmosphere.tmp
mv namelist.init_atmosphere.tmp namelist.init_atmosphere

 = 
# update the prefix for the block decomposition to the domain name
in_blk_prfx="\(config_block_decomp_file_prefix\)${EQUAL}CONFIG_BLOCK_DECOMP_FILE_PREFIX"
out_blk_prfx="\1 = ${DMN_NME}"
cat namelist.init_atmosphere \
  | sed "s/${in_blk_prfx}/${out_blk_prfx}/" \
  > namelist.init_atmosphere.tmp
mv namelist.init_atmosphere.tmp namelist.init_atmosphere

##################################################################################
# Run init_atmosphere
##################################################################################
# Print run parameters
printf "\n"
printf "EXP_CNFG = ${EXP_CNFG}\n"
printf "MEMID    = ${MEMID}\n"
printf "CYC_HME  = ${CYC_HME}\n"
printf "STRT_DT  = ${strt_iso}\n"
printf "END_DT   = ${end_iso}\n"
printf "BKG_INT  = ${BKG_INT}\n"
printf "MAX_DOM  = ${MAX_DOM}\n"
printf "\n"
now=`date +%Y-%m-%d_%H_%M_%S`
printf "metgrid started at ${now}.\n"
cmd="${MPIRUN} -n ${N_PROC} ${init_atmosphere_exe}"
printf "${cmd}\n"; eval "${cmd}"

##################################################################################
# Run time error check
##################################################################################
error=$?

# save metgrid logs
log_dir=metgrid_log.${now}
mkdir ${log_dir}
cmd="mv metgrid.log* ${log_dir}"
printf "${cmd}\n"; eval "${cmd}"

cmd="mv namelist.init_atmosphere ${log_dir}"
printf "${cmd}\n"; eval "${cmd}"

if [ ${error} -ne 0 ]; then
  printf "ERROR:\n ${init_atmosphere_exe}\n exited with status ${error}.\n"
  exit ${error}
fi

# Check to see if metgrid outputs are generated
for dmn in ${dmns[@]}; do
  for fcst in ${fcst_seq[@]}; do
    dt_str=`date +%Y-%m-%d_%H:%M:%S -d "${strt_dt} ${fcst} hours"`
    out_name="met_em.d${dmn}.${dt_str}.nc"
    if [ ! -s "${out_name}" ]; then
      printf "ERROR:\n ${init_atmosphere_exe}\n failed to complete for d${dmn}.\n"
      exit 1
    else
      # rename to no-colon style for WRF
      dt_str=`date +%Y-%m-%d_%H_%M_%S -d "${strt_dt} ${fcst} hours"`
      re_name="met_em.d${dmn}.${dt_str}.nc"
      cmd="mv ${out_name} ${re_name}"
      printf "${cmd}\n"; eval "${cmd}"
    fi
  done
done

# Remove links to the INIT_ATMOS DAT files
for file in ${init_atmosphere_dat_files[@]}; do
  cmd="rm -f `basename ${file}`"
  printf "${cmd}\n"; eval "${cmd}"
done

printf "metgrid.sh completed successfully at `date +%Y-%m-%d_%H_%M_%S`.\n"

##################################################################################
# end

exit 0
