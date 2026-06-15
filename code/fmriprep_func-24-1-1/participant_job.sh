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

# Fail whenever something is fishy, use -x to get verbose logfiles:
set -e -u -x

dssource="$1"	# i.e., `input_ria`
pushgitremote="$2"	# i.e., `output_ria`
SUBJECT_CSV="$3"

subject_row=$(head -n $((${SLURM_ARRAY_TASK_ID} + 1)) ${SUBJECT_CSV} | tail -n 1)
subid=$(echo "$subject_row" | sed -n 's/^.*\(sub-[A-Za-z0-9]*\).*$/\1/p')
sesid=$(echo "$subject_row" | sed -n 's/^.*\(ses-[A-Za-z0-9]*\).*$/\1/p')

# Change path to an ephemeral (temporary) job compute workspace:
# The path is specified according to 'job_compute_space' in container's configuration YAML file.
cd ${TMP}

# Branch name (also used as temporary directory):
BRANCH="job-${SLURM_ARRAY_JOB_ID}-${subid}-${sesid}"
mkdir ${BRANCH}
cd ${BRANCH}

# Clone the data from input RIA:
datalad clone "${dssource}" ds
cd ds
# Register output RIA as remote for result deposition:
git remote add outputstore "${pushgitremote}"

# Create a new branch for this job's results:
git checkout -b "${BRANCH}"

# Pull down the input subject (or dataset) but don't retrieve data contents:
datalad get -n "inputs/data/BIDS/${subid}"
(cd inputs/data/BIDS && rm -rf `find . -type d -name 'sub*' | grep -v $subid`)
datalad get -n "inputs/data/fmriprep_anat"
(cd inputs/data/fmriprep_anat && rm -f `ls sub-*.zip | grep -v ${subid}`)

# Get the zip filename of current subject (or session):
FMRIPREP_ANAT_ZIP=$(ls inputs/data/fmriprep_anat/${subid}_${sesid}_*fmriprep_anat*.zip | cut -d '@' -f 1 || true)
echo 'found fmriprep_anat zipfile:'
echo ${FMRIPREP_ANAT_ZIP}
if [ -z "${FMRIPREP_ANAT_ZIP}" ]; then
	echo 'No input zipfile of fmriprep_anat found for ${subid} ${sesid}'
	exit 99
fi
array=($FMRIPREP_ANAT_ZIP)
if [ "${#array[@]}" -gt "1" ]; then
	echo 'There is more than one input zipfile of fmriprep_anat found for ${subid} ${sesid}'
	exit 98
fi

# datalad run:
datalad run \
	-i code/fmriprep-24-1-1_zip.sh \
	-i inputs/data/BIDS/${subid}/${sesid} \
	-i 'inputs/data/BIDS/*json' \
	-i ${FMRIPREP_ANAT_ZIP} \
	-i containers/.datalad/environments/fmriprep-24-1-1/image \
	--expand inputs \
	--explicit \
	-o ${subid}_${sesid}_fmriprep_func-24-1-1.zip \
	-m "fmriprep-24-1-1 ${subid} ${sesid}" \
	"bash ./code/fmriprep-24-1-1_zip.sh ${subid} ${sesid} ${FMRIPREP_ANAT_ZIP}"

# Push result file content to output RIA storage:
datalad push --to output-storage
# Push the branch with provenance records:
flock $DSLOCKFILE git push outputstore

echo 'Delete temporary directory:'
echo ${BRANCH}
datalad drop -d inputs/data/BIDS -r --reckless availability --reckless modification
datalad drop -d inputs/data/fmriprep_anat -r --reckless availability --reckless modification
datalad drop -r . --reckless availability --reckless modification
git annex dead here
cd ../..
rm -rf $BRANCH

echo SUCCESS
