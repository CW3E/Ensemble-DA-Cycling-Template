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
# Make checks for atmosphere settings
##################################################################################
# Options below are defined in workflow variables
#
# EXP_NME      = Case study / config short name directory structure
# CFG_ROOT     = Root directory containing simulation settings
# MSH_NME      = MPAS mesh name used to call mesh file name patterns
# MEMID        = Ensemble ID index, 00 for control, i > 0 for perturbation
# STRT_DT      = Simulation start time in YYYYMMDDHH
# IF_DYN_LEN   = If to compute forecast length dynamically (Yes / No)
# FCST_HRS     = Total length of MPAS forecast simulation in HH, IF_DYN_LEN=No
# EXP_VRF      = Verfication time for calculating forecast hours, IF_DYN_LEN=Yes
# IF_RGNL      = Equals "Yes" or "No" if MPAS regional simulation is being run
# BKG_INT      = Interval of lbc input data in HH, required IF_RGNL = Yes
# DIAG_INT     = Interval at which diagnostic fields are output (HH)
# HIST_INT     = Interval at which model history fields are output (HH)
# SND_INT      = Interval at which soundings are made (HH)
# RSTRT_INT    = Interval at which model restart files are output (HH)
# IF_RSTRT     = If performing a restart run initialization (Yes / No)
# IF_DA        = If peforming DA (Yes - writes out necessary fields / No)
# IF_DA_CYC    = If performing DA cycling initialization (Yes / No)
# IF_IAU       = If performing incremental assimilation update (Yes / No)
# IF_SST_UPDT  = If updating SST with lower BC update files
# IF_SST_DIURN = If updating SST with diurnal cycling
# IF_DEEPSOIL  = If slowly updating lower boundary deep soil temperature
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
  printf "Running atmosphere_model for ensemble member ${MEMID}.\n"
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

# define the end time based on forecast length control flow above
stop_dt=`date -d "${strt_dt} ${fcst_hrs} hours"`

if [[ ${IF_RGNL} = ${NO} ]]; then 
  printf "MPAS-A is run as a global simulation.\n"
  if_rgnl="false"
  lbc_int="none"

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
  else
    lbc_int="${BKG_INT}:00:00"
    printf "Lateral boundary conditions are read on ${lbc_int} intervals.\n"
  fi
else
  printf "\${IF_RGNL} must be set to 'Yes' or 'No' (case insensitive).\n"
  exit 1
fi

if [ ! ${DIAG_INT} ]; then
  printf "ERROR: \${DIAG_INT} is not defined.\n"
  exit 1
elif [ ${DIAG_INT} -lt 0 ]; then
  printf "ERROR: \${DIAG_INT} must be HH >= 0 for the frequency of diagnostics.\n"
  exit 1
elif [ ${DIAG_INT} = 00 ]; then
  printf "Model diagnostic fields are suppressed.\n"
  diag_int="none"
else
  diag_int="${DIAG_INT}:00:00"
  printf "Model diagnostics are written out on ${diag_int} intervals.\n"
fi

if [ ! ${HIST_INT} ]; then
  printf "ERROR: \${HIST_INT} is not defined.\n"
  exit 1
elif [ ${HIST_INT} -lt 0 ]; then
  printf "ERROR: \${HIST_INT} must be HH >= 0 for the frequency of model history.\n"
  exit 1
elif [ ${HIST_INT} = 00 ]; then
  printf "Model history outputs are suppressed.\n"
  hist_int="none"
else
  hist_int="${HIST_INT}:00:00"
  printf "Model history is written out on ${hist_int} intervals.\n"
fi

if [ ! ${SND_INT} ]; then
  printf "ERROR: \${SND_INT} is not defined.\n"
  exit 1
elif [ ${SND_INT} -lt 0 ]; then
  printf "ERROR: \${SND_INT} must be HH >= 0 for the frequency of soundings.\n"
  exit 1
elif [ ${SND_INT} = 00 ]; then
  printf "Model sounding are suppressed.\n"
  snd_int="none"
else
  snd_int="${SND_INT}:00:00"
  printf "Soundings are written on ${snd_int} intervals.\n"
fi

