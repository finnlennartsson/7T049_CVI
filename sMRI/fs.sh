#!/bin/bash
## 7T049 CVI/Visual Brain Study
#
usage()
{
  base=$(basename "$0")
  echo "usage: $base sID [options]
Running FreeSurfer of sMRI data

Arguments:
  sID				Subject ID (e.g. 107) 
Options:
  -T1				T1w image to be preprocessed and segmented. Full path. (default: $rawdatadir/sub-$sID/anat/sub-$sID_run-1_T1w.nii.gz)
  -threads			Nbr of CPU cores/threads for FreeSurfer analysis. (default: threads=10)  
  -h / -help / --help           Print usage.
"
  exit;
}

################ ARGUMENTS ################

[ $# -ge 1 ] || { usage; }
command=$@
sID=$1

# Define folders
codedir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
studydir=`pwd`
fsdatadir=derivatives/sMRI;
rawdatadir=rawdata;
scriptname=`basename $0 .sh`
logdir=derivatives/logs/sub-${sID}

# Defaults
t1w=$rawdatadir/sub-$sID/anat/sub-${sID}_run-1_T1w.nii.gz
threads=10;

shift
while [ $# -gt 0 ]; do
    case "$1" in
	-T1) shift; t1w=$1; ;;
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

##### MAIN #####

# Perform FreeSurfer segmentation/analysis

recon-all -subjid sub-$sID -i $t1w -sd $fsdatadir -threads 10 -all
