#!/bin/bash
#####################################################
# Description
#####################################################
# This driver script is a major fork and rewrite of the standard GSI.ksh
# driver script for the GSI tutorial
# https://dtcenter.ucar.edu/com-GSI/users/tutorial/online_tutorial/index_v3.7.php
#
# The purpose of this fork is to work in a Rocoto-based
# Observation-Analysis-Forecast cycle with WRF for data denial
# experiments. Naming conventions in this script have been smoothed
# to match a companion major fork of the wrf.ksh
# WRF driver script of Christopher Harrop.
#
# One should write machine specific options for the GSI environment
# in a GSI_constants.sh script to be sourced in the below.  Variables
# aliases in this script are based on conventions defined in the
# companion GSI_constants.sh with this driver.
#
# SEE THE README FOR FURTHER INFORMATION
#
#####################################################
# License Statement:
#####################################################
# Copyright 2022 Colin Grudzien, cgrudzien@ucsd.edu
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
#####################################################
# Preamble
#####################################################
# Options below are hard-coded based on the type of experiment
# (i.e., these not expected to change within DA cycles).
#
# bk_core     = Which WRF core is used as background (NMM or ARW or NMMB)
# bkcv_option = Which background error covariance and parameter will be used
#              (GLOBAL or NAM)
#
# if_clean    = clean  : delete temporal files in working directory (default)
#               no     : leave running directory as is (this is for debug only)
# byte_order  = Big_Endian or Little_Endian
# ens_prfx    = Prefix for the local links for ensemble member names of the form
#               ${ens_prfx}xxx
# grid_ratio  = 1 default, still testing option for dual resolution
# if_nemsio   = Yes   : The GFS background files are in NEMSIO format
# if_oneob    = Yes   : Do single observation test
#
#####################################################
# uncomment to run verbose for debugging / testing
set -x

bk_core=ARW
bkcv_option=NAM
if_clean=clean
byte_order=Big_Endian
ens_prfx=wrf_en
grid_ratio=1
if_nemsio=No
if_oneob=No

#####################################################
# Read in GSI constants for local environment
#####################################################

if [ ! -x "${CONSTANT}" ]; then
  echo "ERROR: \$CONSTANT does not exist or is not executable!"
  exit 1
fi

. ${CONSTANT}

#####################################################
# Make checks for DA method settings
#####################################################
# Options below are defined in cycling.xml (case insensitive)
#
# WRF_CTR_DOM       = INT : GSI analyzes the control domain d0${dmn} for 
#                           dmn -le ${WRF_CTR_DOM}
# WRF_ENS_DOM       = INT : GSI utilizes ensemble perturbatiosn on d0${dmn}
#                           for dmn -le ${WRF_ENS_DOM}
# IF_CTR_COLD_START = Yes : GSI analyzes wrfinput control file instead
#                           of wrfout control file
# IF_ENS_COLD_START = Yes : GSI uses ensemble perturbations from wrfinput files
#                           instead of wrfout files
# IF_SATRAD         = Yes : GSI uses satellite radiances, gpsro and radar data
#                           in addition to conventional data from prepbufr
#                     No  : GSI uses conventional data alone
#
# IF_HYBRID         = Yes : Run GSI as 3D/4D EnVAR
# IF_OBSERVER       = Yes : Only used as observation operator for EnKF
# N_ENS             = INT : Max ensemble index (00 for control alone)
#                           NOTE this must be set when `IF_HYBRID=Yes` and
#                           when `IF_OBSERVER=Yes`
# MAX_BC_LOOP       = INT : Maximum number of times to iteratively generate
#                           variational bias correction files, loop zero starts
#                           with GDAS defaults
# IF_4DENVAR        = Yes : Run GSI as 4D EnVar
#
#####################################################

if [ ! ${WRF_CTR_DOM} ]; then
  echo "ERROR: \$WRF_CTR_DOM is not defined!"
  exit 1
fi

if [ ! ${WRF_ENS_DOM} ]; then
  echo "ERROR: \$WRF_ENS_DOM is not defined!"
  exit 1
fi

if [[ ${IF_CTR_COLD_START} != ${YES} && ${IF_CTR_COLD_START} != ${NO} ]]; then
  echo "ERROR: \$IF_CTR_COLD_START must equal 'Yes' or 'No' (case insensitive)"
  exit 1
fi

if [[ ${IF_ENS_COLD_START} != ${YES} && ${IF_ENS_COLD_START} != ${NO} ]]; then
  echo "ERROR: \$IF_ENS_COLD_START must equal 'Yes' or 'No' (case insensitive)"
  exit 1
fi

if [[ ${IF_SATRAD} != ${YES} && ${IF_SATRAD} != ${NO} ]]; then
  echo "ERROR: \$IF_SATRAD must equal 'Yes' or 'No' (case insensitive)"
  exit 1
fi

if [[ ${IF_OBSERVER} != ${YES} && ${IF_OBSERVER} != ${NO} ]]; then
  echo "ERROR: \$IF_OBSERVER must equal 'Yes' or 'No' (case insensitive)"
  exit 1
fi

