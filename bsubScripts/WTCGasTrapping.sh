#!/bin/bash
#BSUB -L /bin/bash 
#BSUB -J my_job[1-1336]%200
#BSUB -M 4000
#BSUB -o job_out
#BSUB -e job_err
#BSUB -q short

#Other options commented
#number of processors
##BSUB -n 5
#number of threads
##BSUB -T 4
#send email for each job
##BSUB -N


# move to the directory where the data files locate
#cd /PHShome/rs117/Databases/COPDGene

# set input file to be processed
line=(`sed -n "$LSB_JOBINDEX"p /PHShome/rs117/Databases/WTC/WTINSP-EXPCaseList.txt`)
#name=(`sed -n "$LSB_JOBINDEX"p /data/acil/tmp/20CaseListFromReston.txt`)

insp=`echo $line | cut -f1 -d ","`
exp=`echo $line | cut -f2 -d ","`

cid=`echo $insp | cut -f1 -d "_"`

# run the analysis command
cip=/PHShome/rs117/projects/code/cip
cipBuild=/PHShome/rs117/projects/code/cip-build/
tmpDir=/data/acil/tmp/WTCAnalysis/registration/
mkdir $tmpDir/$cid
mkdir $tmpDir/$cid/cache
cd $tmpDir/$cid

#Delay to prevent overflow
perl /PHShome/rs117/projects/code/acil/Scripts/MADWait.pl 200 10 15

scp "mad.research.partners.org:Processed/WTC/$cid/$insp/$insp.*" .
scp "mad.research.partners.org:Processed/WTC/$cid/$insp/${insp}_partial*" .

scp "mad.research.partners.org:Processed/WTC/$cid/$exp/$exp.*" .
scp "mad.research.partners.org:Processed/WTC/$cid/$exp/${exp}_to*" .

export ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=2
output=$tmpDir/${exp}_gasTrappingPhenotpyes.csv
python /PHShome/rs117/projects/Scripts/WTC/WTCGasTrappingPhenotypes.py -i $insp -e $exp --tmpDir $tmpDir/$cid/cache --dataDir $tmpDir/$cid -s 0.8 -o $output

scp $output mad.research.partners.org:Processed/WTC/$cid/$exp/

\rm $tmpDir/$cid/cache/*
\rm $tmpDir/$cid/*

#echo "Job: $LSB_JOBINDEX"
