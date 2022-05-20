# 7T049_CVI
Processing of 7T MRI data within CVI / Visual Brain project

Data is organised in [BIDS convention](https://bids.neuroimaging.io/specification.html)

Prodessed data are organised in `/derivatives`. Inspiration on nameing conventions can be taken from [dHRP 3rd data release](https://biomedia.github.io/dHCP-release-notes/structure.html) 

-------------

BIDS conversion is set up using [heudiconv](https://heudiconv.readthedocs.io/en/latest/) (a heuristic-centric DICOM converter), mimicking the tutorial [here](http://reproducibility.stanford.edu/bids-tutorial-series-part-2a/).

For quality assessment of sMRI and rs-fMRI, [MRIQC](https://mriqc.readthedocs.io/en/stable/) is used. For dMRI, the QC outputs from FSL `eddy` or `eddy_quad` will be used. 
