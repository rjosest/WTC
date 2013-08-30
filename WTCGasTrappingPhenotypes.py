#!/usr/bin/python

import subprocess
import os
import nrrd
import numpy as np
from subprocess import PIPE

from optparse import OptionParser

parser = OptionParser()

parser.add_option("-i",dest="inspCID",help="case ID for inspiratory image")
parser.add_option("-e",dest="expCID",help="case ID for expiratory image")
parser.add_option("-s",dest="sigma",help="sigma for initial smoothing [default: %default]", type="float",default=1)
parser.add_option("-r",dest="rate",help="initial upsampling/downsampling rate [default: %default]", type="float", default=1)
parser.add_option("--tmpDir",dest="tmpDirectory",help="temporary directory" )
parser.add_option("--dataDir", dest="dataDirectory",help="data directory for the case IDs")

(options, args) = parser.parse_args()

insp_cid = options.inspCID
exp_cid = options.expCID
sigma = options.sigma
rate = options.rate
tmp_dir = options.tmpDirectory
data_dir = options.dataDirectory

#Check required tools path enviroment variables for tools path
toolsPaths = ['ANTS_PATH','TEEM_PATH','ITKTOOLS_PATH'];
path=dict()
for path_name in toolsPaths:
  path[path_name]=os.environ.get(path_name,False)
  if path[path_name] == False:
    print path_name + " environment variable is not set"
    exit()

# Set up input and output and temp volumes
insp  = os.path.join(data_dir,insp_cid + ".nhdr")
exp = os.path.join(data_dir,exp_cid + ".nhdr")
insp_tmp = os.path.join(tmp_dir,insp_cid + ".nhdr")
exp_tmp = os.path.join(tmp_dir,exp_cid + ".nhdr")
exp_to_insp = os.path.join(data_dir,exp_cid + "_to_" + insp_cid + ".nhdr")
exp_to_insp_tmp = os.path.join(tmp_dir,exp_cid + "_to_" + insp_cid + ".nhdr")

deformation_prefix = os.path.join(data_dir,exp_cid + "_to_" + insp_cid + "_tfm_")
affine_tfm = deformation_prefix + "0GenericAffine.mat"
elastic_tfm = deformation_prefix + "1Warp.nii.gz"
elastic_inv_tfm = deformation_prefix + "1InverseWarp.nii.gz"

insp_mask = os.path.join(data_dir,insp_cid + "_partialLungLabelMap.nhdr")
exp_mask = os.path.join(data_dir,exp_cid + "_partialLungLabelMap.nhdr")
insp_mask_tmp = os.path.join(tmp_dir,insp_cid + "_partialLungLabelMap.nhdr")
exp_mask_tmp = os.path.join(tmp_dir,exp_cid + "_partialLungLabelMap.nhdr")

#Conditions input images: Gaussian blurring to account for SHARP kernel
#Compute tissue compartment volume (silly linear mapping)
unu = os.path.join(path['TEEM_PATH'],"unu")
for im in [insp,exp_to_insp]:
  out = os.path.join(tmp_dir,os.path.basename(im))
  tmp_command = unu + " resample -i %(in)s -s x1 x1 = -k dgauss:%(sigma)f,3 | "+ unu + " resample -s x%(r)f x%(r)f x%(r)f -k tent -o %(out)s"
  tmp_command = tmp_command % {'in':im, 'out':out,'sigma':sigma,'r':rate}
  print tmp_command
  subprocess.call( tmp_command, shell=True)

#Define region labels and variables
regions=[(5,7),(5,5),(6,6),(7,7)]
regionsLabels=['Global','Upper','Middle','Lower']


# Compute Gas Trapping metrics based on Galban's paper

insp_im , insp_header = nrrd.read(insp_tmp)
reg_exp_im ,  reg_exp_header = nrrd.read(exp_to_insp_tmp)
insp_mask_im , insp_mask_header = nrrd.read(insp_mask)

val=list()
gastrapping_mask=  np.logical_and(insp_im > -950, reg_exp_im < -856)
for ii,rr in enumerate(regions):
  region_mask = np.logical_and(insp_mask_im>=rr[0],insp_mask_im<=rr[1])
  print ii,gastrapping_mask[region_mask].sum(),region_mask.sum()
  val.append(100*gastrapping_mask[region_mask].sum()/float(region_mask.sum()));
  print "Gas trapping region "+ str(rr[0]) + "is "+ str(val[ii])


# Compute Gas Trapping metric using Jacobian