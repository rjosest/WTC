#!/bin/bash 
#BSUB -L /bin/bash 
#BSUB -J my_job[1-4025]%200
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
name=$2
tmpDir=$3
mkdir $tmpDir/$name
cd $tmpDir/$name

#Delay to prevent overflow
perl /PHShome/rs117/projects/code/acil/Scripts/MADWait.pl 200 10 15


scp "mad-replicated1.research.partners.org:Processed/WTC/$cid/$name/$name.*" .
scp "mad-replicated1.research.partners.org:Processed/WTC/$cid/$name/${name}_bodyComposition*" .

PerformMorphological -i ${name}_bodyComposition.nrrd -o ${name}-tmp.nrrd -a --radx 1 --rady 1 --radz 0 --cl
ComputeCrossSectionalArea -i ${name}-tmp.nrrd -o ${name}_bodyCompositionCSA.csv
ComputeIntensityStatistics -c ${name}.nrrd -l ${name}-tmp.nrrd -o ${name}_bodyCompositionIntensity.csv

remote=mad-replicated1.research.partners.org:Processed/WTC/$cid/$name

scp $tmpDir/${name}/${name}_bodyCompositionCSA.csv $remote
scp $tmpDir/${name}/${name}_bodyCompositionIntensity.csv $remote

mv $tmpDir/${name}/${name}_body*.csv $tmpDir/

\rm -rf $tmpDir/${name}/*
rmdir $tmpDir/${name}

#echo "Job: $LSB_JOBINDEX"
}

# move to the directory where the data files locate
#cd /PHShome/rs117/Databases/COPDGene

study=WTC
tmpDir=/data/acil/tmp/raul/WTCAnalysis

# set input file to be processed
#name=(`sed -n "$LSB_JOBINDEX"p /PHShome/rs117/Databases/WTC/WTMendelsonCaseList.txt`)
name=(`sed -n "$LSB_JOBINDEX"p /PHShome/rs117/Databases/WTC/WTNewINSPCaseList.txt`)

cid=`echo $name | cut -f1 -d "_"`

#Inital check could be to see if output file exists to avoid retriggering the pipeline
testfile1=Processed/$study/$cid/$name/${name}_bodyCompositionCSA.csv

#Second check to decide if we trigger the pipeline is to see if input file is available

testfile2=Processed/$study/$cid/$name/${name}_bodyComposition.nrrd

#Test file and run processing command if needed
ssh mad-replicated1.research.partners.org "test ! -s $testfile1 -a -s $testfile2" && run $cid $name $tmpDir || echo "$name: Input file does not exist or has no content"
