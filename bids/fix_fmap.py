import os
import json
import pydicom
import bids_util

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
		s.sc_pre_str = "fmap/{}".format(subj)
		
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
	
	def calc_total_readout_time(s, se_dir):
		"""
		read DICOM files to get phase encoding direction and  
		calculate total readout time according to 
		https://osf.io/xvguw/wiki/home/?view_only=6887e555825743c7bbdfce114500fb8d
		
		arguments.
			se_dir: either PA or AP. affects which file to edit. 
		"""
		idx = 12 if se_dir == "PA" else 13
		dcm_file = "./sourcedata/{}/s{}01_fmap_acq-se_dir-{}/fmap_acq-se_dir-{}_00001.dcm".format(s.subj, idx, se_dir, se_dir) 
		print("reading header from " + dcm_file)
		ds = pydicom.read_file(dcm_file)
		
		if(ds[0x0018, 0x1312].value == 'COL'): #'InPlanePhaseEncodingDirection'
			phase_encoding_dir =  'i'
		else:
			print("ERROR: unknown phase encoding direction in DICOM files")
			phase_encoding_dir =  'Error' 
		water_fat_shift = ds[0x2001, 0x1022].value #'WaterFatShift'
		imag_freq = ds[0x0018, 0x0084].value #'ImagingFrequency'
		epi_factor = ds[0x2001, 0x1013].value #'EPIFactor'
		actual_echo_spacing = water_fat_shift / (imag_freq * 3.4
								* (epi_factor + 1))
		total_readout_time = actual_echo_spacing * epi_factor
		print("calculated total readout time as " +  str(total_readout_time))
		return phase_encoding_dir, total_readout_time
	
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
			phase_enc_dir, total_readout_time = s.calc_total_readout_time(dr)
			json_dict["PhaseEncodingDirection"] = phase_enc_dir
			json_dict["TotalReadoutTime"] = total_readout_time
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
			executed by fix_bids_tree.py
			performs fixes for BIDS tree and updates scans.tsv
		"""
		print("folder fmap on " + s.part_filename)
		s.rename_gre_fmap()
		s.add_missing_se_data()
		s.add_missing_gre_data()
		
		bids_util.rename_scan_file(s.sc_pre_str + "_acq-gre_dir-AP_run-1_epi1.nii.gz",
				[s.sc_pre_str + "_acq-gre_run-1_fieldmap.nii.gz"])
		bids_util.rename_scan_file(s.sc_pre_str + "_acq-gre_dir-AP_run-1_epi2.nii.gz",
				[s.sc_pre_str + "_acq-gre_run-1_magnitude.nii.gz"])
