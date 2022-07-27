
import os
import sys
import glob
import argparse
import subprocess
import shutil
from distutils.dir_util import copy_tree, remove_tree
from distutils.errors import DistutilsFileError

import bids_util
from fix_anat import fix_anat
from fix_fmap import fix_fmap
from fix_other import fix_dwi, fix_func

source = "rawdata"
dest = "fixed_rawdata"
#default subject goes here - maybe replace with error message later
subj = "sub-7T049C10"
code_path = ""

new_lines = []


#dest = "func/sub-7T049C10_task-8bars_dir-AP_run-3_bold.nii.gz"
#count = 0
#s Strips the newline character
#for line in Lines:
#	count += 1
#	line_file, rest_line  = line.split('\t', 1)
#	print(line_file)
#	if(dest == line_file):
#		print("REPLACE")
#		line = "gay" + "\t" + rest_line 
	#new_lines.append(line)
#print(new_lines)
#sys.quit()

scans_lines = []
def load_original_scans():
	"""
	Load the original list of files in scans.tsv, before renaming 
	"""
	global scans_lines
	scans = "{}/{}/{}_scans.tsv".format(dest, subj, subj)
	f = open(scans, 'r')
	scans_lines = f.readlines()
	f.close()

def save_new_scans():
	global scans_lines
	"""
	Save the updates list of files in scans.tsv, after renaming 
	"""
	scans = "{}/{}/{}_scans.tsv".format(dest, subj, subj)
	with open(scans, 'w') as f:
		for line in scans_lines:
			f.write(f"{line}\n")

def copy_bids_tree():
	"""
	Create or update a bids tree in <dest> folder. <subj> will be copied 
	here and processed to not cause BIDS validation errors.  
	"""
	
	global source, dest
	# Create a new directory if it does not exist 
	dest_tree = "./{}/{}".format(dest, subj)
	quit_tree = "./derivatives/quit/{}/anat".format(subj)
	pymp2rage_tree = "./derivatives/pymp2rage/{}/anat".format(subj)

	#create empty derivatives folder
	for tree in (quit_tree, pymp2rage_tree):
		if os.path.exists(tree):
			remove_tree(tree)
		os.makedirs(tree)
	
	#delete old bids tree copy if exists
	if not os.path.exists("./" + dest):
		os.makedirs("./" + dest)
	if os.path.exists(dest_tree):
		print("delete old dataset " + dest_tree)
		remove_tree(dest_tree)

	#fetch README and dataset_description
	shutil.copy("./{}/README".format(source), "./{}/README".format(dest))
	shutil.copy("./{}/dataset_description.json".format(source), "./{}/dataset_description.json".format(dest))
	
	#make new copy of bids tree
	try:
		copy_tree("./{}/{}".format(source, subj), dest_tree)
		print("copied " + "./{}/{}".format(source, subj) + " to " + dest_tree)		
	except DistutilsFileError as e:
		print("invalid subject " + subj)
		sys.exit()

def process_folder(folder_obj):
	"""
		execute the execute() function of the module passed to it. 
		delete all the files in the blacklist returned from the execute function
		
		Inputs:
			- folder_obj - a class that has an execute function that 
				returns a list of tuple of two strings, source and destination
				destination is None if the file is to be deleted. 
		
	"""
	print("executing " + folder_obj.name + " module")
	folder_obj.execute()

def update_bids_ignore():
	"""
		writes a new .bidsignore file in BIDS root. 
	"""
	with open(dest + '/.bidsignore', 'w') as f:
		f.write("#Ignore certain warnings\n")
		f.write('./*.tsv\n')
		f.write('**/*_bold.nii.gz')
	print("Wrote .bidsignore")
	#fix 6: custom column without description error in 
	#func/sub-7T049C10_task-8bars_dir-AP_run-1_events.tsv

def run_validator():
	"""
		runs the bids validator program from docker container
	"""
	print("Running the bids validator docker script")
	result = subprocess.run(["{}/validate_bids_output.sh".format(code_path)], stdout=subprocess.PIPE)
	print("check ./derivatives/bids-validator_report.txt")
	
def main():
	"""
	fix_bids_tree program 
	creates a new BIDS tree copy if not existing, and adds a new subject 
	to the tree. 
	arguments:
		- -v verbose output (not implemented)
		- first argument: subject string, if missing use default sub-7T049C10
	
	copy subject to tree
	process each subfolder
	write .bidsignore file
	run BIDS validator script
	
	output:
		- an updates fixed-rawdata directory with new subject added
		- updated derivatives directory
		- bids validator output
	"""
	global subj, code_path
	#todo: use issues on githubs
	#TODO: implement verbose? 
	#TODO: allow to pass multiple subjects to script and do them all?
	code_path = os.path.dirname(os.path.relpath(__file__))
	
	parser = argparse.ArgumentParser(description = "Fix BIDS tree output from Philips 7T")
	parser.add_argument('-v', '--verbose', nargs='?', const=True, type=bool)
	parser.add_argument('positionals', nargs='*')
	args = parser.parse_args()
	
	if args.verbose:
		print("TODO: implement Verbose output")
	if not args.positionals:
		print("using default subject " + subj)
	else:
		subj = args.positionals[0]
		print("subject is " + subj)
		
	#copy the subject files to the destination tree
	copy_bids_tree()
	#prepare scans.tsv file
	bids_util.load_original_scans(dest, subj)
	#execute fixes for each folder
	fix_anat(dest, subj).execute()
	fix_dwi(dest, subj).execute()
	fix_func(dest, subj).execute()
	fix_fmap(dest, subj).execute()
	#save scans.tsv with changes
	bids_util.save_new_scans()
	
	update_bids_ignore()

	run_validator()

if __name__ == "__main__":
	main()

