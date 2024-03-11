"""
Code to make directories for each case study.
Also copies over or symlinks relevant files and 
modifies ctr_flw.xml from template.
"""

import os
import glob
import argparse
import setup_ctr_flw as scf

def make_dir(path_str, overwrite=True):
    """
    Function to make or overwrite directories.
    """
    
    # Resets user's umask settings
    os.umask(0)
        
    if not os.path.isdir(path_str):
        # Makes directory if it doesn't already exist
        os.mkdir(path_str)
        
    if overwrite == True:
        # Overrites directory and all files if it already exists
        cmd = f'rm -rf {path_str}'
        os.system(cmd)
        os.mkdir(path_str)

    # Makes sure permissions are 775
    os.chmod(path_str, mode=0o775)

# Launches argparse to receive arguments
parser = argparse.ArgumentParser(
                    prog='MakeDirs',
                    description='Program to automate the creation and organization '\
                                'of subdirectories for a case study.')

# Retrieves arguments from command line
parser.add_argument('cse_nme', help='Case study directory name.') # vertical_levels, for instance
parser.add_argument('run_nme', help='Experiment within case study name.') # WWRFZetaLevels, for instance
parser.add_argument('valid_date', help='Case study valid date in YYYYMMDDHH') # 2022122800, for instance
parser.add_argument('-e', '--ensembles', type=int, required=False, default=1, 
                    help='Number of ensembles')
parser.add_argument('-f', '--forcing-src', required=False, default='GEFS', 
                    help='Forcing data source (GEFS, GFS, etc.)')
parser.add_argument('-m', '--mesh-pfx', required=False, default=['x20.835586', 'x6.999426'],
                    help='Grid prefix name in format: xN.NNNNNN')
parser.add_argument('-n', '--num-nodes', required=False, default=None,
                    help='Optional, number of nodes for running mpas_atmosphere.'\
                    '\nDefault set based on supplied mesh or two default meshes of 60-3km and 60-10km')
parser.add_argument('-z', '--zeta-levels', required=False, default=True)
# TODO: add in print statement if path to zeta-levels isn't supplied

# Assigns supplied arguments as variables
args = parser.parse_args()
case_name = args.cse_nme
run_name = args.run_nme
valid_date = args.valid_date

num_ensembles = args.ensembles
forcing_src = args.forcing_src
mesh_prefix = args.mesh_pfx
num_nodes = args.num_nodes
num_cores = os.cpu_count() * 2 # 2 sockets on Expanse
zeta_levels = args.zeta_levels

# Checks to see if forcing_src is available
if forcing_src.upper() not in ['GEFS', 'GFS']:
    raise ValueError(f'Supplied --forcing-src {forcing_src} '\
                     'not in available options: "GEFS" or "GFS".')

# Checks for number of ensembles
if num_ensembles == 0:
    num_ensembles = 1

if 'ensemble' in run_name:
    if num_ensembles == 1:
        print('Number of ensembles not declared; using default of 6 ensemble members.')
        # Puts it into string of '00 01 02 03 04 05 06' for ctr_flw.xml
        MEM_LIST = ' '.join([f'0{x}' for x in range(6)])
    else:
        MEM_LIST = ' '.join([f'0{x}' if x < 10 else f'{x}' for x in range(num_ensembles)])
elif 'ensemble' not in run_name:
    if num_ensembles == 1:
        print('Number of ensembles not declared; using default of 1 ensemble member.')
        MEM_LIST = '00'
    else:
        print('Number of ensembles declared but "ensemble" not in run_nme.')
        print(f'Renaming directory to {run_name}_mpas_ensemble')
        run_name = f'{run_name}_mpas_ensemble'
        MEM_LIST = ' '.join([f'0{x}' if x < 10 else f'{x}' for x in range(num_ensembles)])

# Makes sure mesh_pfx is a list just for downstream ease
if not isinstance(mesh_prefix, list):
    mesh_prefix = [mesh_prefix]

# Organizes variables for better legibility and to mimic XML vars
domain_names = [f'{pfx}.{run_name}' for pfx in mesh_prefix]
config_names = [f'{valid_date}_valid_date_{dmn}' for dmn in domain_names]

# Makes top-level directory
current_dir = os.getcwd().split('/Ensemble-DA-Cycling-Template')[0]
runs_dir = f'{current_dir}/Ensemble-DA-Cycling-Template'
print(f'Nesting subdirectories in: {runs_dir}/simulation_settings/{case_name}')
make_dir(f'{runs_dir}/simulation_settings/{case_name}')

# Defines where template ctr_flw.xml file is
ctr_flw_in = f'{runs_dir}/static_files/ctr_flw.xml'

