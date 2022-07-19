import os
import json

#fix the fmap folder. 

#fix 2: add phasecodingdirection to fmap/sub-7T049C10_acq-se_dir-AP_run-1_epi.nii.gz
#fmap.fix_phase_coding(subj)
	
#fix 3: fix =TOTAL_READOUT_TIME_MUST_DEFINE  for 
#fmap/sub-7T049C10_acq-se_dir-AP_run-1_epi.nii.gz

class fix_fmap:
	"""
	class for fixing the fmap folder
	"""
	
	def __init__(s, dest, subj):
		"""
		arguments: 
			- dest: relative folder to root of BIDS tree
			- subj: subject folder name
		
		"""
		s.name = "fmap"
		s.part_filename = "./{}/{}/{}/{}".format(dest, subj, s.name, subj)
		s.part_bold_name = "{}/{}".format("func", subj)
		s.subj = subj
		s.blacklist=[]
	
	def add_missing_gre_data(s):
		"""
		update GRE fieldmap file to have  Units = rad/s
		"""
		#TODO: make wrapper code for json config handling?
		#would need to put that in separate utility py script, or pass to constructor
		json_file = s.part_filename + "_acq-gre_run-1_fieldmap.json"
		print("editing " + json_file)
		input_json = open(json_file)
		json_file_temp = json_file + ".tmp"
		json_dict = json.load(input_json)
		input_json.close()
		#update the json dict according to nii header?
		json_dict["Units"] = 'rad/s'
		out_file = open(json_file_temp, "w")
		json.dump(json_dict, out_file)
		out_file.close()
		os.rename(json_file_temp, json_file)
	
	def calc_total_readout_time(s):
		"""
		calculate total readout time according to 
		https://osf.io/xvguw/wiki/home/?view_only=6887e555825743c7bbdfce114500fb8d
		"""
		#values fetched from source data dicoms
		#WaterFatShift = 2001,1022
		#dcmdump fmap_acq-se_dir-PA_00107.dcm  | grep 2001,1022
		# (2001,1022) FL 31.384811 #   4, 1 WaterFatShift
		water_fat_shift = 31.384811
		#ImagingFrequency = 0018,0084
		#dcmdump fmap_acq-se_dir-PA_00107.dcm  | grep 0018,0084
		# (0018,0084) DS [298.038485] #  10, 1 ImagingFrequency
		imag_freq = 298.038485
		#EPI_Factor = 0018,0091 or 2001,1013 			
		#(2001,1013) SL 45             #   4, 1 EPIFactor
		epi_factor = 45 
		actual_echo_spacing = water_fat_shift / (imag_freq * 3.4
								* (epi_factor + 1))
		total_readout_time = actual_echo_spacing * epi_factor
		print("calculated total readout time as " +  str(total_readout_time))
		return total_readout_time
	
	def add_missing_se_data(s):
		"""
		add the missing json config for the SE fieldmap. This includes
		TotalReadoutTime, PhaseEncodingDirection and IntendedFor. 
		"""
		
		target_files = []
		#The target fMRI files the SE fieldmap will be used for. 
		for i in (1, 2, 3 ,4):
			target_files.append(s.part_bold_name + "_task-8bars_dir-AP_run-{}_bold.nii.gz".format(i))
		for dr in ['AP', 'PA']:
			json_file = s.part_filename + "_acq-se_dir-" + dr + "_run-1_epi.json"
			print("editing " + json_file)
			input_json = open(json_file)
			json_file_temp = json_file + ".tmp"
			json_dict = json.load(input_json)
			input_json.close()
			#Phaseencoding can be found from:
			#dcmdump fmap_acq-se_dir-PA_00001.dcm | grep 0018,1312
			#CS [COL]           #   4, 1 InPlanePhaseEncodingDirection
			# COL means PhaseEncodingDirection is set to  i 
			json_dict["PhaseEncodingDirection"] = 'i'
			json_dict["TotalReadoutTime"] = s.calc_total_readout_time()
			json_dict["IntendedFor"] = target_files	
			out_file = open(json_file_temp, "w")
			json.dump(json_dict, out_file)
			out_file.close()
			os.rename(json_file_temp, json_file)
			
	def rename_gre_fmap(s):
		"""
		function to make sure the GRE fieldmap files are named
		_fieldmap and _magnitude respectively. 
		"""
		base_gre_filename = s.part_filename + "_acq-gre_dir-AP_run-1_"
		out_fmap_filename = s.part_filename + "_acq-gre_run-1_" 
		
		for idx in [1, 2]:
			if(idx == 1):
				input_file = base_gre_filename + "epi1";
				output_file = out_fmap_filename + "fieldmap";
			elif(idx == 2): 
				input_file = base_gre_filename + "epi2";
				output_file = out_fmap_filename + "magnitude";
			else:
				print("wrong index")
				sys.quit();
			for ending in [".json", ".nii.gz"]:
				os.rename(input_file + ending, output_file + ending)
				print("moved " + output_file + ending)
			
	def execute(s):
		"""
			executed by process_folder in fix_bids_tree.py
			returns a list of strings of files to be deleted, with wildcards
		"""
		print("folder fmap on " + s.part_filename)
		s.rename_gre_fmap()
		s.add_missing_se_data()
		s.add_missing_gre_data()
		return s.blacklist

	
	

