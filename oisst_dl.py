from datetime import date, timedelta
import argparse
import os
from subprocess import Popen

# Variables needed:
url = 'https://www.ncei.noaa.gov/data/sea-surface-temperature-optimum-interpolation/v2.1/access/avhrr/'
FILE = 'oisst-avhrr-v02r01.'
FILETYPE = '.nc'
PRELIM = '_preliminary.nc'

def parse_input():
    ''' Parse input arguments '''
    parser = argparse.ArgumentParser(description='''Download OISST netcdf files from ncei.noaa.gov and 
    store them in directories by year. 
             Usage: python3 oisst_dl.py -y <year>  ''', formatter_class=argparse.RawTextHelpFormatter)
    parser.add_argument('-y','--year', type=int, help='year to process',
                        required=True)
    return vars(parser.parse_args())

def daterange(start_date, end_date):
    '''Creates a list of the dates in the specified year'''
    for n in range(int((end_date - start_date).days)):
        yield start_date + timedelta(n)

def folder_exist(year):
    '''Checks if the yearly directory exists, creates it if not.'''
    dir_year=str(year)
    path = '/home/green/Downloads/oisst/test/'+dir_year
    isExist = os.path.exists(path)
    if isExist == False:
        print('Folder'+' '+dir_year+' '+'does not exist')
        os.mkdir(path)
    else:
        print('Folder'+' '+dir_year+' '+'exists')

def rm_prelim(year, YMD, YM):
    dir_year=str(year)
    YMD_file = str(YMD)
    YM_file = str(YM)
    
    path_file = '/home/green/Downloads/oisst/test/'+dir_year+'/'+FILE+YMD_file+FILETYPE
    path_prelim = '/home/green/Downloads/oisst/test/'+dir_year+'/'+FILE+YMD_file+PRELIM
    isExist = os.path.exists(path_file)
    isExist_prelim = os.path.exists(path_prelim)

    if ((isExist == True) and (isExist_prelim == True)):
        os.remove(path_prelim)
    else:
        pass

def bash_wget(year, YMD, YM):
    dir_year=str(year)
    YMD_file = str(YMD)
    YM_file = str(YM)

    url1 = url+str(YM_file)+'/'+FILE+str(YMD_file)+FILETYPE
    url_prelim = url+str(YM_file)+'/'+FILE+str(YMD_file)+PRELIM

    #path = '/home/green/Downloads/oisst/test/'+dir_year+'/'+FILE+YMD_file+FILETYPE
    #path_prelim = '/home/green/Downloads/oisst/test/'+dir_year+'/'+FILE+YMD_file+PRELIM
    location = '/home/green/Downloads/oisst/test/'+dir_year+'/'
    #isExist = os.path.exists(path)
    #isExist_prelim = os.path.exists(path_prelim)

    today = date.today()
    log_date = today.strftime("%d-%m-%Y")

    args = ['wget', '-N', '-P', location, '-a', 'out-'+log_date+'.log', url1]
    args_prelim = ['wget', '-N', '-P', location, '-a', 'out-'+log_date+'_prelim.log', url_prelim]

    output = Popen(args, stdout=None)
    output = Popen(args_prelim, stdout=None)

def main():
    # Save the inputted year
    inputs=parse_input()
    year = inputs["year"]

    # Set the date range for the requested year.
    # Takes into account leap years.
    start_date = date(year, 1, 1)
    if year == date.today().year:
        end_date = date(year, date.today().month, date.today().day)
    else:
        end_date = date(inputs["year"], 12, 31)

    # Make sure the folder for this year exists:
    folder_exist(year)

    # Loop through all the dates and download the required files:
    for single_date in daterange(start_date, end_date):
        YMD = single_date.strftime("%Y%m%d")
        YM = single_date.strftime("%Y%m")

        #file_download(year, YMD, YM)
        bash_wget(year, YMD, YM)

        # Remove any redundant prelim file
        rm_prelim(year, YMD, YM)

# Run the script.
if __name__ == "__main__":
    main()
