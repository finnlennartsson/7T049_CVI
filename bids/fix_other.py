import bids_util
from bids_util import log_print

class fix_func:
	"""
	class for fixing the func folder
	
	fix 4: slice timing not defined for func
	fix warning av TSV file columns
	"""
	
	def __init__(s, runner):
		"""
		arguments: 
			- runner: task runner executing fix bids
		"""
		s.name = "func"
		s.bids_out = runner.get_task_conf("bids_output")
		s.subj = runner.subj
		s.ap_ph_enc_dir = runner.get_task_conf("epi_ap_ph_enc_dir")
		s.dicom_dir = "./sourcedata/{}/*fmri_8bars*/".format(s.subj) 
		#first half of each bids fileanme
		s.root_folder = "{}/{}/{}/".format(s.bids_out, s.subj, s.name)
		s.part_filename = s.root_folder + s.subj
		s.blacklist=[]
	
	def fix_tsv_column_desc(s):
		log_print("TODO: fix missing column desc in tsv file")
	
	def add_missing_json_data(s):
		log_print("TODO: implement SliceTiming, currently done in .bidsignore")
	
	def execute(s):
		"""
			executed in fix_bids_tree.py
		"""
		try:
			bids_util.update_epi_json_files(s.root_folder, s.dicom_dir, s.ap_ph_enc_dir)
			s.fix_tsv_column_desc()
			s.add_missing_json_data()
		except Exception as e:
			log_print("fix_fmap failed with: " + str(e), force=True)
		
class fix_dwi:
	"""
	class for fixing the dwi folder
	delete unwanted files in dwi folder
	fix 1c: remove unneeded ADC files
	
	TODO: get the right b-values and b-vectors - from sequences folder? 
	"""
	
	def __init__(s, runner):
		"""
		ssetup filenames needed for fixes.  
		arguments
			- runner: task runner executing fix bids
		"""
		s.name = "dwi"
		s.bids_out = runner.get_task_conf("bids_output")
		s.subj = runner.subj
		s.ap_ph_enc_dir = runner.get_task_conf("epi_ap_ph_enc_dir")
		s.dicom_dir = "./sourcedata/{}/*dmri*/".format(s.subj) 
		#first half of each bids fileanme
		s.root_folder = "{}/{}/{}/".format(s.bids_out, s.subj, s.name)
		s.part_filename = s.root_folder + s.subj
		s.blacklist=[s.part_filename + "*heudiconv*ADC*"]
		
	def execute(s):
		"""
			executed in fix_bids_tree.py
		"""
		try:
			bids_util.update_epi_json_files(s.root_folder, s.dicom_dir, s.ap_ph_enc_dir)
		except Exception as e:
			log_print("fix_dwi failed with: " + str(e), force=True) 
		for f in s.blacklist:
			 bids_util.wildcard_delete(f)
