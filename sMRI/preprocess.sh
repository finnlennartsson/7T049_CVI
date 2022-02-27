#!/bin/bash
## 7T049 CVI/Visual Brain Study
#
usage()
{
  base=$(basename "$0")
  echo "usage: $base sID [options]
Running FreeSurfer of sMRI data
1. Preprocess 4D MP2RAGE into correct 3D MP2RAGE (normalised)
2. FreeSurfer analysis

Arguments:
  sID				Subject ID (e.g. 107) 
Options:
  -T1				T1w MP2RAGE image to be preprocessed and segmented. NOTE includes MP2RAGE + PD. (default: $rawdatadir/sub-$sID/anat/sub-$sID_run-1_T1w.nii.gz)
  -threads			Nbr of CPU cores/threads for FreeSurfer analysis. (default: threads=10)  
  -h / -help / --help           Print usage.
"
  exit;
}

################ ARGUMENTS ################

[ $# -ge 1 ] || { usage; }
command=$@
sID=$1
shift

# Define folders
codedir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
studydir=`pwd`
fsdatadir=derivatives/sMRI;
rawdatadir=rawdata;
scriptname=`basename $0 .sh`
logdir=derivatives/logs/sub-${sID}

# Defaults
t1=$rawdatadir/sub-$sID/anat/sub-${sID}_run-1_T1w.nii.gz
threads=10;

while [ $# -gt 0 ]; do
    case "$1" in
	-T1) shift; t1=$1; ;;
	-threads) shift; threads=$1; ;;
	-h|-help|--help) usage; ;;
	-*) echo "$0: Unrecognized option $1" >&2; usage; ;;
	*) break ;;
    esac
    shift
done

if [ ! -d $logdir ]; then mkdir -p $logdir; fi
if [ ! -d $fsdatadir ]; then mkdir -p $fsdatadir; fi

# System specific #
# (These are the same for all studies/subjects):
# FreeSurfer license path:
#      We first check whether FREESURFER_LICENSE is an environmnetal variable
#      If not, we assume the path based on Mac OS organization
if [ -z "$FREESURFER_LICENSE" ]
then fsLicense=${FREESURFER_HOME}/license.txt
else fsLicense="$FREESURFER_LICENSE"
fi
[ -r "$fsLicense" ] || {
    echo "FreeSurfer license (${fsLicense}) not found!"
    echo "You can set a custom license path by storing it in the environment variable FREESURFER_LICENSE"
    exit 1
}

################ MAIN ################


################################################
## 1. Make proper 3D MP2RAGE image

if [ ! -d $fsdatadir/sub-$sID/preproc ]; then mkdir -p $fsdatadir/sub-$sID/preproc ;fi

t1base=`basename $t1 .nii.gz`
t1mp2ragebase=`echo $t1base | sed 's/T1w/desc\-mp2rage\_T1w/g'`

# Extract the two volumes (mr2rage and t1)
if [ ! -f $fsdatadir/sub-$sID/preproc/$t1mp2ragebase.nii.gz ]; then
	mrconvert $t1 -coord 3 0 -axes 0,1,2 $fsdatadir/sub-$sID/preproc/${t1base}_tmp_mp2rage.nii.gz;
	mrconvert $t1 -coord 3 1 -axes 0,1,2 $fsdatadir/sub-$sID/preproc/${t1base}_tmp_t1.nii.gz;
	# and divide them / normalise
	mrcalc $fsdatadir/sub-$sID/preproc/${t1base}_tmp_mp2rage.nii.gz $fsdatadir/sub-$sID/preproc/${t1base}_tmp_t1.nii.gz -div $fsdatadir/sub-$sID/preproc/$t1mp2ragebase.nii.gz

	# clean up
	rm $fsdatadir/sub-$sID/preproc/${t1base}_tmp_*.nii.gz
fi

################################################
## 2.  Perform FreeSurfer segmentation/analysis

#recon-all -subjid sub-$sID -i $fsdatadir/sub-$sID/preproc/$t1mp2ragebase.nii.gz -sd $fsdatadir -threads $threads -all

################ FINISHED ################