if [ ! ${RSTRT_INT} ]; then
  printf "ERROR: \${RSTRT_INT} is not defined.\n"
  exit 1
elif [ ${RSTRT_INT} -lt 0 ]; then
  printf "ERROR: \${RSTRT_INT} must be HH >= 0 for the frequency of data inputs.\n"
  exit 1
elif [ ${RSTRT_INT} = 00 ]; then
  printf "Model restart files are suppressed.\n"
  rstrt_int="none"
else
  rstrt_int="${RSTRT_INT}:00:00"
  printf "Restart files are written on ${rstrt_int} intervals.\n"
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
  if_dacyc="false"
  if_iau="off"

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

if [[ ${IF_SST_UPDT} = ${NO} ]]; then 
  printf "MPAS-A uses static lower boundary conditions.\n"
  if_sst_updt="false"
  if_sst_diurn="false"
  if_deepsoil="false"
  sfc_int="none"

elif [[ ${IF_SST_UPDT} = ${YES} ]]; then
  printf "MPAS-A updates lower boundary conditions.\n"
  if_sst_updt="true"

  # check that interval for background surface data is defined
  if [ ! ${BKG_INT} ]; then
    printf "ERROR: \${BKG_INT} is not defined.\n"
    exit 1
  elif [ ${BKG_INT} -le 0 ]; then
    printf "ERROR: \${BKG_INT} must be HH > 0 for the frequency of data inputs.\n"
    exit 1
  else
    sfc_int="${BKG_INT}:00:00"

  fi

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
  printf "\${IF_SST_UPDT} must be set to 'Yes' or 'No' (case insensitive).\n"
  exit 1
fi

##################################################################################
# Define atmosphere workflow dependencies
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
  msg+=" of nodes to run atmosphere_model > 0.\n"
  printf "${msg}"
  exit 1
fi

if [ ! ${N_PROC} ]; then
  printf "ERROR: \${N_PROC} is not defined.\n"
  exit 1
elif [ ${N_PROC} -le 0 ]; then
  msg="ERROR: The variable \${N_PROC} must be set to the number"
  msg+=" of processes-per-node to run atmosphere_model > 0.\n"
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
# Begin pre-atmosphere_model setup
##################################################################################
# The following paths are relative to workflow root paths
#
# ic_root    = Directory from which initial condition data is sourced
# sfc_root   = Directory from which surface update data is sourced
# lbc_root   = Directory from which lateral boundary data is sourced
# work_root  = Work directory where atmosphere_model runs and outputs
# mpas_files = All file contents of clean MPAS build directory
# atmos_exe  = Path and name of working executable
# phys_files = All files from WRF physics directory, incl Thompson MP
#
##################################################################################
# Create work root and change directory
work_root=${CYC_HME}/atmosphere_model/ens_${memid}
cmd="mkdir -p ${work_root}; cd ${work_root}"
printf "${cmd}\n"; eval "${cmd}"

# check that the atmosphere_model executable exists and can be run
atmos_exe=${MPAS_ROOT}/atmosphere_model
if [ ! -x ${atmos_exe} ]; then
  printf "ERROR:\n ${atmos_exe}\n does not exist, or is not executable.\n"
  exit 1
fi

