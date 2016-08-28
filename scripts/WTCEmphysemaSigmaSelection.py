#!/usr/bin/python

import subprocess
import os
import sys
from subprocess import PIPE

from optparse import OptionParser

parser = OptionParser()

parser.add_option("-c",dest="cid")
parser.add_option("--tmpDir",dest="tmpDirectory")
parser.add_option("--dataDir", dest="dataDirectory")
#parser.add_option("-s",dest="sigma")

sigma=list()
tmp = 0.6
for ss in range(5):
  sigma.append(tmp)
  tmp=tmp+0.05

(options, args) = parser.parse_args()

cid = options.cid
tmpDir = options.tmpDirectory


ctFileName = os.path.join(options.dataDirectory,cid + ".nhdr")
plFileName = os.path.join(tmpDir,cid + "_partialLungLabelMap.nhdr")
csvFileName = os.path.join(tmpDir,cid + "_emphysemaMeasures")
qualityFileName = os.path.join(tmpDir,cid + "_labelMapCoronalProjectionImage.png")
quality2FileName= os.path.join(tmpDir,cid + "_labelMapAxialProjectionImage.png")


lpiPath="/PHShome/rs117/projects/code/Slicer3_lmi-build/lib/Slicer3/Plugins/"
cipPath="/PHShome/rs117/projects/code/cip-build/"
itkToolsPath="/data/acil/Code/ITKTools-build/"


tmpCommand = "LungMaskExtraction %(vol)s %(output)s"
tmpCommand = tmpCommand % {'vol':ctFileName, 'output':plFileName}
tmpCommand = os.path.join(lpiPath,tmpCommand);
#subprocess.call( tmpCommand, shell=True)


#Compute distance map for rine/core computations
distanceImage = os.path.join(tmpDir,cid + "_distanceMap.nhdr")
lungImage = os.path.join(tmpDir,cid + "_lung.nhdr")
tmpCommand ="unu 3op in_cl 2 %(lm-in)s 7 -o %(lung)s"
tmpCommand = tmpCommand % {'lm-in':plFileName,'lung':lungImage}
subprocess.call( tmpCommand, shell=True)
#tmpCommand = "ComputeDistanceMap -l %(lung)s -d %(distance-map)s -s 2"
tmpCommand = "pxdistancetransform -in %(lung)s -out %(distance-map)s -m Maurer"
tmpCommand = tmpCommand % {'lung':lungImage,'distance-map':distanceImage}
tmpCommand = os.path.join(itkToolsPath,"bin",tmpCommand)
print tmpCommand
#subprocess.call( tmpCommand, shell=True )

for ss in range(len(sigma)):
  # Smooth data to normalized recon kernels
  print "Smoothing "+str(sigma[ss])
  smoothImage = os.path.join(tmpDir,cid + "_smooth.nhdr")
  tmpCommand = "unu resample -k dgauss:%(sigma)f,3 -s x1 x1 = -i %(vol)s -o %(out)s"
  tmpCommand = tmpCommand % {'vol':ctFileName, 'out':smoothImage, 'sigma':float(sigma[ss])}
  print tmpCommand
  sys.stdout.flush()
  subprocess.call (tmpCommand, shell=True)

  tmpCommand = "GenerateEmphysemaMeasures %(vol)s %(output)s --outputCSV %(res)s_%(sigma)s.csv -d %(dm)s"
  tmpCommand = tmpCommand % {'vol':smoothImage, 'output':plFileName, 'res':csvFileName, 'sigma':str(sigma[ss]), 'dm':distanceImage}
  tmpCommand = os.path.join(lpiPath,tmpCommand);
  print tmpCommand
  sys.stdout.flush()
  subprocess.call( tmpCommand, shell=True)


tmpCommand = "unu 2op lt %(output)s 8 | unu 2op x %(output)s - | unu project -a 1 -m variance \
             | unu resample -s x1 x3 -k tent | unu flip -a 1 | unu quantize -b 8 -o %(quality)s"
tmpCommand = tmpCommand % {'output':plFileName, 'quality':qualityFileName}
subprocess.call( tmpCommand, shell=True)

tmpCommand = "unu 2op lt %(output)s 8 | unu 2op x %(output)s - | \
             unu project -a 2 -m variance | unu resample -s x1 x1 -k tent | \
             unu quantize -b 8 -o %(quality2)s"
tmpCommand = tmpCommand % {'output':plFileName, 'quality2':quality2FileName}
subprocess.call ( tmpCommand, shell=True)