if [[ ${IF_HYBRID} = ${YES} ]]; then
  # ensembles are required for hybrid EnVAR
  if [ ! "${N_ENS}" ]; then
    echo "ERROR: \$N_ENS must be specified to the number of ensemble perturbations!"
    exit 1
  fi
  if [ ${N_ENS} -lt 3 ]; then
    echo "ERROR: \$N_ENS must be three or greater!"
    exit 1
  fi
  echo "GSI performs hybrid ensemble variational DA with ensemble size ${N_ENS}"
  ifhyb='.true.'
elif [[ ${IF_HYBRID} = ${NO} ]]; then
  echo "GSI performs variational DA without ensemble"
  ifhyb='.false.'
else
  echo "ERROR: \$IF_HYBRID must equal 'Yes' or 'No' (case insensitive)"
  exit 1
fi

if [[ ${IF_OBSERVER} = ${YES} ]]; then
  if [[ ! ${IF_HYBRID} = ${YES} ]]; then
    echo "ERROR: \$IF_HYBRID must equal Yes if \$IF_OBSERVER = Yes"
    exit 1
  fi
fi

if [ ! "${MAX_BC_LOOP}" ]; then
  echo "ERROR: \$MAX_BC_LOOP must be specified to the number of variational bias correction iterations!"
  exit 1
  if [ ${MAX_BC_LOOP} -lt 0 ]; then
    echo "ERROR: the number of iterations of variational bias correction must be non-negative!"
    exit 1
  fi
fi

if [[ ${IF_4DENVAR} = ${YES} ]]; then
  if [[ ! ${IF_HYBRID} = ${YES} ]]; then
    echo "ERROR: \$IF_HYBRID must equal Yes if \$IF_4DENVAR = Yes"
    exit 1
  else
    echo "GSI performs 4D hybrid ensemble variational DA"
    if4d='.true.'
  fi
elif [[ ${IF_4DENVAR} = ${NO} ]]; then
    if4d='.false.'
else
  echo "ERROR: \$IF_4DENVAR must equal 'Yes' or 'No' (case insensitive)"
  exit 1
fi

if [[ ${if_nemsio} = ${YES} ]]; then
  if_gfs_nemsio='.true.'
elif [[ ${if_nemsio} = ${NO} ]]; then 
  if_gfs_nemsio='.false.'
else
  echo "ERROR: \$if_nemsio must equal 'Yes' or 'No' (case insensitive)"
  exit 1
fi

if [[ ${if_oneob} = ${YES} ]]; then
  echo "GSI performs single observation test"
  if_oneobtest='.true.'
elif [[ ${if_oneob} = ${NO} ]]; then
  if_oneobtest='.false.'
else
  echo "ERROR: \$if_oneob must equal 'Yes' or 'No' (case insensitive)"
  exit 1
fi

#####################################################
# Define GSI workflow dependencies
#####################################################
# Below variables are defined in cycling.xml workflow variables
#
# ANL_TIME       = Analysis time YYYYMMDDHH
# GSI_ROOT       = Directory for clean GSI build
# CRTM_VERSION   = Version number of CRTM to specify path to binaries
# STATIC_DATA    = Root directory containing sub-directories for constants,
#                  namelists grib data, geogrid data, obs tar files etc.
# INPUT_DATAROOT = Analysis time named directory for input data, containing
#                  subdirectories bkg, wpsprd, realprd, wrfprd, wrfdaprd, gsiprd
# MPIRUN         = MPI Command to execute GSI
# GSI_PROC       = Number of workers for MPI command to exectute on
#
# Below variables are derived by cycling.xml variables for convenience
#
# date_str       = Defined by the ANL_TIME variable, to be used as path
#                  name variable in YYYY-MM-DD_HH:MM:SS format for wrfout
#
#####################################################

if [ ! "${ANL_TIME}" ]; then
  echo "ERROR: \$ANL_TIME is not defined!"
  exit 1
fi

if [ `echo "${ANL_TIME}" | awk '/^[[:digit:]]{10}$/'` ]; then
  # Define directory path name variable date_str=YYMMDDHH from ANL_TIME
  hh=`echo ${ANL_TIME} | cut -c9-10`
  anl_date=`echo ${ANL_TIME} | cut -c1-8`
  date_str=`date +%Y-%m-%d_%H:%M:%S -d "${anl_date} ${hh} hours"`
else
  echo "ERROR: start time, '${ANL_TIME}', is not in 'yyyymmddhh' or 'yyyymmdd hh' format"
  exit 1
fi

if [ -z "${date_str}"]; then
  echo "ERROR: \$date_str is not defined correctly, check format of \$ANL_TIME!"
  exit 1
fi

if [ ! "${GSI_ROOT}" ]; then
  echo "ERROR: \$GSI_ROOT is not defined!"
  exit 1
fi

if [ -z "${CRTM_VERSION}" ]; then
  echo "ERROR: The variable \$CRTM_VERSION must be set to version number for specifying binary path!"
  exit 1
fi

if [ ! ${STATIC_DATA} ]; then
  echo "ERROR: \$STATIC_DATA is not defined!"
  exit 1
fi

