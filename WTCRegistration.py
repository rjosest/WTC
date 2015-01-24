#!/usr/bin/python

import subprocess
import os
import sys
from subprocess import PIPE

from optparse import OptionParser

parser = OptionParser()

parser.add_option("-f",dest="fixedCID",help="case ID for fixed image")
parser.add_option("-m",dest="movingCID",help="case ID for moving image")
parser.add_option("-s",dest="sigma",help="sigma for initial smoothing [default: %default]", type="float",default=1)
parser.add_option("-r",dest="rate",help="initial upsampling/downsampling rate [default: %default]", type="float", default=0.5)
parser.add_option("-d",dest="dimension",help="dimensionality of the data [default: %default]", type="integer", default=3)
parser.add_option("--tmpDir",dest="tmpDirectory",help="temporary directory" )
parser.add_option("--dataDir", dest="dataDirectory",help="data directory for the case IDs")
parser.add_option("--fast",dest="fast",help="fast execution [default: %default]",action="store_true",default=False)

(options, args) = parser.parse_args()

fixed_cid = options.fixedCID
moving_cid = options.movingCID
sigma = options.sigma
rate = options.rate
tmp_dir = options.tmpDirectory
data_dir = options.dataDirectory
dimension = options.dimension
fast=options.fast

#Check required tools path enviroment variables for tools path
toolsPaths = ['ANTS_PATH','TEEM_PATH','ITKTOOLS_PATH'];
path=dict()
for path_name in toolsPaths:
  path[path_name]=os.environ.get(path_name,False)
  if path[path_name] == False:
    print path_name + " environment variable is not set"
    exit()


# Set up input, output and temp volumes
fixed = os.path.join(data_dir,fixed_cid + ".nhdr")
moving = os.path.join(data_dir,moving_cid + ".nhdr")
fixed_tmp = os.path.join(tmp_dir,fixed_cid + ".nhdr")
moving_tmp = os.path.join(tmp_dir,moving_cid + ".nhdr")
moving_deformed = os.path.join(data_dir,moving_cid + "_to_" + fixed_cid + ".nhdr")
fixed_deformed = os.path.join(data_dir,fixed_cid + "_to_"+ moving_cid + ".nhdr")
moving_deformed_tmp = os.path.join(tmp_dir,moving_cid + "_to_" + fixed_cid + ".nhdr")
fixed_deformed_tmp = os.path.join(tmp_dir,fixed_cid + "_to_"+ moving_cid + ".nhdr")


deformation_prefix = os.path.join(data_dir,moving_cid + "_to_" + fixed_cid + "_tfm_")
affine_tfm = deformation_prefix + "0GenericAffine.mat"
elastic_tfm = deformation_prefix + "1Warp.nii.gz"
elastic_inv_tfm = deformation_prefix + "1InverseWarp.nii.gz"

fixed_mask = os.path.join(data_dir,fixed_cid + "_partialLungLabelMap.nhdr")
moving_mask = os.path.join(data_dir,moving_cid + "_partialLungLabelMap.nhdr")
fixed_mask_tmp = os.path.join(tmp_dir,fixed_cid + "_partialLungLabelMap.nhdr")
moving_mask_tmp = os.path.join(tmp_dir,moving_cid + "_partialLungLabelMap.nhdr")

#Conditions input images: Gaussian blurring to account for SHARP kernel
#Compute tissue compartment volume (silly linear mapping)
unu = os.path.join(path['TEEM_PATH'],"unu")
for im in [fixed,moving]:
  out = os.path.join(tmp_dir,os.path.basename(im))
  tmp_command = unu + " resample -i %(in)s -s x1 x1 = -k dgauss:%(sigma)f,3 | "+ unu + " resample -s x%(r)f x%(r)f x%(r)f -k tent"
  tmp_command = tmp_command + " | "+ unu + " 2op + - 1000 | " + unu + " 2op / - 1055 -t float -o %(out)s"
  tmp_command = tmp_command % {'in':im, 'out':out,'sigma':sigma,'r':rate}
  print tmp_command
  sys.stdout.flush()
  subprocess.call( tmp_command, shell=True)

#Extract lung mask region and dilate result
dilation_distance=[10,20]
for kk,im in enumerate([fixed_mask,moving_mask]):
  out = os.path.join(tmp_dir,os.path.basename(im))
  tmp_command = unu + " 3op in_op 1 %(in)s 8 | " + unu + " resample -s x%(r)f x%(r)f x%(r)f -k cheap -o %(out)s"
  tmp_command = tmp_command % {'in':im, 'out':out,'r':rate}
  print tmp_command
  sys.stdout.flush()
  subprocess.call( tmp_command, shell=True)
  tmp_command = "pxdistancetransform -m Maurer -in %(in)s -out %(out)s"
  tmp_command = tmp_command % {'in':out, 'out':out}
  tmp_command = os.path.join(path['ITKTOOLS_PATH'],tmp_command)
  print tmp_command
  sys.stdout.flush()
  subprocess.call( tmp_command, shell=True)
  tmp_command = "unu 2op lt %(in)s %(val)d -o %(out)s"
  tmp_command = tmp_command % {'in':out, 'out':out,'val':dilation_distance[kk]}
  tmp_command = os.path.join(path['TEEM_PATH'],tmp_command)
  print tmp_command
  sys.stdout.flush()
  subprocess.call( tmp_command, shell=True)


