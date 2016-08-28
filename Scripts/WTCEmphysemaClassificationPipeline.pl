#!/usr/bin/perl


@caseList = $ARGV[0];
$i = 0;

$study=WTC;

#for ($i = 0; $i < scalar(@caseList); $i++) {
    print "--------------- $caseList[$i] ------------------\n";
    @scanInfo = split(/_/,$caseList[$i]);


    $patientID   = $scanInfo[0];
    $breathCycle = $scanInfo[1];
    $reconKernel = $scanInfo[2];
    $institution = $scanInfo[3];
    
    $madFileNameRoot                                   = "copd\@mad-replicated1.research.partners.org:/mad/store-replicated/clients/copd/Processed/".$study."/".$patientID."/".$caseList[$i]."/".$caseList[$i];
    $tempDirRoot                                       = "/data/acil/tmp/emphysemaClassification/";
    $tempFileNameRoot                                  = $tempDirRoot.$patientID."/".$caseList[$i]."/".$caseList[$i];
    $tempDir                                           = $tempDirRoot.$patientID."/".$caseList[$i];
    $madDir                                            = "copd\@mad-replicated1.research.partners.org:/mad/store-replicated/clients/copd/Processed/".$study."/".$patientID."/".$caseList[$i];
    $out1FileNameExt                                   = "_emphysemaClassification";
    $out2FileNameExt		                       = "_emphysemaClassificationPercentages.csv";
    $partialLungLabelMapFileNameExt                    = "_partialLungLabelMap";

   $computeEmphysemaClassification   = 1;
   $cleanUpTmpFiles               = 1;

    $checkCmd    = "ssh copd\@mad-replicated1.research.partners.org file -b /mad/store-replicated/clients/copd/Processed/".$study."/".$patientID."/".$caseList[$i]."/".$caseList[$i].$out1FileNameExt.".nrrd";
    $checkString = `$checkCmd`;
    $code        = substr $checkString, 0, 5;
    if ( $code eq "ERROR" || $code eq "empty" )
      {
        print "Compute emphysema classification!\n";
        $computeEmphysemaClassification   = 1;
      }

    #check input status
    $convertDicom                  = 0;
    $generatePartialLungLabelMap   = 0;

    $checkCmd    = "ssh copd\@mad-replicated1.research.partners.org file -b /mad/store-replicated/clients/copd/Processed/".$study."/".$patientID."/".$caseList[$i]."/".$caseList[$i].".nrrd";
    $checkString = `$checkCmd`;
    $code        = substr $checkString, 0, 5;
    if ( $code eq "ERROR" || $code eq "empty" )
      {
        print "Convert Dicom 1: ".$code."!\n";
        $convertDicom      = 1;
      }
    $checkCmd    = "ssh copd\@mad-replicated1.research.partners.org file -b /mad/store-replicated/clients/copd/Processed/".$study."/".$patientID."/".$caseList[$i]."/".$caseList[$i].".nrrd";
    $checkString = `$checkCmd`;
    $code        = substr $checkString, 0, 5;
    if ( $code eq "ERROR" || $code eq "empty" )
      {
        print "Convert Dicom 2: ".$code."!\n";
        $convertDicom      = 1;
      }

    $checkCmd    = "ssh copd\@mad-replicated1.research.partners.org file -b /mad/store-replicated/clients/copd/Processed/".$study."/".$patientID."/".$caseList[$i]."/".$caseList[$i].$partialLungLabelMapFileNameExt.".nrrd";
    $checkString = `$checkCmd`;
    $code        = substr $checkString, 0, 5;
    if ( $code eq "ERROR" || $code eq "empty" )
      {
        print "Generate partial lung label map 1!\n";
        $generatePartialLungLabelMap      = 1;
      }

    $checkCmd    = "ssh copd\@mad-replicated1.research.partners.org file -b /mad/store-replicated/clients/copd/Processed/".$study."/".$patientID."/".$caseList[$i]."/".$caseList[$i].$partialLungLabelMapFileNameExt.".nrrd";
    $checkString = `$checkCmd`;
    $code        = substr $checkString, 0, 5;
    if ( $code eq "ERROR" || $code eq "empty" )
      {
        print "Generate partial lung label map 2!\n";
        $generatePartialLungLabelMap      = 1;
      }


    if ( $convertDicom == 1 || $generatePartialLungLabelMap == 1 ) {
      print "Skipping case...";
      exit;
    }

    #------------------------------------------------------------------------------------------------------------------------------------
    unless ( -d $tempDirRoot )
      {
        system("mkdir ".$tempDirRoot);
      }
    unless ( -d $tempDirRoot.$patientID )
      {
        system("mkdir ".$tempDirRoot.$patientID );
      }
    unless ( -d $tempDir )
      {
        system("mkdir ".$tempDir );
      }
  
    #------------------------------------------------------------------------------------------------------------------------------------
    if ( $computeEmphysemaClassification )
      {

        unless ( -e $tempFileNameRoot.$partialLungLabelMapFileNameExt.".nrrd" )
          {
            system( "scp ".$madFileNameRoot.$partialLungLabelMapFileNameExt.".nrrd ".$tempDir );
          }
        unless ( -e $tempFileNameRoot.".nrrd" )
          {
            system( "scp ".$madFileNameRoot.".nrrd ".$tempDir );
          }
        if ( -e $tempFileNameRoot.".nrrd" )
          {
            print "-----------------------------------------------------------------\n";
            print "Smoothing...\n";
	    system("unu resample -k dgauss:1.1,3 -s x1 x1 = -i ".$tempFileNameRoot.".nrrd -o ".$tempFileNameRoot.".nrrd");
	    system("unu 3op in_op 4 ".$tempFileNameRoot."_partialLungLabelMap.nrrd 8 | unu save -e gzip -f nrrd -o ".$tempFileNameRoot."_partialLungLabelMap.nrrd ");

            print "Computing emphysema classification...\n";
            print "matlab -nodesktop -nodisplay -nosplash -r \"ComputeEmphysemaClassification(\'$tempDir\',\'$caseList[$i]\');\n";
           system("echo hola;cd /PHShome/rs117/projects/matlab/EmphysemaCarlos/Code-v1/;matlab -nodesktop -nodisplay -nosplash -r \"ComputeEmphysemaClassification(\'$tempDir\',\'$caseList[$i]\');exit;\">& /dev/null;echo adios;exit");

             if ( -e $tempFileNameRoot.$out1FileNameExt.".nrrd" )
              {
                system( "scp ".$tempFileNameRoot.$out1FileNameExt.".nrrd ".$madDir );
              }
              if ( -e $tempFileNameRoot.$out2FileNameExt )
              {
                system( "scp ".$tempFileNameRoot.$out2FileNameExt." ".$madDir );
                system( "scp ".$tempFileNameRoot.$out2FileNameExt." ".$tempDirRoot."/csv/" );
              }

          }
      }
   #------------------------------------------------------------------------------------------------------------------------------------

    if ( $cleanUpTmpFiles == 1 )
      {
        if ( -d $tempDirRoot.$patientID."/".$caseList[$i] )
          {
            system("/bin/rm ".$tempDirRoot.$patientID."/".$caseList[$i]."/*" );
            system("rmdir ".$tempDirRoot.$patientID."/".$caseList[$i] );
          }
      }

#}
