#!/bin/bash
# 7T_049_Visual_Brain
#
usage()
{
  base=$(basename "$0")
  echo "usage: $base subjectID [options]
Script to preprocess dMRI data 
1. MP-PCA Denoising and Gibbs Unringing 
2. TOPUP and EDDY for motion- and susceptebility image distortion correction
3. N4 biasfield correction, Normalisation

Arguments:
  sID				Subject ID (e.g. 7T049S01) 

Options:
  -dwiAP			dMRI AP data (default: rawdata/sub-sID/dwi/sub-sID_dir-AP_run-1_dwi.nii.gz)
  -dwiPA			dMRI PA data, potentially for TOPUP  (default: rawdata/sub-sID/dwi/sub-sID_dir-PA_run-1_dwi.nii.gz)
  -b0APvol			b0 volume in dMRI AP data to use in TOPUP (default: 0)
  -b0PAvol			b0 volume in dMRI PA data to use in TOPUP (default: 0)
  -d / -data-dir  <directory>   The directory used to output the preprocessed files (default: derivatives/dMRI/sub-sID)
  -t / -threads	  		Number of threads	  		
  -h / -help / --help           Print usage.
"
  exit;
}

################ ARGUMENTS ################

[ $# -ge 1 ] || { usage; }
command=$@
sID=$1

shift; 

studydir=$PWD

# Defaults
dwiAP=rawdata/sub-$sID/dwi/sub-${sID}_dir-AP_run-1_dwi.nii.gz
dwiPA=rawdata/sub-$sID/dwi/sub-${sID}_dir-PA_run-1_dwi.nii.gz
b0APvol=0
b0PAvol=0
datadir=derivatives/dMRI/sub-$sID

# check whether the different tools are set and load parameters
codedir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

while [ $# -gt 0 ]; do
    case "$1" in
	-dwiAP) shift; dwiAP=$1; ;;
	-dwiPA) shift; dwiPA=$1; ;;
	-b0APvol) shift; b0APvol=$1; ;;
	-b0PAvol) shift; b0PAvol=$1; ;;
	-d|-data-dir)  shift; datadir=$1; ;;
	-h|-help|--help) usage; ;;
	-*) echo "$0: Unrecognized option $1" >&2; usage; ;;
	*) break ;;
    esac
    shift
done

# Check if images exist, else put in No_image
if [ ! -f $dwiAP ]; then dwiAP=""; fi
if [ ! -f $dwiPA ]; then dwiPA=""; fi

echo "dMRI-preprocessing
Subject:       $sID 
DWI (AP):      $dwiAP
DWI (PA):      $dwiPA
b0APvol:       $b0APvol
b0PAvol:       $b0PAvol	       
Directory:     $datadir
Threads:       $threads 
$BASH_SOURCE   $command
----------------------------"

logdir=$datadir/logs
if [ ! -d $datadir ];then mkdir -p $datadir; fi
if [ ! -d $logdir ];then mkdir -p $logdir; fi

echo dMRI preprocessing on subject $sID
script=`basename $0 .sh`
echo Executing: $codedir/dMRI/$script.sh $command > ${logdir}/sub-${sID}_dMRI_$script.log 2>&1
echo "" >> ${logdir}/sub-${sID}_dMRI_$script.log 2>&1
echo "Printout $script.sh" >> ${logdir}/sub-${sID}_dMRI_$script.log 2>&1
cat $codedir/$script.sh >> ${logdir}/sub-${sID}_dMRI_$script.log 2>&1
echo

##################################################################################
# 0. Create subfolder structure in $datadir

cd $datadir
if [ ! -d anat ]; then mkdir -p anat; fi
if [ ! -d dwi ]; then mkdir -p dwi; fi
if [ ! -d fmap ]; then mkdir -p fmap; fi
if [ ! -d xfm ]; then mkdir -p xfm; fi
if [ ! -d qc ]; then mkdir -p qc; fi
cd $studydir

##################################################################################
# 0. Copy to files to datadir/preproc (incl .json and bvecs/bvals files if present at original location)

