#!/bin/bash 
#BSUB -L /bin/bash 
#BSUB -J my_job[1-469]%10
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


function run {

from_cid=$1
to_cid=$2

#Delay to prevent overflow
perl /PHShome/rs117/projects/code/acil/Scripts/MADWait.pl 5 10 5

python /PHShome/rs117/projects/code/acil/acil_python/mad_tools.py mv -f $from_cid -t $to_cid -s WTC

#echo "Job: $LSB_JOBINDEX"
}

# move to the directory where the data files locate
#cd /PHShome/rs117/Databases/COPDGene

study=WTC

# set input file to be processed
name=(`sed -n "$LSB_JOBINDEX"p /PHShome/rs117/Databases/WTC/RenameInspToExpCaseList-Missing.txt`)
#name=(`sed -n "$LSB_JOBINDEX"p /data/acil/tmp/20CaseListFromReston.txt`)

from_cid=`echo $name | cut -f1 -d ","`
to_cid=`echo $name | cut -f2 -d ","`

from_sid=`echo $from_cid | cut -f1 -d "_"` 

#File check to decide if we trigger the pipleine

testfile="~/CT_SCANS/WTC/$from_sid/${from_cid}.tar.gz" 

ssh mad.research.partners.org "test -e $testfile" &&  run $from_cid $to_cid || echo "$from_cid: Case does not exists"


# run the analysis command
