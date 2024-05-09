#!/bin/bash
##################################################################################
# Description
##################################################################################
# This driver script is designed to dynamically propagate the
# namelist.init_atmosphere and streams.init_atmosphere templates included in
# this repository to generate real data initial conditions for the MPAS-A model.
#
# One should write machine specific options for the MPAS environment
# in a MPAS_constants.sh script to be sourced in the below.
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
# Make checks for init_atmosphere settings
##################################################################################
# Options below are defined in workflow variables
#
# EXP_NME    = Case study / config short name directory structure
# CFG_ROOT   = Root directory containing simulation settings
# MSH_NME    = MPAS mesh name used to call mesh file name patterns
# MEMID      = Ensemble ID index, 00 for control, i > 0 for perturbation
# STRT_DT    = Simulation start time in YYYYMMDDHH
# IF_DYN_LEN = If to compute forecast length dynamically (Yes / No)
# FCST_HRS   = Total length of MPAS forecast simulation in HH, IF_DYN_LEN=No
# EXP_VRF    = Verfication time for calculating forecast hours, IF_DYN_LEN=Yes
# BKG_DATA   = String case variable for supported inputs: GFS, GEFS currently
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

if [ ! ${MSH_NME} ]; then
  printf "ERROR: \${MSH_NME} is not defined.\n"
  exit 1
else
  printf "MPAS domain name is ${MSH_NME}.\n"
fi

if [ ! ${MEMID} ]; then
  printf "ERROR: \${MEMID} is not defined.\n"
  exit 1
else
  # ensure padding to two digits is included
  memid=`printf %02d $(( 10#${MEMID} ))`
  printf "Running init_atmosphere for ensemble member ${MEMID}.\n"
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
  if [ ! ${FCST_HRS} ]; then
    printf "ERROR: \${FCST_HRS} is not defined.\n"
    exit 1
  else
    # parse forecast hours as base 10 padded
    fcst_len=`printf %03d $(( 10#${FCST_HRS} ))`
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
    fcst_len=$(( (${exp_vrf} - `date +%s -d "${strt_dt}"`) / 3600 ))
    fcst_len=`printf %03d $(( 10#${fcst_len} ))`
  fi
else
  printf "\${IF_DYN_LEN} must be set to 'Yes' or 'No' (case insensitive).\n"
  exit 1
fi

# define the stop time based on forecast length control flow above
stop_dt=`date -d "${strt_dt} ${fcst_len} hours"`

if [[ ${IF_ZETA_LIST} = ${NO} ]]; then 
  printf "Uses automatically generated zeta levels for vertical grid spacing.\n"
  # define string replacement for the namelist
  if_zeta_list=""