if [ ! -d ${STATIC_DATA} ]; then
  echo "ERROR: \$STATIC_DATA directory ${STATIC_DATA} does not exist"
  exit 1
fi

if [ ! "${INPUT_DATAROOT}" ]; then
  echo "ERROR: \$INPUT_DATAROOT is not defined!"
  exit 1
fi

if [ ! "${MPIRUN}" ]; then
  echo "ERROR: \$MPIRUN is not defined!"
  exit 1
fi

if [ ! "${GSI_PROC}" ]; then
  echo "ERROR: \$GSI_PROC is not defined"
  exit 1
fi

if [ -z "${GSI_PROC}" ]; then
  echo "ERROR: The variable \$GSI_PROC must be set to the number of processors to run GSI"
  exit 1
fi

#####################################################
# The following paths are relative to cycling.xml supplied root paths
#
# work_root    = Working directory where GSI runs, either to analyze the control or to be the observer for EnKF
# bkg_root     = Path for root directory of control from WRFDA or real depending on cycling
# obs_root     = Path of observations files
# fix_root     = Path of fix files
# gsi_exe      = Path and name of the gsi.x executable
# gsi_namelist = Path and name of the gsi namelist constructor script
# crtm_root    = Path of the CRTM root directory, contained in GSI_ROOT
# prepbufr     = Path of PreBUFR conventional obs
#
#####################################################

if [[ ${IF_OBSERVER} = ${NO} ]]; then
  echo "GSI updates control forecast"
  nummiter=2
  if_read_obs_save='.false.'
  if_read_obs_skip='.false.'
  work_root=${INPUT_DATAROOT}/gsiprd
  max_dom=${WRF_CTR_DOM}
else
  echo "GSI is observer for EnKF ensemble"
  nummiter=0
  if_read_obs_save='.true.'
  if_read_obs_skip='.false.'
  work_root=${INPUT_DATAROOT}/enkfprd
  max_dom=${WRF_ENS_DOM}
fi

if [[ ${IF_CTR_COLD_START} = ${NO} ]]; then
  # NOTE: the background files are taken from the WRFDA outputs when cycling, having updated the lower BCs
  bkg_root=${INPUT_DATAROOT}/wrfdaprd
else
  # otherwise, the background files are take from wrfinput generated by real.exe
  bkg_root=${INPUT_DATAROOT}/realprd
fi

obs_root=${STATIC_DATA}/obs_data
fix_root=${GSI_ROOT}/fix
gsi_exe=${GSI_ROOT}/build/bin/gsi.x
gsi_namelist=${STATIC_DATA}/namelists/comgsi_namelist.sh
crtm_root=${GSI_ROOT}/CRTM_v${CRTM_VERSION}
prepbufr_tar=${obs_root}/prepbufr.${anl_date}.nr.tar.gz
prepbufr_dir=${obs_root}/${anl_date}.nr
prepbufr=${prepbufr_dir}/prepbufr.gdas.${anl_date}.t${hh}z.nr

if [ ! -d "${obs_root}" ]; then
  echo "ERROR: obs_root directory '${obs_root}' does not exist!"
  exit 1
fi

if [ ! -d "${bkg_root}" ]; then
  echo "ERROR: \$bkg_root directory '${bkg_root}' does not exist!"
  exit 1
fi

if [ ! -d "${fix_root}" ]; then
  echo "ERROR: FIX directory '${fix_root}' does not exist!"
  exit 1
fi

if [ ! -x "${gsi_exe}" ]; then
  echo "ERROR: ${gsi_exe} does not exist!"
  exit 1
fi

if [ ! -x "${gsi_namelist}" ]; then
  echo "ERROR: ${gsi_namelist} does not exist!"
  exit 1
fi

if [ ! -d "${crtm_root}" ]; then
  echo "ERROR: CRTM directory '${crtm_root}' does not exist!"
  exit 1
fi

if [ ! -r "${prepbufr_tar}" ]; then
  echo "ERROR: file '${prepbufr_tar}' does not exist!"
  exit 1
