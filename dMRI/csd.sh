#!/bin/bash
# 7T 049 Visual Brain
#
usage()
{
  base=$(basename "$0")
  echo "usage: $base subjectID sessionID [options]
Estimation of CSD

Arguments:
  sID				Subject ID (e.g. 7T049S02) 
Options:
  -dwi				Preprocessed dMRI data serie (format: .mif.gz) (default: derivatives/dMRI/sub-sID/dwi/dwi_preproc_inorm.mif.gz)
  -mask				Mask for dMRI data (format: .mif.gz) (default: derivatives/dMRI/sub-sID/dwi/mask.mif.gz)
  -response			Response function (tournier or dhollander) (default: dhollander)
  -d / -data-dir  <directory>   The directory used to output the preprocessed files (default: derivatives/dMRI/sub-sID)
  -t / -threads	  		Threads (default: 10)
  -h / -help / --help           Print usage.
"
  exit;
}

################ ARGUMENTS ################

[ $# -ge 1 ] || { usage; }
command=$@
sID=$1
shift

currdir=$PWD

# Defaults
datadir=derivatives/dMRI/sub-$sID
dwi=$datadir/dwi/dwi_preproc_inorm.mif.gz
mask=$datadir/dwi/mask.mif.gz
response=dhollander
threads=10

# check whether the different tools are set and load parameters
codedir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"


while [ $# -gt 0 ]; do
    case "$1" in
	-dwi) shift; dwi=$1; ;;
	-mask) shift; mask=$1; ;;
	-response) shift; response=$1; ;;
	-d|-data-dir)  shift; datadir=$1; ;;
	-t|-threads)  shift; threads=$1; ;;
	-h|-help|--help) usage; ;;
	-*) echo "$0: Unrecognized option $1" >&2; usage; ;;
	*) break ;;
    esac
    shift
done

echo "CSD estimation of dMRI using 5TT
Subject:       $sID 
DWI:	       $dwi
Mask:	       $mask
Response:      $response
Directory:     $datadir 
Threads:       $threads
$BASH_SOURCE   $command
----------------------------"

logdir=$datadir/logs
if [ ! -d $datadir ];then mkdir -p $datadir; fi
if [ ! -d $logdir ];then mkdir -p $logdir; fi

script=`basename $0 .sh`
echo Executing: $codedir/sMRI/$script.sh $command > ${logdir}/sub-${sID}_dMRI_$script.log 2>&1
echo "" >> ${logdir}/sub-${sID}_dMRI_$script.log 2>&1
echo "Printout $script.sh" >> ${logdir}/sub-${sID}_dMRI_$script.log 2>&1
cat $codedir/$script.sh >> ${logdir}/sub-${sID}_dMRI_$script.log 2>&1
echo


##################################################################################
# 0. Copy to files to datadir (incl .json if present at original location)

for file in $dwi $mask; do
    origdir=`dirname $file`
    filebase=`basename $file .mif.gz`
    outdir=$datadir/dwi

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
mask=`basename $mask .mif.gz`

##################################################################################
## Make Response Function estimation and then CSD calcuation

cd $datadir/dwi
responsedir=response

# output folder for CSD


# ---- Tournier ----
if [[ $response = tournier ]]; then
    # Do CSD estimation
    csddir=csd #Becomes as sub-folder in $datadir/dwi
    if [ ! -d $csddir ];then mkdir -p $csddir;fi

    if [ ! -f $csddir/csd_${response}.mif.gz ]; then
	echo "Estimating ODFs with CSD"
	dwi2fod -force -nthreads $threads -mask $mask.mif.gz csd $dwi.mif.gz $responsedir/${response}_response.txt $csddir/csd_${response}.mif.gz
	echo Check results of ODFs
	mrview -load meanb0_brain.nii.gz -odf.load_sh $csddir/csd_${response}.mif.gz -mode 2
    fi
fi

# ---- MSMT = msmt_5tt and dhollander ----
if [[ $response = dhollander ]]; then
    csddir=csd #Becomes as sub-folder in $datadir/dwi
    if [ ! -d $csddir ];then mkdir -p $csddir;fi
fi
if [[ $response = msmt_5tt ]]; then
    csddir=csd/$method-$atlas #Becomes as sub-folder in $datadir/dwi
    if [ ! -d $csddir ];then mkdir -p $csddir;fi
fi

    # Calculate ODFs
    echo "Calculating CSD using ACT and $response"
    if [ ! -f $csddir/csd_${response}_wm_3tt.mif.gz ]; then
	# model with all 3 tissue types: WM GM CSF
	dwi2fod msmt_csd -force -nthreads $threads -mask $mask.mif.gz $dwi.mif.gz $responsedir/${response}_wm.txt $csddir/csd_${response}_wm_3tt.mif.gz $responsedir/${response}_gm.txt $csddir/csd_${response}_gm_3tt.mif.gz $responsedir/${response}_csf.txt $csddir/csd_${response}_csf_3tt.mif.gz
    fi
    if [ ! -f $csddir/csd_${response}_wm_2tt.mif.gz ]; then
	# model with all 2 tissue types: WM CSF
	dwi2fod msmt_csd -force -nthreads $threads -mask $mask.mif.gz $dwi.mif.gz $responsedir/${response}_wm.txt $csddir/csd_${response}_wm_2tt.mif.gz $responsedir/${response}_csf.txt $csddir/csd_${response}_csf_2tt.mif.gz
    fi
    mrview -load meanb0_brain.mif.gz -odf.load_sh $csddir/csd_${response}_wm_3tt.mif.gz -odf.load_sh $csddir/csd_${response}_wm_2tt.mif.gz -mode 2;
fi

cd $currdir
