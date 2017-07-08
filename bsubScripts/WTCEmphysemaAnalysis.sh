
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
name=$2
cip=/PHShome/rs117/projects/code/cip
cipBuild=/PHShome/rs117/projects/code/cip-build/
tmpDir=/data/acil/tmp/WTCAnalysis2
mkdir $tmpDir/$name
cd $tmpDir

#Delay to prevent overflow
perl /PHShome/rs117/projects/code/acil/Scripts/MADWait.pl 200 10 5

#perl /PHShome/rs117/projects/Scripts/COPDGene/FixWait.pl $LSB_JOBINDEX 40 1

scp "mad.research.partners.org:Processed/WTC/$cid/$name/$name.*" .
#scp "mad.research.partners.org:Processed/WTC/$cid/$name/${name}_partial*" .

python /PHShome/rs117/projects/Scripts/WTC/WTCEmphysemaAnalysis.py -c $name --tmpDir $tmpDir/$name --dataDir $tmpDir

scp $tmpDir/${name}/${name}_partial* mad.research.partners.org:Processed/WTC/$cid/$name/
scp $tmpDir/${name}/${name}_emphy*.csv mad.research.partners.org:Processed/WTC/$cid/$name/
scp $tmpDir/${name}/${name}_labelMap*.png mad.research.partners.org:Processed/WTC/$cid/$name/
mv $tmpDir/${name}/${name}_emphy*.csv $tmpDir/
\rm $tmpDir/${name}.*
\rm -rf $tmpDir/${name}/*
rmdir $tmpDir/${name}

#echo "Job: $LSB_JOBINDEX"
}

# move to the directory where the data files locate
#cd /PHShome/rs117/Databases/COPDGene

study=WTC

# set input file to be processed
#name=(`sed -n "$LSB_JOBINDEX"p /PHShome/rs117/Databases/WTC/WTMendelsonCaseList.txt`)
name=(`sed -n "$LSB_JOBINDEX"p /PHShome/rs117/Databases/WTC/WTCaseList.txt`)
#name=(`sed -n "$LSB_JOBINDEX"p /data/acil/tmp/20CaseListFromReston.txt`)

cid=`echo $name | cut -f1 -d "_"`


#File check to decide if we trigger the pipleine

testfile=Processed/$study/$cid/$name/${name}_emphysemaMeasures.csv

ssh mad.research.partners.org "test -s $testfile" && echo "$name: File exists and has content" || run $cid $name


# run the analysis command
