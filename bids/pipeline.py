#!/usr/bin/python
import json
import sys
import time
import argparse
import datetime
import os
import bids_util
from bids_util import log_print
import subprocess

import fix_bids_tree
from create_pymp2rage import pymp2rage_module
from create_derivs import quit_module, spm12_module

#this program was written by Axel Landgren for Region Skåne, for questions: 
#axel.landgren@skane.se  
#or gmail

def dicom_convert(runner):
	"""
	task to convert dicoms to nifti files using DcmSourcedata_to_NiftiRawdata.sh 
	 		
	argument:
		- runner: parent task_runner context
	"""
	subj = runner.subj
	#TODO: allow use of global "orig_bids_root" option, requires mod script.  
	log_print("running dicom convert on " + subj)
	sh_cmd = "{}/DcmSourcedata_to_NiftiRawdata.sh".format(runner.code_path)
	short_subj = subj[4:]
	runner.sh_run("{}/DcmSourcedata_to_NiftiRawdata.sh".format(runner.code_path), short_subj)	

def fix_bids_task(runner):
	"""
	task to fix the bids free from validation errors. 
	argument:
		- runner: parent task_runner context
	"""
	subj = runner.subj
	vprint = runner.verbose_print
	vprint("running fix_bids convert on " + subj)
	
	fix_bids_tree.process_subject(runner)
	fix_bids_tree.run_validator(runner)

def mp2rage_task(runner):
	"""
	performs two small tasks computing input files and creating output 
	images with QUIT an pymp2rage.  
	
	argument:
		- runner: parent task_runner context
	"""
	#TODO: add derivatives folder option properly
	#run QUIT MP2RAGE processing
	quit_mod = quit_module(runner)
	runner.create_derivatives_destination("quit", "anat")
	quit_mod.create_QUIT_nifti()
	quit_mod.gen_T1_map_mp2rage()
	
	#run pymp2rage processing
	pymp2_mod = pymp2rage_module(runner)
	runner.create_derivatives_destination("pymp2rage", "anat")
	pymp2_mod.create_pymp2rage_input_files()
	pymp2_mod.make_pymp2rage()

def mask_background_task(runner):
	"""
	given a specific configuration outputs a masked brain image, using 
	bet or spmmask, and quit or pymp2rage. 
	
	argument:
		- runner: parent task_runner context
	"""
	runner.create_derivatives_destination("spm12", "anat")
	log_print(runner.task_config)
	spm_mod = spm12_module(runner)
	if(runner.get_task_conf("use_bet")):
		spm_mod.make_bet_mask()
	else:
		spm_mod.make_spm12_mask()
	spm_mod.remove_background()
	
def cat12_task(runner):
	"""
	executes cat12 processing to get a noise reduced t1w image from a 
	masked t1w image. 
	takes about 
	
	argument:
		- runner: parent task_runner context
	"""
	spm_mod = spm12_module(runner)
	runner.create_derivatives_destination("cat12", "anat")
	spm_mod.call_cat12()

def freesurfer_task(runner):
	"""
	executes freesurfer to <derivatives>/freesurfer/<subj>
	takes about 3hr. 
	
	argument:
		- runner: parent task_runner context
	"""
	subj = runner.subj
	fs_out_dir = runner.create_derivatives_destination("freesurfer", "anat")
	cat12_no_bg_nif = runner.get_deriv_folder("cat12", "anat") + "/mi.input_no_bg.nii.gz"
	fs_cmd = "recon-all -subjid {} -i {} -sd {}".format(subj, cat12_no_bg_nif, fs_out_dir)
	#TODO: do i need to pass the license file? read from environmental vars?
	runner.sh_run(fs_cmd, "-threads " + str(runner.get_task_conf("threads")) , "-all")

