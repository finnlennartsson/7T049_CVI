#!/bin/bash
# 7T_049_Visual_Brain - pilot (kind of in a BIDS format)
#
# Sets up dMRI folder in /derivatives and performs denoising and uringing on raw dMRI data (mrtrix3's dwidenoise and mrdegibbs) 
#
# Input:
# $1 = subject = SubjectID (e.g. 106SI)
# $2 = raw dMRI AP data, with extention (full relative path, but typically located in sub-$SubjectID/dwi)
# $3 (optional) = raw dMRI PA data, with extention (full relative path, but typically located in sub-$SubjectID/dwi)
#
# Output:
# preprocessed (denoised and unringing) dMRI in derivatives/dmri_mrtrix_pipeline/sub-$SubjectID
#

## To CODE_DIR as global variable
source code/setup.sh
# Study/subject specific #
codeFolder=$CODE_DIR;
studyFolder=`dirname -- "$codeFolder"`;

SubjectID=$1;
#rawdatapath=$SubjectID/dwi
derivativespath=derivatives/dmri_mrtrix_pipeline/sub-$SubjectID
if [ ! -d $derivativespath ]; then mkdir -p $derivativespath; fi

# Take care of all the input arguments
# dir-AP
if [ ! -f $derivativespath/dwi_dir-AP.mif.gz ]; then
    mrconvert $2 $derivativespath/dwi_dir-AP.mif.gz
fi
dMRI=dwi_dir-AP; #defines the raw dMRI data in /$derivativespath
# dir-PA, if given
if [ $# -gt 2 ]; then
    if [ ! -f $derivativespath/dwi_dir-PA.mif.gz ]; then
        mrconvert $3 $derivativespath/dwi_dir-PA.mif.gz
    fi
    if [ ! -f $derivativespath/dwi_dir-APPA.mif.gz ]; then
      mrcat $derivativespath/dwi_dir-AP.mif.gz $derivativespath/dwi_dir-PA.mif.gz $derivativespath/dwi_dir-APPA.mif.gz
    fi  
    dMRI=dwi_dir-APPA;  #defines the raw dMRI data in /$derivativespath
fi

echo "Preparing dMRI, doing denoise (dwidenoise MP-PCA) and unringing (mrdegibbs) on $SubjectID"

# Do denoising on dwi series
if [ -f $derivativespath/${dMRI}_den.mif.gz ]; then echo $derivativespath/${dMRI}_den.mif.gz already exists;
else
    echo "Doing MP-PCA dwidenoise on $SubjectID"
    dwidenoise $derivativespath/$dMRI.mif.gz $derivativespath/${dMRI}_den.mif.gz -noise $derivativespath/${dMRI}_noise.mif.gz;
    #calculate residuals
    mrcalc $derivativespath/$dMRI.mif.gz $derivativespath/${dMRI}_den.mif.gz -subtract $derivativespath/${dMRI}_den_residuals.mif.gz
    # Visual inspection of dMRI denoised data by inspecting the different shells
    echo "Do visual inspection of dMRI denoised data - shell per shell"
    echo "Check the residuals! Should not contain anatomical structure"
fi

# Do unringing on denoised on dwi series
if [ -f $derivativespath/${dMRI}_den_unr.mif.gz ]; then echo $derivativespath/${dMRI}_den_unr.mif.gz already exists;
else
    echo "Doing unringing with mrdegibbs on $SubjectID"
    mrdegibbs -axes 0,1 $derivativespath/${dMRI}_den.mif.gz $derivativespath/${dMRI}_den_unr.mif.gz
    #calculate residuals
    mrcalc $derivativespath/${dMRI}_den.mif.gz $derivativespath/${dMRI}_den_unr.mif.gz -subtract $derivativespath/${dMRI}_den_unr_residuals.mif.gz

    # Visual inspection of dMRI denoised data by inspecting the different shells
    echo "Do visual inspection of dMRI denoised data - shell per shell"
    echo "Check the residuals! Should not contain anatomical structure"
fi


