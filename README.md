# Ensemble-DA-Cycling-Template

## Description
This is a template for running WRF-GSI-based / MPAS-JEDI-based ensemble DA and reforecast twin
experiments in an offline setting. This repository is based on the work of Colin Grudizen,
Daniel Steinhoff, Matthew Simpson, Christopher Harrop, Caroline Papadopoulos, Corrine Deciampa,
Patrick Mulrooney, Minghua Zheng, Ivette Hernandez Ba&ntilde;os, Allison Michaelis and others.

Twin experiment workflows are currenlty in-development, with further integrations of
templates from NCAR's [MPAS Workflow](https://github.com/NCAR/MPAS-Workflow) planned.
Scripts in this repository were forked and re-written from examples from the CW3E
WRF NRT ensemble forecast system. Variable conventions have been changed in order to
integrate a full end-to-end re-forecast system with forecast skill evaluated with
[MET-tools](https://github.com/CW3E/MET-tools) workflows.

Please pardon the lack of documentation while the system undergoes a major re-write
to convert the system to the [Cylc workflow manager](https://cylc.github.io/) from the
[Rocoto worfklow manager](http://christopherwharrop.github.io/rocoto/) on which it was
previously designed.

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
