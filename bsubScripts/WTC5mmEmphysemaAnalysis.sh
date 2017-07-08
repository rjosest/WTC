#!/bin/csh 
#BSUB -L /bin/csh 
#BSUB -J my_job[1-5]%90
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
set name=(`sed -n "$LSB_JOBINDEX"p /PHShome/rs117/Databases/WTC/WT5mmCaseList.txt`)
#set name=(`sed -n "$LSB_JOBINDEX"p /data/acil/tmp/20CaseListFromReston.txt`)

set cid=`echo $name | cut -f1 -d "_"`

# run the analysis command
set cip=/PHShome/rs117/projects/code/cip
set cipBuild=/PHShome/rs117/projects/code/cip-build/
set tmpDir=/data/acil/tmp/WTCAnalysis
mkdir $tmpDir/$name
cd $tmpDir

#Delay to prevent overflow
perl /PHShome/rs117/projects/Scripts/COPDGene/FixWait.pl $LSB_JOBINDEX 40 1

scp "mad.research.partners.org:Processed/WTC/$cid/$name/$name.*" .
#scp "mad.research.partners.org:Processed/WTC/$cid/$name/${name}_partial*" .

python /PHShome/rs117/projects/Scripts/WTC/WTCEmphysemaAnalysis.py -c $name --tmpDir $tmpDir/$name --dataDir $tmpDir

scp "$tmpDir/${name}/${name}_partial*" mad.research.partners.org:Processed/WTC/$cid/$name/
scp "$tmpDir/${name}/${name}_emphy*.csv" mad.research.partners.org:Processed/WTC/$cid/$name/
scp "$tmpDir/${name}/${name}_labelMap*.png" mad.research.partners.org:Processed/WTC/$cid/$name/
#\rm $tmpDir/${name}.*
#\rm $tmpDir/${name}_partial*

#echo "Job: $LSB_JOBINDEX"
