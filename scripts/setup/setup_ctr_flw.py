# This and setup_dirs should probably be their own standalone scripts called by batch_rocoto.sh
# On second thought, this should eventually be packed into a class so the two functions
# don't need to be imported into setup_dirs
import os
import re

def get_dt_nodes(GRID_PFX, req_nodes=None):
    """
    Calculates timestep and (optionally) number of nodes
    based on MPAS grid.
    """
    if GRID_PFX == 'x20.835586':
        res = 3
        nnodes = 6 # optimally 7?
    elif GRID_PFX == 'x6.999426':
        res = 10
        nnodes = 7 # optimally 8?
    elif GRID_PFX == 'x4.5243369':
        res = 3 # this is the clipped 15-3km regional
        nnodes = 37
    elif GRID_PFX == 'x1.40962':
        res = 120
        nnodes = 1
    elif GRID_PFX == 'x1.10242':
        res = 240
        nnodes = 1
    elif GRID_PFX == 'x1.163842':
        res = 60
        nnodes = 2

    # Model timestep
    config_dt = float(res * 6) # Minimum grid resolution * 6

    # Overwrites calculated number of nodes if supplied a value
    if req_nodes != None:
        nnodes = int(req_nodes)

    return config_dt, nnodes    

def edit_ctr_flw(ctr_flw_in, ctr_flw_out, ensembles, nnodes, config_dt):
    """
    Function to automate overwriting the ctr_flw.xml
    template.
    """
    # TODO Ensure config_dt is divisible by model output?

    # Sets variables based on ctr_flw_out path
    EXP_VRF = ctr_flw_out.split('/')[-2].split('_')[0]
    GRID_PFX = '.'.join(ctr_flw_out.split('/')[-2].split('_')[3].split('.')[0:2])
    CSE_NME = ctr_flw_out.split('/')[-3]
    RUN_NME = ctr_flw_out.split('/')[-2].split('_')[3].split('.')[-1]
    USR_NME = ctr_flw_out.split('/')[5]
    
    with open(ctr_flw_in, mode='r') as f:
        # Reads in file and assigns to variable
        contents = f.read()
        
        # Replaces experiment verification date
        contents = re.sub('(?<=ENTITY\sEXP_VRF\s{6}\")\d+(?=\"\>\s\<\!\-\- Define the valid date)', 
                          f'{EXP_VRF}', contents)
    
        # Replaces grid prefix
        contents = re.sub('(?<=ENTITY\sGRID_PFX\s{5}\")\D\d+\.\d+(?=\"\>\s\<\!\-\- Mesh file prefix)', 
                          f'{GRID_PFX}', contents)
    
        # Replaces case study name
        contents = re.sub('(?<=ENTITY\sRUN_NME\s{6}\")\D+(?=\"\>\s\<\!\-\- Define the run name)', 
                          f'{RUN_NME}', contents)
    
        # Replaces username
        contents = re.sub('(?<=ENTITY\sUSR_NME\s{6}\")\D+(?=\"\>\s\<\!\-\- Username, for generic)', 
                          f'{USR_NME}', contents)
    
        # Makes sure ensembles are set if ensemble in RUN_NME (done in setup_dirs.py)
        contents = re.sub('(?<=ENTITY\sMEM_LIST\s{5}\")[\d+\s+]*(?=\"\>\s\<\!\-\- list of ensemble)', 
                          ensembles, contents)

        # Toggles on/off zeta levels setting if 'ZetaLevels' in run name
        if 'ZetaLevels' in RUN_NME:
            zlevs = 'Yes'
        else:
            zlevs = 'No'
        contents = re.sub('(?<=ENTITY\sIF_ZETA_LIST\s{1}\")\D{2,3}(?=\"\>\s\<\!\-\- If zeta levels)', zlevs, contents)
    
        # Checks to make sure forcing data exists
        scratch_root = re.search('(?<=ENTITY\sSCRATCH_ROOT\s{1}\")[\\/\D+]*(?=\"\>\s\<\!\-\- Path to output scratch)', 
                                 contents).group()
        scratch_root = re.sub('\&USR\_NME;', f'{USR_NME}', scratch_root)
        re_srch = re.compile('(?<=ENTITY\sDATA_ROOT\s{4}\")[\\/\D+]*(?=\"\>\s\<\!\-\- Root directory of case study forcing)')
        data_root = re.search(re_srch, contents).group()
        data_root = re.sub('\&SCRATCH\_ROOT;', scratch_root, data_root)
        data_root = re.sub('\&CSE\_NME;', CSE_NME, data_root)
        ENS_BKG_DATA = re.search('(?<=ENTITY\sENS_BKG_DATA\s{1}\")\D+(?=\"\>\s\<\!\-\- GFS and GEFS currently)', 
                                 contents).group()
        data_folder = f'{data_root}/gribbed/{ENS_BKG_DATA}/{EXP_VRF[:-2]}'
       
        # Eventually automate this to download forcing data based on EXP_VRF and ENS_BKG_DATA 
        if not os.path.isdir(data_folder):
            if not os.path.islink(data_folder):
                raise ValueError(f'Forcing data folder does not exist:\n{data_folder}')
        elif len(os.listdir(data_folder)) == 0:
           raise ValueError(f'No forcing data in folder:\n{data_folder}')
        
        forcing_files = sorted(os.listdir(data_folder))
    
        # Grabs X-hourly forcing data frequency
        forcing_hour1 = int(forcing_files[0].split('.f')[-1])
        forcing_hour2 = int(forcing_files[1].split('.f')[-1])
        fh_diff = forcing_hour2 - forcing_hour1
        if fh_diff < 10:
            fh_diff = f'0{fh_diff}'
    
        # Automatically replaces X-hourly forcing data frequency
        contents = re.sub('(?<=ENTITY\sENS_BKG_INT\s{2}\")\d{2}(?=\"\>\s\<\!\-\- Data file frequency)', 
                         f'{fh_diff}', contents)

        # Checks to make sure config_dt is divisible by model output
        hist_int = int(re.search('(?<=ENTITY\sHIST_INT\s{5}\")\d{2}(?=\"\>\s\<\!\-\- Output interval for history)', 
                                 contents).group())
        if config_dt % hist_int != 0:
            raise ValueError(f'Supplied model timestep ({config_dt}) is not '\
                             f'divisible by the history file output interval ({hist_int})')
                             
        diag_int = int(re.search('(?<=ENTITY\sDIAG_INT\s{5}\")\d{2}(?=\"\>\s\<\!\-\- Output interval for diagnostic)', 
                                 contents).group())
        if config_dt % diag_int != 0:
            raise ValueError(f'Supplied model timestep ({config_dt}) is not '\
                             f'divisible by the diagnostic file output interval ({hist_int})')
    
        # Configures model timestep based on finest grid resolution
        contents = re.sub('(?<=ENTITY\sCONFIG\_DT\s{5}\")\d+(?=\"\>\s\<\!\-\- Model timestep)', 
                          f'{config_dt}', contents)
    
        # Configures number of requested nodes based on number of grid cells
        contents = re.sub('(?<=ENTITY\sMPAS_NDES\s{4}\")\d+(?=\"\>\s\<\!\-\- Number of nodes for atmosphere_model)', 
                          f'{nnodes}', contents)
    
        # TODO implement automation of wallclock time based on (testing data) ...?
        # This command works, I just need to define wc_model_hours
        # contents = re.sub('(?<=ENTITY\sMPAS_WC\s{6}\")\d+(?=\:00\:00\"\>\s\<\!\-\- Wallclock limit for atmosphere_model)', 
        #                   f'{wc_model_hrs}', contents)

    with open(ctr_flw_out, mode='w') as f:
        f.write(contents)
