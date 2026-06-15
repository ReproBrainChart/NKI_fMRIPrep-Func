#!/bin/bash
set -e -u -x

subid="$1"
sesid="$2"
FMRIPREP_ANAT_ZIP="$3"

# Create a filter file that only allows this session
filterfile=${PWD}/${sesid}_filter.json
echo "{" > ${filterfile}
echo "'fmap': {'datatype': 'fmap'}," >> ${filterfile}
echo "'bold': {'datatype': 'func', 'session': '$sesid', 'suffix': 'bold'}," >> ${filterfile}
echo "'sbref': {'datatype': 'func', 'session': '$sesid', 'suffix': 'sbref'}," >> ${filterfile}
echo "'flair': {'datatype': 'anat', 'session': '$sesid', 'suffix': 'FLAIR'}," >> ${filterfile}
echo "'t2w': {'datatype': 'anat', 'session': '$sesid', 'suffix': 'T2w'}," >> ${filterfile}
echo "'t1w': {'datatype': 'anat', 'session': '$sesid', 'suffix': 'T1w'}," >> ${filterfile}
echo "'roi': {'datatype': 'anat', 'session': '$sesid', 'suffix': 'roi'}" >> ${filterfile}
echo "}" >> ${filterfile}

# remove ses and get valid json
sed -i "s/'/\"/g" ${filterfile}
sed -i "s/ses-//g" ${filterfile}

wd=${PWD}
cd inputs/data/fmriprep_anat
7z x `basename ${FMRIPREP_ANAT_ZIP}`
cd $wd

mkdir -p ${PWD}/.git/tmp/wkdir
singularity run --cleanenv \
	-B ${PWD} \
	-B code/license.txt:/SGLR/FREESURFER_HOME/license.txt \
	containers/.datalad/environments/fmriprep-24-1-1/image \
	inputs/data/BIDS \
	outputs/fmriprep_func \
	participant \
	-w ${PWD}/.git/tmp/wkdir \
	--stop-on-first-crash \
	--fs-license-file /SGLR/FREESURFER_HOME/license.txt \
	--output-spaces func T1w MNI152NLin6Asym:res-2 \
	--force-bbr \
	--skip-bids-validation \
	-vv \
	--cifti-output 91k \
	--n_cpus 4 \
	--mem-mb 30000 \
	--fs-subjects-dir inputs/data/fmriprep_anat/fmriprep_anat/sourcedata/freesurfer \
	--bids-filter-file "${filterfile}" \
	--participant-label "${subid}"

cd outputs
7z a ../${subid}_${sesid}_fmriprep_func-24-1-1.zip fmriprep_func
cd ..
rm -rf outputs .git/tmp/wkdir
rm ${filterfile} 

