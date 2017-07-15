
#!/bin/bash 
#BSUB -L /bin/bash 
#BSUB -J my_job[1-5211]%200
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

cid=$1
study=$2
tmp_base=$3

sid=`echo $cid | cut -f1 -d "_"`

remote="copd@mad-replicated1.research.partners.org:Processed/$study/$sid/$cid/"

tmpDir=$tmp_base/$cid

mkdir $tmpDir
cd $tmpDir

#Delay to prevent overflow
perl ${ACIL_PATH}/Scripts/MADWait.pl 100 10 5

#Copy data
scp $remote/$cid.nrrd .

#Execute program
python ${ACIL_PATH}/Projects/noise_stabilization/noise_stabilization.py -i ${tmpDir}/${cid}.nrrd --omean ${tmpDir}/${cid}_signalNoiseStabilization.nrrd --ostd ${tmpDir}/${cid}_noiseNoiseStabilization.nrrd

#Transfer data
scp $tmpDir/${cid}_signalNoiseStabilization.nrrd $remote
scp $tmpDir/${cid}_noiseNoiseStabilization.nrrd $remote

#Delete tmpdir
\rm $tmpDir/${cid}*
rmdir $tmpDir

}

#Setting up config variables
study=WTC
tmp_base=${TMP_DIR}/NoiseStabilization


caselist[0]="${WTC_PATH}/CaseLists/WTGoodCTCaseList.txt"
id=0

#LSB_JOBINDEX=1
# set input file to be processed
cid=(`sed -n "$LSB_JOBINDEX"p ${caselist[$id]}`)

sid=`echo $cid | cut -f1 -d "_"`

#File check to decide if we trigger the pipleine

testfile=Processed/$study/$sid/$cid/${cid}_signalNoiseStabilization.nrrd

#Run analysis
ssh copd@mad-replicated1.research.partners.org "test -s $testfile" && echo "$cid: File exists and has content" || run $cid $study $tmp_base 


