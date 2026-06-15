#!/bin/bash
#SBATCH --time=7:00:00
#SBATCH --tmp=200G
#SBATCH -p all
#SBATCH --nodes=1 
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=30G
#SBATCH --propagate=NONE


# Script preambles:
source /cbica/projects/pennlinc_rbc/miniforge3/bin/activate base

echo I\'m in $PWD using `which python`
path_check_setup=/cbica/projects/pennlinc_rbc/datasets/LINC_NKI/derivatives/fmriprep_func-24-1-1-babs/analysis/code/check_setup

# Fail whenever something is fishy, use -x to get verbose logfiles:
set -e -u -x

# Change path to an ephemeral (temporary) job compute workspace:
# The path is specified according to 'job_compute_space' in container's configuration YAML file.
cd ${TMP}

# Call `test_job.py`:
which_python=`which python`
current_pwd=${PWD}
echo 'Calling `test_job.py`...'
${which_python} /cbica/projects/pennlinc_rbc/datasets/LINC_NKI/derivatives/fmriprep_func-24-1-1-babs/analysis/code/check_setup/test_job.py --path-workspace ${current_pwd} --path-check-setup /cbica/projects/pennlinc_rbc/datasets/LINC_NKI/derivatives/fmriprep_func-24-1-1-babs/analysis/code/check_setup

echo SUCCESS
