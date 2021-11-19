#!/bin/bash
# Zagreb Collab dhcp - PMR
#
usage()
{
  base=$(basename "$0")
  echo "usage: $base subjectID sessionID [options]
Estimation of CSD

Arguments:
  sID				Subject ID (e.g. PMR001) 
  ssID                       	Session ID (e.g. MR2)
Options:
  -dwi				Preprocessed dMRI data serie (format: .mif.gz) (default: derivatives/dMRI/sub-sID/ses-ssID/dwi/dwi_preproc_norm.mif.gz)
  -mask				Mask for dMRI data (format: .mif.gz) (default: derivatives/dMRI/sub-sID/ses-ssID/dwi/mask.mif.gz)
  -response			Response function (tournier or msmt_5tt) (default: msmt_5tt)
  -m / -method			Method with which the segmentation was done (options DrawEM or neonatal-5TT) (default: DrawEM)
  -a / -atlas			Atlas used for segmentation (options ALBERT or M-CRIB) (default: ALBERT)
  -5TT				5TT in dMRI space (format: .mif.gz) (default: derivatives/dMRI/sub-sID/ses-ssID/dwi/act/$method-$atlas/5TT_coreg.mif.gz)
  -d / -data-dir  <directory>   The directory used to output the preprocessed files (default: derivatives/dMRI/sub-sID/ses-ssID)
  -h / -help / --help           Print usage.
"
  exit;
}

################ ARGUMENTS ################

[ $# -ge 2 ] || { usage; }
command=$@
sID=$1
ssID=$2

currdir=$PWD

# Defaults
datadir=derivatives/dMRI/sub-$sID/ses-$ssID
method=DrawEM
atlas=ALBERT
dwi=$datadir/dwi/dwi_preproc_norm.mif.gz
mask=$datadir/dwi/mask.mif.gz
response=msmt_5tt

# check whether the different tools are set and load parameters
codedir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

shift; shift
while [ $# -gt 0 ]; do
    case "$1" in
	-dwi) shift; dwi=$1; ;;
	-mask) shift; mask=$1; ;;
	-m|-method) shift; method=$1; ;;
	-a|-atlas) shift; atlas=$1; ;;      
	-5TT) shift; act5tt=$1; ;;
	-response) shift; response=$1; ;;
	-d|-data-dir)  shift; datadir=$1; ;;
	-h|-help|--help) usage; ;;
	-*) echo "$0: Unrecognized option $1" >&2; usage; ;;
	*) break ;;
    esac
    shift
done

act5tt=$datadir/dwi/act/$method-$atlas/5TT_coreg.mif.gz

echo "CSD estimation of dMRI using 5TT
Subject:       $sID 
Session:       $ssID
DWI:	       $dwi
Mask:	       $mask
Response:      $response
5TT:           $act5tt
Directory:     $datadir 
$BASH_SOURCE   $command
----------------------------"

logdir=$datadir/logs
if [ ! -d $datadir ];then mkdir -p $datadir; fi
if [ ! -d $logdir ];then mkdir -p $logdir; fi

script=`basename $0 .sh`
echo Executing: $codedir/sMRI/$script.sh $command > ${logdir}/sub-${sID}_ses-${ssID}_sMRI_$script.log 2>&1
echo "" >> ${logdir}/sub-${sID}_ses-${ssID}_sMRI_$script.log 2>&1
echo "Printout $script.sh" >> ${logdir}/sub-${sID}_ses-${ssID}_sMRI_$script.log 2>&1
cat $codedir/$script.sh >> ${logdir}/sub-${sID}_ses-${ssID}_sMRI_$script.log 2>&1
echo


##################################################################################
# 0. Copy to files to datadir (incl .json if present at original location)

for file in $dwi $act5tt $mask; do
    origdir=`dirname $file`
    filebase=`basename $file .mif.gz`
    if [[ $file = $act5tt ]];then
	outdir=$datadir/dwi/act/$method-$atlas
    else
	outdir=$datadir/dwi
    fi

    if [ ! -d $outdir ]; then mkdir -p $outdir; fi
    
    if [ ! -f $ourdir/$filebase.mif.gz ];then
	cp $file $outdir/.
	if [ -f $origdir/$filebase.json ];then
	    cp $origdir/$filebase.json $outdir/.
	fi
    fi
done

# Update variables to point at corresponding filebases in $datadir
dwi=`basename $dwi .mif.gz`
act5tt=`basename $act5tt .mif.gz`
mask=`basename $mask .mif.gz`


##################################################################################
## Make Response Function estimation and then CSD calcuation

cd $datadir/dwi

# output folder for CSD
csddir=csd/$method-$atlas #Becomes as sub-folder in $datadir/dwi
if [ ! -d $csddir ];then mkdir -p $csddir;fi

# ---- Tournier ----
if [[ $response = tournier ]]; then
    # response fcn
    if [ ! -f $csddir/${response}_response.txt ]; then
	echo "Estimating response function use $response method"
	dwi2response tournier -force -mask  $mask.mif.gz -voxels $csddir/${response}_sf.mif $dwi.mif.gz $csddir/${response}_response.txt
	echo Check results: response fcn and sf voxels
	shview  $csddir/${response}_response.txt
	mrview  meanb0_brain.nii.gz -roi.load $csddir/${response}_sf.mif -roi.opacity 0.5 -mode 2
    fi
    # Do CSD estimation
    if [ ! -f $csddir/CSD_${response}.mif.gz ]; then
	echo "Estimating ODFs with CSD"
	dwi2fod -force -mask $mask.mif.gz csd $dwi.mif.gz $csddir/${response}_response.txt $csddir/csd_${response}.mif.gz
	echo Check results of ODFs
	mrview -load meanb0_brain.nii.gz -odf.load_sh $csddir/csd_${response}.mif.gz -mode 2
    fi
fi

# ---- MSMT ----
if [[ $response = msmt_5tt ]]; then
    # Estimate msmt_csd response functions (note use FA < 0.15 for gm and csf)
    echo "Estimating response function use $response method"
    dwi2response msmt_5tt -force -voxels $csddir/${response}_sf.mif -fa 0.15 $dwi.mif.gz act/$method-$atlas/$act5tt.mif.gz $csddir/${response}_wm.txt $csddir/${response}_gm.txt $csddir/${response}_csf.txt
    echo "Check results for response fcns (wm, gm and csf) and single-fibre voxels (sf)"
    shview  $csddir/${response}_wm.txt
    shview  $csddir/${response}_gm.txt
    shview  $csddir/${response}_csf.txt
    mrview  meanb0_brain.nii.gz -overlay.load $csddir/${response}_sf.mif -overlay.opacity 0.5 -mode 2
    # Calculate ODFs
    echo "Calculating CSD using ACT and $response"
    dwi2fod msmt_csd -force -mask $mask.mif.gz $dwi.mif.gz $csddir/${response}_wm.txt $csddir/csd_${response}_wm.mif.gz $csddir/${response}_gm.txt $csddir/csd_${response}_gm.mif.gz $csddir/${response}_csf.txt $csddir/csd_${response}_csf.mif.gz
    mrview -load meanb0_brain.nii.gz -odf.load_sh $csddir/csd_${response}_wm.mif.gz -mode 2;
fi


cd $currdir
