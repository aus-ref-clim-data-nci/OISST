#!/usr/bin/env python
"""
Copyright 2022 ARC Centre of Excellence for Climate Systems Science

author: Sam Green <sam.green@unsw.edu.au>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

This script is used to download and/or update the OISST dataset on
    the NCI server from https://ncei.noaa.gov/data/sea-surface-temperature-optimum-interpolation/v2.1/access/avhrr/
Last change:
    2022-09-27

Usage:
 Required inputs:
   y - year to download/update

 Optional inputs:
   st - start day & month, eg: for 1st Feb use -st 1 2
   en - end day & month, eg: for 31st Mar use -st 31 3

To check options, use: 
   python3 oisst_dl.py -h

Logging:
    - wget output info is saved to out-'today date'.log
    - wget output for preliminary files saved to out-'today date'_prelim.log
 
Uses the following modules:
from datetime import date, timedelta
import argparse
import os
import sys
from subprocess import Popen

Works with python 3, and should work with python 2 (but not tested).
"""

from datetime import date, timedelta
import argparse
import os
import sys
from subprocess import Popen

# Variables needed:
url = 'https://www.ncei.noaa.gov/data/sea-surface-temperature-optimum-interpolation/v2.1/access/avhrr/'
FILE = 'oisst-avhrr-v02r01.'
FILETYPE = '.nc'
PRELIM = '_preliminary.nc'
PATH_BASE = '/g/data/ia39/aus-ref-clim-data-nci/oisst/data/tmp/'


def parse_input():
    ''' Parse input arguments '''
    parser = argparse.ArgumentParser(description='''Download OISST netcdf files from ncei.noaa.gov and 
    store them in directories by year. 
             Usage: python3 oisst_dl.py -y <year>
                If you just enter the year it defaults to (01/01--31/12), or (01/01--Today) if using the current year. 
                    Please see below options to specify specific dates in the year.''', formatter_class=argparse.RawTextHelpFormatter)
    parser.add_argument('-y','--year', type=int, help='year to process',
                        required=True)
    parser.add_argument('-st','--start', nargs='+', help='start day & month, eg: for 1st Feb use -st 1 2',
                        required=False)
    parser.add_argument('-en','--end', nargs='+', help='end day & month, eg: for 31st Mar use -st 31 3',
                        required=False)
    return vars(parser.parse_args())  


def set_dates():
    '''Set the date range for the requested year.
       Takes into account leap years. '''
    inputs=parse_input()
    year = inputs["year"]
    first = inputs["start"]
    last = inputs["end"]

    # Set the end dates
    if last == None:
        if year == date.today().year:
            end_date = date(year, date.today().month, date.today().day)
        else:
            end_date = date(year+1, 1, 1)
    elif len(last) == 2:
        end_date = date(year, int(last[1]), int(last[0]))
    else:
        sys.exit("Error - End date (-en) has to include 2 values. eg: for 31st Mar use -en 31 3")

    # Set the starting dates
    if first == None:
        start_date = date(year, 1, 1)
    elif len(first) == 2:
        start_date = date(year, int(first[1]), int(first[0]))
    else:
        sys.exit("Error - Start date (-st) has to include 2 values. eg: for 31st Mar use -st 31 3")

    return {'start': start_date, 'end': end_date}


def daterange(start_date, end_date):
    '''Creates a list of the dates in the specified year'''
    for n in range(int((end_date - start_date).days)):
        yield start_date + timedelta(n)

def folder_exist(year):
    '''Checks if the yearly directory exists, creates it if not.'''
    dir_year=str(year)
    path = PATH_BASE+dir_year
    isExist = os.path.exists(path)
    if isExist == False:
        print('Folder'+' '+dir_year+' '+'does not exist')
        os.mkdir(path)
    else:
        print('Folder'+' '+dir_year+' '+'exists')

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

def bash_wget(year, YMD, YM):
    '''Using subprocess to run wget to download any missing files,
    or to update any files that are newer on the data server.'''
    dir_year=str(year)
    YMD_file = str(YMD)
    YM_file = str(YM)

    url1 = url+str(YM_file)+'/'+FILE+str(YMD_file)+FILETYPE
    url_prelim = url+str(YM_file)+'/'+FILE+str(YMD_file)+PRELIM

    location = PATH_BASE+dir_year+'/'

    today = date.today()
    log_date = today.strftime("%d-%m-%Y")

    args = ['wget', '-N', '-P', location, '-a', 'out-'+location+log_date+dir_year+'.log', url1]
    args_prelim = ['wget', '-N', '-P', location, '-a', 'out-'+location+log_date+dir_year+'_prelim.log', url_prelim]

    output = Popen(args, stdout=None)
    output = Popen(args_prelim, stdout=None)

def main():
    '''Main function to combine everything together.'''

    inputs=parse_input()
    year = inputs["year"]

    # Make sure the folder for this year exists:
    folder_exist(year)

    # Loop through all the dates and download the required files:
    for single_date in daterange(set_dates()['start'], set_dates()['end']):
        YMD = single_date.strftime("%Y%m%d")
        YM = single_date.strftime("%Y%m")

        bash_wget(year, YMD, YM)

        # Remove any redundant prelim file
        rm_prelim(year, YMD, YM)

# Run the script.
if __name__ == "__main__":
    main()
