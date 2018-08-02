#!/bin/bash

#BSUB -L /bin/bash
#BSUB -M 8000
#BSUB -q medium
#BSUB -J wt_str[1-5211]%200
#BSUB -o wt_structures_out
#BSUB -e wt_structures_err
#BSUB -u rubensanjose@bwh.harvard.edu


study=WTC
caselist=/PHShome/rs251/src/WTC/CaseLists/WTGoodCTCaseList.txt


models_folder="/data/acil/DCNN_models"
output_folder="/data/acil/tmp/ruben/WTC/structuresDetection"

mkdir -p ${output_folder}

function run {
  cid=$1
  models_folder=$2
  output_folder=$3
  output_file_name=$4
  
  sid=`echo $cid | cut -f1 -d "_"`
  
  perl ${ACIL_PATH}/Scripts/MADWait.pl 200 10 5

  # Download case
  echo "Download volume..."
  python ${ACIL_PATH}/acil_python/data/acilget.py Processed/WTC/${sid}/${cid}/${cid}.nrrd ${output_folder}

  # Run the algorithm
  echo "Running algorithm..."
  result_file=${output_folder}/${output_file_name}

  python ${ACIL_PATH}/Projects/dcnn_object_detection/experiments/detection_pipeline.py \
  --case ${output_folder}/${cid}.nrrd \
  --models_folder ${models_folder} \
  --output_geometry_topology_data_file ${result_file} \
  --use_structures_prior

   # Upload the result to MAD if the file was generated ok
  test -s ${result_file} \
          && python ${ACIL_PATH}/acil_python/data/acilput.py -remote_path Processed/WTC/${sid}/${cid}/${output_file_name} ${result_file} \
          || echo "Something went wrong in the pipeline. Result file ${result_file} not found!"

  # Remove CT scan
  rm ${output_folder}/${cid}.nrrd
}

# BSUB mode
index=$LSB_JOBINDEX

cid=(`sed -n "${index}"p ${caselist}`)
output_file_name=${cid}_dcnnStructuresDetection.xml
file_exists=$((python ${ACIL_PATH}/acil_python/data/archive_manager_facade.py EXIST -rf ${output_file_name}) 2>&1 )

if [ $file_exists = 'N' ];
  then run ${cid} ${models_folder} ${output_folder} ${output_file_name};
  else echo "File ${output_file_name} already exists";
fi

#echo "run ${cid} ${models_folder} ${output_folder} ${output_file_name}"
#run ${cid} ${models_folder} ${output_folder} ${output_file_name}

# Caselist mode
#while read cid; do
#  run $cid $models_folder $output_geometry_topology_data_folder $cases_temp_folder
#done < ${caselist}
