
<!-- README.md is generated from README.Rmd. Please edit that file -->

# paleocar_v2

<!-- badges: start -->

<!-- badges: end -->

**DEPRECATION WARNING**

The PaleoCAR v2 dataset has been superceded by the [PaleoCAR v3
dataset](https://github.com/bocinsky/paleocar_v3). New analyses should
use those data.

------------------------------------------------------------------------

This is an archive of the PaleoCAR v2 paleoclimate reconstruction
datasets originally published in Science Advances:

Bocinsky, R.K.; Rush, J.; Kintigh, K.W.; Kohler, T.A. (2016-04-01):
NOAA/WDS Paleoclimatology - SW USA 2000 Year Growing Degree Days and
Precipitation Reconstructions.

The dataset is available as tiled NetCDF files as part of the NOAA
National Centers for Environmental Information Paleoclimate archive at
[https://doi.org/10.25921/8ctk-8v26](DOI%2010.25921/8ctk-8v26).

The PaleoCAR v2 data are high spatial resolution (30 arc-second)
Southwestern United States tree-ring reconstructions of May-September
Growing-degree Days (GDD) and Net Water-year Precipitation (previous
October - current November). The reconstructions were performed using
the “PaleoCAR” method detailed in Bocinsky and Kohler (2014), as updated
in Bocinsky et al. (2016).

The script in this repository downloads the archived tiled data, mosaics
them together, writes them as cloud-optimized GeoTiffs, and uploads them
to an Amazon AWS S3 bucket at
<https://skope.s3.us-west-2.amazonaws.com/index.html>. These files are
then able to be queried remotely.
