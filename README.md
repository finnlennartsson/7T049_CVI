# 7T049_CVI
Processing of 7T MRI data within CVI / Visual Brain project

Data is organised in [BIDS convention](https://bids.neuroimaging.io/specification.html)

Prodessed data are organised in `/derivatives`. Inspiration on nameing conventions can be taken from [dHRP 3rd data release](https://biomedia.github.io/dHCP-release-notes/structure.html) 

-------------

BIDS conversion is set up using [heudiconv](https://heudiconv.readthedocs.io/en/latest/) (a heuristic-centric DICOM converter), mimicking the tutorial [here](http://reproducibility.stanford.edu/bids-tutorial-series-part-2a/).

For quality assessment of sMRI and rs-fMRI, [MRIQC](https://mriqc.readthedocs.io/en/stable/) is used. For dMRI, the QC outputs from FSL `eddy` or `eddy_quad` will be used. 

# Python tools for automatic processing of 7T Philips MRI data 
In the summer of 2022 Axel Landgren (github.com/axelland) worked on developing a pipeline for preprocessing the dicom data from the 7T scanner so that is it BIDS-compliant as well as ready to be processed with fMRIPREP. The desired steps in the processing was inspired by Jurjen Heij's processing pipeline described on the Knapen lab Wiki: https://github.com/tknapen/tknapen.github.io/wiki/Anatomical-workflows

In short the goals of the preprocessing is  
 - Make the original BIDS data compliant, this includes renaming wrongly named files to the BIDS standard and adding missing nifti and json metadata. The aim is that the missing parameters will be calculated correctly with no manual input. 
 - Generate T1-weighted MP2RAGE images either with QUIT or py2mprage, with optional use of B1 fieldmap correction (WIP)
 - Compute a brain mask with BET or spmmask
 - Remove the background from the T1w image using this mask
 - Use CAT12 to reduce noise in the the T1w image and improve segmentation of white and gray matter
 - Run freesurfer on the denoised image
 - TODO: also execute fMRIPREP on the data  
 - While doing the above, keep detailed logs of the execution of the subroutines and external programs

# Description of the currently defined tasks
- dicom_convert: convert a folder of dicom files of a subject into a BIDS tree of nifti+json files 
- fix_bids: output a valid bids tree in a chosen destination from a converted BIDS tree. Note that the phase encoding direction for the AP and PA spin echo fieldmaps are manually entered. 
- mp2rage: compute MP2RAGE UNIT1 and T1map images into the derivatives folder
- mask_remove_bg: compute a mask and remove the background and skull
- cat12: execute CAT12 to process the masked image
- freesurfer: run freesurfer on the denoised image  

# Usage instructions
execute pipeline.py with a python 3.7+ interpreter. 

usage: pipeline.py [-h] [-v] [-c CONFIG] [-t TASK] [-d]
                   [subj_list [subj_list ...]]
  -h, --help    
  -v, --verbose 
  -c CONFIG, --config CONFIG
  -t TASK, --task TASK
  -d, --dummy

 - -v, verbose: bool flag, set to show all log printing in terminal 
 - -c, --config: choose a json configuration file, see below
 - -t, --task: name a task to execute, selected from the task list below. more can be easily added but requires changed in pipeline.py at the moment. 
 - -d, --dummy: dont actually execute any shell commands, for testing purposes
 - subject list: one or more subject labels, incluNOT including "sub-", separated by space.   

if no task is set, the sequence of tasks in task_list in the config file is used. 
if no subject list is provided, the list of subjects in subj_list in the config file is used. 

#the configuration json file
A default json file is provided in pipeline_conf.json which is used for 

the most important options here are choosing the new bids tree output directory (default fixed_bids/), choosing the derivatives directory (default derivatives/). The file have options that are global, as well as options for each task. Note that the location of the spm12 toolbox is needed. 

# Logging of task progress
The logging directory is chosen in the config file, and by default is 
located at derivatives/logs where each subject its logs in /<subject>/ 
The bids validation report is located in the root of the log directory since the whole bids tree is validated at once.  

The task execution log is located in the root log folder under the name <subj>_tasks.log. This file will include one line for each task ran with pipeline.py.  
The tab separated columns in the line is the task name, the execution start time, the elapsed time at finish, and the task configuration options that was used when the task was ran.
at the very end of the log file the global options are appended in a line. this line is replaced every time a task is ran.   

In the subject log folder, there will be one file <subj>_<task name>.log for each task that was ran. This file contains all log prints from the execution, and error messages. 
There are also a file for each shell command that was executed by these tasks. these are named similarly, for example <subj>_call_cat12.log, these include all output from stdout and stderr from the execution of the commands. 

# Dependencies
This package runs a number of external programs, executables and toolboxes that are needed. 

- Python 3.7+ with the pip packages mentioned in requirements.txt
- While most things in theory could be executed on windows, a modern Linux environment is assumed for most part since shell scripts are used. Also, file path names are not written in a portable fashion. 
- Jurjen Heij's tools in the linescanning repo 
- FSL tools (https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/Fslutils)
- MATLAB or MATLAB runtime 
- SPM12 toolbox
- CAT12 for SPM12, version r1450
- freesurfer
- fMRIPREP (WIP)

# Description of the BIDS errors that are fixed

- Leftover files that arent needed are deleted. e.g. *heudiconv* files, *ADC* files..
- Anatomical MRI images that had the data dimensions wrong are fixed
- Anatomical MRI images that had both inversion times in one file are split up
- Fieldmap files that were not named correctly by the Heuristics.py script are renamed
- Fieldmap files that dont have Unit, IntendedFor set have it added
- Multiple files that have wrong PhaseEncodingDirection set have it fixed
- Likewise TotalReadoutTime is added in multiple places
- <subj>-scans is updated for each deleted or renamed file
- participants.tsv is updated for each subject added to the new tree

# Future features that could be added 

- Import the B1 fieldmap and use it to compute MP2RAGE files
- Output valid json sidecar files for the derivative nifti files
- Compute Phase Encoding Direction without needing to define it manually
- Write SliceTiming for the fMRI files
- Shell program logs could be included in the task output log