# Make links to the model run files
mpas_files=(${MPAS_ROOT}/*)
for run_f in ${mpas_files[@]}; do
  cmd="ln -sf ${run_f} ."
  printf "${cmd}\n"; eval "${cmd}"
done

# Make links to the model physics files
phys_files=(${MPAS_ROOT}/src/core_atmosphere/physics/physics_wrf/files/*)
for phys_f in ${phys_files[@]}; do
  cmd="ln -sf ${phys_f} ."
  printf "${cmd}\n"; eval "${cmd}"
done

# Remove any mpas init files following ${cfg_nme}.init.nc pattern
cmd="rm -f *.init.nc"
printf "${cmd}\n"; eval "${cmd}"

# Remove any mpas partition files following ${cfg_nme}.graph.info.part.* pattern
cmd="rm -f *.graph.info.part.*"
printf "${cmd}\n"; eval "${cmd}"

# Remove any previous namelists and stream lists
cmd="rm -f namelist.*; rm -f streams.*; rm -f stream_list.*"
printf "${cmd}\n"; eval "${cmd}"

# Remove any previous lateral boundary condition files ${cfg_nme}.lbc.*.nc
cmd="rm -f *.lbc.*.nc"
printf "${cmd}\n"; eval "${cmd}"

# Remove pre-existing model run outputs
cmd="rm -f *.history.*"
printf "${cmd}\n"; eval "${cmd}"

cmd="rm -f *.diag.*"
printf "${cmd}\n"; eval "${cmd}"

cmd="rm -f *.restart.*"
printf "${cmd}\n"; eval "${cmd}"

cmd="rm -f *.snd.*"
printf "${cmd}\n"; eval "${cmd}"

# Move existing log files to a subdir if there are any
printf "Checking for pre-existing log files.\n"
if [ -f log.atmosphere.0000.out ]; then
  logdir=atmosphere_model_log.`ls -l --time-style=+%Y-%m-%d_%H_%M%_S log.atmosphere.0000.out | cut -d" " -f 6`
  mkdir ${logdir}
  printf "Moving pre-existing log files to ${logdir}.\n"
  cmd="mv log.* ${logdir}"
  printf "${cmd}\n"; eval "${cmd}"
else
  printf "No pre-existing log files were found.\n"
fi

# Define list of preprocessed data and make links
ic_root=${CYC_HME}/init_atmosphere_ic/ens_${memid}
input_files=( "${ic_root}/${cfg_nme}.init.nc" )

if [[ ${IF_SST_UPDT} = ${YES} ]]; then
  sfc_root=${CYC_HME}/init_atmosphere_sfc/ens_${memid}
  input_files+=( "${sfc_root}/${cfg_nme}.sfc_update.nc" )
fi

if [[ ${IF_RGNL} = ${YES} ]]; then 
  # define a sequence of all forecast hours with background interval spacing
  bkg_seq=`seq -f "%03g" 0 ${BKG_INT} ${fcst_hrs}`
  for fcst in ${fcst_seq[@]}; do
    lbc_time="`date +%Y-%m-%d_%H_%M_%S -d "${strt_dt} ${fcst} hours"`"
    input_files+=( "${lbs_root}/${DMN}.lbc.${lbc_time}.nc" )
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
# NOTE: ${mpiprocs} must match the number of MPI processes
graph_part=${CFG_ROOT}/static_files/${MSH_NME}.graph.info.part.${mpiprocs}
if [ ! -r "${graph_part}" ]; then
  printf "ERROR: Input file\n ${graph_part}\n is missing.\n"
  exit 1
else
  cmd="ln -sf ${graph_part} ."
  printf "${cmd}\n"; eval "${cmd}"
fi

##################################################################################
#  Build atmosphere namelist
##################################################################################
# Copy the atmosphere namelist / streams templates,
# NOTE: THESE WILL BE MODIFIED DO NOT LINK TO THEM
namelist_tmp=${cfg_dir}/namelists/namelist.atmosphere
streams_tmp=${cfg_dir}/namelists/streams.atmosphere
if [ ! -r ${namelist_tmp} ]; then 
  msg="atmosphere namelist template\n ${namelist_tmp}\n is not readable or "
  msg+="does not exist.\n"
  printf "${msg}"
  exit 1
else
  cmd="cp -L ${namelist_tmp} ./namelist.atmosphere"
  printf "${cmd}\n"; eval "${cmd}"
fi

if [ ! -r ${streams_tmp} ]; then 
  msg="atmosphere streams template\n ${streams_tmp}\n is not readable or "
  msg+="does not exist.\n"
  printf "${msg}"
  exit 1
else
  cmd="cp -L ${streams_tmp} ./streams.atmosphere"
  printf "${cmd}\n"; eval "${cmd}"
fi

streamlist_out_tmp=${cfg_dir}/namelists/stream_list.atmosphere.output
if [ ! -r ${streamlist_out_tmp} ]; then 
  msg="atmosphere stream_list.atmosphere.output\n ${streamlist_out_tmp}\n"
  msg+=" is not readable or does not exist.\n"
  printf "${msg}"
  exit 1
else
  cmd="cp -L ${streamlist_out_tmp} ./stream_list.atmosphere.output"
  printf "${cmd}\n"; eval "${cmd}"
fi

streamlist_sfc_tmp=${cfg_dir}/namelists/stream_list.atmosphere.surface
if [ ! -r ${streamlist_sfc_tmp} ]; then 
  msg="atmosphere stream_list.atmosphere.surface\n ${streamlist_sfc_tmp}\n"
  msg+=" is not readable or does not exist.\n"
  printf "${msg}"
  exit 1
else
  cmd="cp -L ${streamlist_sfc_tmp} ./stream_list.atmosphere.surface"
  printf "${cmd}\n"; eval "${cmd}"
fi

streamlist_diag_tmp=${cfg_dir}/namelists/stream_list.atmosphere.diagnostics
if [ ! -r ${streamlist_diag_tmp} ]; then 
  msg="atmosphere stream_list.atmosphere.diagnostics\n ${streamlist_diag_tmp}\n"
  msg+=" is not readable or does not exist.\n"
  printf "${msg}"
  exit 1
else
  cmd="cp -L ${streamlist_diag_tmp} ./stream_list.atmosphere.diagnostics"
  printf "${cmd}\n"; eval "${cmd}"
fi

# define start / end time patterns for namelist.atmosphere
strt_iso=`date +%Y-%m-%d_%H:%M:%S -d "${strt_dt}"`
stop_iso=`date +%Y-%m-%d_%H:%M:%S -d "${stop_dt}"`

# Update background data interval in namelist
data_interval_sec=$(( ${BKG_INT} * 3600 ))

# Update the atmosphere namelist / streams for surface boundary conditions
cat namelist.atmosphere \
  | sed "s/= STRT_DT,/= '${strt_iso}'/" \
  | sed "s/= FCST_HRS,/= '${fcst_hrs}:00:00'/" \
  | sed "s/= IF_RGNL,/= ${if_rgnl}/" \
  | sed "s/= IF_RSTRT,/= ${if_rstrt}/" \
  | sed "s/= IF_DA,/= ${if_da}/" \
  | sed "s/= IF_IAU,/= '${if_iau}'/" \
  | sed "s/= IF_DACYC,/= ${if_dacyc}/" \
  | sed "s/= IF_SST_UPDT,/= ${if_sst_updt}/" \
  | sed "s/= IF_SST_DIURN,/= ${if_sst_diurn}/" \
  | sed "s/= IF_DEEPSOIL,/= ${if_deepsoil}/" \
  | sed "s/= SND_INT,/= '${snd_int}'/" \
  | sed "s/= PIO_NUM,/= ${PIO_NUM}/" \
  | sed "s/= PIO_STRD,/= ${PIO_STRD}/" \
  | sed "s/MSH_NME/${MSH_NME}/" \
  > namelist.atmosphere.tmp
mv namelist.atmosphere.tmp namelist.atmosphere

cat streams.atmosphere \
  | sed "s/CFG_NME/${CFG_NME}/" \
  | sed "s/=RSTRT_INT,/=\"${rstrt_int}\"/" \
  | sed "s/=HIST_INT,/=\"${hist_int}\"/" \
  | sed "s/=DIAG_INT,/=\"${diag_int}\"/" \
  | sed "s/=SFC_INT,/=\"${sfc_int}\"/" \
  | sed "s/=LBC_INT,/=\"${lbc_int}\"/" \
  > streams.atmosphere.tmp
mv streams.atmosphere.tmp streams.atmosphere

##################################################################################
# Run atmosphere
##################################################################################
# Print run parameters
printf "\n"
printf "EXP_NME = ${EXP_NME}\n"
printf "MSH_NME = ${MSH_NME}\n"
printf "MEMID   = ${MEMID}\n"
printf "CYC_HME = ${CYC_HME}\n"
printf "STRT_DT = ${strt_iso}\n"
printf "STOP_DT = ${stop_iso}\n"
printf "BKG_INT = ${BKG_INT}\n"
printf "\n"
now=`date +%Y-%m-%d_%H_%M_%S`
printf "atmosphere_model started at ${now}.\n"
cmd="${MPIRUN} -n ${mpiprocs} ${atmos_exe}"
printf "${cmd}\n"
${MPIRUN} -n ${mpiprocs} ${atmos_exe}

##################################################################################
# Run time error check
##################################################################################
error="$?"
printf "atmosphere_model exited with code ${error}.\n"

# save mpas_model logs
log_dir=atmosphere_model_log.${now}
mkdir ${log_dir}
cmd="mv log.* ${log_dir}"
printf "${cmd}\n"; eval "${cmd}"

cmd="mv namelist.atmosphere ${log_dir}"
printf "${cmd}\n"; eval "${cmd}"

cmd="mv streams.atmosphere ${log_dir}"
printf "${cmd}\n"; eval "${cmd}"

cmd="mv stream_list.* ${log_dir}"
printf "${cmd}\n"; eval "${cmd}"

# Remove links to the model run files
for run_f in ${mpas_files[@]}; do
  cmd="rm -f `basename ${run_f}`"
  printf "${cmd}\n"; eval "${cmd}"
done

# Remove links to the model physics files
for phys_f in ${phys_files[@]}; do
  cmd="rm -f `basename ${phys_f}`"
  printf "${cmd}\n"; eval "${cmd}"
done

# remove links to input files
for input_f in ${input_files[@]}; do
  cmd="rm -f `basename ${input_f}`"
  printf "${cmd}\n"; eval "${cmd}"
done

# remove links to partition data
cmd="rm -f *.graph.info.part.*"
printf "${cmd}\n"; eval "${cmd}"

if [ ${error} -ne 0 ]; then
  printf "ERROR:\n ${atmos_exe}\n exited with status ${error}.\n"
  exit ${error}
fi

if [ ! ${HIST_INT} = 00 ]; then
  # verify all history outputs
  hist_seq=`seq -f "%03g" 0 ${HIST_INT} ${fcst_hrs}`
  
  for hist in ${hist_seq[@]}; do
    filename="${cfg_nme}.history.`date +%Y-%m-%d_%H_%M_%S -d "${strt_dt} ${hist} hours"`.nc"
    if [ ! -s ${filename} ]; then
      printf "ERROR: ${filename} is missing.\n"
      exit 1
    fi
  done
fi

if [ ! ${DIAG_INT} = 00 ]; then
  # verify all diagnostic outputs
  diag_seq=`seq -f "%03g" 0 ${DIAG_INT} ${fcst_hrs}`
  
  for diag in ${diag_seq[@]}; do
    filename="${cfg_nme}.diag.`date +%Y-%m-%d_%H_%M_%S -d "${strt_dt} ${diag} hours"`.nc"
    if [ ! -s ${filename} ]; then
      printf "ERROR: ${filename} is missing.\n"
      exit 1
    fi
  done
fi

if [ ! ${RSTRT_INT} = 00 ]; then
  # verify all diagnostic outputs
  rstrt_seq=`seq -f "%03g" ${RSTRT_INT} ${RSTRT_INT} ${fcst_hrs}`
  
  for rstrt in ${rstrt_seq[@]}; do
    filename="${cfg_nme}.restart.`date +%Y-%m-%d_%H_%M_%S -d "${strt_dt} ${rstrt} hours"`.nc"
    if [ ! -s ${filename} ]; then
      printf "ERROR: ${filename} is missing.\n"
      exit 1
    fi
  done
fi

# NOTE: Sounding is still experimental in the workflow, this is just a place holder
if [ ! ${SND_INT} = 00 ]; then
  # verify all sounding outputs
  snd_seq=`seq -f "%03g" 0 ${SND_INT} ${fcst_hrs}`
  
  for snd in ${snd_seq[@]}; do
    filename="${cfg_nme}.snd.`date +%Y-%m-%d_%H_%M_%S -d "${strt_dt} ${snd} hours"`.nc"
    if [ ! -s ${filename} ]; then
      printf "ERROR: ${filename} is missing.\n"
      exit 1
    fi
  done
fi

printf "mpas_model.sh completed successfully at `date +%Y-%m-%d_%H_%M_%S`.\n"

##################################################################################
# end

exit 0