class log_item():
	def __init__(s, runner):
		"""
		manages logging of a single task. 
		
		a log item is created at the point in time when a task starts.
		It is not written to disk until the task is finished or failed. 

		argument:
			- runner: parent task_runner context

		"""
		s.runner = runner
		subj = runner.subj
		s.task = runner.cur_task
		s.t0 = datetime.datetime.now()
		#pass the running log file to bids_util so the prints will go there
		task_log_file_name = "{}/logs/{}/{}_{}.log".format(
			s.runner.get_global("deriv_folder"), subj, subj, s.task)
		s.task_log = open(task_log_file_name, "w")
		bids_util.update_log(s.task_log, runner.verbose)
		bids_util.log_print("{}: starting {}".format(s.t0, s.task, subj), force=True)
	
	def get_time_str(s, seconds):
		"""
		get runtime in minutes or seconds depending on time elapsed. 
		
		arguments:
			seconds: seconds elapsed as float
		returns:
			string in seconds or minutes
		"""
		if seconds > 150.0:
			return "{}min".format(str(round(seconds/60, 2)))
		else:
			return "{}s".format(str(round(seconds, 2)))
		
		
	def replace_log_line(s, log_line):
		"""
		the task log keeps track of when the last task was ran on a 
		given subject. this will replace the log line of a task if it exists,
		otherwise add it. 
		arguments.
			- log_line
		"""
		#create log dir if missing
		#create log file if missing
		#read all lines of log file
		#look for task in log file in first column	
		log_file = "{}/logs/{}_tasks.log".format(
			s.runner.get_global("deriv_folder"), s.runner.subj)
		try:
			f = open(log_file, 'r')
			old_lines = f.readlines()
			f.close()
		except: 
			old_lines = []
		new_lines = []
		replaced_line = False
		for line in old_lines:
			try:
				line_task, rest_line  = line.split('\t', 1)
			except:
				#ignore lines without correct tab formatting
				line_task = ""
			if(line_task == s.task):
				replaced_line = True
				old_line = line 
			elif not line_task == "":
				new_lines.append(line.rstrip())
		new_lines.append(log_line)
		
		with open(log_file, 'w') as f:
			for line in new_lines:
				f.write(f"{line}\n")
			f.write(f"{str(s.runner.config['global'])}")

	def write_error(s, e_str):
		"""
		close and update the log file after failure to execute a 
		task_runner task. 
		"""
		s.t1 = datetime.datetime.now()
		elapsed = (s.t1 - s.t0).total_seconds()
		log_print("task " + str(s.task) + " failed with " + e_str, force=True)
		log_line = "{}\t{}\t{}\t{}\t{}".format(s.task, str(s.t0), 
			str(elapsed), s.runner.task_config, e_str)
	
	def close(s):
		"""
		close and update the log file after successful execution of a 
		task_runner task. 
		"""
		s.t1 = datetime.datetime.now()
		elapsed = (s.t1 - s.t0).total_seconds()
		log_print("{} finished in {}".format(s.task, s.get_time_str(elapsed)), force=True)
		log_line = "{}\t{}\t{}\t{}".format(s.task, str(s.t0), str(elapsed), 
			s.runner.task_config)
		s.task_log.close()
		bids_util.update_log(None, s.runner.verbose)
		s.replace_log_line(log_line)