#Perform Affine registration
if fast == True:
  percentage=0.1
  its=10000x0x0
  syn="100x0x0,0,5"
else:
  percentage=0.3
  its="10000x5000x2000"
  syn="100x100x50,-0.01,5"

tmp_command = "antsRegistration -d %(dim)s -r [ %(f)s,%(m)s,0] \
               -m mattes[  %(f)s, %(m)s , 1 , 32, regular, %(percentage)f ] \
               -t  translation[ 0.1 ] \
               -c [%(its)s,1.e-8,20]  \
               -s 4x2x1vox \
               -f 6x4x2 \
               -l 1 \
               -m mattes[  %(f)s, %(m)s , 1 , 32, regular, %(percentage)f ] \
               -t affine[ 0.1 ] \
               -c [%(its)s,1.e-8,20]  \
               -s 4x2x1vox  \
               -f 3x2x1 \
               -l 1 -u 1 -z 1 \
               -o [%(nm)s]"
tmp_command = tmp_command % {'f':fixed_tmp,'m':moving_tmp, \
'percentage':percentage,'its':its,'nm':deformation_prefix,'dim':dimension}
tmp_command = os.path.join(path['ANTS_PATH'],tmp_command)
print tmp_command
sys.stdout.flush()
subprocess.call( tmp_command, shell=True, env=os.environ.copy())

#Perform Diffeomorphic registration
tmp_command = "antsRegistration -d %(dim)s -r %(affine)s \
-m cc[ %(f)s, %(m)s , 0.5 , 4 ] \
-t SyN[ .20, 3, 0 ] \
-c [ %(syn)s ]  \
-s 2x1x0vox  \
-f 4x2x1 \
-x [%(f_mask)s,%(m_mask)s] \
-l 1 -z 1 \
-o [%(nm)s,%(out)s,%(out_inv)s]"
tmp_command = tmp_command % {'affine':affine_tfm, 'f':fixed_tmp, 'm':moving_tmp, \
'syn':syn,'f_mask':fixed_mask_tmp,'m_mask':moving_mask_tmp, \
'nm':deformation_prefix,'out':moving_deformed_tmp,'out_inv':fixed_deformed_tmp,'dim':dimension}
tmp_command = os.path.join(path['ANTS_PATH'],tmp_command)
print tmp_command
sys.stdout.flush()
subprocess.call( tmp_command, shell=True, env=os.environ.copy())

#Apply composite transform (if necessary)
# The previous command already outputs the transformed images composed with both
# transformations for the tmp images used in the registration. Here we deformed the original ones

tmp_command = "antsApplyTransforms -d %(dim)s -i %(m)s -r %(f)s -n linear \
   -t %(elastic-tfm)s -t %(affine-tfm)s -o %(deformed)s"
tmp_command = tmp_command % {'f':fixed,'m':moving, \
'elastic-tfm':elastic_tfm,'affine-tfm':affine_tfm,'deformed':moving_deformed_tmp,'dim':dimension}
tmp_command = os.path.join(path['ANTS_PATH'],tmp_command)
subprocess.call( tmp_command, shell=True, env=os.environ.copy())

tmp_command = "antsApplyTransforms -d %(dim)s -i %(f)s -r %(m)s -n linear \
-t [%(affine-tfm)s,1] -t %(elastic-inv-tfm)s  -o %(deformed)s"
tmp_command = tmp_command % {'f':fixed,'m':moving, \
'elastic-inv-tfm':elastic_inv_tfm,'affine-tfm':affine_tfm,'deformed':fixed_deformed_tmp,'dim':dimension}
tmp_command = os.path.join(path['ANTS_PATH'],tmp_command)
subprocess.call( tmp_command, shell=True, env=os.environ.copy())

# Do nrrd gzip compression and type casting for the output images
for im_out,im_in in zip([fixed_deformed,moving_deformed],[fixed_deformed_tmp,moving_deformed_tmp]):
  tmp_command = unu + " convert -i %(in)s -t short | "+ unu + " save -f nrrd -e gzip -o %(out)s"
  tmp_command = tmp_command % {'in':im_in,'out':im_out}
  subprocess.call( tmp_command, shell=True)