else
  # untar prepbufr data to predefined directory
  # define prepbufr directory
  mkdir -p ${prepbufr_dir}
  tar -xvf ${prepbufr_tar} -C ${prepbufr_dir}

  # unpack nested directory structure
  prepbufr_nest=(`find ${prepbufr_dir} -type f`)
  nest_indx=0
  while [ ${nest_indx} -le ${#prepbufr_nest[@]} ]; do
    mv ${prepbufr_nest[${nest_indx}]} ${prepbufr_dir}
    (( nest_indx += 1))
  done
  rmdir ${prepbufr_dir}/*

  if [ ! -r "${prepbufr}" ]; then
    echo "ERROR: file '${prepbufr}' does not exist!"
    exit 1
  fi
fi

#####################################################
# Begin pre-GSI setup, running one domain at a time
#####################################################
# Create the work directory organized by domain analyzed and cd into it
dmn=1

while [ ${dmn} -le ${max_dom} ]; do
  # each domain will generated a variational bias correction file iteratively starting with GDAS defaults
  bc_loop=0

  # NOTE: Hybrid DA uses the control forecast as the EnKF forecast mean, not the control analysis 
  # work directory for GSI is sub-divided based on domain index
  dmndir=${work_root}/d0${dmn}
  echo " Create work root directory:" ${workdir}

  if [ -d "${dmndir}" ]; then
    rm -rf ${dmndir}
  fi
  mkdir -p ${dmndir}

  while [ ${bc_loop} -le ${MAX_BC_LOOP} ]; do

    cd ${dmndir}
    if [ ${bc_loop} -ne ${MAX_BC_LOOP} ]; then
      # create storage for the outputs indexed on bc_loop except for final loop
      workdir=${dmndir}/bc_loop_${bc_loop}
      mkdir ${workdir}
      cd ${workdir}
    else
      workdir=${dmndir}
    fi

    echo " Link observation bufr to working directory"

    # Link to the prepbufr conventional data
    ln -s ${prepbufr} ./prepbufr

    # Link to satellite data
    if [[ ${IF_SATRAD} = ${YES} ]] ; then
       srcobsfile=()
       gsiobsfile=()

       #srcobsfile+=("1bamua")
       #gsiobsfile+=("amsuabufr")

       #srcobsfile+=("1bamub")
       #gsiobsfile+=("amsubbufr")

       #srcobsfile+=("1bhrs4")
       #gsiobsfile+=("hirs4bufr")

       #srcobsfile+=("1bmhs")
       #gsiobsfile+=("mhsbufr")

       #srcobsfile+=("airsev")
       #gsiobsfile+=("airsbufr")

       #srcobsfile+=("amsr2")
       #gsiobsfile+=("amsrebufr")

       #srcobsfile+=("atms")
       #gsiobsfile+=("atmsbufr")

       #srcobsfile+=("esamua")
       #gsiobsfile+=("amsuabufrears")

       #srcobsfile+=("eshrs3")
       #gsiobsfile+=("hirs3bufrears")

       #srcobsfile+=("esmhs")
       #gsiobsfile+=("mhsbufrears")

       #srcobsfile+=("geoimr")
       #gsiobsfile+=("gimgrbufr")

       #srcobsfile+=("goesfv")
       #gsiobsfile+=("gsnd1bufr")

       #srcobsfile+=("gome")
       #gsiobsfile+=("gomebufr")

       srcobsfile+=("gpsro")
       gsiobsfile+=("gpsrobufr")

       #srcobsfile+=("lgycld")
       #gsiobsfile+=("larcglb")

       #srcobsfile+=("mtiasi")
       #gsiobsfile+=("iasibufr")

       #srcobsfile+=("nexrad")
       #gsiobsfile+=("l2rbufr")

       #srcobsfile+=("omi")
       #gsiobsfile+=("omibufr")

       #srcobsfile+=("osbuv8")
       #gsiobsfile+=("sbuvbufr")

       #srcobsfile+=("satwnd")
       #gsiobsfile+=("satwndbufr")

       #srcobsfile+=("ssmisu")
       #gsiobsfile+=("ssmirrbufr")

       #srcobsfile+=("sevcsr")
       #gsiobsfile+=("seviribufr")

       # loop over obs types
       len=${#srcobsfile[@]}
       ii=0

       while [[ ${ii} -lt ${len} ]]; do
          cd ${obs_root}
          tar_file=${obs_root}/${srcobsfile[$ii]}.${anl_date}.tar.gz
	  obs_dir=${obs_root}/${anl_date}.${srcobsfile[$ii]}
	  mkdir -p ${obs_dir}

          if [ -r "${tar_file}" ]; then
	    # untar to specified directory
            tar -xvf ${tar_file} -C ${obs_dir}

            # unpack nested directory structure, if exists
            obs_nest=(`find ${obs_dir} -type f`)
            nest_indx=0
            while [ ${nest_indx} -le ${#obs_nest[@]} ]; do
              mv ${obs_nest[${nest_indx}]} ${obs_dir}
              (( nest_indx += 1))
            done
            rmdir ${obs_dir}/*
	    # NOTE: differences in data file types for "satwnd"
            if [[ ${srcobsfile[$ii]} = "satwnd" ]]; then
              obs_file=${obs_dir}/gdas.${srcobsfile[$ii]}.t${hh}z.${anl_date}.txt
            else
              obs_file=${obs_dir}/gdas.${srcobsfile[$ii]}.t${hh}z.${anl_date}.bufr
            fi

            if [ -r "${obs_file}" ]; then
               echo "Link source obs file ${obs_file}"
               cd ${workdir}
               ln -sf ${obs_file} ./${gsiobsfile[$ii]}

            else
               echo "ERROR: obs file ${srcobsfile[$ii]} not found!"
               exit 1
            fi

          else
            echo "ERROR: file ${tar_file} not found!"
            exit 1
          fi

          cd ${workdir}
          (( ii += 1 ))
       done
    fi

    echo " Copy fix files and link CRTM coefficient files to working directory"

    #####################################################
    # Set fix files
    #
    #   berror    = Forecast model background error statistics
    #   specoef   = CRTM spectral coefficients
    #   trncoef   = CRTM transmittance coefficients
    #   emiscoef  = CRTM coefficients for IR sea surface emissivity model
    #   aerocoef  = CRTM coefficients for aerosol effects
    #   cldcoef   = CRTM coefficients for cloud effects
    #   satinfo   = Text file with information about assimilation of brightness temperatures
    #   satangl   = Angle dependent bias correction file (fixed in time)
    #   pcpinfo   = Text file with information about assimilation of prepcipitation rates
    #   ozinfo    = Text file with information about assimilation of ozone data
    #   errtable  = Text file with obs error for conventional data (regional only)
    #   convinfo  = Text file with information about assimilation of conventional data
    #   lightinfo = Text file with information about assimilation of GLM lightning data
    #   bufrtable = Text file ONLY needed for single obs test (oneobstest=.true.)
    #   bftab_sst = Bufr table for sst ONLY needed for sst retrieval (retrieval=.true.)
    #
    #####################################################

    if [ ${bkcv_option} = GLOBAL ] ; then
      echo ' Use global background error covariance'
      berror=${fix_root}/${byte_order}/nam_glb_berror.f77.gcv
      oberror=${fix_root}/prepobs_errtable.global
      if [ ${bk_core} = NMM ] ; then
         anavinfo=${fix_root}/anavinfo_ndas_netcdf_glbe
      fi
      if [ ${bk_core} = ARW ] ; then
        anavinfo=${fix_root}/anavinfo_arw_netcdf_glbe
      fi
      if [ ${bk_core} = NMMB ] ; then
        anavinfo=${fix_root}/anavinfo_nems_nmmb_glb
      fi
    else
      echo ' Use NAM background error covariance'
      berror=${fix_root}/${byte_order}/nam_nmmstat_na.gcv
      oberror=${fix_root}/nam_errtable.r3dv
      if [ ${bk_core} = NMM ] ; then
         anavinfo=${fix_root}/anavinfo_ndas_netcdf
      fi
      if [ ${bk_core} = ARW ] ; then
         anavinfo=${fix_root}/anavinfo_arw_netcdf
      fi
      if [ ${bk_core} = NMMB ] ; then
         anavinfo=${fix_root}/anavinfo_nems_nmmb
      fi
    fi

    satangl=${fix_root}/global_satangbias.txt
    satinfo=${fix_root}/global_satinfo.txt
    convinfo=${fix_root}/global_convinfo_profiler_ascat.txt
    ozinfo=${fix_root}/global_ozinfo.txt
    pcpinfo=${fix_root}/global_pcpinfo.txt
    lightinfo=${fix_root}/global_lightinfo.txt

    # copy Fixed fields to working directory
    cp ${anavinfo} anavinfo
    cp ${berror}   berror_stats
    cp ${satangl}  satbias_angle
    cp ${satinfo}  satinfo
    cp ${convinfo} convinfo
    cp ${ozinfo}   ozinfo
    cp ${pcpinfo}  pcpinfo
    cp ${lightinfo} lightinfo
    cp ${oberror}  errtable

    # CRTM Spectral and Transmittance coefficients
    crtm_root_order=${crtm_root}/${byte_order}
    emiscoef_IRwater=${crtm_root_order}/Nalli.IRwater.EmisCoeff.bin
    emiscoef_IRice=${crtm_root_order}/NPOESS.IRice.EmisCoeff.bin
    emiscoef_IRland=${crtm_root_order}/NPOESS.IRland.EmisCoeff.bin
    emiscoef_IRsnow=${crtm_root_order}/NPOESS.IRsnow.EmisCoeff.bin
    emiscoef_VISice=${crtm_root_order}/NPOESS.VISice.EmisCoeff.bin
    emiscoef_VISland=${crtm_root_order}/NPOESS.VISland.EmisCoeff.bin
    emiscoef_VISsnow=${crtm_root_order}/NPOESS.VISsnow.EmisCoeff.bin
    emiscoef_VISwater=${crtm_root_order}/NPOESS.VISwater.EmisCoeff.bin
    emiscoef_MWwater=${crtm_root_order}/FASTEM6.MWwater.EmisCoeff.bin
    aercoef=${crtm_root_order}/AerosolCoeff.bin
    cldcoef=${crtm_root_order}/CloudCoeff.bin

    ln -s ${emiscoef_IRwater} ./Nalli.IRwater.EmisCoeff.bin
    ln -s ${emiscoef_IRice} ./NPOESS.IRice.EmisCoeff.bin
    ln -s ${emiscoef_IRsnow} ./NPOESS.IRsnow.EmisCoeff.bin
    ln -s ${emiscoef_IRland} ./NPOESS.IRland.EmisCoeff.bin
    ln -s ${emiscoef_VISice} ./NPOESS.VISice.EmisCoeff.bin
    ln -s ${emiscoef_VISland} ./NPOESS.VISland.EmisCoeff.bin
    ln -s ${emiscoef_VISsnow} ./NPOESS.VISsnow.EmisCoeff.bin
    ln -s ${emiscoef_VISwater} ./NPOESS.VISwater.EmisCoeff.bin
    ln -s ${emiscoef_MWwater} ./FASTEM6.MWwater.EmisCoeff.bin
    ln -s ${aercoef}  ./AerosolCoeff.bin
    ln -s ${cldcoef}  ./CloudCoeff.bin

    # Copy CRTM coefficient files based on entries in satinfo file
    for file in `awk '{if($1!~"!"){print $1}}' ./satinfo | sort | uniq` ;do
       ln -s ${crtm_root_order}/${file}.SpcCoeff.bin ./
       ln -s ${crtm_root_order}/${file}.TauCoeff.bin ./
    done

    if [[ ${if_oneob} = ${YES} ]]; then
      # Only need this file for single obs test
      bufrtable=${fix_root}/prepobs_prep.bufrtable
      cp ${bufrtable} ./prepobs_prep.bufrtable
    fi

    if [ ${bc_loop} -eq 0 ]; then
      # first bias correction loop uses the combined bias correction files from GDAS
      tar_files=()
      tar_files+=(${obs_root}/abias.${anl_date}.tar.gz)
      tar_files+=(${obs_root}/abiaspc.${anl_date}.tar.gz)

      bias_dirs=()
      bias_dirs+=(${obs_root}/${anl_date}.abias)
      bias_dirs+=(${obs_root}/${anl_date}.abiaspc)

      bias_files=()
      bias_files+=(${obs_root}/${anl_date}.abias/gdas.abias.t${hh}z.${anl_date}.txt)
      bias_files+=(${obs_root}/${anl_date}.abiaspc/gdas.abiaspc.t${hh}z.${anl_date}.txt)

      bias_in_files=()
      bias_in_files+=(satbias_in)
      bias_in_files+=(satbias_pc_in)

      # loop over bias files
      len=${#tar_files[@]}
      ii=0

      while [[ ${ii} -lt ${len} ]]; do
	tar_file=${tar_files[$ii]}
	bias_dir=${bias_dirs[$ii]}
	bias_file=${bias_files[$ii]}
        if [ -r "${tar_file}" ]; then
	  # untar to specified directory
	  mkdir -p ${bias_dir}
          tar -xvf ${tar_file} -C ${bias_dir}

	  # unpack nested directory structure
	  bias_nest=(`find ${bias_dir} -type f`)
          nest_indx=0
          while [ ${nest_indx} -le ${#bias_nest[@]} ]; do
            mv ${bias_nest[${nest_indx}]} ${bias_dir}
            (( nest_indx += 1))
          done
	  rmdir ${bias_dir}/*

          if [ -r "${bias_file}" ]; then
            echo "Link the GDAS bias correction file ${bias_file} for loop zero of analysis"
            ln -sf ${bias_file} ./${bias_in_files[$ii]}
          else
            echo "GDAS bias correction file not readable at ${bias_file}"
            exit 1
          fi
        else
          echo "Tar ${tar_file} of GDAS bias corrections not readable"
            exit 1
        fi
	(( ii +=1 ))
      done
    else
      # use the bias correction file generated on the last GSI loop 
      bias_files=()
      (( lag_loop = ${bc_loop} - 1 ))
      bias_files+=(${dmndir}/bc_loop_${lag_loop}/satbias_out)
      bias_files+=(${dmndir}/bc_loop_${lag_loop}/satbias_pc.out)

      bias_in_files=()
      bias_in_files+=(satbias_in)
      bias_in_files+=(satbias_pc_in)

      # loop over bias files
      len=${#tar_files[@]}
      ii=0

      while [[ ${ii} -lt ${len} ]]; do
	bias_file=${bias_files[$ii]}
        if [ -r "${bias_file}" ]; then
          ln -sf ${bias_file} ./${bias_in_files[$ii]}
        else
          echo "Bias file ${bias_file} variational bias corrections not readable"
            exit 1
        fi
	(( ii +=1 ))
      done
    fi

    #####################################################
    # Prep GSI background 
    #####################################################
    # Below are defined depending on the ${dmn} -le ${max_dom}
    #
    # bkg_file = Path and name of background file
    #
    #####################################################

    if [[ ${IF_CTR_COLD_START} = ${NO} ]]; then
      bkg_file=${bkg_root}/ens_00/lower_bdy_update/wrfout_d0${dmn}_${date_str}
    else
      bkg_file=${bkg_root}/ens_00/wrfinput_d0${dmn}
    fi

    if [ ! -r "${bkg_file}" ]; then
      echo "ERROR: background file ${bkg_file} does not exist!"
      exit 1
    fi

    echo " Copy background file(s) to working directory"
    # Copy over background field -- THIS IS MODIFIED BY GSI DO NOT LINK TO IT
    cp ${bkg_file} ./wrf_inout

    # NOTE: THE FOLLOWING DIRECTORIES WILL NEED TO BE REVISED
    #if [[ ${IF_4DENVAR} = ${YES} ]] ; then
    # PDYa=`echo ${ANL_TIME} | cut -c1-8`
    # cyca=`echo ${ANL_TIME} | cut -c9-10`
    # gdate=`date -u -d "${PDYa} ${cyca} -6 hour" +%Y%m%d%H` #guess date is 6hr ago
    # gHH=`echo ${gdate} |cut -c9-10`
    # datem1=`date -u -d "${PDYa} ${cyca} -1 hour" +%Y-%m-%d_%H:%M:%S` #1hr ago
    # datep1=`date -u -d "${PDYa} ${cyca} 1 hour"  +%Y-%m-%d_%H:%M:%S`  #1hr later
    #  bkg_file_p1=${bkg_root}/wrfout_d0${dmn}_${datep1}
    #  bkg_file_m1=${bkg_root}/wrfout_d0${dmn}_${datem1}
    #fi

    #####################################################
    # Prep GSI ensemble 
    #####################################################

    if [[ ${IF_HYBRID} = ${YES} ]]; then

      if [[ ${IF_ENS_COLD_START} = ${NO} ]]; then
        # NOTE: the background files are taken from the WRFDA outputs when cycling, having updated the lower BCs
        ens_root=${INPUT_DATAROOT}/wrfdaprd
      else
        # otherwise, the background files are take from wrfinput generated by real.exe
        ens_root=${INPUT_DATAROOT}/realprd
      fi

      if [ ${dmn} -le ${WRF_ENS_DOM} ]; then
        # take ensemble generated by WRF members
        echo " Copy ensemble perturbations to working directory"
        ens_n=1

        while [ ${ens_n} -le ${N_ENS} ]; do
          # two zero padding for GEFS
          iimem=`printf %02d $(( 10#${ens_n} ))`

          # three zero padding for GSI
          iiimem=`printf %03d $(( 10#${ens_n} ))`

          if [[ ${IF_ENS_COLD_START} = ${NO} ]]; then
            ens_file=${ens_root}/ens_${iimem}/lower_bdy_update/wrfout_d0${dmn}_${date_str}
          else
            ens_file=${ens_root}/ens_${iimem}/wrfinput_d0${dmn}
          fi

          if [ ! -r "${ens_file}" ]; then
            echo "ERROR: ensemble file ${ens_file} does not exist!"
            exit 1
          else
            ln -sf ${ens_file} ./${ens_prfx}${iiimem}
          fi
          (( ens_n += 1 ))
        done

        ls ./${ens_prfx}* > filelist02

        # NOTE: THE FOLLOWING DIRECTORIES WILL NEED TO BE REVISED
        #if [[ ${IF_4DENVAR} = ${YES} ]]; then
        #  cp ${bkg_file_p1} ./wrf_inou3
        #  cp ${bkg_file_m1} ./wrf_inou1
        #  ls ${ENSEMBLE_FILE_mem_p1}* > filelist03
        #  ls ${ENSEMBLE_FILE_mem_m1}* > filelist01
        #fi

      else
        # run simple 3D-VAR without an ensemble 
        ifhyb=.false.
      fi

      # define namelist ensemble size
      nummem=${N_ENS}
    fi

    #####################################################
    # Build GSI namelist
    #####################################################
    echo " Build the namelist "

    # default is NAM
    #   as_op='1.0,1.0,0.5 ,0.7,0.7,0.5,1.0,1.0,'
    vs_op='1.0,'
    hzscl_op='0.373,0.746,1.50,'

    if [ ${bkcv_option} = GLOBAL ] ; then
    #   as_op='0.6,0.6,0.75,0.75,0.75,0.75,1.0,1.0'
       vs_op='0.7,'
       hzscl_op='1.7,0.8,0.5,'
    fi

    if [ ${bk_core} = NMMB ] ; then
       vs_op='0.6,'
    fi

    # default is NMM
    bk_core_arw='.false.'
    bk_core_nmm='.true.'
    bk_core_nmmb='.false.'
    bk_if_netcdf='.true.'

    if [ ${bk_core} = ARW ] ; then
       bk_core_arw='.true.'
       bk_core_nmm='.false.'
       bk_core_nmmb='.false.'
       bk_if_netcdf='.true.'
    fi

    if [ ${bk_core} = NMMB ] ; then
       bk_core_arw='.false.'
       bk_core_nmm='.false.'
       bk_core_nmmb='.true.'
       bk_if_netcdf='.false.'
    fi

    # Build the GSI namelist on-the-fly
    . ${gsi_namelist}

    # modify the anavinfo vertical levels based on wrf_inout for WRF ARW and NMM
    if [ ${bk_core} = ARW ] || [ ${bk_core} = NMM ] ; then
      bklevels=`ncdump -h wrf_inout | grep "bottom_top =" | awk '{print $3}' `
      bklevels_stag=`ncdump -h wrf_inout | grep "bottom_top_stag =" | awk '{print $3}' `
      anavlevels=`cat anavinfo | grep ' sf ' | tail -1 | awk '{print $2}' ` # levels of sf, vp, u, v, t...
      anavlevels_stag=`cat anavinfo | grep ' prse ' | tail -1 | awk '{print $2}' `  # levels of prse
      sed -i 's/ '${anavlevels}'/ '${bklevels}'/g' anavinfo
      sed -i 's/ '${anavlevels_stag}'/ '${bklevels_stag}'/g' anavinfo
    fi

    #####################################################
    # Run GSI
    #####################################################
    # Print run parameters
    echo
    echo "IF_CTR_COLD_START  = ${IF_CTR_COLD_START}"
    echo "IF_ENS_COLD_START  = ${IF_ENS_COLD_START}"
    echo "IF_SATRAD          = ${IF_SATRAD}"
    echo "IF_HYBRID          = ${IF_HYBRID}"
    echo "N_ENS              = ${N_ENS}"
    echo "IF_OBSERVER        = ${IF_OBSERVER}"
    echo "IF_4DENVAR         = ${IF_4DENVAR}"
    echo
    echo "ANL_TIME           = ${ANL_TIME}"
    echo "GSI_ROOT           = ${GSI_ROOT}"
    echo "CRTM_VERSION       = ${CRTM_VERSION}"
    echo "INPUT_DATAROOT     = ${INPUT_DATAROOT}"
    echo
    now=`date +%Y%m%d%H%M%S`
    echo "gsi started at ${now} with ${bk_core} background on domain d0${dmn}"
    ${MPIRUN} -n ${GSI_PROC} ${gsi_exe} > stdout_ens_00.anl.${ANL_TIME} 2>&1

    #####################################################
    # Run time error check
    #####################################################
    error=$?

    if [ ${error} -ne 0 ]; then
      echo "ERROR: ${GSI} exited with status ${error}"
      exit ${error}
    fi

    #####################################################
    # GSI updating satbias_in
    #####################################################
    # GSI updating satbias_in (only for cycling assimilation)

    # Rename the output to more understandable names
    cp wrf_inout   wrfanl_ens_00.${ANL_TIME}
    cp fort.201    fit_p1_ens_00.${ANL_TIME}
    cp fort.202    fit_w1_ens_00.${ANL_TIME}
    cp fort.203    fit_t1_ens_00.${ANL_TIME}
    cp fort.204    fit_q1_ens_00.${ANL_TIME}
    cp fort.207    fit_rad1_ens_00.${ANL_TIME}

    #####################################################
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
    #####################################################

    loops="01 03"
    for loop in ${loops}; do
      case ${loop} in
        01) string=ges;;
        03) string=anl;;
         *) string=${loop};;
      esac

      #####################################################
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
      #####################################################

      listall=`ls pe* | cut -f2 -d"." | awk '{print substr($0, 0, length($0)-3)}' | sort | uniq `
      for type in ${listall}; do
         count=`ls pe*${type}_${loop}* | wc -l`
         if [[ ${count} -gt 0 ]]; then
            cat pe*${type}_${loop}* > diag_${type}_${string}.${ANL_TIME}
         fi
      done
    done

    #  Clean working directory to save only important files
    ls -l * > list_run_directory

    if [[ ${if_clean} = clean && ${IF_OBSERVER} = ${NO} ]]; then
      echo ' Clean working directory after GSI run'
      rm -f *Coeff.bin     # all CRTM coefficient files
      rm -f pe0*           # diag files on each processor
      rm -f obs_input.*    # observation middle files
      rm -f siganl sigf0?  # background middle files
      rm -f fsize_*        # delete temperal file for bufr size
    fi

    #####################################################
    # Calculate diag files for each member if EnKF observer
    #####################################################

    if [[ ${IF_OBSERVER} = ${YES} ]]; then
      string=ges
      for type in ${listall}; do
        if [[ -f diag_${type}_${string}.${ANL_TIME} ]]; then
           mv diag_${type}_${string}.${ANL_TIME} diag_${type}_${string}.ensmean
        fi
      done
      mv wrf_inout wrf_inout_ensmean

      # Build the GSI namelist on-the-fly for each member
      if_read_obs_save='.false.'
      if_read_obs_skip='.true.'
      . ${gsi_namelist}

      # Loop through each member
      loop="01"
      ens_n=1

      while [[ ${ens_n} -le ${N_ENS} ]]; do
        rm pe0*
        print "\$ens_n is ${ens_n}"
        iimem=`printf %02d $(( 10#${ens_n} ))`
        iiimem=`printf %03d $(( 10#${ens_n} ))`

        # get new background for each member
        if [[ -f wrf_inout ]]; then
          rm wrf_inout
        fi

        ens_file="./${ens_prfx}${iiimem}"
        echo "Copying ${ens_file} for GSI observer"
        cp ${ens_file} wrf_inout

        # run GSI
        echo " Run GSI observer with ${bk_core} for member ${iiimem}"
        ${MPIRUN} ${gsi_exe} > stdout_ens_${iimem}.anl.${ANL_TIME} 2>&1

        # run time error check and save run time file status
        error=$?

        if [ ${error} -ne 0 ]; then
          echo "ERROR: ${gsi_exe} exited with status ${error} for member ${iiimem}"
          exit ${error}
        fi

        ls -l * > list_run_directory_mem${iimem}

        # generate diag files
        for type in ${listall}; do
          count=`ls pe*${type}_${loop}* | wc -l`
          if [[ ${count} -gt 0 ]]; then
            cat pe*${type}_${loop}* > diag_${type}_${string}.mem${iiimem}
          fi
        done
        # next member
        (( ens_n += 1 ))
      done
    fi

    # next variational bias correction loop
    (( bc_loop += 1 ))
  done 

  # Next domain
  (( dmn += 1 ))
done

echo "gsi.sh completed successfully at `date`"

exit 0