class task_runner():
	"""
	a class to control and log execution of pipeline processing steps. 
	see main program documention for usage instructions. 
	"""
	
	def verbose_print(s, arg):
		"""
		a print to stdout that only displays if verbose mode is true
		"""
		if s.verbose:
			print(arg)
	
	def sh_run(s, cmd, in_arg="", out_arg="", extra="", no_log=False):
		"""
		run a shell command with stdout and stderr being logged to 
		a log file. 
		arguments:
			cmd: first part of command line
			in_arg: second part of command (optional)
			out_arg: third part of command (optional)
			extra: extra arguments (optional)
			no_log: set true to not write log output to disk
		"""
		#identify the name of the command that will be used in the log
		#file, logs/<subj>/<subj>_<cmd>.log
		try:
			first_cmd, rest  = cmd.split(" ", 1) 
		except:
			first_cmd = cmd
		cmd_only = os.path.basename(first_cmd)
		log_dir = "{}/logs/{}".format(
			s.get_global("deriv_folder"), s.subj)
		pipe = "" if no_log else ">{}/{}_{}.log 2>&1".format(log_dir, s.subj, cmd_only)
		
		cmd = "{} {} {} {} {}".format(cmd, in_arg, out_arg, extra, pipe)
		log_print(cmd)
		if(not s.dummy_run):
			subprocess.run([cmd], shell=True)
		else:
			log_print("skipped execution")

	def get_deriv_folder(s, name, dest):
		"""
		Get the current derivatives folder plus 
		"""
		deriv = s.get_global("deriv_folder")
		return "{}/{}/{}/{}".format(deriv, name, s.subj, dest)

	def create_derivatives_destination(s, name, dest):
		"""
		create a derivatives tree named according to bids standard.
		
		arguments:
			subj: subject folder name
			name: deriv folder name
			dest: bids folder to create, such as anat, func etc. 
			delete_old: optional argument to remove old directory if existing. 
		"""
		deriv = s.get_global("deriv_folder")
		tree = "{}/{}/{}/{}".format(deriv, name, s.subj, dest)
		delete_old=False
		if os.path.exists(tree) and delete_old:
			remove_tree(tree)
		try:
			os.makedirs(tree)
		except:
			pass
		return tree

	def get_task_conf(s, key):
		"""
		alias to access a config option for task config. 
		arguments
			-key: option dict key. 
		"""
		return s.config[s.cur_task][key]

	def get_global(s, key):
		"""
		fetch a global option from config dict/json file, 
		providing a default value if missing.  
		"""
		#TODO: ponder defaults
		global_defaults = {
			"deriv_folder": "derivatives",
			"log_folder": "logs",
			"orig_bids_root": "rawdata"}
		try:
			return s.config["global"][key]
		except:
			default_val = global_defaults[key]
			s.config["global"][key] = default_val
			return default_val
	
	def __init__(s, json_config=None, task_arg=None, dummy=False, verbose=False):
		"""
		set up the task runner object given the program arguments
		"""
		s.verbose = verbose
		s.subj = None
		s.cur_task = None
		s.code_path = os.path.dirname(os.path.relpath(__file__))
		if(s.code_path == ""):
			s.code_path = "."
		s.dummy_run = dummy
		
		if(json_config==None):
			#fetch a default config
			json_config = s.code_path + "/pipeline_conf.json"
		
		print("loading " + json_config)
		input_json = open(json_config)
		s.config = json.load(input_json)
		s.config["global"]["version"] = PROGRAM_VERSION
		input_json.close()

		if(not task_arg == None):
			s.task_list = [task_arg[0]]
		else:
			s.task_list = s.config['task_list']

		#add all the current available tasks
		s.avail_tasks = {}
		s.avail_tasks["dicom_convert"] = dicom_convert
		s.avail_tasks["fix_bids"] = fix_bids_task
		s.avail_tasks["mp2rage"] = mp2rage_task
		s.avail_tasks['mask_remove_bg'] = mask_background_task
		s.avail_tasks["cat12"] = cat12_task
		s.avail_tasks["freesurfer"] = freesurfer_task

	def run_subject(s, subj):
		"""
		execute the current task/tasks for a given subject
		arguments:
			subj: a subject, typically from a list
		"""
		s.subj = subj
		for task in s.task_list:
			s.execute_task(task)

	def execute_task(s, task_name):
		"""
		execute and log a task for the current subject. 
		requires task name to already exist in the list of tasks 
		defined by the class. 
		
		arguments:
			task_name: a task that will be logged, must have a corresponding 
			task function in the list of tasks.  
		"""
		
		try:
			log_print("running {} for {}".format(task_name, s.subj), force=True)
			log_dir = "{}/logs/{}".format(s.get_global("deriv_folder"), s.subj)
			if not os.path.exists(log_dir):
				os.makedirs(log_dir)
			s.cur_task = task_name
			task_log = log_item(s)
			s.task_config = s.config[task_name]
			s.avail_tasks[task_name](s)
		except Exception as e:
			print("Error: Task error: " + str(e))
			task_log.write_error(str(e))
		#write to log
		task_log.close()

#this will be stored in the log, might be useful if future versions are 
#are incompatible? or not. 
PROGRAM_VERSION = 0.2

def main():
	"""
	set up a configuration of one or more to be run for one or more subject 
	folders, loaded from a json file. 
	intialize a task_runner instance that will execute this for each subject.  
	"""
	
	parser = argparse.ArgumentParser(description = "process BIDS data from 7T Philips MRI")
	parser.add_argument('-v', '--verbose',  action='store_true', default=False)
	parser.add_argument('-c', '--config', nargs=1, default=None, type=str)
	parser.add_argument('-t', '--task', nargs=1, default=None, type=str)
	parser.add_argument('-d', '--dummy', action='store_true', default=False)
	parser.add_argument('subj_list', nargs='*')
	args = parser.parse_args()
	print(args)
	#check if task is in there
	runner = task_runner(args.config, args.task, dummy=args.dummy, verbose=args.verbose)
	if(args.subj_list == []):
		print("using subject list from conf: " + str(runner.config["subj_list"]))
		subj_list = runner.config["subj_list"]
	else:
		subj_list = args.subj_list
	for subj in subj_list:
		runner.run_subject(subj)

if __name__ == "__main__":
   main()
