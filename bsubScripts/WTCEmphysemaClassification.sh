#!/bin/bash 
#BSUB -L /bin/bash 
#BSUB -J my_job[1-90]%50
#BSUB -M 4000
#BSUB -o job_out
#BSUB -e job_err
#BSUB -q medium

#Other options commented
#number of processors
##BSUB -n 5
#number of threads
##BSUB -T 10 
#send email for each job
##BSUB -N


# move to the directory where the data files locate
#cd /PHShome/rs117/Databases/COPDGene

# set input file to be processed
name=(`sed -n "$LSB_JOBINDEX"p /PHShome/rs117/Databases/WTC/WTCaseList.txt`)
#name=(`sed -n "$LSB_JOBINDEX"p /data/acil/tmp/20CaseListFromReston.txt`)

cid=`echo $name | cut -f1 -d "_"`
cycle=`echo $name | cut -f3 -d "_"` 

if [ $cycle == "EXP"]
 then
 exit
fi

# run the analysis command
cip=/PHShome/rs117/projects/code/cip
cipBuild=/PHShome/rs117/projects/code/cip-build/
tmpDir=/data/acil/tmp/WTCAnalysis2/
mkdir $tmpDir/$name
cd $tmpDir

#Delay to prevent overflow
#perl /PHShome/rs117/projects/Scripts/COPDGene/FixWait.pl $LSB_JOBINDEX 20 2
perl /PHShome/rs117/projects/code/acil/Scripts/MADWait.pl 50 10 5


scp "mad.research.partners.org:Processed/WTC/$cid/$name/$name.*" .
scp "mad.research.partners.org:Processed/WTC/$cid/$name/${name}_partial*" .

perl /PHShome/rs117/projects/Scripts/WTC/WTCEmphysemaClassificationPipeline.pl $name

scp $tmpDir/${name}/${name}_*Classif* mad.research.partners.org:Processed/WTC/$cid/$name/

cp $tmpDir/${name}/${name}_*Classif* $tmpDir
#\rm $tmpDir/${name}.*
#\rm $tmpDir/${name}_partial*
#\rm -rf $tmpDir/${name}/

#echo "Job: $LSB_JOBINDEX"