if [ ! -d $datadir/dwi/orig ]; then mkdir -p $datadir/dwi/orig; fi

filelist="$dwiAP $dwiPA"
for file in $filelist; do
    filebase=`basename $file .nii.gz`;
    filedir=`dirname $file`
    cp $file $filedir/$filebase.json $filedir/$filebase.bval $filedir/$filebase.bvec $datadir/dwi/orig/.
done

#Then update variables to only refer to filebase names (instead of path/file)
dwiAP=`basename $dwiAP .nii.gz` 
dwiPA=`basename $dwiPA .nii.gz`

##################################################################################
# 0. Create dwi.mif.gz to work with in /preproc and b0APPA.mif.gz in /preproc/topup

if [ ! -d $datadir/dwi/preproc/topup ]; then mkdir -p $datadir/dwi/preproc/topup; fi

cd $datadir

if [[ $dwiAP = "" ]];then
    echo "No dwiAP data provided";
    exit;
else
    # Create a dwiAP.mif.gz-file to work with
    if [ ! -f dwi/preproc/dwiAP.mif.gz ]; then
	mrconvert -strides -1,2,3,4 -json_import dwi/orig/$dwiAP.json -fslgrad dwi/orig/$dwiAP.bvec dwi/orig/$dwiAP.bval -import_pe_table $codedir/../sequences/petable_dwi_acq-se_dir-AP_dwi.txt dwi/orig/$dwiAP.nii.gz dwi/preproc/dwiAP.mif.gz
    fi
fi

if [[ $dwiPA = "" ]]; then
    echo "No dwiPA data provided";
    exit;
else
    # Create a dwiPA.mif.gz-file to work with
    if [ ! -f dwi/preproc/dwiPA.mif.gz ]; then
	mrconvert -strides -1,2,3,4 -json_import dwi/orig/$dwiPA.json -fslgrad dwi/orig/$dwiPA.bvec dwi/orig/$dwiPA.bval -import_pe_table $codedir/../sequences/petable_dwi_acq-se_dir-PA_dwi.txt dwi/orig/$dwiPA.nii.gz dwi/preproc/dwiPA.mif.gz
    fi
fi

# Split data into data for different shells 
cd dwi/preproc

if [ ! -f dwi.mif.gz ]; then

    for dir in AP PA; do

	# 1. extract higher shells and put in a joint file
	if [ $dir == AP ]; then
	    dwiextract -shells 1000,2600 dwi$dir.mif.gz tmp_dwi${dir}_b1000b2600.mif
	fi
	if [ $dir == PA ]; then
	    dwiextract -shells 1000 dwi$dir.mif.gz tmp_dwi${dir}_b1000.mif
	fi

	# 2. extract the b0 that will be used for TOPUP by
	# a) noting correct volume
	if [ $dir == AP ]; then b0topup=$b0APvol; fi
	if [ $dir == PA ]; then b0topup=$b0PAvol; fi
	# b) and put in /topup/tmp_b0$dir.mif
	mrconvert -coord 3 $b0topup -axes 0,1,2 dwi$dir.mif.gz topup/tmp_b0$dir.mif
	# c) and extract b0s from dwi$dir.mif where the b0 for TOPUP will be placed first (by creating and an indexlist)
	indexlist=$b0topup;
	for index in `mrinfo -shell_indices dwi$dir.mif.gz | awk '{print $1}' | sed 's/\,/\ /g'`; do
	    if [ ! $index == $b0topup ]; then
		indexlist=`echo $indexlist,$index`;
	    fi
	    echo $indexlist;
	done
	mrconvert -coord 3 $indexlist dwi$dir.mif.gz tmp_dwi${dir}_b0.mif
	
    done
    
    # Put everything into file dwi.mif.gz, with AP followed by PA volumes
    # FL 2021-12-20 - NOTE TOPUP and EDDY not working properly for dirPA, so only use dirAP to go into dwi.mif.gz
    mrcat -axis 3 tmp_dwiAP_b0.mif tmp_dwiAP_b1000b2600.mif dwi.mif.gz

    # clean-up
    rm tmp_dwi*.mif
    
fi

