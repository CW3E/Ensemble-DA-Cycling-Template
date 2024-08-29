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
export = # Full path of framework git clone, is used for embedded Cylc installation
export SOFT_ROOT= # Root directory of software stack executables
export DATA_ROOT= # Root directory of simulation forcing data
export GRIB_ROOT= # Root directory of grib data data
export WORK_ROOT= # Root directory of simulation_io
```
NOTE: the Unix `${HOME}` variable will be reset in the shell to the repository
when sourcing the configuration.  This is to handle Cylc's usual dependence on a `${HOME}` directory
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
The code is currently designed around executing case studies in which the configuration is transferable
in order to facilitate experiment replication.  Example templates for a variety of simulation configurations
are archived for a generic Atmospheric River case study in the following.

### Archive of templates
At the path
```
${HOME}/simulation_settings/archive/control_flows/valid_date_2022-12-28T00
```
pre-configured templates are provided for running a case study with a specified valid date in which to end
the forecast verification.  Forecast initialization date times are cycled with the Cylc workflow manager
with the forecast length dynamically defined by the length of forecast time to the valid date of `2022-12-28T00`.  Cylc
and the driving simulation scripts at
```
${HOME}/scripts/drivers
```
can be configured for a variety of additional types simulation execution, with options commented in the code.

### Case study / Experiment configuration / Experiment sub-configuration 
A common directory and naming structure must be observed with the definition of case studies and
configurations.  Experiment configurations are assumed to take on a naming structure
```
experiment_short_name.sub_configuration
```
where the experiment short name corresponds to the name of the static file for MPAS.  Sub-configurations
of MPAS with e.g., physics suites for a given static configuration can be denoted with a `.sub_configuration`
naming convention as above.  Experiment configurations are assumed to have a nested directory structure as
```
${HOME}/simulation_settings/${case_study}/experiment_short_name.sub_configuration
```
where for example copying one of the archived templates to the path
```
${HOME}/simulation_settings/valid_date_2022-12-28T00/MPAS_240-U
```
makes this case study and MPAS configuration sourceable by Cylc. 

### flow.cylc files
The cylc workflow configuration file 
```
${HOME}/simulation_settings/${case_study}/experiment_short_name.sub_configuration/flow.cylc
```
defines the dependency graph between tasks and the the switches to configure the task's driving script
execution, propagating namelist templates and linking of data and executables.

### Namelists, streamlists and static files
Each simulation configuration has a nested directory for namelists and streamlists for MPAS and WRF,
and a directory for static files that are unique to the configuration:
```
${HOME}/simulation_settings/${case_study}/experiment_short_name.sub_configuration/namelist
${HOME}/simulation_settings/${case_study}/experiment_short_name.sub_configuration/static
```
namelist and streamlist files are pre-templated to propagate Cylc cycle points for ISO date time cycling.
Static simulation configurations for the course of an experiment, currently such as the physics suite, 
can be defined in the namelist itself. Static files for MPAS or geogrid files for WRF should be stored
in the static file directory.  Additionally, if explicit zeta levels are specified for MPAS, the static
file directory can contain one definition file for the explicit vertical level heights.

### Shared mesh and variable table files
Common files that are independent of simulation configurations, such as mesh partitions and ungrib variable
tables are kept in the directories
```
${HOME}/simulation_settings/meshes
${HOME}/simulation_settings/variable_tables
```

## Installing and running an experiment's workflow


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
