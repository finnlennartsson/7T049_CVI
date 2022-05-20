## fMRI processing

### Preprocessing
Preprocessing of fMRI data time-series
Run script \
`preprocess_fsl.sh`
1. `mcflirt -in fmri`
2. choose example_func as the mean of the mcf funcionals 
`fslmaths func_mcf -Tmean example_func`
3a. BET the flair and example_func
`bet -F`
3b. BET the fmap_magnitude (without -F)
`bet` 
4. Non-linear reg functional and FLAIR
`epi_reg_nobbr.sh example_func_brain and flair_brain`
5. No unwarp
`applywarp`

This gives motion and unwarp time-series


or \
`preprocess_fmriprep.sh`\
- [fMRIprep](https://fmriprep.org/en/stable/)

### 

## Resources
- [Winawer Lab](https://wikis.nyu.edu/display/winawerlab/home) [[Sample Data Pipeline](https://wikis.nyu.edu/display/winawerlab/Sample+Data+Pipeline)]

