#!/bin/bash
#BSUB -L /bin/bash 
#BSUB -J my_job[1-4025]%100
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
  #Set up variables
  cip=/PHShome/rs117/projects/code/cip
  cipBuild=/PHShome/rs117/projects/code/cip-build/

  #Delay to prevent overflow
  perl /PHShome/rs117/projects/code/acil/Scripts/MADWait.pl 100 10 15

  # run the analysis command
  mkdir $tmpDir/$name
  cd $tmpDir
  scp "mad-replicated1.research.partners.org:Processed/WTC/$cid/$name/$name.*" .
  scp "mad-replicated1.research.partners.org:Processed/WTC/$cid/$name/${name}_airwayRegionAndTypePoints.csv" .

  python $cip/Scripts/ExtractAirwayParticlesFromPoints.py -c $name --cipPython $cip --cipBuildDir $cipBuild --tmpDir $tmpDir/$name --dataDir $tmpDir

  scp $tmpDir/${name}_*Airway*.vtk mad-replicated1.research.partners.org:Processed/WTC/$cid/$name/
  \rm -rf $tmpDir/${name}/
  \rm $tmpDir/${name}.nhdr
  \rm $tmpDir/${name}.raw.gz

}




# move to the directory where the data files locate
#cd /PHShome/rs117/Databases/COPDGene
# set input file to be processed
#set name=(`sed -n "$LSB_JOBINDEX"p /PHShome/rs117/Databases/COPDGene/20CaseListFromReston.txt`)
name=(`sed -n "$LSB_JOBINDEX"p /PHShome/rs117/Databases/WTC/WTNewINSPCaseList.txt`)
#name=(`sed -n "$LSB_JOBINDEX"p /PHShome/rs117/Databases/WTC/WTPriorityList.txt`)


if [ -z "$name" ] 
then
 echo "No case name"
 exit
fi  


cid=`echo $name | cut -f1 -d "_"`

study="WTC"
tmpDir=/data/acil/tmp/WTCAirwayAnalysis

#if [ -e $tmpDir/${name}_AirwayParticlesSubset.vtk ] 
#then
#  exit
#fi

testfile=Processed/$study/$cid/$name/${name}_airwayRegionAndTypePoints.csv

ssh mad-replicated1.research.partners.org "test -s $testfile" && run $cid $name $tmpDir || echo "$name: airway point file does not exists"
  

#echo "Job: $LSB_JOBINDEX"
