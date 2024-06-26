#!/bin/bash
#SBATCH --account=cwp157
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH -p cw3e-shared
#SBATCH -t 1:00:00
#SBATCH -J rocoto
#SBATCH --export=ALL

# run rocoto 
python -u rocoto_utilities.py
