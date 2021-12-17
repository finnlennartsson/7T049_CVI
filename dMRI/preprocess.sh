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
  -seAP				Spin-echo field map AP, for TOPUP (default: rawdata/sub-sID/fmap/sub-sID_acq-se_dir-AP_run-1_epi.nii.gz)
  -sePA				Spin-echo field map PA, for TOPUP (default: rawdata/sub-sID/fmap/sub-sID_acq-se_dir-PA_run-1_epi.nii.gz)
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
seAP=rawdata/sub-$sID/fmap/sub-${sID}_acq-se_dir-AP_run-1_epi.nii.gz
sePA=rawdata/sub-$sID/fmap/sub-${sID}_acq-se_dir-PA_run-1_epi.nii.gz
datadir=derivatives/dMRI/sub-$sID

# check whether the different tools are set and load parameters
codedir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

while [ $# -gt 0 ]; do
    case "$1" in
	-dwiAP) shift; dwi=$1; ;;
	-dwiPA) shift; dwiPA=$1; ;;
	-seAP) shift; seAP=$1; ;;
	-seAP) shift; sePA=$1; ;;
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
if [ ! -f $seAP ]; then seAP=""; fi
if [ ! -f $sePA ]; then sePA=""; fi

echo "Registration and sMRI-processing
Subject:       $sID 
DWI (AP):      $dwiAP
DWI (PA):      $dwiPA
SE fMAP (AP):  $seAP	       
SE fMAP (PA):  $sePA	       
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

filelist="$dwiAP $dwiPA $seAP $sePA"
for file in $filelist; do
    filebase=`basename $file .nii.gz`;
    filedir=`dirname $file`
    cp $file $filedir/$filebase.json $filedir/$filebase.bval $filedir/$filebase.bvec $datadir/dwi/orig/.
done

#Then update variables to only refer to filebase names (instead of path/file)
dwiAP=`basename $dwiAP .nii.gz` 
dwiPA=`basename $dwiPA .nii.gz`
seAP=`basename $seAP .nii.gz`
sePA=`basename $sePA .nii.gz`


##################################################################################
# 0. Create dwi.mif.gz to work with in /preproc

if [ ! -d $datadir/dwi/preproc ]; then mkdir -p $datadir/dwi/preproc; fi

cd $datadir

if [[ $dwiAP = "" ]];then
    echo "No dwiAP data provided";
    exit;
else
    # Create a dwiAP.mif.gz-file to work with
    if [ ! -f dwi/preproc/dwiAP.mif.gz ]; then
	mrconvert -json_import dwi/orig/$dwiAP.json -fslgrad dwi/orig/$dwiAP.bvec dwi/orig/$dwiAP.bval -import_pe_table $codedir/../sequences/petable_dwi_acq-se_dir-AP_dwi.txt dwi/orig/$dwiAP.nii.gz dwi/preproc/dwiAP.mif.gz
    fi
fi

if [[ $dwiPA = "" ]];then
    echo "No dwiAP data provided";
    exit;
else
    # Create a dwiPA.mif.gz-file to work with
    if [ ! -f dwi/preproc/dwiPA.mif.gz ]; then
	mrconvert -json_import dwi/orig/$dwiPA.json -fslgrad dwi/orig/$dwiPA.bvec dwi/orig/$dwiPA.bval -import_pe_table $codedir/../sequences/petable_dwi_acq-se_dir-PA_dwi.txt dwi/orig/$dwiPA.nii.gz dwi/preproc/dwiPA.mif.gz
    fi
fi

# We only use dwiAP in dwi.mif.gz
# Look into incorporating dwiPA as well
cd dwi/preproc
if [ ! -f dwi.mif.gz ]; then
    ln -s dwiAP.mif.gz dwi.mif.gz
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

if [ ! -d topup ]; then mkdir topup; fi

# Create b0APPA.mif.gz to go into TOPUP
if [ ! -f topup/b0APPA.mif.gz ];then
    echo "Create a PErevPE pair of SE images to use with TOPUP
1. Do this by put one good b0 from dir-AP_dwi and dir-PA_dwi into a file b0APPA.mif.gz into $datadir/dwi/preproc/topup
2. Run this script again.    
    	 "
    exit;
fi

# Create a brain mask for EDDY to go into dwifslpreproc

if [ ! -f eddy_mask.mif.gz ]; then
    # NOTE - normally dwifslpreproc creates mask from dwi2mask
    # Instead make mask with BET from as the union av BET from meanb1000AP and meanb2600AP to ensure sufficient coverage/extent
    for bvalue in 0 1000 2600; do
	dwiextract -force -shells $bvalue -strides -1,2,3,4 dwiAP.mif.gz - | mrmath -axis 3 - mean meanb${bvalue}APtmp.nii.gz
	bet meanb${bvalue}APtmp.nii.gz meanb${bvalue}APtmp_brain.nii.gz -R -F -m
    done
    for bvalue in 0 1000; do
	dwiextract -force -shells $bvalue -strides -1,2,3,4 dwiPA.mif.gz - | mrmath -axis 3 - mean meanb${bvalue}PAtmp.nii.gz
	bet meanb${bvalue}PAtmp.nii.gz meanb${bvalue}PAtmp_brain.nii.gz -R -F -m
    done
    # make union av brain masks and save into eddy_mask.mif.gz
    mrcat meanb*tmp_brain_mask.nii.gz - | mrmath - mean -axis 3 - | mrcalc - 1 -ge - | maskfilter -npass 3 -force - dilate eddy_mask.mif.gz
    #clean-up
    rm meanb*APtmp*
