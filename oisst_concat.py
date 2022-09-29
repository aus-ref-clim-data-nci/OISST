from datetime import date, timedelta, datetime
import argparse
import os
import getpass
import sys
from subprocess import Popen

# Variables needed:
url = 'https://www.ncei.noaa.gov/data/sea-surface-temperature-optimum-interpolation/v2.1/access/avhrr/'
FILE = 'oisst-avhrr-v02r01.'
FILETYPE = '.nc'
PRELIM = '_preliminary.nc'
PATH_BASE = '/g/data/ia39/aus-ref-clim-data-nci/oisst/data/tmp/'
PATH_OUT = '/g/data/ia39/aus-ref-clim-data-nci/oisst/data/yearly/'


def parse_input():
    ''' Parse input arguments '''
    parser = argparse.ArgumentParser(description='''Concatonate daily OISST netcdf files into yearly. 
             Usage: python3 oisst_concat.py -y <year>
             Also rechunks yearly files and saves the info to its history attr.''', formatter_class=argparse.RawTextHelpFormatter)
    parser.add_argument('-y','--year', type=int, help='year to process',
                        required=True)
    return vars(parser.parse_args())


def daterange(start_date, end_date):
    '''Creates a list of the dates in the specified year'''
    for n in range(int((end_date - start_date).days)):
        yield start_date + timedelta(n)


def rm_prelim(year, YMD, YM):
    '''Removes preliminary files if the proper files exist.'''
    dir_year=str(year)
    YMD_file = str(YMD)
    YM_file = str(YM)
    
    path_file = PATH_BASE+dir_year+'/'+FILE+YMD_file+FILETYPE
    path_prelim = PATH_BASE+dir_year+'/'+FILE+YMD_file+PRELIM
    isExist = os.path.exists(path_file)
    isExist_prelim = os.path.exists(path_prelim)

    if ((isExist == True) and (isExist_prelim == True)):
        os.remove(path_prelim)
    else:
        pass

def bash_cdo(year):
    '''Using subprocess to run cdo to conatenate daily files into yearly.
    And ncks to rechunk the yearly file.'''
    dir_year=str(year)

    IN_FILE = PATH_BASE+dir_year+'/'+FILE+dir_year+'*.nc'
    TMP_FILE = PATH_OUT+'oisst-avhrr-v02r01_'+dir_year+'_tmp.nc'
    OUT_FILE = PATH_OUT+'oisst-avhrr-v02r01_'+dir_year+'.nc'
    
    # Check to see if final file exists
    # Delete it if it does, ncks doesn't seem to like it already exisitng.
    isExist = os.path.exists(OUT_FILE)
    if isExist == True:
        os.remove(OUT_FILE)
    else:
        pass

    # Concatenate the daily files into one yearly file:
    cmd_cat = 'cdo --no_history -O -L --sortname --no_warnings -f nc4 -z zip_5 cat'+' '+IN_FILE+' '+TMP_FILE
    os.system(cmd_cat)
    print('Concatonate done!')

    # Rechunk the yearly file:
    cmd_chun = 'ncks --cnk_dmn time,366 --cnk_dmn lat,720 --cnk_dmn lon,720'+' '+TMP_FILE+' '+OUT_FILE
    os.system(cmd_chun)
    os.remove(TMP_FILE)
    print('Re-chunking done!')
    
    # Add what has been done to the history:
    hist = 'downloaded original files from'+' '+url+'. Using cdo to concatenate files: '+cmd_cat+' '+'and nco to modify chunks: '+cmd_chun
    cmd_ncatted = 'ncatted -O -a history,global,o,c,\'{0}\' %s'.format(hist)%(OUT_FILE)
    print(cmd_ncatted)
    os.system(cmd_ncatted)
    print('History added to'+OUT_FILE)


def main():
    '''Main function to combine everything together.'''

    inputs=parse_input()
    year = inputs["year"]

    start_date = date(year, 1, 1)
    if year == date.today().year:
        end_date = date(year, date.today().month, date.today().day)
    else:
        end_date = date(year+1, 1, 1)

    # Loop through all the dates and download the required files:
    for single_date in daterange(start_date, end_date):
        YMD = single_date.strftime("%Y%m%d")
        YM = single_date.strftime("%Y%m")

        # Remove any redundant prelim file
        rm_prelim(year, YMD, YM)

    dt = str(date.today())
    usr = str(getpass.getuser())
    print('-------------------------------------------------------------------------')

    # Run the conatenate & rechunking:
    bash_cdo(year)

    # Info for logging:
    now = datetime.now()
    current_time = str(now.strftime("%H:%M:%S"))
    print(dt+' '+current_time+': the'+' '+str(year)+' daily data was concatenated into one file by'+' '+usr)
    print('-------------------------------------------------------------------------')


# Run the script.
if __name__ == "__main__":
    # Logs all python output to file:
    with open("oisst_concat.log", 'a') as f:
        sys.stdout = f
        # Run the script
        main()

    f.close()