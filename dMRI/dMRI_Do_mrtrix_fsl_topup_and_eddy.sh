#!/bin/bash
# 7T_049_Visual_Brain - pilot (with BIDS)
# Does Topup on SE fieldmap and Eddy on dwi_data (e.g. dwi_APPA_den_unr.mif.gz)
#
# Input:
# $1 = subject (e.g. 106SI)
# $2 = dMRI data (full relative path, e.g. after denoising and unringing, with extention .mif.gz)
# $3 = fmap SE dir-AP for topup (full relative path, NO MOTION with extension .mif.gz)
# $4 = fmap SE dir-PA for topup (full relative path, NO MOTION with extension .mif.gz)
# $5 (optional) = slspec.txt file for s2v with EDDY (full relative path)
# $6 (optional) = topup_in.txt file for TOPUP (full relative path)
#
# Output:
# topup folder derivatives/dmri_mrtrix_pipeline/topup
# eddy folder derivatives/dmri_mrtrix_pipeline/eddy
# eddy corrected 

rootpath=`pwd`;

SubjectID=$1 #subj (e.g. 106SI)
derivativespath=`dirname $2`;
dwi=`basename $2 .mif.gz`; # e.g. "relativepath"/dwi_dir-APPA_den_unr.mif.gz
se_ap=$3; # e.g. "relativepath"/sub-106SI_acq-se_dir-AP_desc-nomotion_epi.mif.gz
se_pa=$4; # e.g. "relativepath"/sub-106SI_acq-se_dir-PA_desc-nomotion_epi.mif.gz

if [ $# -gt 4 ]; then
    slspec_file=$5;
else
    slspec_file=sequences/slspec_MB1_60slices_interleaved.txt #located in /sequences
fi
if [ $# -gt 5 ]; then
    topup_file=$5;
else
    topup_file=sequences/fmap_se_topup_in_dir-APPA.txt #located in /sequences
fi

# Do Topup
if [ ! -d $derivativespath/eddy/topup ]; then echo "making topup folder"; mkdir -p $derivativespath/eddy/topup; fi
# put $slpec_file and $topup_file in eddy/topup-folders
if [ ! -f $derivativespath/eddy/slspec.txt ]; then cp $slspec_file $derivativespath/eddy/slspec.txt; fi
if [ ! -f $derivativespath/eddy/topup/topup_datain.txt ]; then cp $topup_file $derivativespath/eddy/topup/topup_datain.txt; fi
# create combined fmap_se_APPA file
if [ ! -f $derivativespath/eddy/topup/topup_in.nii.gz ]; then
    mrcat $se_ap $se_pa $derivativespath/eddy/topup/topup_in.nii.gz;
fi


# Go to dMRI data location (in $derivativspath)
cd $derivativespath

if [ -f eddy/topup/fmap_se_fieldcoef.nii.gz ]; then
    echo "TOPUP has already been performed"
else
    echo "Performing TOPUP"
    topup --imain=eddy/topup/topup_in --datain=eddy/topup/topup_datain.txt --out=eddy/topup/fmap_se --fout=eddy/topup/fmap_se_field
fi

# Creating hifi magnitude image
if [ ! -f eddy/topup/fmap_se_mag.nii.gz ]; then
    mrconvert -coord 3 0 eddy/topup/topup_in.nii.gz eddy/topup/topup_in_1.nii.gz
    mrconvert -coord 3 1 eddy/topup/topup_in.nii.gz eddy/topup/topup_in_2.nii.gz
    applytopup --imain=eddy/topup/topup_in_1,eddy/topup/topup_in_2 --inindex=1,2 --datain=eddy/topup/topup_datain.txt --topup=eddy/topup/fmap_se --out=eddy/topup/fmap_se_mag
fi

# Do Eddy
if [ ! -d eddy ]; then mkdir eddy; fi
# Put correct files in eddy-subfolder
if [ ! -f eddy/eddy_in.nii.gz ]; then
    #mrconvert $dwi.mif.gz eddy/eddy_in.nii.gz -export_grad_fsl eddy/bvecs eddy/bvals -export_pe_eddy eddy/eddy_config.txt eddy/eddy_indices.txt -json_export eddy/eddy_in.json
    #mrconvert -export_grad_fsl eddy/bvecs eddy/bvals $dwi.mif.gz eddy/eddy_in.nii.gz  
fi

# Now create a BET-brain mask (note - needs -f 0.1 to increase the size of the mask)
if [ ! -f eddy/topup/fmap_se_mag_brain ]; then
    bet eddy/topup/fmap_se_mag eddy/topup/fmap_se_mag_brain -m -f 0.15
fi
#  and dilate and put into eddy_mask
if [ ! -f eddy/eddy_mask.nii.gz ]; then
    maskfilter eddy/topup/fmap_se_mag_brain_mask.nii.gz dilate eddy/eddy_mask.nii.gz
fi
# Performing eddy
if [ -f eddy/eddy_in_post_eddy.nii.gz ]; then
    echo "EDDY has already been performed"
else
    # Running eddy_cuda
    echo "Running EDDY with eddy_cuda"
    #eddy_cuda --imain=eddy/eddy_in --mask=eddy/eddy_mask --acqp=eddy/eddy_config.txt --index=eddy/eddy_indices.txt --bvecs=eddy/bvecs --bvals=eddy/bvals --topup=eddy/topup/fmap_se --niter=8 --fwhm=10,8,4,2,0,0,0,0 --repol --out=eddy/eddy_in_post_eddy --mporder=6 --slspec=eddy/slspec.txt --s2v_niter=5 --s2v_lambda=1 --s2v_interp=trilinear --cnr_maps --residuals
fi

eddy_qc_folder=eddy/eddy_in_post_eddy.qc;
if [ -d $eddy_qc_folder ] ; then
    echo "EDDY QC has been performed"
else
    echo "Running EDDY QC with eddy_quad"
    #eddy_quad eddy/eddy_in_post_eddy -idx eddy/eddy_indices.txt -par eddy/eddy_config.txt -m eddy/eddy_mask -b eddy/bvals -g eddy/bvecs -s eddy/slspec.txt -f eddy/topup/fmap_se_map
    # NOTE - vols_no_outliers.txt not yet implemented as output from eddy_quad
    # fslselectvols -i eddy/eddy_in_post_eddy -o eddy/eddy_in_post_eddy_clean --vols=$eddy_qc_folder/vols_no_outliers.txt
fi
    
# and transforming back
if [ ! -f ${dwi}_eddy.mif.gz ]; then
    echo "transform the results back"
    #mrconvert -fslgrad eddy/bvecs eddy/bvals -import_pe_eddy eddy/eddy_config.txt eddy/eddy_indices.txt -json_import eddy/eddy_in.json eddy/eddy_in_post_eddy.nii.gz ${dwi}_eddy.mif.gz
    # NOTE - change? once vol_no_outliers.txt becomes available?
    # mrconvert -fslgrad eddy/bvecs eddy/bvals -import_pe_eddy eddy/eddy_config.txt eddy/eddy_indices.txt -json_import eddy/eddy_in.json eddy/eddy_in_post_eddy_clean.nii.gz ${dwi}_eddy_clean.mif.gz 
fi

# Go back to origin = $rootpath
cd $rootpath


