#!/bin/bash 
#BSUB -L /bin/bash
#BSUB -J my_job[1-73]%20
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


# move to the directory where the data files locate
#cd /PHShome/rs117/Databases/COPDGene



function run {

  cid=$1
  sid=`echo $cid | cut -d "_" -f1`  
  
  #Create tarball
  tar czf ${cid}.tar.gz $cid
  md5sum ${cid}.tar.gz > ${cid}.md5sum
  
  #Transfer data to mad
  scp ${cid}.tar.gz mad.research.partners.org:CT_SCANS/WTC/$sid/
  scp ${cid}.md5sum mad.research.partners.org:CT_SCANS/WTC/$sid/
  
  #Convert to NRRD
  ConvertDicom --inputDicomDirectory $cid -o ${cid}.nhdr
  
  #Extract Dicom tags
  ReadDicomWriteTags -i $cid -o ${cid}_dicomTags.csv
  
  #Compute Projection Images
  unu 3op clamp -1024 ${cid}.nhdr 100 | \
  unu project -i - -a 0 -m mean -o ${cid}-tmp1.nhdr ; \
  unu quantize -i ${cid}-tmp1.nhdr -b 8 -o ${cid}-tmp2.nhdr ; \
  unu flip -a 1 -i ${cid}-tmp2.nhdr -o ${cid}-tmp1.nhdr; \
  unu save -i ${cid}-tmp1.nhdr -f png -o ${cid}_projectionAlongX.png
  
  unu 3op clamp -1024 ${cid}.nhdr 100 | \
  unu project -i - -a 1 -m mean -o ${cid}-tmp1.nhdr ; \
  unu quantize -i ${cid}-tmp1.nhdr -b 8 -o ${cid}-tmp2.nhdr ; \
  unu flip -a 1 -i ${cid}-tmp2.nhdr -o ${cid}-tmp1.nhdr; \
  unu save -i ${cid}-tmp1.nhdr -f png -o ${cid}_projectionAlongY.png
  
  unu 3op clamp -1024 ${cid}.nhdr 100 | \
  unu project -i - -a 2 -m mean -o ${cid}-tmp1.nhdr ; \
  unu quantize -i ${cid}-tmp1.nhdr -b 8 -o ${cid}-tmp2.nhdr ; \
  unu save -i ${cid}-tmp2.nhdr -f png -o ${cid}_projectionAlongZ.png
  
  #Create directory in mad
  ssh copd@mad.research.partners.org mkdir /mad/store-replicated/clients/copd/Processed/WTC/${sid}/${cid}
  
  #Transfer data to mad
  scp ${cid}_* mad.research.partners.org:Processed/WTC/$sid/$cid/ 
  scp ${cid}.nhdr mad.research.partners.org:Processed/WTC/$sid/$cid/
  scp ${cid}.raw.gz mad.research.partners.org:Processed/WTC/$sid/$cid/
   } 





# set input file to be processed
#LSB_JOBINDEX=1
#sid=(`sed -n "$LSB_JOBINDEX"p /PHShome/rs117/Databases/WTC/WTSID.txt`)
#sid=(`sed -n "$LSB_JOBINDEX"p /PHShome/rs117/bsubScripts/WTC/WTMissingSIDwoduplicates.txt`)
sid=(`sed -n "$LSB_JOBINDEX"p /PHShome/rs117/Databases/WTC/WTCBatch7SID.txt`)
#set cid=`echo $name | cut -f1 -d "_"`


# run the analysis command
cip=/PHShome/rs117/projects/code/cip
cipBuild=/PHShome/rs117/projects/code/cip-build/
dataDir=/data/acil/tmp/WTCData/batch7/
tmpDirFix=/data/acil/tmp/WTCTmpBatch7/
tmpDir=/tmp/
mkdir $tmpDir/$sid


if [ -s $tmpDirFix/${sid}_done.csv ]
 then
  echo " Done"
  #exit
fi


#Delay to prevent overflow
perl /PHShome/rs117/projects/code/acil/Scripts/MADWait.pl 20 20 10

#Untar data and split Dicom in series
cd $tmpDir
tar xzf $dataDir/$sid.tgz
python /PHShome/rs117/projects/Scripts/WTC/WTCSplitSeriesInDirectories.py -i $tmpDir/$sid -o $tmpDir/$sid -v $tmpDirFix/${sid}.csv

dos2unix $tmpDirFix/${sid}.csv
cidList=`cat $tmpDirFix/${sid}.csv`
echo $cidList
for cid in $cidList; do
  echo $cid
done

#Create directory in mad
ssh copd@mad.research.partners.org mkdir /mad/store-replicated/clients/copd/Processed/WTC/${sid}
ssh copd@mad.research.partners.org mkdir /mad/store-replicated/clients/copd/CT_SCANS/WTC/${sid}

cd $tmpDir/$sid
for cid in $cidList; do
  #Pack if file is not in MAD (either INSP or EXP version!!)
  date=`echo $cid | cut -d "_" f2`
  series=`echo $cid | cut -d "_" f4`
  insp=${sid}_${date}_INSP_$series
  exp=${sid}_${date}_EXP_$series
  
  testINSP=Processed/WTC/${sid}/${insp}/${insp}.raw.gz
  testEXP=Processed/WTC/${sid}/${exp}/${exp}.raw.gz
  ssh mad.research.partners.org "test -s $testINSP || test -s $testEXP" && echo "$cid: NRRD exists and has content" || run $cid; echo $cid >> ${tmpDirFix}/${sid}_done.csv
done

#Delete files
\rm -rf $tmpDir/${sid}/*
\rmdir $tmpDir/${sid}