# Sort out topup/b0APPA.mif.gz
cd topup
if [ ! -f b0APPA.mif.gz ]; then
    mrcat -axis 3 tmp_b0AP.mif tmp_b0PA.mif b0APPA.mif.gz
    #clean-up
    rm tmp_dwi*_b0.mif
fi
    
cd $studydir

##################################################################################
# 1. Do PCA-denoising and Remove Gibbs Ringing Artifacts
cd $datadir/dwi/preproc

# Directory for QC files
if [ ! -d denoise ]; then mkdir denoise; fi

# Perform PCA-denosing
if [ ! -f dwi_den.mif.gz ]; then
    echo Doing MP PCA-denosing with dwidenoise
    # PCA-denoising
    dwidenoise dwi.mif.gz dwi_den.mif.gz -noise denoise/dwi_noise.mif.gz;
    # and calculate residuals
    mrcalc dwi.mif.gz dwi_den.mif.gz -subtract denoise/dwi_den_residuals.mif.gz
    echo Check the residuals! Should not contain anatomical structure
fi

# Directory for QC files
if [ ! -d unring ]; then mkdir unring; fi

if [ ! -f dwi_den_unr.mif.gz ]; then
    echo Remove Gibbs Ringing Artifacts with mrdegibbs
    # Gibbs 
    mrdegibbs -axes 0,1 dwi_den.mif.gz dwi_den_unr.mif.gz
    #calculate residuals
    mrcalc dwi_den.mif.gz  dwi_den_unr.mif.gz -subtract unring/dwi_den_unr_residuals.mif.gz
    echo Check the residuals! Should not contain anatomical structure
fi

cd $studydir

##################################################################################
# 2. TOPUP and EDDY for Motion- and susceptibility distortion correction

cd $datadir/dwi/preproc

if [ ! -d topup ]; then mkdir -p topup; fi
if [ ! -d eddy ]; then mkdir -p eddy; fi

cd topup

# Create b0APPA.mif.gz to go into TOPUP
if [ ! -f b0APPA.mif.gz ];then
    echo "Create a PErevPE pair of SE images to use with TOPUP
1. Do this by put one good b0 from dir-AP_dwi and dir-PA_dwi into a file b0APPA.mif.gz into $datadir/dwi/preproc/topup
2. Run this script again.    
    	 "
    exit;
fi

# create input files from b0APPA.mif.gz
if [ ! -f topup_in.nii.gz ]; then
    mrconvert b0APPA.mif.gz topup_in.nii.gz -strides -1,+2,+3,+4 -export_pe_table topup_datain.txt
fi

# RUN TOPUP
if [ ! -f field_mag_unwarped.nii.gz ]; then 
    echo running TOPUP
    topup --imain=topup_in.nii.gz --datain=topup_datain.txt --out=field --fout=field_fieldmap.nii.gz --config=$FSLDIR/etc/flirtsch/b02b0.cnf --verbose --iout=field_mag_unwarped
    fslmaths field_mag_unwarped.nii.gz -Tmean field_magnitude.nii.gz
fi
# Create a mask
if [ ! -f field_magnitude_brain_mask.nii.gz ]; then
    bet field_magnitude.nii.gz field_magnitude_brain.nii.gz -m -R -F
fi

cd ../eddy

# Create brain mask eddy_mask_edit.nii.gz to go inte EDDY.
if [ ! -f eddy_mask_edit.nii.gz ]; then
    # use brain mask from topup 
    mrconvert -datatype float32 ../topup/field_magnitude_brain_mask.nii.gz eddy_mask.nii.gz
    echo edit brain mask and save into eddy/eddy_mask.nii.gz
    mrview ../topup/field_magnitude.nii.gz -roi.load eddy_mask.nii.gz -roi.opacity 0.5 -mode 2
    
fi

# Create input to EDDY
if [ ! -f eddy_in.nii.gz ]; then
    mrconvert -strides -1,2,3,4 ../dwi_den_unr.mif.gz eddy_in.nii.gz -export_pe_eddy eddy_config.txt eddy_indices.txt -export_grad_fsl bvecs bvals -json_export eddy_in.json
