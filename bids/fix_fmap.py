import os
import json
import pydicom
import bids_util
from bids_util import log_print
import glob

class fix_fmap:
	"""
	class for fixing the fmap, called by fix_bids
	"""
	
	def __init__(s, runner):
		"""
		arguments: 
			- runner: task runner executing fix bids
		"""
		s.name = "fmap"
		s.bids_out = runner.get_task_conf("bids_output")
		s.subj = runner.subj
		#first half of each bids fileanme
		s.root_folder = "{}/{}/{}/".format(s.bids_out, s.subj, s.name)
		s.part_filename = s.root_folder + s.subj
		s.epi_ap_ph_enc_dir = runner.get_task_conf("epi_ap_ph_enc_dir")
		s.part_bold_name = "{}/{}".format("func", s.subj)
		s.dicom_dir = "./sourcedata/{}/*fmap*/".format(s.subj)
		s.sc_pre_str = "fmap/{}".format(s.subj)
		
		s.blacklist=[]
	
	def add_missing_gre_data(s):
		"""
		update GRE fieldmap file to have  Units = rad/s
		"""
		#TODO: make wrapper code for json config handling?
		#would need to put that in separate utility py script, or pass to constructor
		json_file = s.part_filename + "_acq-gre_run-1_fieldmap.json"
		log_print("editing " + json_file)
		input_json = open(json_file)
		json_file_temp = json_file + ".tmp"
		json_dict = json.load(input_json)
		input_json.close()
		#update the json dict according to nii header?
		json_dict["Units"] = 'rad/s'
		out_file = open(json_file_temp, "w")
		json.dump(json_dict, out_file, indent=2)
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
		
		dcm_file = glob.glob("./sourcedata/{}/*fmap*dir-{}*/*.dcm".format(s.subj, se_dir))[0]
		print("reading header from " + dcm_file)
		ds = pydicom.read_file(dcm_file)
		if(ds[0x0018, 0x1312].value == 'COL'): #'InPlanePhaseEncodingDirection'
			#TODO: fix correct phase encoding readout
			phase_encoding_dir =  'j' if se_dir == "PA" else 'j-'
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
		IntendedFor. Since we now do TotalReadoutTime and PhaseEncodingDirection
		in bids_util.update_epi_json_files
		"""
		
		target_files = []
		#The target fMRI files the SE fieldmap will be used for. 
		for i in (1, 2, 3 ,4):
			target_files.append(s.part_bold_name + "_task-8bars_dir-AP_run-{}_bold.nii.gz".format(i))
		for dr in ['AP', 'PA']:
			json_file = s.part_filename + "_acq-se_dir-" + dr + "_run-1_epi.json"
			log_print("editing " + json_file)
			try: 
				input_json = open(json_file)
				json_file_temp = json_file + ".tmp"
				json_dict = json.load(input_json)
				input_json.close()
				json_dict["IntendedFor"] = target_files	
				out_file = open(json_file_temp, "w")
				json.dump(json_dict, out_file, indent=2)
				out_file.close()
				os.rename(json_file_temp, json_file)
			except Exception as e:
				log_print(str(e), force=True)
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
				log_print("renamed " + output_file + ending)
			
	def execute(s):
		"""
			executed by fix_bids_tree.py
			performs fixes for BIDS tree and updates scans.tsv
		"""
		bids_util.update_epi_json_files(s.root_folder, s.dicom_dir, s.epi_ap_ph_enc_dir)
		s.rename_gre_fmap()
		s.add_missing_se_data()
		s.add_missing_gre_data()
		bids_util.rename_scan_file(s.sc_pre_str + "_acq-gre_dir-AP_run-1_epi1.nii.gz",
				[s.sc_pre_str + "_acq-gre_run-1_fieldmap.nii.gz"])
		bids_util.rename_scan_file(s.sc_pre_str + "_acq-gre_dir-AP_run-1_epi2.nii.gz",
				[s.sc_pre_str + "_acq-gre_run-1_magnitude.nii.gz"])
