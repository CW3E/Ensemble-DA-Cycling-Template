# Ensemble-DA-Cycling-Template

## Description
This is a [Cylc-driven](https://cylc.github.io/) workflow for [MPAS](https://mpas-dev.github.io/) versus
[WRF](https://www2.mmm.ucar.edu/wrf/users/) ensemble twin experiments, currently focusing on case study
ensemble forecast analysis with WRF / MPAS, ensemble DA cycling experiments with
[WRF-GSI](https://github.com/NOAA-EMC/GSI/tree/develop) and with additional development pending to integrate
[MPAS-JEDI](https://www.jcsda.org/jedi-mpas) ensemble DA. The purpose of this workflow framework is to produce
offline reforecast analysis for the state-of-the-science MPAS system versus the legacy WRF model. The
code structure is based around defining case studies and simulation configurations in a way that is
self-contained and transferrable to facilitate experiment replication.  The repository is also designed to run
with an embedded Cylc installation using
[Micromamba](https://mamba.readthedocs.io/en/latest/installation/micromamba-installation.html#)
with an automated build procedure for the Cylc environment and its configuration for this repository.

The repository is structured as follows:
```
Ensemble-DA-Cycling-Template/     # Root directory of the repository
├── cylc                          # Directory of embedded Cylc installation and wrappers
├── cylc-run                      # Directory of cylc workflow installations and run directories
├── cylc-src                      # Installable workflow settings for configuring experiments
├── settings                      # HPC environments / configurations for executables
│   ├── shared                    # Shared executable / driver configuration files
│   ├── sites                     # Root directory of HPC system configuration sub-directories 
│   └── template_archive          # Templates for workflow development
└── src                           # Workflow core source code
    ├── downloads                 # Utility scripts for downloading data
    └── drivers                   # Task execution run scripts
```

## Installing Cylc
Cylc can be run on an HPC system in a centralized or a distributed fashion.  This build procedure will
create an embedded Cylc installation with the configuration of Cylc inferred from the `config_workflow.sh`
at the root of the repository.  One should edit this file as in the following to define the local
HPC system paramters for the workflow.

###  Workflow configuration
In the workflow configuration one should define the full path of clone
```
export HOME="/expanse/nfs/cw3e/cwp168/Ensemble-DA-Cycling-Template"
```
NOTE: when sourcing this configuration the Unix `${HOME}` variable will be reset in the shell
to the repository.  This is to handle Cylc's usual dependence on a `${HOME}` directory
to write out workflow logs and make them shareable in a self-contained repository / project folder
directory structure.

One should also define a site-specific configuration to source for HPC global variables
throughout the workflow and for the software environment to load for the model and DA executables.
```
export SITE="expanse-cwp168"
```
the settings for the local HPC system parameters are sourced in the `config_workflow.sh` file as
```
source ${HOME}/settings/sites/${SITE}/config.sh
```
New "sites" can be defined by creating a new directory containing a `config.sh` file
edited to set local paths / computing environment. Example configuration variables for
the workflow include:
```
export SOFT_ROOT= # Root directory of software stack executables
export DATA_ROOT= # Root directory of simulation forcing data
export GRIB_ROOT= # Root directory of grib data data
export WORK_ROOT= # Root directory of simulation_io
export MOD_ENV=   # The full path to a module load / shared library path definition file for WRF / MPAS
export GSI_ENV=   # The full path to a module load / shared library path definition file for GSI
```
In the example site configuration
```
source ${HOME}/settings/sites/expanse-cwp168/config.sh
```
this defines the `${MOD_ENV}` variable to be
```
export MOD_ENV="${HOME}/settings/sites/expanse-cwp168/${MOD_STACK}.sh"
```
where the `${MOD_STACK}` variable is the name of the software stack used to compile
the WRF and MPAS model environments.  Respectively, the example defines the `${GSI_ENV}` as
```
export GSI_ENV="${HOME}/settings/sites/expanse-cwp168/${GSI_STACK}.sh"
```
where ongoing support for GSI is provided by the
[NOAA HPC Stack](https://github.com/NOAA-EMC/hpc-stack) and the 
[NOAA EMC GSI Github](https://github.com/NOAA-EMC/GSI/tree/develop).


### Building Cylc
The Cylc build script
```
${HOME}/cylc/cylc_build.sh
```
sources the `config_workflow.sh` configuration file to configure the local installation of
the Cylc executable in a self-contained Micromamba enviornment.  The Cylc installation
will be built at
```
${HOME}/cylc/Micromamba/envs/${CYLC_ENV_NAME}
```
with the Cylc software environment defined in the file
```
${HOME}/scripts/environments/${CYLC_ENV_NAME}.yml
```
sourcing a `.yml` definition file for the build.  Sourcing the `config_workflow.sh` the `${PATH}`
is set to source the cylc-wrapper script
```
${HOME}/cylc/cylc
```
configured to match the self-contained Micromamba environment.  Cylc command Bash auto-completion
is configured by default by sourcing the `config_workflow.sh` file.  Additionally the 
[cylc global configuration file](https://cylc.github.io/cylc-doc/stable/html/reference/config/global.html#global.cylc)
```
${HOME}/cylc/global.cylc
```
is configured so that workflow definitions will source the global variables
in `config_workflow.sh`, and so that task job scripts will inherit these variables as well.

### The cylc-run and log files
The Cylc workflow manager uses the [cylc-run directory](https://cylc.github.io/cylc-doc/stable/html/glossary.html#term-cylc-run-directory)
```
${HOME}/cylc-run
```
to [install workflows](https://cylc.github.io/cylc-doc/stable/html/user-guide/installing-workflows.html),
[run workflows](https://cylc.github.io/cylc-doc/latest/html/user-guide/running-workflows/index.html)
and [manage their progress](https://cylc.github.io/cylc-doc/latest/html/user-guide/interventions/index.html)
with automated logging of job status andt task execution within the associated run directories.  Job execution such as
MPAS / WRF simulation IO will not be performed in the `cylc-run` directory, as this run directory only encompasses
the execution of the workflow prior to calling the task driving script.  Task driving scripts will have
work directories nested in the directory structure at `${WORK_ROOT}` defined in the `config_workflow.sh`.

## Installing MPAS, WRF and GSI
It is assumed that there is a suitable installation of MPAS and / or WRF available on the HPC system. Basic
build examples for WRF, MPAS and their dependencies from source can be found in the
[template archive](https://github.com/CW3E/Ensemble-DA-Cycling-Template/tree/main/settings/template_archive/build_examples)
in this repository.  This repository also includes a 
[build example for GSI](https://github.com/CW3E/Ensemble-DA-Cycling-Template/blob/main/settings/template_archive/build_examples/make_GSI-HPC-STACK.sh)
building GSI with the HPC Stack providing the underlying dependencies.  The build is loosely integrated to the repository in that
it references a site configuration for code deployment with example
[HPC Stack Environment configuration](https://github.com/CW3E/Ensemble-DA-Cycling-Template/blob/main/settings/sites/expanse-cwp168/config_NOAA_HPC_STACK.sh) 
and
[HPC Stack Yaml definition](https://github.com/CW3E/Ensemble-DA-Cycling-Template/blob/main/settings/sites/expanse-cwp168/config_NOAA_HPC_STACK.yaml)
files for the build on Expanse.

Paths to the executables' compilation directories should be set in the `config_workflow.sh` file.  This repository assumes
that the executable compilation directories are "clean" builds, in that no simulations have been run within
these compilation directories.  Safety checks are performed in the workflow, but sourcing compilation directories that
have also been used as run directories may produce unpredictable results.

## Defining a case study / configuration
The code is currently designed around executing case studies in which the full experiment configuration is transferable
as a self-contained directory structure in order to facilitate experiment replication.  Example templates for
a variety of simulation configurations are archived for a generic Atmospheric River case study in the following.

### Archives of templates
At the path
```
${HOME}/cylc-src/valid_date_2022-12-28T00
```
templates are provided for running an ensemble forecast case study with the specified valid date of
`2022-12-28T00` at which to end the forecast verification.  Forecast initialization date times are
cycled with the Cylc workflow manager and the forecast length is dynamically defined by the length of
forecast time to the valid date of `2022-12-28T00`.  Cylc and the source task driving scripts at
```
${HOME}/src/drivers
```
can be configured for a variety of additional types of experiment execution, such as with a fixed forecast length,
with the configuration options commented in the code.

At the path
```
${HOME}/cylc-src/valid_date_2021-01-29T00
```
templates are provided additionally for running 3D-VAR and 3D-EnVAR case studies with WRF-GSI data assmilation cycling
such that:
  * A first 6 hour cold start forecast is generated at 2021-01-21T18 to 2021-01-22T00;
  * A first GSI / WRFDA initial / boundary condition update is performed at 2021-01-22T00;
  * 6-hourly cycling is performed until a final analysis at 2021-01-29T00;
  * Extended forecasts are generated every 24 hours at 00Z starting from 2021-01-23T00 to 2021-01-28T00 each running until 2021-01-29T00 for event verfication.
    
All of the above cycling settings can be revised using the workflow parameters in order to generate
extended forecasts from a DA cylcing experiment for a target event verifcation date.  The template name
```
valid_date_2021-01-29T00/D3envar_NAM_lag06_b0.00_v06_h0300
```
includes tunable parameter settings for hybridization (`b0.00`), vertical (`v06`) and horizontal (`h0300`) localization
radii and obs / background error settings `NAM`, which can all be changed to new settings.  New configurations should
have the same directory structure as the examples with names defined to reflect the particular tunable settings.

Finally, for downscaling ensemble forecasts for the background error covariance calculation in EnVAR, there is
one template available to generate ensemble forecasts offline for WRF
```
EnsembleBackground/WRF_9_WestCoast_lag06
```
including a tunable lag setting.  The lag setting defines how many hours in the past the ensemble forecast is
initialized beyond the usual 6-hourly cycling zero hour at which the control member is initialized.  For example,
for an analysis at 2021-01-22T00, the `lag06` workflow generates a 12-hour ensemble forecast initialized at
2021-01-21T12 lagged by 6 hours relative the control member initialized at 2021-01-21T18.  The lag is a tuneable
setting that can be used to increase the spread of the ensemble background to tune the analysis.

### Case study / configuration / sub-configuration 
Cylc will search for installable workflows at the simulation settings root directory 
```
${HOME}/cylc-src
```
which is configured in the repository as the default [source workflow directory](https://cylc.github.io/cylc-doc/stable/html/glossary.html#term-source-workflow).
A common directory naming structure must be observed with the definition of case studies and
configurations nested at this simulation settings root.
Experiment configurations are assumed to take on a naming structure
```
configuration.sub_configuration
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
${HOME}/cylc_src/case_study/configuration.sub_configuration
```
where for example, directories defined as
```
${HOME}/cylc_src/valid_date_2022-12-28T00/MPAS_60-10_CONUS.convection_permitting
${HOME}/cylc_src/valid_date_2022-12-28T00/MPAS_60-10_CONUS.mesoscale_reference
${HOME}/cylc_src/valid_date_2022-12-28T00/MPAS_240-U
${HOME}/cylc_src/valid_date_2022-12-28T00/WRF_9-3_WestCoast
```
are all valid case study / configuration / sub-configuration directory structures to install the
workflows for the `valid_date_2022-12-28T00` valid date case study.

### The flow.cylc file
Every experiment configuration uses a 
[Cylc workflow configuration file](https://cylc.github.io/cylc-doc/stable/html/user-guide/writing-workflows/configuration.html#the-flow-cylc-file) 
```
${HOME}/cylc_src/case_study/configuration.sub_configuration/flow.cylc
```
to define the dependency graph between workflow tasks and the switches that configure the tasks' driving scripts'
execution.  Parameters defined in the `flow.cylc` file include HPC job scheduler parameters, job cycling settings,
settings for propagating namelist templates and settings for linking simulation data and executables.

### Namelists, streamlists and static files
Each experiment configuration directory has a nested sub-directory for namelists and streamlists for MPAS and WRF,
and a sub-directory for static files that are unique to the experiment configuration:
```
${HOME}/cylc_src/case_study/configuration.sub_configuration/namelist
${HOME}/cylc_src/case_study/configuration.sub_configuration/static
```
Namelist and streamlist files within the above namelist directory are templated to propagate Cylc workflow parameters
for e.g., [ISO date time cycling](https://cylc.github.io/cylc-doc/latest/html/tutorial/scheduling/datetime-cycling.html),
in order to dynamically set simulation start and run parameters depending on the cycle point. Simulation configurations 
that are held static for the course of an experiment, currently such as the physics suite, are defined in the namelist
template itself. Static files for MPAS or respectively the geogrid files for WRF should be stored in the static file directory.
Additionally, if explicit zeta levels are specified for MPAS, the static file directory should contain only one definition
file for the explicit vertical level heights, with naming convention
```
*.ZETA_LIST.txt
```
Workflow scripts will source the `*.ZETA_LIST.txt` file in the static directory for the zeta level definitions at the
`init_atmosphere` runtime.

### Shared mesh and variable table files
Shared files that are independent of a simulation configurations, such as mesh partitions and ungrib variable
tables are kept in the directories
```
${HOME}/settings/shared/meshes
${HOME}/settings/shared/variable_tables
```
respectively.  The underlying mesh name to source, e.g., `x6.999426` is defined in the experiment's `flow.cylc` file.

## Running an experiment

### Downloading forcing data
Iinitial / boundary condition data can be obtained from, e.g., the 
[GEFS AWS Bucket](https://www.ncei.noaa.gov/products/weather-climate-models/global-ensemble-forecast).
An automated data download and formatting script
```
${HOME}/src/downloads/download_GEFS_AWS.py
```
is included for anonymous downloads from the GEFS bucket above, and can be configured within the script
to download arbirary forecast initialization dates and forecast hours from public GEFS data.  This script
requires the use of AWS Command Line Interface, which is installable by e.g.,
[conda-forge](https://anaconda.org/conda-forge/awscli).

### Installing and playing Cylc workflows
Assuming that the global configuration `configure_worklfow.sh` has been set to the local HPC system,
the embedded Cylc installation is built in the repository, the experiment configuration directory
```
${HOME}/cylc-src/case_study/configuration.sub_configuration
```
has been set up including necessary static files, Cylc can install the workflow
```
${HOME}/cylc-src/case_study/configuration.sub_configuration/flow.cylc
```
and run the experiment.  The experiment above can be
[installed](https://cylc.github.io/cylc-doc/stable/html/user-guide/installing-workflows.html) as
```
cylc install case_study/configuration.sub_configuration
```
and [run](https://cylc.github.io/cylc-doc/latest/html/user-guide/running-workflows/index.html)
and [managed](https://cylc.github.io/cylc-doc/latest/html/user-guide/interventions/index.html)
through any of Cylc command interfaces.

Generic Slurm and PBS scheduler configurations are provided to submit
task to the HPC job scheduler, but modifications are necessary for specific systems.  HPC system
account information should be set in the repository configuration file `configure_workflow.sh`.

### Checking logs and verifying outputs
The `cylc-run` directory contains
[logs for all experiments](https://cylc.github.io/cylc-doc/stable/html/user-guide/task-implementation/job-submission.html#task-stdout-and-stderr-logs),
their tasks' execution and the status of the Cylc workflow manager.  Task execution will
produce outputs in the above discussed case study / configuration / sub-configuration
naming convention.  In MPAS and WRF ensemble forecast experiments the experiment is broken over
multiple tasks including preprocessing input data and running the simulation.  Task outputs are organized
with the heirarchy
```
${WORK_ROOT}/case_study/configuration.sub_configuration/cycle_date/task_name/ensemble_member
```
which is generated by the task driving script.  

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

