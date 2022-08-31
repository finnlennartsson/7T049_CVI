Bash and python scripts to convert DICOM data into [BIDS-organised](https://bids.neuroimaging.io/) NIfTI data.

The folder structure will be
- Original dicoms in `/dicomdir`
- Re-named and re-arranged dicoms in are `/sourcedata`, which is the BIDS sourcedata-folder
- BIDS-organised NIfTIs in `/rawdata`

To complete the conversion: 

1. Run script `DcmDicomdir_to_DcmSourcedata.sh` \
This re-names the dicoms and sorts them into `/sourcedata`

2. Run script `DcmSourcedata_to_NiftiRawdata_generate_Dicominfo.sh` \
Runs heudiconv without conversion
Generates /rawdata/.heudiconv/sub-$sID/dicominfo.tsv which is used to generate 7T049_CVI_heuristic.py

3. Run script `DcmSourcedata_to_NiftiRawdata.sh` \
This converts the dicoms in `/sourcedata` to BIDS-organised NIfTIs in `/rawdata`using the heudiconv routine. 
- [heudiconv](https://github.com/nipy/heudiconv) is run with using a Docker container using rules set in the python file `7T049_CVI_heuristic.py`
- The script also makes a BIDS-validation 
4. Run script `MRIQC.sh` \
This script runs [MRIQC](https://github.com/bids-standard/bids-validator) on the data

Running the fix_bids_tree.py script:
Prerequisites:
	- a python 3.7+ environment with the pip packages in requirements.txt.
	- QUIT binary qi must be in path. 
	- execute the script from the root folder, (with code, rawdata etc)

run python ./code/bids/fix_bids_tree.py <subject>
where subject is the subject marker such as sub-7T049C10. 
This will create a new bids tree in fixed_rawdata, and copy the subject
data over, and fix the bids tree structure. it will also create a matching 
derivatives folder, containing MP2RAGE/T1 map output and the bids validator report
repeat the command for each subject to be imported. 
Note the conversion from dicom to nifti must have been done. 
