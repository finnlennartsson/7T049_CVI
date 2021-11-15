#!/bin/bash
# Input
# $1 = json-file

# For Philips data - https://osf.io/xvguw/wiki/home/?view_only=6887e555825743c7bbdfce114500fb8d
#ActualEchoSpacing = WaterFatShift / (ImagingFrequency * 3.4 * (EPI_Factor + 1)) 
#TotalReadoutTIme = ActualEchoSpacing * EPI_Factor
#EffectiveEchoSpacing = TotalReadoutTime / (ReconMatrixPE - 1)
#where (in Dicom elements)
#WaterFatShift = 2001,1022
#ImagingFrequency = 0018,0084
#EPI_Factor = 0018,0091 or 2001,1013             ReconMatrixPE = 0028,0010 or 0028,0011 depending on 0018,1312

#wfs=`cat $1 | grep WaterFatShift | awk '{print $2}' | sed 's/,//g' `
#imf=`cat $1 | grep ImagingFrequency | awk '{print $2}' | sed 's/,//g' `
#etl=`cat $1 | grep EchoTrainLength | awk '{print $2}' | sed 's/,//g' `


# Diffusion
WaterFatShift=31.617767
ImagingFrequency=298.03869
EPI_Factor=45
ReconMatrixPE=112


echo
echo `basename $@`
echo WaterFatShift [ppx] = $WaterFatShift
echo ImagingFrequency [Hz] = $ImagingFrequency
echo EPI_Factor = $EPI_Factor

echo "$WaterFatShift / ($ImagingFrequency * 3.4 * ($EPI_Factor + 1))" | bc -l
ActualEchoSpacing=`echo "$WaterFatShift / ($ImagingFrequency * 3.4 * ($EPI_Factor + 1))" | bc -l`


# ActualEchoSpacing = WaterFatShift / (ImagingFrequency * 3.4 * (EPI_Factor + 1))
# ActualEchoSpacing = 31.3847/(289 * 3.4 *(45+1)) = 6.9436e-04
ActualEchoSpacing=0.00069436
# TotalReadoutTime = ActualEchoSpacing * EPI_Factor
# TotalReadoutTime = 0.00069436 * 45 = 0.031
TotalReadoutTime=0.0312
echo
echo "Diffusion and SE-EPI fieldmaps have"
echo "ActualEchoSpacing [s] = $ActualEchoSpacing"
echo "TotalReadoutTime [s] = $TotalReadoutTime"

# fMRI
# ActualEchoSpacing = WaterFatShift / (ImagingFrequency * 3.4 * (EPI_Factor + 1))
# ActualEchoSpacing = 25.915/(289 * 3.4 *(37+1)) = 6.9405e-04
ActualEchoSpacing=0.00069405
# TotalReadoutTime = ActualEchoSpacing * EPI_Factor
# TotalReadoutTime = 0.00069405 * 37 = 0.031
TotalReadoutTime=0.0257
echo
echo "fMRI"
echo "ActualEchoSpacing [s] = $ActualEchoSpacing"
echo "TotalReadoutTime [s] = $TotalReadoutTime"