elif [[ ${IF_ZETA_LIST} = ${YES} ]]; then
  # define full path to zeta list
  zeta_list=( `ls ${cfg_dir}/static/*.ZETA_LIST.txt` )
  if [ $? -ne 0 ]; then
    printf "ERROR: no match found for pattern\n"
    printf "    ${cfg_dir}/static/*.ZETA_LIST.txt"
    printf "A *.ZETA_LIST.txt is required for specified zeta levels."
    exit 1
  elif [ ${#zeta_list[@]} -gt 1 ]; then
    printf "ERROR: multiple matches found for *.ZETA_LIST.txt\n"
    for tmp in ${zeta_list[@]}; do
      printf "    ${tmp}\n"
    done
    printf "Simulation configuration directory\n    ${cfg_dir}/static\n"
    printf "must have a unique choice of *.ZETA_LIST.txt\n"
    exit 1
  else
    zeta_list=${zeta_list[0]}
  fi

  # define string replacement for the namelist
  if_zeta_list="config_specified_zeta_levels = `basename ${zeta_list}`"

  printf "Uses explicitly defined zeta levels for vertical grid spacing in file\n"
  printf "`basename ${zeta_list}`\n"
else
  printf "\${IF_ZETA_LIST} must be set to 'Yes' or 'No' (case insensitive).\n"
  exit 1
fi

if [[ ${BKG_DATA} != GFS && ${BKG_DATA} != GEFS ]]; then
  msg="ERROR: \${BKG_DATA} must equal 'GFS' or 'GEFS'"
  msg+=" as currently supported inputs.\n"
  printf "${msg}"
  exit 1
else
  printf "Background data is ${BKG_DATA}.\n"
fi

##################################################################################
# Define init_atmosphere workflow dependencies
##################################################################################
# Below variables are defined in workflow variables
#
# MPAS_ROOT = Root directory of a clean MPAS build
# CYC_HME   = Cycle YYYYMMDDHH named directory for cycling data
# MPIRUN    = MPI multiprocessing evaluation call, machine specific
# N_NDES    = Total number of nodes
# N_PROC    = The total number of processes per node
# PIO_NUM   = Number of tasks to perform file I/O
# PIO_STRD  = Stride between file I/O tasks
#
##################################################################################

if [ ! ${MPAS_ROOT} ]; then
  printf "ERROR: \${MPAS_ROOT} is not defined.\n"
  exit 1
elif [ ! -d ${MPAS_ROOT} ]; then
  printf "ERROR: \${MPAS_ROOT} directory\n ${MPAS_ROOT}\n does not exist.\n"
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

if [ ! ${N_NDES} ]; then
  printf "ERROR: \${N_NDES} is not defined.\n"
  exit 1
elif [ ${N_NDES} -le 0 ]; then
  msg="ERROR: The variable \${N_NDES} must be set to the number"
  msg+=" of nodes to run init_atmosphere > 0.\n"
  printf "${msg}"
  exit 1
fi

if [ ! ${N_PROC} ]; then
  printf "ERROR: \${N_PROC} is not defined.\n"
  exit 1
elif [ ${N_PROC} -le 0 ]; then
  msg="ERROR: The variable \${N_PROC} must be set to the number"
  msg+=" of processes-per-node to run init_atmosphere > 0.\n"
  printf "${msg}"
  exit 1
fi

if [ ! ${PIO_NUM} ]; then
  printf "ERROR: \${PIO_NUM} is not defined.\n"
  exit 1
elif [ ${PIO_NUM} -lt 0 ]; then
  msg="ERROR: \${PIO_NUM} must be >= 0 for the number of IO tasks, with equal to"
  msg+=" 0 corresponding to all tasks performing IO.\n"
  printf "${msg}"
  exit 1
elif [ ${PIO_NUM} -gt ${N_PROC} ]; then
  msg="ERROR: \${PIO_NUM} must be <= \${NUM_PROC}, ${NUM_PROC}, the number of"
  msg+=" MPI processes.\n"
  printf "${msg}"
  exit 1
fi

if [ ! ${PIO_STRD} ]; then
  printf "ERROR: \${PIO_STRD} is not defined.\n"
  exit 1
fi

mpiprocs=$(( ${N_NDES} * ${N_PROC} ))

##################################################################################
# Begin pre-init_atmosphere setup
##################################################################################
# The following paths are relative to workflow root paths
#
# ungrib_dir = Directory from which ungrib data is sourced
# work_dir   = Work directory where init_atmosphere runs and outputs
# mpas_files = All file contents of clean MPAS build directory
# init_exe   = Path and name of init_atmosphere_model executable
#
##################################################################################
# Create work root and change directory
work_dir=${CYC_HME}/init_atmosphere_ic/ens_${memid}
cmd="mkdir -p ${work_dir}; cd ${work_dir}"
printf "${cmd}\n"; eval "${cmd}"

# Check that the executable exists and can be run
init_exe=${MPAS_ROOT}/init_atmosphere_model
if [ ! -x ${init_exe} ]; then
  printf "ERROR:\n ${init_exe}\n does not exist, or is not executable.\n"
  exit 1
fi

# Make links to the init_atmos run files
mpas_files=(${MPAS_ROOT}/*)
for file in ${mpas_files[@]}; do
  cmd="ln -sf ${file} ."
  printf "${cmd}\n"; eval "${cmd}"
done

# Remove any mpas static files following ${cfg_nme}.static.nc pattern
cmd="rm -f *.static.nc"
printf "${cmd}\n"; eval "${cmd}"

# Remove any mpas init files following ${cfg_nme}.init.nc pattern
cmd="rm -f *.init.nc"
printf "${cmd}\n"; eval "${cmd}"

# Remove any mpas partition files following ${cfg_nme}.graph.info.part.* pattern
cmd="rm -f *.graph.info.part.*"
printf "${cmd}\n"; eval "${cmd}"

# Remove any previous namelists and stream lists
cmd="rm -f namelist.*; rm -f streams.*; rm -f stream_list.*; rm -f *.ZETA_LIST.txt"
printf "${cmd}\n"; eval "${cmd}"

# Move existing log files to a subdir if there are any
printf "Checking for pre-existing log files.\n"
if [ -f log.init_atmosphere.0000.out ]; then
  logdir=init_amosphere_ic_log.`ls -l --time-style=+%Y-%m-%d_%H_%M%_S log.out.0000 | cut -d" " -f 6`
  mkdir ${logdir}
  printf "Moving pre-existing log files to ${logdir}.\n"
  cmd="mv log.* ${logdir}"
  printf "${cmd}\n"; eval "${cmd}"
else
  printf "No pre-existing log files were found.\n"
fi

# Remove pre-existing ungrib case data
filename="${BKG_DATA}:`date +%Y-%m-%d_%H -d "${strt_dt} 0 hours"`"
cmd="rm -f ./${filename}"
printf "${cmd}\n"; eval "${cmd}"

# Link case ungrib data from ungrib root
ungrib_dir=${CYC_HME}/ungrib/ens_${memid}
if [ ! -d ${ungrib_dir} ]; then
  printf "ERROR: \${ungrib_dir} directory\n ${ungrib_dir}\n does not exist.\n"
  exit 1
else
  filename="${ungrib_dir}/${BKG_DATA}:`date +%Y-%m-%d_%H -d "${strt_dt} 0 hours"`"
  if [ ! -s ${filename} ]; then
    printf "ERROR: ${filename} is missing.\n"
    exit 1
  else
    cmd="ln -sfr ${filename} ."
    printf "${cmd}\n"; eval "${cmd}"
  fi
fi

# Check to make sure the static terrestrial input file is available and link
static_input=${cfg_dir}/static/${cfg_nme}.static.nc
if [ ! -r "${static_input}" ]; then
  printf "ERROR: Input file\n ${static_input}\n is missing.\n"
  exit 1
else
  cmd="ln -sf ${static_input} ."
  printf "${cmd}\n"; eval "${cmd}"
fi

# Check to make sure the graph partitioning file is available and link
# NOTE: ${mpiprocs} must match the number of MPI processes
graph_part=${CFG_ROOT}/meshes/${MSH_NME}.graph.info.part.${mpiprocs}
if [ ! -r "${graph_part}" ]; then
  printf "ERROR: Input file\n ${graph_part}\n is missing.\n"
  exit 1
else
  cmd="ln -sf ${graph_part} ."
  printf "${cmd}\n"; eval "${cmd}"
fi

##################################################################################
#  Build init_atmosphere namelist
##################################################################################
# Copy the init_atmosphere namelist / streams templates,
# NOTE: THESE WILL BE MODIFIED DO NOT LINK TO THEM
namelist_tmp=${cfg_dir}/namelists/namelist.init_atmosphere.${BKG_DATA}
streams_tmp=${cfg_dir}/namelists/streams.init_atmosphere

if [ ! -r ${namelist_tmp} ]; then 
  msg="init_atmosphere namelist template\n ${namelist_tmp}\n is not readable or "
  msg+="does not exist.\n"
  printf "${msg}"
  exit 1
else
  cmd="cp -L ${namelist_tmp} ./namelist.init_atmosphere"
  printf "${cmd}\n"; eval "${cmd}"
fi

if [[ ${IF_ZETA_LIST} = ${YES} ]]; then
  if [ ! -r ${zeta_list} ]; then 
    msg="Vertical level list\n ${zeta_list}\n is not readable or "
    msg+="does not exist.\n"
    printf "${msg}"
    exit 1
  else
    cmd="cp -L ${zeta_list} ./"
    printf "${cmd}\n"; eval "${cmd}"
  fi
fi

if [ ! -r ${streams_tmp} ]; then 
  msg="init_atmosphere streams template\n ${streams_tmp}\n is not readable or "
  msg+="does not exist.\n"
  printf "${msg}"
  exit 1
else
  cmd="cp -L ${streams_tmp} ./streams.init_atmosphere"
  printf "${cmd}\n"; eval "${cmd}"
fi

# define start / stop time patterns for namelist.init_atmosphere
strt_iso=`date +%Y-%m-%d_%H:%M:%S -d "${strt_dt}"`
stop_iso=`date +%Y-%m-%d_%H:%M:%S -d "${stop_dt}"`

# Update the init_atmosphere namelist / streams for real initial conditions
cat namelist.init_atmosphere \
  | sed "s/= INIT_CASE,/= 7/" \
  | sed "s/= STRT_DT,/= '${strt_iso}'/" \
  | sed "s/= STOP_DT,/= '${stop_iso}'/" \
  | sed "s/BKG_DATA/${BKG_DATA}/" \
  | sed "s/= FG_INT,/= 0/" \
  | sed "s/= IF_STATIC_INTERP,/= false/" \
  | sed "s/= IF_NATIVE_GWD_STATIC,/= false/" \
  | sed "s/= IF_VERTICAL_GRID,/= true/" \
  | sed "s/= IF_MET_INTERP,/= true/" \
  | sed "s/= IF_INPUT_SST,/= false/" \
  | sed "s/= IF_FRAC_SEAICE,/= true/" \
  | sed "s/IF_ZETA_LIST/${if_zeta_list}/" \
  | sed "s/= PIO_NUM,/= ${PIO_NUM}/" \
  | sed "s/= PIO_STRD,/= ${PIO_STRD}/" \
  | sed "s/MSH_NME/${MSH_NME}/" \
  > namelist.init_atmosphere.tmp
mv namelist.init_atmosphere.tmp namelist.init_atmosphere

cat streams.init_atmosphere \
  | sed "s/CFG_NME/${cfg_nme}/" \
  | sed "s/=SFC_INT,/=\"00:00:00\"/" \
  | sed "s/=LBC_INT,/=\"00:00:00\"/" \
  > streams.init_atmosphere.tmp
mv streams.init_atmosphere.tmp streams.init_atmosphere

##################################################################################
# Run init_atmosphere
##################################################################################
# Print run parameters
printf "\n"
printf "EXP_NME  = ${EXP_NME}\n"
printf "MSH_NME  = ${MSH_NME}\n"
printf "MEMID    = ${MEMID}\n"
printf "CYC_HME  = ${CYC_HME}\n"
printf "STRT_DT  = ${strt_iso}\n"
printf "STOP_DT  = ${stop_iso}\n"
printf "BKG_DATA = ${BKG_DATA}\n"
printf "\n"
now=`date +%Y-%m-%d_%H_%M_%S`
printf "init_atmpshere started at ${now}.\n"
cmd="${MPIRUN} -n ${mpiprocs} ${init_exe}"
printf "${cmd}\n"
${MPIRUN} -n ${mpiprocs} ${init_exe}

##################################################################################
# Run time error check
##################################################################################
error="$?"
printf "init_atmosphere exited with code ${error}.\n"

# save mpas_ic logs
log_dir=init_atmosphere_ic_log.${now}
mkdir ${log_dir}
cmd="mv log.init_atmosphere.* ${log_dir}"
printf "${cmd}\n"; eval "${cmd}"

cmd="mv namelist.init_atmosphere ${log_dir}"
printf "${cmd}\n"; eval "${cmd}"

cmd="mv streams.init_atmosphere ${log_dir}"
printf "${cmd}\n"; eval "${cmd}"

if [[ ${IF_ZETA_LIST} = ${YES} ]]; then
  cmd="mv `basename ${zeta_list}` ${log_dir}"
  printf "${cmd}\n"; eval "${cmd}"
fi

# Remove links to the init_atmos run files
for file in ${mpas_files[@]}; do
  cmd="rm -f `basename ${file}`"
  printf "${cmd}\n"; eval "${cmd}"
done

# remove links to ungrib data
filename="${BKG_DATA}:`date +%Y-%m-%d_%H -d "${strt_dt} 0 hours"`"
cmd="rm -f ${filename}"
printf "${cmd}\n"; eval "${cmd}"

# remove links to static and partition data
cmd="rm -f *.static.nc"
printf "${cmd}\n"; eval "${cmd}"

cmd="rm -f *.graph.info.part.*"
printf "${cmd}\n"; eval "${cmd}"

if [ ${error} -ne 0 ]; then
  printf "ERROR:\n ${init_exe}\n exited with status ${error}.\n"
  exit ${error}
fi

# Check to see if init_atmosphere outputs are generated
out_name=${cfg_nme}.init.nc
if [ ! -s "${out_name}" ]; then
  printf "ERROR:\n ${init_exe}\n failed to complete writing ${out_name}.\n"
  exit 1
fi

printf "mpas_ic.sh completed successfully at `date +%Y-%m-%d_%H_%M_%S`.\n"

##################################################################################
# end

exit 0
