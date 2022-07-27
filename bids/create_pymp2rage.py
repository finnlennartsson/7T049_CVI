
import subprocess
import pymp2rage
import nibabel as nib

def sh_run(cmd, in_arg="", out_arg="", dim=""):
	cmd = "{} {} {} {}".format(cmd, in_arg, out_arg, dim)
	print(cmd)	
	result = subprocess.run([cmd], shell=True, stdout=subprocess.PIPE)

subj = "sub-7T049C10"

def create_pymp2rage_input_files(subj):
	#Ways to create a magnitude image
	
	pymp2rage_pre = "derivatives/pymp2rage/{}/anat".format(subj)
	raw_anat_path = "./rawdata/{}/anat/{}".format(subj, subj)

	real_1and2 = raw_anat_path +  "_run-1_inv-1and2_part-real_MP2RAGE.nii.gz"
	imag_1and2 = raw_anat_path +  "_run-1_inv-1and2_part-imag_MP2RAGE.nii.gz"
	cplx_1 = pymp2rage_pre + "/inv1_complex.nii.gz"
	cplx_2 = pymp2rage_pre + "/inv2_complex.nii.gz"
	cplx_1and2 = pymp2rage_pre + "/comb_complex.nii.gz"

	print("making combined complex nifti")	
	sh_run("fslcomplex -complex",  real_1and2 + " " + imag_1and2, cplx_1and2)

	print("making split complex niftis")	
	sh_run("fslcomplex -complex",  real_1and2 + " " + imag_1and2, cplx_1, " 0 0")
	sh_run("fslcomplex -complex",  real_1and2 + " " + imag_1and2, cplx_2, " 1 1")

	#print("getting combined mag and phase")
	#inv1and2_mag = pymp2rage_pre + "/inv1and2_mag.nii.gz"
	#inv1and2_phase = pymp2rage_pre + "/inv1and2_phase.nii.gz"
	#sh_run("fslcomplex -realpolar ", cplx_1, inv1and2_mag + " " + inv1and2_phase)

	print("getting magnitude and phase for inv 1")
	inv1_mag = pymp2rage_pre + "/inv1_mag.nii.gz"
	inv1_phase = pymp2rage_pre + "/inv1_phase.nii.gz"
	sh_run("fslcomplex -realpolar ", cplx_1, inv1_mag + " " + inv1_phase)
	
	print("getting magnitude and phase for inv 2")
	inv2_mag = pymp2rage_pre + "/inv2_mag.nii.gz"
	inv2_phase = pymp2rage_pre + "/inv2_phase.nii.gz"
	sh_run("fslcomplex -realpolar ", cplx_2, inv2_mag + " " + inv2_phase)

	print("copying geometry to output files")
	for f in (inv1_mag, inv1_phase):
		sh_run("fslcpgeom", cplx_1, f)
	for f in (inv2_mag, inv2_phase):
		sh_run("fslcpgeom", cplx_2, f)

def make_mp2rage(subj):
	"""
	Create a MP2RAGE object by passing the input files previously created. 
	
	See documentation at  
	https://github.com/Gilles86/pymp2rage/blob/master/pymp2rage/mp2rage.py
	"""
	print("calculating pyMP2RAGE")
	pymp2rage_pre = "derivatives/pymp2rage/{}/anat".format(subj)
	inv1_mag = pymp2rage_pre + "/inv1_mag.nii.gz"
	inv1_phase = pymp2rage_pre + "/inv1_phase.nii.gz"
	inv2_mag = pymp2rage_pre + "/inv2_mag.nii.gz"
	inv2_phase = pymp2rage_pre + "/inv2_phase.nii.gz"
#	our settings?
#	mp2_obj = pymp2rage.MP2RAGE(MPRAGE_tr=6,
#		invtimesAB=[0.9, 2],
#		flipangleABdegree=[6, 8],
#		nZslices=257,
#		FLASH_tr=[0.062, 0.320],
#	B0=7.0,
#   B1_fieldmap=<insert fieldmap file here>
#use default settings now to prevent crashing
	mp2_obj = pymp2rage.MP2RAGE(MPRAGE_tr=6.0,
		invtimesAB=[0.67, 3.855],
		flipangleABdegree=[7, 6],
		nZslices=150,
		FLASH_tr=[0.0062, 0.0320],
		
		inv1=inv1_mag,
		inv1ph=inv1_phase,
		inv2=inv2_mag,
		inv2ph=inv2_phase)
	print("done")
	
	#The object has these Attributes:
    #    t1map (Nifti1Image): Quantitative T1 map
    #    t1w_uni (Nifti1Image): Bias-field corrected T1-weighted image
    #    t1map_masked (Nifti1Image): Quantitative T1 map, masked
    #    t1w_uni_masked (Nifti1Image): Bias-field corrected T1-weighted map, masked
	nib.save(mp2_obj.t1w_uni, pymp2rage_pre + "/py_MP2RAGE_UNI.nii.gz")
	print("saved " + pymp2rage_pre + "/py_MP2RAGE_UNI.nii.gz")
	nib.save(mp2_obj.t1map, pymp2rage_pre + "/py_MP2RAGE_T1.nii.gz")
	print("saved " + pymp2rage_pre + "/py_MP2RAGE_T1.nii.gz")
	
create_pymp2rage_input_files(subj)
make_mp2rage(subj)
