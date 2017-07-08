#!/bin/bash 
#BSUB -L /bin/bash 
#BSUB -J my_job[1-1336]%100
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
cip=/PHShome/rs117/projects/code/cip
cipBuild=/PHShome/rs117/projects/code/cip-build/
tmpDir=/data/acil/tmp/raul/WTCAnalysis2
cd $tmpDir

#Delay to prevent overflow
#perl /PHShome/rs117/projects/code/acil/Scripts/MADWait.pl 100 10 10

#perl /PHShome/rs117/projects/Scripts/COPDGene/FixWait.pl $LSB_JOBINDEX 40 1

scp "mad-replicated1.research.partners.org:Processed/WTC/$cid/$name/$name.nrrd" .

unu resample -k dgauss:0.7,4 -s x1 x1 = -i $name.nrrd -o ${name}_filtered.nrrd
GenerateMedianFilteredImage -i ${name}_filtered.nrrd -r 1 -o ${name}_filtered.nrrd
unu resample -k dgauss:0.7,4 -s x1 x1 = -i ${name}_filtered.nrrd | unu save -f nrrd -e gzip -o ${name}_filtered.nrrd

scp $tmpDir/${name}_filtered.nrrd mad-replicated1.research.partners.org:Processed/WTC/$cid/$name/
\rm $tmpDir/${name}_filtered.*
\rm $tmpDir/${name}.*


#echo "Job: $LSB_JOBINDEX"
}

# move to the directory where the data files locate
#cd /PHShome/rs117/Databases/COPDGene

study=WTC
# set input file to be processed
#name=(`sed -n "$LSB_JOBINDEX"p /PHShome/rs117/Databases/WTC/WTMendelsonCaseList.txt`)
#name=(`sed -n "$LSB_JOBINDEX"p /PHShome/rs117/Databases/WTC/WTCaseList.txt`)
#name=(`sed -n "$LSB_JOBINDEX"p /PHShome/rs117/Databases/WTC/WTCBodyCompositionList.csv`)
#name=(`sed -n "$LSB_JOBINDEX"p /PHShome/rs117/Databases/WTC/WTDeclinersINSPCaseList.txt`)
name=(`sed -n "$LSB_JOBINDEX"p /PHShome/rs117/Databases/WTC/WTINSP_fromINSPEXPCaseList.txt`) 

cid=`echo $name | cut -d _ -f1`

#File check to decide if we trigger the pipleine

testfile="~/Processed/$study/$cid/$name/${name}_filtered.nrrd"

ssh -x mad-replicated1.research.partners.org "test -s $testfile" && echo "$name: Field exists and has content" || run $cid $name


# run the analysis command
