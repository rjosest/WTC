#!/bin/bash

#BSUB -L /bin/bash
#BSUB -M 4000
#BSUB -q short

#BSUB -J WT_pect[1-5211]%200
#BSUB -o unet_pect_WT_out
#BSUB -e unet_pect_WT_err
##BSUB -u ${USER_EMAIL}

study=WTC
caselist=/PHShome/rs251/src/WTC/CaseLists/WTGoodCTCaseList.txt


#LSB_JOBINDEX=1
cid=(`sed -n "$LSB_JOBINDEX"p ${caselist}`)
#cid=(`sed -n "1"p ${caselist}`)
sid=`echo $cid | cut -f1 -d "_"`

segmentationResultFileName=${cid}_dcnnBodyComposition.nrrd
segmentationResultFileRemotePath="Processed/${study}/${sid}/${cid}/${segmentationResultFileName}"
modelsFolder="/data/acil/DCNN_models/unet_pectoralis_segmentation"
localTempFolder="/data/acil/tmp/ruben/WTC/unetBodyComposition/${cid}"
qcFilesFolder="/data/acil/tmp/ruben/WTC/unetBodyComposition/qc"
qcImageOutput="${qcFilesFolder}/${cid}_dcnnBodyComposition_qc.png"

# We need two different environments, unless we add keras and tensorflow to ACIL-CIP python
#kerasPython="/PHShome/jo780/anaconda2/envs/keras/bin/python"
#acilPython="/PHShome/jo780/anaconda2/envs/acil/bin/python"
#kerasPython="${HOME}/anaconda2/envs/keras/bin/python"
kerasPython="${HOME}/anaconda2/bin/python"
acilPython="${HOME}/anaconda2/bin/python"

function runSegmentation(){
  # Download XML and run the segmentation pipeline
  casePath=$1
  xmlPath=$2
  modelsFolder=$3
  localTempFolder=$4
  cid=$5
  segmentationResultFileRemotePath=$6

  echo "Downloading xml to ${localTempFolder}..."
  # Download the GeometryTopologyData xml
  ${acilPython} ${ACIL_PATH}/acil_python/data/acilget.py Processed/WTC/${sid}/${cid}/${cid}_dcnnStructuresDetection.xml ${localTempFolder}

  echo "Run segmentation..."
  echo "${kerasPython} ${ACIL_PATH}/Projects/dcnn_object_detection/experiments/unet_pectoralis_pipeline.py \
  --case_path ${casePath} \
  --xml_path ${xmlPath} \
  --segmentation_type 4 \
  --pectoralis_model ${modelsFolder}/unet_nc5_pecs_v01.hdf5 \
  --fat_model ${modelsFolder}/unet_nc3_fat_v01.hdf5 \
  --output_path ${localTempFolder}/${cid}_dcnnBodyComposition.nrrd"

  ${kerasPython} ${ACIL_PATH}/Projects/dcnn_object_detection/experiments/unet_pectoralis_pipeline.py \
  --case_path ${casePath} \
  --xml_path ${xmlPath} \
  --segmentation_type 4 \
  --pectoralis_model ${modelsFolder}/unet_nc5_pecs_v01.hdf5 \
  --fat_model ${modelsFolder}/unet_nc3_fat_v01.hdf5 \
  --output_path ${localTempFolder}/${cid}_dcnnBodyComposition.nrrd

   # Upload the file to MAD
  echo "Uploading result file to MAD (${segmentationResultFileRemotePath})..."
  ${acilPython} ${ACIL_PATH}/acil_python/data/acilput.py -remote_path Processed/WTC/${sid}/${cid}/${cid}_dcnnBodyComposition.nrrd ${localTempFolder}/${cid}_dcnnBodyComposition.nrrd
}

function runQC {
  # Generate QC images for the generated labelmap
  case_ct=$1
  labelmap=$2
  resultFile=$3

 echo "Generating QC image ${resultFile}..."
  ${acilPython} ${CIP_SRC}/cip_python/qualitycontrol/body_composition_qc.py \
    --in_ct \
    ${case_ct} \
    --in_body_composition \
    ${labelmap} \
    --qc_pecs_subcutaneousfat \
    --output_file \
    ${resultFile} \
    --overlay_opacity \
    0.6
}

function run {
  perl ${ACIL_PATH}/Scripts/MADWait.pl 200 10 5

  cid=$1
  localTempFolder=$2
  segmentationResultFileRemotePath=$3
  segmentationResultFileName=$4
  modelsFolder=$5
  qcFilesFolder=$6
  qcImageOutput=$7

  casePath=${localTempFolder}/${cid}.nrrd
  xmlPath=${localTempFolder}/${cid}_dcnnStructuresDetection.xml

  echo "Creating folders ${localTempFolder} and ${qcFilesFolder}..."
  mkdir -p "${localTempFolder}"
  mkdir -p "${qcFilesFolder}"

  # Download the volume
  echo "Download volume (localTempFolder=${localTempFolder})..."
  ${acilPython} ${ACIL_PATH}/acil_python/data/acilget.py Processed/WTC/${sid}/${cid}/${cid}.nrrd ${localTempFolder}

  # Run the pecs + fat segmentation (dcnn slice detection + unet segmentation)
  runSegmentation ${casePath} ${xmlPath} ${modelsFolder} ${localTempFolder} ${cid} ${segmentationResultFileRemotePath}

  # Generate a QC png image for the final result
  runQC ${casePath} "${localTempFolder}/${segmentationResultFileName}" ${qcImageOutput}

  # Remove temp files
  echo "Removing temp files..."
  rm -rf ${localTempFolder}
}

# Check if the QC image already exists. Otherwise, run the script
test -S ${qcImageOutput} \
  && echo "${qcImageOutput} already exists" \
  || run ${cid} ${localTempFolder} ${segmentationResultFileRemotePath} ${segmentationResultFileName} ${modelsFolder} ${qcFilesFolder} ${qcImageOutput}


echo "DONE ${cid}"

