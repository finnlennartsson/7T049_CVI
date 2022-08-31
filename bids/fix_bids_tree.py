
import os
import sys
import glob
import argparse
import subprocess
import shutil
from distutils.dir_util import copy_tree, remove_tree
from distutils.errors import DistutilsFileError

import bids_util
from bids_util import log_print
from fix_anat import fix_anat
from fix_fmap import fix_fmap
from fix_other import fix_dwi, fix_func
from create_pymp2rage import pymp2rage_module
from create_derivs import quit_module

"""
routines used by the fix_bids task, which populates a new bids tree root 
at ["bids_output"] based on the tree at ["global"]["orig_bids_root"]. 

should result in a bids validation log that shows no errors. 
"""

def add_subject_to_participants(runner):
	"""
	make sure the participants.tsv contains the subject data from 
	original bids tree participants.tsv, but only the ones that have been processed. 
	if file dont exist, create a new one. 
	dont add the subject if it has already been run. 
	TODO: maybe make sure to copy over the subj line even if already exists?
	arguments:
		- runner: task_runner parent 
	"""
	old_part_tsv = "{}/participants.tsv".format(runner.get_global("orig_bids_root"))
	#first find the current subjects line in old particpants.tsv
	found = False
	try:
		with open(old_part_tsv, 'r') as f:
			for cur_part_line in f.readlines():
				try:
					subj_name, rest_line  = cur_part_line.split('\t', 1)
					if(subj_name == runner.subj):
						found = True
						subj_part_line = cur_part_line
						break
				except Exception as e:
					#ignore non tab lines
					pass
		if not found:
			raise(Exception("Participant {} not in participants.tsv".format(runner.subj)))
	except Exception as e:
		log_print(str(e))
		sys.exit(str(e))
	#then try to find the line in the new participants.tsv
	#(fix bids might have been run before and we dont want two lines)
	new_part_tsv = "{}/participants.tsv".format(runner.get_task_conf("bids_output"))
	try:
		if not os.path.exists(new_part_tsv):
			#if the file dont exist yet, create it
			log_print("creating new " + new_part_tsv, force=True)
			with open(new_part_tsv, 'w') as f:
				participant_header = "participant_id\tage\tsex\tgroup\n"
				f.write(f"{participant_header}")
				f.write(f"{subj_part_line}")
		else:
			with open(new_part_tsv, 'r') as f:
				found = False
				for read_line in f.readlines():
					try:
						subj_name, rest_line  = read_line.split('\t', 1)
						if(subj_name == runner.subj):
							found = True
							#the line was already there, no changes
							#TODO: maybe delete old line and copy again?
							break
					except Exception as e:
						#ignore non tab lines
						pass
			if not found:
				#it was not found, add the line
				with open(new_part_tsv, 'a') as f:
					f.write(f"{subj_part_line}")
					print("appended to " + new_part_tsv)
	except Exception as e:
		log_print("failed to update participants.tsv: " + str(e), force=True)

def copy_to_new_tree(runner, f):
	"""
	copy a file from bids root to new bids tree
	arguments
			- runner: task runner executing fix bids
			- f: a filename
	"""
	in_bids = runner.get_global("orig_bids_root")
	out_bids = runner.get_task_conf("bids_output")
	shutil.copy("./{}/{}".format(in_bids, f), "./{}/{}".format(out_bids, f))

def copy_bids_tree(runner):
	"""
	Create or update a bids tree in <bids_output> folder. <bids_input>/<subj> 
	will be copied here and processed to not cause BIDS validation errors.  
	
	arguments
			- runner: task runner executing fix bids
	"""
	in_bids = runner.get_global("orig_bids_root")
	out_bids = runner.get_task_conf("bids_output")
	dest_tree = "./{}/{}".format(out_bids, runner.subj)
	#delete old bids tree copy if exists
	if not os.path.exists("./" + out_bids):
		os.makedirs("./" + out_bids)
	if os.path.exists(dest_tree):
		log_print("delete old dataset " + dest_tree)
		remove_tree(dest_tree)
	
	add_subject_to_participants(runner)
	
	#fetch README and dataset_description
	for f in ("README", "dataset_description.json", "participants.json", 
		"scans.json", "task-8bars_bold.json" ):
		copy_to_new_tree(runner, f)
	
	#make new copy of subject bids tree
	try:
		copy_tree("./{}/{}".format(in_bids, runner.subj), dest_tree)
		log_print("copied " + "./{}/{}".format(in_bids, runner.subj) + " to " + dest_tree)		
	except DistutilsFileError as e:
		log_print("invalid subject " + runner.subj)
		sys.exit()

def update_bids_ignore(bids_root):
	"""
		writes a new .bidsignore file in BIDS root. 
		arguments:
			-bids_root
	"""
	with open(bids_root + '/.bidsignore', 'w') as f:
		f.write("#Add files to ignore here\n")
	log_print("Wrote .bidsignore")

def run_validator(runner):
	"""
		runs the bids validator program from docker container
	"""
	log_print("Running the bids validator docker script")
	
	runner.sh_run("{}/validate_bids_output.sh".format(runner.code_path))
	log_print("check ./{}/bids-validator_report.txt".format(runner.get_global("deriv_folder")))

def process_subject(runner):
	"""
	fix bids tree for a given bids tree and subject
	and run validator
	
	input arguments:
		runner: parent task_runner object 
		in_bids: input root bids folder
		out_bids: output root bids folder
		subject: subj label
	"""
	
	#copy the subject files to the destination tree
	copy_bids_tree(runner)
	#prepare scans.tsv file
	bids_util.load_original_scans(runner.get_task_conf("bids_output"), runner.subj)
	#execute fixes for each folder
	#note: its ok for folders to be missing, fail gracefully. 
	fix_anat(runner).execute()
	fix_dwi(runner).execute()
	fix_func(runner).execute()
	fix_fmap(runner).execute()
	#save scans.tsv with changes
	bids_util.save_new_scans(runner)
	update_bids_ignore(runner.get_task_conf("bids_output"))
	
if __name__ == "__main__":
	print("run with pipeline.py -t fix_bids <subj> -c <conf.json>")

