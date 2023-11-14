#!/bin/bash
#SBATCH --account=ddp181
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH -p shared
#SBATCH -t 48:00:00
#SBATCH -J rocoto
#SBATCH --export=ALL

# run rocoto 
python -u rocoto_utilities.py
