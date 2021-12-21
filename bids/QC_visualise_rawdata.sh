#!/bin/bash
# 7T 049 Visual Brain
# Script for QC eye-balling of images in a BIDS rawdata folder given from a heudiconv "session.tsv"-file
# Creates a session.tsv file for QC purposes
#
usage()
{
  base=$(basename "$0")
  echo "usage: $base subjectID sessionID [options]
Visualize NIfTIs in BIDS rawdata folder 
Arguments:
  sID				Subject ID (e.g. 7T049S02) 
Options:
  -f / -tsv_file		Session.tsv file containing Heuristic file to use with heudiconv (default: $studydir/rawdata/sub-\$sID/sub-\$sID_scans.tsv)
  -h / -help / --help           Print usage.
"
  exit;
}

dMRI_rawdata_visualisation ()
{
    # get input file
    file=$1;

    filebase=`basename $file .nii.gz`
    filedir=`dirname $file`

    # check if SBRef file
    issbref=`echo $file | grep sbref`

    # if sbref file, then just visualise this
    if [[ $issbref ]]; then
	mrview $file -mode 2 
    else #is dwi file
	# Launch viewer and load all images
	mrconvert -quiet -fslgrad $filedir/$filebase.bvec $filedir/$filebase.bval $file tmp.mif
	mrinfo -shell_indices tmp.mi
	shells=`mrinfo -shell_bvalues tmp.mif`;
	for shell in $shells; do
	    echo Inspecting shell with b-value=$shell
	    if [ $shell == 5 ]; then echo b0 have this volume indices; mrinfo -shell_indices tmp.mif; fi
	    dwiextract -quiet -shell $shell tmp.mif - | mrview - -mode 2 
	done
	rm tmp.mif
    fi
}

################ ARGUMENTS ################

[ $# -ge 1 ] || { usage; }
command=$@
sID=$1
shift

codedir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
studydir=$PWD 
rawdatadir=$studydir/rawdata
tsvfile=$rawdatadir/sub-$sID/sub-${sID}_scans.tsv

# Read arguments
while [ $# -gt 0 ]; do
    case "$1" in
	-f|-tsv_file)  shift; tsvfile=$1; ;;
	-h|-help|--help) usage; ;;
	-*) echo "$0: Unrecognized option $1" >&2; usage; ;;
	*) break ;;
    esac
    shift
done

# Go to rawdata dir
cd $rawdatadir/sub-$sID

# Create $rawdatadir/sub-$sID/session.tsv file is not present
if [ ! -f session.tsv ]; then
    {
	echo "Creating session.tsv file from $tsvfile"
	echo -e "participant_id\tfilename\tqc_pass_fail\tqc_signature\tdMRI_dwiAP\tdMRI_vol_for_b0AP\tdMRI_dwiPA\tdMRI_vol_for_b0PA" > session.tsv

	read;
	while IFS= read -r line
	do
	    file=`echo "$line" | awk '{ print $1 }'`
	    echo -e "sub-$sID\t$file\t0/1\tFL\t-\t-\t-\t-" >> session.tsv
	done
    } < "$tsvfile"
fi 

# Eye-ball data in session.tsv 
echo "QC eye-balling of BIDS rawdata given by session.tsv file"
echo All scans
cat session.tsv | awk '{print $2}'
echo
# Read input file line by line, but skip first line
{
    read;
    counter=2; #Keeps track of line number to display on I/O to make it easier to detect corresponding line in session.tsv file
    while IFS= read -r line
    do
	file=`echo "$line" | awk '{ print $2 }'`
	filedir=`dirname $file`
	echo $counter $file
	if [ $filedir == "dwi" ]; then
	    dMRI_rawdata_visualisation $file;
	else
	    mrview $file -mode 2 
	fi
        let counter++
    done
} < session.tsv

cd $studydir
