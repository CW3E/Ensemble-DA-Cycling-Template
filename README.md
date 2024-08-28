# Ensemble-DA-Cycling-Template

## Description
This is a [Cylc-driven](https://cylc.github.io/) workflow for [MPAS](https://mpas-dev.github.io/) versus
[WRF](https://www2.mmm.ucar.edu/wrf/users/) ensemble twin experiments, currently focusing on downscaling
foreacst analysis with additional development pending to integrate [WRF-GSI](https://github.com/NOAA-EMC/GSI/tree/develop)
and [MPAS-JEDI](https://www.jcsda.org/jedi-mpas) ensemble DA. The purpose of this workflow is to produce
offline reforecast analysis for the state-of-the-science MPAS system versus the legacy WRF model. The
code structure is based around defining case studies and simulation configurations in a way that is
self-contained and transferrable to facilitate experiment replication.  The repository is also designed to run
with an embedded Cylc installation using
[Micromamba](https://mamba.readthedocs.io/en/latest/installation/micromamba-installation.html#)
with an automated build procedure for the Cylc environment and its configuration for this repository.

NOTE: if you want to get running as quickly as possible it is recommended that you start downloading the
initial / boundary condition data from, e.g., the 
[GEFS AWS Bucket](https://www.ncei.noaa.gov/products/weather-climate-models/global-ensemble-forecast)
while you work through the rest of the installation.  An automated 
[data download and formatting script](https://github.com/CW3E/Ensemble-DA-Cycling-Template/blob/main/scripts/downloads/download_GEFS_AWS.py)
is included for anonymous downloads from the GEFS bucket above, and can be configured within the script
to download arbirary forecast initialization dates and forecast hours.  This script requires the use of
AWS Command Line Interface, which is installable by e.g., [conda-forge](https://anaconda.org/conda-forge/awscli).

## Installing Cylc
Cylc can be run on an HPC system in a centralized or a distributed fashion.  This build procedure will
create a local installation with the configuration of Cylc inferred from the `config_template.sh`
at the root of the repository.  One should edit this file as in the following to define the local
HPC system paramters for the workflow.

###  Workflow configuration
Global variables for the workflow are defined in the `config_template.sh` script which is
sourced in order to run Cylc, and to provide global variables to Cylc.  Exmample configuration
variables for the workflow template include:
```
export HOME= # Full path of framework git clone, is used for embedded Cylc installation
export SOFT_ROOT= # Root directory of software stack executables
export DATA_ROOT= # Root directory of simulation forcing data
export GRIB_ROOT= # Root directory of grib data data
export WORK_ROOT= # Root directory of simulation_io
```
NOTE: the Unix `${HOME}` variable will be reset in the shell to the repository
when sourcing the configuration.  This is to handle Cylc's usual dependence on a ${HOME} directory
to write out workflow logs and make them shareable in a self-contained repository / project folder
directory structure.

### Building Cylc
The build script
```
${HOME}/cylc/cylc_build.sh
```
sources the above discussed configuration file to configure the local installation of
the Cylc executable in a self-contained Micromamba enviornment.  The Cylc installation
will be built at
```
${HOME}/cylc/Micromamba/envs/${CYLC_ENV_NAME}
```
with the Cylc version defined in the file
```
${HOME}/docs/build_examples/${CYLC_ENV_NAME}.yml
```
sourcing a `.yml` definition file for the build.  The `${PATH}` variable will be set
to source the cylc-wrapper
```
${HOME}/cylc/cylc
```
preconfigured to match the self-contained Micromamba environment.

### cylc-run and log files
The Cylc workflow uses the the directory
```
${HOME}/cylc-run
```
to [install workflows](https://cylc.github.io/cylc-doc/latest/html/user-guide/installing-workflows.html#using-cylc-install),
[run workflows](https://cylc.github.io/cylc-doc/latest/html/user-guide/running-workflows/index.html)
and [manage their progress](https://cylc.github.io/cylc-doc/latest/html/user-guide/interventions/index.html)
with automated logging of job status andt task execution within the associated run directories.

## Installing MPAS and WRF
It is assumed that there is a suitable installation of MPAS and / or WRF available on the HPC system.

### Environment constants
Module loads and shared library paths needed for the compilation and execution of the MPAS and WRF executables
should be set as an environment in the
```
${HOME}/scripts/environments/MPAS_constants.sh
${HOME}/scripts/environments/WRF_constants.sh
```
files respectively.  These files will be sourced for these exports and loads, along with generic regex patterns and
constants used throughout the MPAS and WRF driver scripts.

## Defining a case study / configuration

### Archive of templates

### Case study / Experiment configuration / Experiment sub-configuration 

#### flow.cylc files

#### Namelists, streamlists and static files

#### Shared mesh and variable table files

### Creating a new reforecast experiment

#### Building from the archived templates





## Known issues
See the Github issues page for ongoing issues / debugging efforts with this template.

## Posting issues
If you encounter bugs, please post a detailed issue in the Github page, with steps and parameter
settings that reproduce this issue, and please include any related error messages / logs that
may be useful for solving this.  Limited support and debugging will be performed for issues that do
not adhere to this request.

## Fixing issues
If you encounter a bug and have a solution, please follow the same steps as above to post the issue
and then submit a pull request with your branch that fixes the issue with a detailed explanation of
the solution.
