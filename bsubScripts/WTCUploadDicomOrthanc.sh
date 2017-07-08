#!/bin/bash 
#BSUB -L /bin/bash 
#BSUB -J my_job[2-3017]%3
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
#perl /PHShome/rs117/projects/code/acil/Scripts/MADWait.pl 200 10 10
#perl /PHShome/rs117/projects/Scripts/COPDGene/FixWait.pl $LSB_JOBINDEX 40 1

scp "mad.research.partners.org:CT_SCANS/WTC/$cid/$name.tar.gz" .
tar xzvf $name.tar.gz
python /PHShome/rs117/projects/Scripts/WTC/fix_dicom.py -d $name -c $name
python /PHShome/rs117/projects/Scripts/WTC/ImportDicomFiles.py 52.90.215.26 80 $name/ wtc test-wtc

\rm -rf $tmpDir/${name}*

#echo "Job: $LSB_JOBINDEX"
}

study=WTC
#LSB_JOBINDEX=1
# set input file to be processed
#name=(`sed -n "$LSB_JOBINDEX"p /PHShome/rs117/Databases/WTC/WTMendelsonCaseList.txt`)
name=(`sed -n "$LSB_JOBINDEX"p /PHShome/rs117/Databases/WTC/WTCaseList.txt`)
#name=(`sed -n "$LSB_JOBINDEX"p /PHShome/rs117/Databases/WTC/WTCBodyCompositionList.csv`)
#name=(`sed -n "$LSB_JOBINDEX"p /data/acil/tmp/20CaseListFromReston.txt`)

cid=`echo $name | cut -f1 -d "_"`


#File check to decide if we trigger the pipleine

#testfile="~/Processed/WTC/$cid/$name/${name}_filtered.nhdr"
#ssh mad.research.partners.org "test -s $testfile" && echo "$name: Field exists and has content" || run $cid $name

# run analysis command
run $cid $name

