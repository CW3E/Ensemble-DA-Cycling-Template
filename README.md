# Ensemble-DA-Cycling-Template

## Description
This is a [Cylc-driven](https://cylc.github.io/) workflow for [MPAS](https://mpas-dev.github.io/) versus
[WRF](https://www2.mmm.ucar.edu/wrf/users/) ensemble twin experiments, currently focusing on downscaling
forecast analysis with additional development pending to integrate [WRF-GSI](https://github.com/NOAA-EMC/GSI/tree/develop)
and [MPAS-JEDI](https://www.jcsda.org/jedi-mpas) ensemble DA. The purpose of this workflow is to produce
offline reforecast analysis for the state-of-the-science MPAS system versus the legacy WRF model. The
code structure is based around defining case studies and simulation configurations in a way that is
self-contained and transferrable to facilitate experiment replication.  The repository is also designed to run
with an embedded Cylc installation using
[Micromamba](https://mamba.readthedocs.io/en/latest/installation/micromamba-installation.html#)
with an automated build procedure for the Cylc environment and its configuration for this repository.

The repository is structured as follows:

```
Ensemble-DA-Cycling-Template  # Root directory of the repository
├── cylc                      # Directory of embedded Cylc installation and wrappers
├── cylc-run                  # Directory of cylc workflow installations and run directories
├── docs                      # General documentation
│   └── build_examples        # Examples of builds for related software
├── scripts                   # Workflow scripts
│   ├── downloads             # Utility scripts for downloading data
│   ├── drivers               # Task execution run scripts
│   └── environments          # HPC environments / configurations for executables
└── simulation_settings       # Workflow settings and related configuration files
    ├── archive               # Example templates and configuration files for defining simulations
    │   ├── control_flows     # Full workflow examples
    │   ├── fix               # GSI fix files
    │   └── namelists         # WRF / MPAS / GSI namelists
    ├── meshes                # MPAS mesh decomposition files
    └── variable_tables       # Ungrib variable tables
```

## Installing Cylc
Cylc can be run on an HPC system in a centralized or a distributed fashion.  This build procedure will
create an embedded Cylc installation with the configuration of Cylc inferred from the `config_template.sh`
at the root of the repository.  One should edit this file as in the following to define the local
HPC system paramters for the workflow.

###  Workflow configuration
Global variables for the repositiory are defined in the `config_template.sh` script which is
sourced to provide global variables to Cylc and the worfklow configuration.  Example configuration
variables for the workflow template include:
```
export HOME = # Full path of framework git clone, is used for embedded Cylc installation
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
sources the `config_template.sh` configuration file to configure the local installation of
the Cylc executable in a self-contained Micromamba enviornment.  The Cylc installation
will be built at
```
${HOME}/cylc/Micromamba/envs/${CYLC_ENV_NAME}
```
with the Cylc software environment defined in the file
```
${HOME}/scripts/environments/${CYLC_ENV_NAME}.yml
```
sourcing a `.yml` definition file for the build.  Sourcing the `config_template.sh` the `${PATH}`
is set to source the cylc-wrapper script
```
${HOME}/cylc/cylc
```
pre-configured to match the self-contained Micromamba environment.  Cylc command Bash auto-completion
is configured by default by sourcing the `config_template.sh` file.  Additionally the 
[cylc global configuration file](https://cylc.github.io/cylc-doc/stable/html/reference/config/global.html#global.cylc)
```
${HOME}/cylc/global.cylc
```
is pre-configured to so that workflow definitions will source the global variables
in `config_template.sh`, and so that task job scripts will inherit these variables as well.

### The cylc-run and log files
The Cylc workflow manager uses the [cylc-run directory](https://cylc.github.io/cylc-doc/stable/html/glossary.html#term-cylc-run-directory)
```
${HOME}/cylc-run
```
to [install workflows](https://cylc.github.io/cylc-doc/latest/html/user-guide/installing-workflows.html#using-cylc-install),
[run workflows](https://cylc.github.io/cylc-doc/latest/html/user-guide/running-workflows/index.html)
and [manage their progress](https://cylc.github.io/cylc-doc/latest/html/user-guide/interventions/index.html)
with automated logging of job status andt task execution within the associated run directories.  Job execution such as
MPAS / WRF simulation IO will not be performed in the `cylc-run` directory, as this run directory only encompasses
the execution of the workflow prior to calling the task driving script.  Task driving scripts will have
work directories nested in the directory structure at `${WORK_ROOT}` defined in the `config_template.sh`.

## Installing MPAS and WRF
It is assumed that there is a suitable installation of MPAS and / or WRF available on the HPC system.  Paths to the
executables' compilation directories should be set in the `config_template.sh` file.  This repository assumes
that the executable compilation directories are "clean" builds, in that no simulations have been run within
these compilation directories.  Safety checks are performed in the workflow, but sourcing compilation directories that
have also been used as run directories may produce unpredictable results.

### Environment constants
Module loads and shared library paths needed for the compilation and execution of the MPAS and WRF executables
should be set as an environment in the
```
${HOME}/scripts/environments/MPAS_constants.sh
${HOME}/scripts/environments/WRF_constants.sh
```
files respectively.  These files are sourced for these exports and load statements, along with helper regex patterns and
constants used throughout the MPAS and WRF driver scripts.

## Defining a case study / configuration
The code is currently designed around executing case studies in which the full experiment configuration is transferable
as a self-contained directory structure in order to facilitate experiment replication.  Example templates for
a variety of simulation configurations are archived for a generic Atmospheric River case study in the following.

### Archive of templates
At the path
```
${HOME}/simulation_settings/archive/control_flows/valid_date_2022-12-28T00
```
pre-configured templates are provided for running a case study with the specified valid date of
`2022-12-28T00` at which to end the forecast verification.  Forecast initialization date times are
cycled with the Cylc workflow manager and the forecast length is dynamically defined by the length of
forecast time to the valid date of `2022-12-28T00`.  Cylc and the driving simulation scripts at
```
${HOME}/scripts/drivers
```
can be configured for a variety of additional types simulation execution, such as with a fixed forecast length,
with the configuration options commented in the code.

### Case study / Experiment configuration / Experiment sub-configuration 
Cylc will search for installable workflows at the simulation settings root directory 
```
${HOME}/simulation_settings
```
which is configured in the repository as the default [source workflow directory](https://cylc.github.io/cylc-doc/stable/html/glossary.html#term-source-workflow).
A common directory naming structure must be observed with the definition of case studies and
configurations nested at this simulation settings root.
Experiment configurations are assumed to take on a naming structure
```
experiment_short_name.sub_configuration
```
where the experiment short name corresponds to the name of the static file for MPAS, e.g., the experiment
short name `MPAS_60-10_CONUS` would have an associated MPAS static file named
```
MPAS_60-10_CONUS.static.nc
```
Optionally, sub-configurations of MPAS with e.g., different physics suites for a given static configuration,
can be denoted with a `.sub_configuration` naming convention as above.  For example, different
sub-configurations of experiments which both use the `MPAS_60-10_CONUS.static.nc` file but differ using
the convection permitting or mesoscale reference physics suites can be denoted as
```
MPAS_60-10_CONUS.convection_permitting
MPAS_60-10_CONUS.mesoscale_reference
```
Experiment configurations are assumed to have a nested directory structure as
```
${HOME}/simulation_settings/case_study/experiment_short_name.sub_configuration
```
where for example, directories defined as
```
${HOME}/simulation_settings/valid_date_2022-12-28T00/MPAS_60-10_CONUS.convection_permitting
${HOME}/simulation_settings/valid_date_2022-12-28T00/MPAS_60-10_CONUS.mesoscale_reference
${HOME}/simulation_settings/valid_date_2022-12-28T00/MPAS_240-U
${HOME}/simulation_settings/valid_date_2022-12-28T00/WRF_9-3_WestCoast
```
are all valid case study / configuration / sub-configuration directory structures to install the
workflows for the `2022-12-28T00` valid date case study.

### The flow.cylc file
Every experiment configuration uses a [Cylc workflow configuration file](https://cylc.github.io/cylc-doc/stable/html/user-guide/writing-workflows/configuration.html#the-flow-cylc-file) 
```
${HOME}/simulation_settings/${case_study}/experiment_short_name.sub_configuration/flow.cylc
```
to define the dependency graph between workflow tasks and the switches that configure the tasks' driving scripts'
execution.  Parameters defined in the `flow.cylc` file include HPC job scheduler parameters, job cycling settings,
settings for propagating namelist templates and settings for linking simulation data and executables.

### Namelists, streamlists and static files
Each experiment configuration directory has a nested sub-directory for namelists and streamlists for MPAS and WRF,
and a sub-directory for static files that are unique to the experiment configuration:
```
${HOME}/simulation_settings/${case_study}/experiment_short_name.sub_configuration/namelist
${HOME}/simulation_settings/${case_study}/experiment_short_name.sub_configuration/static
```
Namelist and streamlist files within the above namelist directory are pre-templated to propagate Cylc
cycle points for [ISO date time cycling](https://cylc.github.io/cylc-doc/latest/html/tutorial/scheduling/datetime-cycling.html),
for simulation start and run parameters. Simulation configurations that are held static for the course of an experiment,
currently such as the physics suite, are defined in the namelist template itself. Static files for MPAS or respectively the geogrid
files for WRF should be stored in the static file directory.  Additionally, if explicit zeta levels are specified for
MPAS, the static file directory should contain only one definition file for the explicit vertical level heights, with naming convention
```
*.ZETA_LIST.txt
```
Workflow scripts will source the `*.ZETA_LIST.txt` file in the static directory for the zeta level definitions at the
`init_atmosphere` runtime.

### Shared mesh and variable table files
Shared files that are independent of a simulation configurations, such as mesh partitions and ungrib variable
tables are kept in the directories
```
${HOME}/simulation_settings/meshes
${HOME}/simulation_settings/variable_tables
```
respectively.  The underlying mesh name to source, e.g., `x6.999426` is defined in the experiment's `flow.cylc` file.

## Installing and running an experiment's workflow


## Downloading forcing data
Iinitial / boundary condition data can be obtained from, e.g., the 
[GEFS AWS Bucket](https://www.ncei.noaa.gov/products/weather-climate-models/global-ensemble-forecast)
An automated 
[data download and formatting script](https://github.com/CW3E/Ensemble-DA-Cycling-Template/blob/main/scripts/downloads/download_GEFS_AWS.py)
is included for anonymous downloads from the GEFS bucket above, and can be configured within the script
to download arbirary forecast initialization dates and forecast hours.  This script requires the use of
AWS Command Line Interface, which is installable by e.g., [conda-forge](https://anaconda.org/conda-forge/awscli).


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

