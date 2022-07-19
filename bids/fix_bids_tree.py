
import os
import sys
import glob
import argparse
import subprocess
import shutil
from distutils.dir_util import copy_tree, remove_tree
from distutils.errors import DistutilsFileError

from fix_anat import fix_anat
from fix_fmap import fix_fmap
from fix_other import fix_dwi, fix_func

source = "rawdata"
dest = "fixed_rawdata"
#default subject goes here - maybe replace with error message later
subj = "sub-7T049C10"
code_path = ""

def copy_bids_tree():
	"""
	Create or update a bids tree in <dest> folder. <subj> will be copied 
	here and processed to not cause BIDS validation errors.  
	"""
	
	global source, dest
	# Create a new directory if it does not exist 
	dest_tree = "./{}/{}".format(dest, subj)
	deriv_tree = "./derivatives/quit/{}/anat".format(subj)

	#create empty derivatives folder
	if os.path.exists(deriv_tree):
		remove_tree(deriv_tree)
	os.makedirs(deriv_tree)
	
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
	
	#update scans.tsv
	#TODO: kind of ugly hack! but would be fiddly to generate this tsv 
	shutil.copy("{}/renamed_scans.tsv".format(code_path), "{}/{}_scans.tsv".format(dest_tree, subj))
	print("updated <subj>_scans.tsv")

def wildcard_delete(f_wc):
	"""
	deletes one or more files that match the filename passed
	Inputs:
		- f_wc: a file name that can include wildcard characters
				to match one or several files
	
	"""
	#support wildcards
	print("deleting " + f_wc)
	matching_files = glob.glob(f_wc)
	# Iterate over the list of filepaths & remove each file.
	f_ct = 0
	for f in matching_files:
		try:
			#print("deleting " + f)
			os.remove(f)
			f_ct += 1
		except:
			print("Error while deleting file : ", f)
	print(str(f_ct) + " files deleted")

def process_folder(folder_obj):
	"""
		execute the execute() function of the module passed to it. 
		delete all the files in the blacklist returned from the execute function
		
		Inputs:
			- folder_obj - a class that has an execute function that 
				returns a list of strings
		
	"""
	print("executing " + folder_obj.name + " module")
	bl = folder_obj.execute()	
	for f in bl:
		wildcard_delete(f)
	
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

	copy_bids_tree()

	process_folder(fix_anat(dest, subj))
	process_folder(fix_dwi(dest, subj))
	process_folder(fix_func(dest, subj))
	process_folder(fix_fmap(dest, subj))

	update_bids_ignore()

	run_validator()

if __name__ == "__main__":
	main()