fi
if [ ! -f eddy_mask_edit.mif.gz ]; then
    echo Check brain mask for EDDY and save into eddy_mask_edit.mif.gz
    cp eddy_mask.mif.gz eddy_mask_edit.mif.gz
    mrview topup/b0APPA.mif.gz -roi.load eddy_mask_edit.mif.gz -mode 2
    exit;
fi

scratchdir=dwifslpreproc
if [ ! -f dwi_den_unr_eddy.mif.gz ];then
    dwifslpreproc -se_epi topup/b0APPA.mif.gz -rpe_pair -pe_dir ap -readout_time 0.0312 -align_seepi \
		  -nocleanup \
		  -scratch $scratchdir \
		  -eddy_mask eddy_mask_edit.mif.gz \
		  -eddy_slspec $codedir/../sequences/slspec_MB1_60slices_interleaved.txt \
		  -topup_options " --iout=field_mag_unwarped" \
		  -eddy_options " --slm=linear --repol --mporder=16 --s2v_niter=10 --s2v_interp=trilinear --s2v_lambda=1 " \
		  -eddyqc_all eddy \
		  dwi_den_unr.mif.gz \
		  dwi_den_unr_eddy.mif.gz;
   # or use -rpe_pair combo: dwifslpreproc DWI_in.mif DWI_out.mif -rpe_pair -se_epi b0_pair.mif -pe_dir ap -readout_time 0.72 -align_seepi
fi
# Now cleanup by transferring relevant files to qc, eddy and topup folder and deleting scratch folder
mv eddy/quad ../../qc/.
cp $scratchdir/command.txt $scratchdir/log.txt $scratchdir/eddy_*.txt $scratchdir/applytopup_*.txt $scratchdir/slspec.txt eddy/.
if [ ! -d topup ]; then mkdir topup; fi
mv $scratchdir/field_* $scratchdir/topup_* topup/.
rm -rf $scratchdir 

cd $studydir


##################################################################################
# 3. Mask generation, N4 biasfield correction, meanb0 generation and tensor estimation
cd $datadir/dwi/preproc

echo "Pre-processing with mask generation, N4 biasfield correction, Normalisation, meanb0 generation and tensor estimation"

# point to right filebase
dwi=dwi_den_unr_eddy

# Create mask for N4 biasfield correction from b1000
if [ ! -f N4_mask.mif.gz ]; then
    # Empirically, meanb2600 produces the best brain mask when extracted with BET at this level
    #bvalue=2600
    #dwiextract -shells $bvalue $dwi.mif.gz - | mrmath -force -axis 3 - mean mean${bvalue}tmp.nii.gz
    #bet mean${bvalue}tmp mean${bvalue}tmp_brain -m -F -R
    ln -s eddy_mask_edit.mif.gz N4_mask.mif.gz 
    echo Check result!
    echo mrview mean${bvalue}tmp.nii.gz -roi.load mean${bvalue}tmp_brain_mask.nii.gz -roi.opacity 0.5 -mode 2
    mrconvert mean${bvalue}tmp_brain_mask.nii.gz N4_mask.mif.gz
    rm mean${bvalue}tmp*
fi

# Do B1-correction. Use ANTs N4
if [ ! -f  ${dwi}_N4.mif.gz ]; then
    threads=10;
    if [ ! -d N4 ]; then mkdir N4;fi
    dwibiascorrect ants -mask N4_mask.mif.gz -bias N4/bias.mif.gz $dwi.mif.gz ${dwi}_N4.mif.gz
fi


# last file in the processing
dwipreproclast=${dwi}_N4.mif.gz

cd $studydir


##################################################################################
## 3. B0-normalise, create meanb0 and do tensor estimation

cd $datadir/dwi

mrconvert preproc/$dwipreproclast dwi_preproc.mif.gz
dwi=dwi_preproc

# Create brain mask for normalization 
if [ ! -f mask.mif.gz ]; then
    # Empirically, the BET mask of meanb1000 produces the best and tightest brain mask for the cerebrum (not cerebellum)
    for bvalue in 1000 2600; do 
	dwiextract -shells $bvalue $dwi.mif.gz - | mrmath -force -axis 3 - mean meanb${bvalue}tmp.nii.gz
	bet meanb${bvalue}tmp meanb${bvalue}tmp_brain -m -F -R
    done
    # Add them together and create a binary mask from union (i.e. voxel value -ge 1)
    if [ -f meanb2600tmp_brain_mask.nii.gz ]; then # means that we went for union b1000 and b2600
	mrcalc meanb1000tmp_brain_mask.nii.gz meanb2600tmp_brain_mask.nii.gz -add 1 -ge mask.mif.gz
    else # we only go for b1000
	mrconvert meanb1000tmp_brain_mask.nii.gz mask.mif.gz
    fi
    echo Check result!
    echo mrview mask.mif.gz -mode 2
    rm meanb*tmp*
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