fi
# RUN EDDY
slspecfile=$codedir/../sequences/slspec_MB1_60slices_interleaved.txt
cp $slspecfile slspec.txt
if [ ! -f ../dwi_den_unr_eddy.mif.gz ]; then
    eddy_cuda9.1 --imain=eddy_in.nii.gz --mask=eddy_mask_edit.nii.gz --acqp=eddy_config.txt --index=eddy_indices.txt --bvecs=bvecs --bvals=bvals --topup=../topup/field --slm=linear --repol --mporder=8 --s2v_niter=10 --s2v_interp=trilinear --s2v_lambda=1 --estimate_move_by_susceptibility --mbs_niter=20 --mbs_ksp=10 --mbs_lambda=10 --slspec=slspec.txt --out=dwi_post_eddy --verbose
    # eddy quad
    #eddy_quad dwi_post_eddy -idx eddy_indices.txt -par eddy_config.txt -b bvals -m eddy_mask_edit.nii.gz -f ../topup/field_fieldmap.nii.gz -s slspec.txt
    mrconvert dwi_post_eddy.nii.gz ../dwi_den_unr_eddy.mif.gz -strides -1,2,3,4 -fslgrad dwi_post_eddy.eddy_rotated_bvecs bvals
fi

cd $studydir

##-------------------------------------

##################################################################################
# 3. Mask generation, N4 biasfield correction, meanb0 generation and tensor estimation

if [ ! -d $datadir/dwi/preproc/N4 ]; then mkdir -p $datadir/dwi/preproc/N4; fi

cd $datadir/dwi/preproc

echo "Pre-processing with mask generation, N4 biasfield correction, Normalisation, meanb0 generation and tensor estimation"

# point to right filebase
dwi=dwi_den_unr_eddy

# Create mask for N4 biasfield correction from b1000
if [ ! -f N4/N4_mask.mif.gz ]; then
    mrconvert eddy/eddy_mask_edit.nii.gz N4/N4_mask.mif.gz 
fi

# Do B1-correction. Use ANTs N4
if [ ! -f  ${dwi}_N4.mif.gz ]; then
    threads=10;
    dwibiascorrect ants -nthreads $threads -mask N4/N4_mask.mif.gz -bias N4/bias.mif.gz $dwi.mif.gz ${dwi}_N4.mif.gz
fi


# last file in the processing
dwipreproclast=${dwi}_N4.mif.gz

cd $studydir


##################################################################################
## 3. B0-normalise, create meanb0 and do tensor estimation

cd $datadir/dwi

if [ ! -f dwi_preproc.mif.gz ]; then
    mrconvert preproc/$dwipreproclast dwi_preproc.mif.gz
fi
dwi=dwi_preproc

# Create brain mask for normalization 
if [ ! -f mask.mif.gz ]; then
    mrconvert preproc/eddy/eddy_mask_edit.nii.gz mask.mif.gz
fi

# B0-normalisation
if [ ! -f ${dwi}_norm.mif.gz ];then
    dwinormalise individual $dwi.mif.gz mask.mif.gz ${dwi}_inorm.mif.gz
fi

# Extract mean b0, b1000 and b2600
for bvalue in 0 1000 2600; do
    bfile=meanb$bvalue
    if [ ! -f $bfile.nii.gz ]; then
	dwiextract -shells $bvalue ${dwi}_inorm.mif.gz - |  mrmath -force -axis 3 - mean $bfile.mif.gz
	mrcalc $bfile.mif.gz mask.mif.gz -mul ${bfile}_brain.mif.gz
	echo "Visually check the ${bfile}_brain"
	echo mrview ${bfile}_brain.nii.gz -mode 2
    fi
done

# Calculate diffusion tensor and tensor metrics

if [ ! -f dt.mif.gz ]; then
    dwi2tensor -mask mask.mif.gz ${dwi}_inorm.mif.gz dt.mif.gz
    tensor2metric -force -fa fa.mif.gz -adc adc.mif.gz -rd rd.mif.gz -ad ad.mif.gz -vector ev.mif.gz dt.mif.gz
fi

cd $studydir
