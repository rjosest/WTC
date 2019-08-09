#!/bin/bash 
#BSUB -L /bin/bash
#BSUB -J WTbodComPhen[1-5211]%250
#BSUB -M 4000
#BSUB -o WT_bodComPhen_out
#BSUB -e WT_bodComPhen_err
#BSUB -q short


#Other options commented
#number of processors
##BSUB -n 5
#number of threads
#sBSUB -T 10
#send email for each job
##BSUB -N


function run {
  cid=$1
  study=$2
  tmp_base=$3
  
  sid=`echo $cid | cut -f1 -d "_"`


  tmpDir=$tmp_base/$cid
  mkdir $tmpDir
  cd $tmpDir


  remote="Processed/$study/$sid/$cid"

  # Delay to prevent overflow
  perl ${ACIL_PATH}/Scripts/MADWait.pl 250 10 5


  # Get data from MAD
  python ${ACIL_PATH}/acil_python/data/acilget.py Processed/WTC/${sid}/${cid}/${cid}.nrrd ${tmpDir}
  python ${ACIL_PATH}/acil_python/data/acilget.py Processed/WTC/${sid}/${cid}/${cid}_dcnnBodyComposition.nrrd ${tmpDir}


  # Compute body composition phenotypes 
  python ${CIP_SRC}/cip_python/phenotypes/body_composition_phenotypes.py --in_ct ${cid}.nrrd --in_lm ${cid}_dcnnBodyComposition.nrrd --out_csv ${cid}_dcnnBodyCompositionPhenotypes.csv --cid $cid

  # Upload phenotypes to MAD
  python ${ACIL_PATH}/acil_python/data/acilput.py -remote_path Processed/WTC/${sid}/${cid}/${cid}_dcnnBodyCompositionPhenotypes.csv ${cid}_dcnnBodyCompositionPhenotypes.csv

  \rm $tmpDir/${cid}*
  rmdir $tmpDir

}

#Setting up config variables
study=WTC
tmp_base=/data/acil/tmp/ruben/WTC


caselist[0]="/PHShome/rs251/src/WTC/CaseLists/WTGoodCTCaseList.txt"

id=0


#LSB_JOBINDEX=1
# set input file to be processed
cid=(`sed -n "$LSB_JOBINDEX"p ${caselist[$id]}`)

sid=`echo $cid | cut -f1 -d "_"`


#File check to decide if we trigger the pipeline

testfile=Processed/$study/$sid/$cid/${cid}_dcnnBodyCompositionPhenotypes.csv


#Run analysis
ssh copd@mad-replicated1.research.partners.org "test -s $testfile" && echo "$cid: File exists and has content" || run $cid $study $tmp_base

#run $cid $study $tmp_base