for i, exp in enumerate(config_names):
    # Declares subfolder and variables (for ease of use downstream)
    grid = mesh_prefix[i]
    domain = domain_names[i].split('_mpas_ensemble')[0]
    config_dir = f'{runs_dir}/simulation_settings/{case_name}/{exp}'
    print(f'Setting up environment for {domain} in folder:\n../../simulation_settings/{case_name}/{exp}')
    
    # Makes individual domain dirs within case study
    make_dir(config_dir)

    # Makes namelist, streamlist, and static_files folders
    make_dir(f'{config_dir}/namelists')
    make_dir(f'{config_dir}/streamlists')
    make_dir(f'{config_dir}/static_files')
    make_dir(f'{config_dir}/output')

    # Declares location of output ctr_flw file
    ctr_flw_out = f'{config_dir}/ctr_flw.xml'

    # Gets nodes and timesteps from setup_ctr_flw
    timestep, num_nodes = scf.get_dt_nodes(mesh_prefix[i], num_nodes)
    partitions = num_nodes * num_cores
    
    # Modifies ctr_flw.xml template and outputs to config_dir
    scf.edit_ctr_flw(ctr_flw_in, ctr_flw_out, MEM_LIST, num_nodes, timestep, forcing_src, zeta_levels)

    # Copies over relevant namelist and streamlist files
    if not os.path.isfile(f'{config_dir}/namelists/namelist.wps'):
        cmd = f'cp {runs_dir}/static_files/namelists/namelist.wps '\
                f'{config_dir}/namelists/namelist.wps'
        os.system(cmd)
    if not os.path.isfile(f'{config_dir}/namelists/namelist.init_atmosphere.{domain}.{forcing_src}'):
        cmd = f'cp {runs_dir}/static_files/namelists/namelist.init_atmosphere '\
                f'{config_dir}/namelists/namelist.init_atmosphere.{domain}.{forcing_src}'
        os.system(cmd)
    if not os.path.isfile(f'{config_dir}/namelists/namelist.atmosphere'):
        cmd = f'cp {runs_dir}/static_files/namelists/namelist.atmosphere '\
                f'{config_dir}/namelists/namelist.atmosphere.{domain}'
        os.system(cmd)
    if not os.path.isfile(f'{config_dir}/streamlists/streams.init_atmosphere'):
        cmd = f'cp {runs_dir}/static_files/streamlists/streams.init_atmosphere '\
                f'{config_dir}/streamlists/'
        os.system(cmd)
    if not os.path.isfile(f'{config_dir}/streamlists/streams.atmosphere'):
        cmd = f'cp {runs_dir}/static_files/streamlists/streams.atmosphere '\
                f'{config_dir}/streamlists/'
        os.system(cmd)
    for sl in glob.glob(f'{runs_dir}/static_files/streamlists/stream_list.atmosphere*'):
        if not os.path.isfile(f'{config_dir}/streamlists/{sl.split("/")[-1]}'):
            cmd = f'cp {runs_dir}/static_files/streamlists/{sl.split("/")[-1]} '\
                    f'{config_dir}/streamlists/'
            os.system(cmd)

    # Symbolically links mesh and partition files
    if not os.path.islink(f'{config_dir}/static_files/{domain}.grid.nc'):
        cmd = f'ln -s {runs_dir}/static_files/grid_files/{grid}*.grid.nc '\
                f'{config_dir}/static_files/{domain}.grid.nc'
        os.system(cmd)
    if not os.path.islink(f'{config_dir}/static_files/{domain}.static.nc'):
        if not os.path.isfile(glob.glob(f'{runs_dir}/static_files/grid_files/{grid}*.static.nc')[0]):
            raise ValueError(f'Static file not found:\n{runs_dir}/static_files/grid_files/{grid}*.static.nc')
        else:
            cmd = f'ln -s {runs_dir}/static_files/grid_files/{grid}*.static.nc '\
                    f'{config_dir}/static_files/{domain}.static.nc'
            os.system(cmd)
    if not os.path.islink(f'{config_dir}/static_files/{domain}.graph.info'):
        cmd = f'ln -s {runs_dir}/static_files/partition_files/{grid}.graph.info '\
                f'{config_dir}/static_files/{domain}.graph.info'
        os.system(cmd)
    if not os.path.islink(f'{config_dir}/static_files/{domain}.graph.info.part.{partitions}'):
        cmd = f'ln -s {runs_dir}/static_files/partition_files/{grid}.graph.info.part.{partitions} '\
                f'{config_dir}/static_files/{domain}.graph.info.part.{partitions}'
        os.system(cmd)

    # Copies over explicit vertical levels if the experiment calls for it
    # Eh, probably change this later to another indicator
    if zeta_levels == True:
        if not os.path.isfile(f'{config_dir}/namelists/zeta_list_{domain}.txt'):
            cmd = f'cp {runs_dir}/static_files/namelists/WWRFZetaLevels.txt {config_dir}/namelists/zeta_list_{domain}.txt'
            os.system(cmd)

    # Implement function to make scratch dirs and to get or link gribbed data?
