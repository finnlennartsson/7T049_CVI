#!/bin/bash
## 7T049 CVI/Visual Brain Study

# Define Folders
codedir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
studydir=$PWD
bidsdir=$studydir/fixed_rawdata;
scriptname=`basename $0 .sh`
logdir=.
#logdir=$studydir/derivatives/logs/sub-${sID}

# we'll be running the Docker containers as yourself, not as root:
userID=$(id -u):$(id -g)

###   Get docker images:   ###
docker -v pull bids/validator:latest

###   Run BIDS validator   ###
docker run --name BIDSvalidation_container \
           --user $userID \
           --rm \
           --volume $bidsdir:/data:ro \
           bids/validator \
               /data \
           > $studydir/derivatives/bids-validator_report.txt 2>&1
           
