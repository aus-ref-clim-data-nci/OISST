# OISST
  
## Overview

The NOAA 1/4 degree Daily Optimum Interpolation Sea Surface Temperature (OISST) is a long term Climate Data Record that incorporates observations from different platforms (satellites, ships, buoys and Argo floats) into a regular global grid. The dataset is interpolated to fill gaps on the grid and create a spatially complete map of sea surface temperature. Satellite and ship observations are referenced to buoys to compensate for platform differences and sensor biases.

OISST v2.1 replaced v2 on April 1, 2020. V2 stopped production on April 26, 2020 after its input datasets were discontinued. Data are currently available from September 1, 1981—present, and updated every day. V2.1 has significant quality improvements for data from January 1, 2016 onward.

Note: For September 1981—December 2015, data for SST and SST anomaly are the same as v2, but have been updated from netCDF3 to netCDF4 with updated metadata in v2.1.

More information and a detailed description of the algorithm and data sources used are available on the [NASA OISST website](https://www.ncei.noaa.gov/products/optimum-interpolation-sst).

## Data download

The data is downloaded from [ncei.noaa.gov](https://www.ncei.noaa.gov/data/sea-surface-temperature-optimum-interpolation/v2.1/access/avhrr/) using wget. This data is updated regularly, every ~1-2 days.
Since the original daily files are relatively small in size (~1.6mb), they are then concatenated in yearly files using CDO and rechunked using NCO.
Updates are run with a weekly frequency via the [accessdev Jenkins server](https://accessdev.nci.org.au/jenkins/job/aus-ref-clim-data-nci/job/OISST/).

The code used to download the files is python based, to see all the options:
```{code}
    python3 oisst.py --help
```
The code used to concatenate the files is a python script calling CDO and NCO:
```{code}
    module load cdo
    module load nco

    ./oisst_concat.py <yr> 
```

## Data location

OISST data is available in

```
/g/data/ia39/aus-ref-clim-data-nci/oisst/data/tmp/<year>/<files>  -- Daily files located here.
/g/data/ia39/aus-ref-clim-data-nci/oisst/data/yearly/<files> -- Yearly files here.
```

## License

This dataset is freely available, there are no use limitations or accounts needed. Although there is an optional registration form that can be reached from the documentation page in the NOAA website under the "data access" session. Please consider [register](https://docs.google.com/a/noaa.gov/forms/d/1zZQKz1qF5Wk7sqQuQmxCiBI4Y-xgtKcBqCykMtW21Dk/viewform?c=0&w=1), so you'll receive updates on the data and as this also helps the data publishers to get an idea of the data usefulness and continue providing for public access.  


## Data citation

Cite as: Huang, Boyin; Liu, Chunying; Banzon, Viva F.; Freeman, Eric; Graham, Garrett; Hankins, Bill; Smith, Thomas M.; Zhang, Huai-Min. (2020): NOAA 0.25-degree Daily Optimum Interpolation Sea Surface Temperature (OISST), Version 2.1. [indicate subset used]. NOAA National Centers for Environmental Information. https://doi.org/10.25921/RE9P-PT57. Accessed [date].


## References

Huang, B., C. Liu, V. Banzon, E. Freeman, G. Graham, B. Hankins, T. Smith, and H.-M. Zhang, 2020: Improvements of the Daily Optimum Interpolation Sea Surface Temperature (DOISST) Version 2.1, Journal of Climate, 34, 2923-2939. [doi:10.1175/JCLI-D-20-0166.1](https://journals.ametsoc.org/view/journals/clim/34/8/JCLI-D-20-0166.1.xml)
Banzon, V., Smith, T. M., Chin, T. M., Liu, C., and Hankins, W., 2016: A long-term record of blended satellite and in situ sea-surface temperature for climate monitoring, modeling and environmental studies. Earth Syst. Sci. Data, 8, 165–176, [doi:10.5194/essd-8-165-2016](http://www.earth-syst-sci-data.net/8/165/2016/essd-8-165-2016.html)
Reynolds, R. W., T. M. Smith, C. Liu, D. B. Chelton, K. S. Casey, and M. G. Schlax, 2007: Daily high-resolution-blended analyses for sea surface temperature. Journal of Climate, 20, 5473–5496, [doi:10.1175/JCLI-D-14-00293.1](http://dx.doi.org/10.1175/2007JCLI1824.1)

A [full reference list](https://www.ncei.noaa.gov/products/optimum-interpolation-sst) is provided with the main documentation.

## Acknowledgement

No statement provided.

## Author note


## Assistance

For assistance with OISST data on NCI, open a new issue at https://github.com/aus-ref-clim-data-nci/OISST/issues


