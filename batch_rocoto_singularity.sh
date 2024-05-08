#!/bin/bash
#SBATCH --account=cwp168
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH -p cw3e-shared
#SBATCH -t 1:00:00
#SBATCH -J rocoto
#SBATCH --export=ALL

# module loads
module load singularitypro/3.9

# run rocoto 
python -u rocoto_singularity_utilities.py
