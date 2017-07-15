
#!/bin/bash 
#BSUB -L /bin/bash 
#BSUB -J my_job[1-3017]%200
#BSUB -M 4000
#BSUB -o job_out
#BSUB -e job_err
#BSUB -q short

#Other options commented
#number of processors
##BSUB -n 5
#number of threads
##BSUB -T 10 
#send email for each job
##BSUB -N


function run {

cid=$1
study=$2
tmp_base=$3

sid=`echo $cid | cut -f1 -d "_"`

remote="copd@mad-replicated1.research.partners.org:Processed/$study/$sid/$cid/"

cip=/PHShome/rs117/projects/code/cip
cipBuild=/PHShome/rs117/projects/code/cip-build/

tmpDir=$tmp_base/$cid
mkdir $tmpDir
cd $tmpDir

#Delay to prevent overflow
perl ${ACIL_PATH}/Scripts/MADWait.pl 200 10 5

#Copy Data
scp $remote/$cid.nrrd .

#OLD Script that relied on LIP
#python /PHShome/rs117/projects/Scripts/WTC/WTCEmphysemaAnalysis.py -c $cid --tmpDir $tmpDir/$cid --dataDir $tmpDir

#New pipeline based on CIP

#Preprocess image to account for noise and kernel deviations
unu resample -k dgauss:0.75,3 -s x1 x1 = -i ${cid}.nrrd -o ${cid}_ff.nrrd

splittingRadius=1
GeneratePartialLungLabelMap --ict ${cid_ff}.nrrd -o ${cid}_partialLungLabelMap.nrrd --lsr $splittingRadius

#Left/Right Splitter
python ${ACIL_PATH}/acil_python/lung_splitter.py -i ${cid}_partialLungLabelMap.nrrd -o ${cid}_partialLungLabelMap.nrrd -t

#QualityControl
#QualityControl --ict ${cid}.nrrd --ilm ${cid}_partialLungLabelMap.nrrd --lung ${cid}_labelMapCoronalProjectionImage.png  --airway ${cid}_labelMapAirwayCoronalProjectionImage.png

python ${CIP_SRC}/cip_python/qualitycontrol/ct_qc.py --in_ct ${cid}.nrrd --output_file ${cid}_projectionMontage.png  --resolution 600 --window_width=1400 --window_level=-500
python ${CIP_SRC}/cip_python/qualitycontrol/lung_segmentation_qc.py --in_ct ${cid}.nrrd --in_partial ${cid}_partialLungLabelMap.nrrd --output_file ${cid}_partialLungLabelMapQCMontage.png --window_width=1400 --window_level=-500  --overlay_opacity=0.2 --qc_regionstypes --qc_leftlung --qc_rightlung --resolution 600


#Generate phenotypes
#GenerateParenchymaPhenotypes -c ${cid}.nrrd -p ${cid}_partialLungLabelMap.nrrd --oh ${cid}_regionHistograms.csv --op ${cid}_parenchymaPhenotypes.csv
regions="WholeLung,LeftLung,RightLung,LeftUpperThird,LeftMiddleThird,LeftLowerThird,RightUpperThird,RightMiddleThird,RightLowerThird"
python ${CIP_SRC}/cip_python/phenotypes/parenchyma_phenotypes.py --in_ct ${cid}.nrrd --in_lm ${cid}_partialLungLabelMap.nrrd -r $regions--cid ${cid} --out_csv ${cid}_parenchymaPhenotypes.csv

scp $tmpDir/${cid}_partialLungLabelMap.nrrd $remote
scp $tmpDir/${cid}_parenchymaPhenotypes.csv $remote
scp $tmpDir/${cid}_*Montage.png $remote

#Delete tmpDir
\rm $tmpDir/${cid}*
rmdir $tmpDir

mv $tmpDir/${cid}/${cid}_emphy*.csv $tmpDir/
\rm $tmpDir/${cid}.*
\rm -rf $tmpDir/${cid}/*
rmdir $tmpDir/${cid}

#echo "Job: $LSB_JOBINDEX"
}

# move to the directory where the data files locate
#cd /PHShome/rs117/Databases/COPDGene

study=WTC
tmp_base=${TMP_DIR}/WTCAnalysis

caselist[0]="${WTC_PATH}/CaseLists/WTMendelsonCaseList.txt"
caselist[1]="${WTC_PATH}/CaseLists/WTCaseList.txt"
caselist[2]="${WTC_PATH}/CaseLists/WTGoodCTCaseList.txt"
id=2


#LSB_JOBINDEX=1
# set input file to be processed
cid=(`sed -n "$LSB_JOBINDEX"p ${caselist[$id]}`)

sid=`echo $cid | cut -f1 -d "_"`


#File check to decide if we trigger the pipleine

testfile=Processed/$study/$sid/$cid/${cid}_parenchymaPhenotypes.csv

ssh copd@mad-replicated1.research.partners.org "test -s $testfile" && echo "$cid: File exists and has content" || run $cid $study $tmp_base

# run the analysis command
# run $cid $study $tmp_base
