
class fix_func:
	"""
	class for fixing the func folder
	
	fix 4: slice timing not defined for func
	fix warning av TSV file columns
	"""
	
	def __init__(s, dest, subj):
		"""
		arguments: 
			- dest: relative folder to root of BIDS tree
			- subj: subject folder name
		"""
		s.name = "func"
		s.subj = subj
		s.part_filename = "./{}/{}/{}/{}".format(dest, subj, s.name, subj)
		s.blacklist=[]
	
	def fix_tsv_column_desc(s):
		print("TODO: fix missing column desc in tsv file")
	
	def add_missing_json_data(s):
		print("TODO: implement SliceTiming, currently done in .bidsignore")
	
	def execute(s):
		"""
			executed by process_folder in fix_bids_tree.py
			returns a list of strings of files to be deleted, with wildcards
		"""
		s.fix_tsv_column_desc()
		s.add_missing_json_data()
		return s.blacklist

class fix_dwi:
	"""
	class for fixing the dwi folder
	delete unwanted files in dwi folder
	fix 1c: remove unneeded ADC files
	"""
	
	def __init__(s, dest, subj):
		"""
		arguments: 
			- dest: relative folder to root of BIDS tree
			- subj: subject folder name
		
		"""
		s.name = "dwi"
		s.subj = subj
		s.part_filename = "./{}/{}/{}/{}".format(dest, subj, s.name, subj)		
		s.blacklist=[s.part_filename + "*heudiconv*ADC*"]
		
	def execute(s):
		"""
			executed by process_folder in fix_bids_tree.py
			returns a list of strings of files to be deleted, with wildcards
		"""
		return s.blacklist
