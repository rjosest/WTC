#!/usr/bin/python

import subprocess
import os
import nrrd
import numpy as np
import scipy.stats as stats
import csv
from subprocess import PIPE

from optparse import OptionParser

parser = OptionParser()

parser.add_option("-i",dest="inspCID",help="case ID for inspiratory image")
parser.add_option("-e",dest="expCID",help="case ID for expiratory image")
parser.add_option("-s",dest="sigma",help="sigma for initial smoothing [default: %default]", type="float",default=1)
parser.add_option("-r",dest="rate",help="initial upsampling/downsampling rate [default: %default]", type="float", default=1)
parser.add_option("-o",dest="out_filename", help="output CSV file for gas trapping phenotpyes")
parser.add_option("--tmpDir",dest="tmp_dir",help="temporary directory" )
parser.add_option("--dataDir", dest="data_dir",help="data directory for the case IDs")

(options, args) = parser.parse_args()

insp_cid = options.inspCID
exp_cid = options.expCID
sigma = options.sigma
rate = options.rate
tmp_dir = options.tmp_dir
data_dir = options.data_dir
out_filename = options.out_filename

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
deformation_prefix_tmp = os.path.join(tmp_dir,exp_cid + "_to_" + insp_cid + "_tfm_")

affine_tfm = deformation_prefix + "0GenericAffine.mat"
elastic_tfm = deformation_prefix + "1Warp.nii.gz"
elastic_inv_tfm = deformation_prefix + "1InverseWarp.nii.gz"

insp_mask = os.path.join(data_dir,insp_cid + "_partialLungLabelMap.nhdr")
exp_mask = os.path.join(data_dir,exp_cid + "_partialLungLabelMap.nhdr")
insp_mask_tmp = os.path.join(tmp_dir,insp_cid + "_partialLungLabelMap.nhdr")
exp_mask_tmp = os.path.join(tmp_dir,exp_cid + "_partialLungLabelMap.nhdr")
insp_wl_mask = os.path.join(tmp_dir,insp_cid + "_wholelung.nhdr")

jacobian_tmp = deformation_prefix_tmp + "jacobian.nhdr"
jacobian_nifti_tmp = deformation_prefix_tmp + "jacobian.nii.gz"

mass_file = os.path.join(data_dir,insp_cid + "_residualMass.nhdr")
mass_mask_file = os.path.join(data_dir,insp_cid + "_residualMassMask.nhdr")

#Conditions input images: Gaussian blurring to account for SHARP kernel
unu = os.path.join(path['TEEM_PATH'],"unu")
for im in [insp,exp_to_insp]:
  out = os.path.join(tmp_dir,os.path.basename(im))
  tmp_command = unu + " resample -i %(in)s -s x1 x1 = -k dgauss:%(sigma)f,3 | "+ unu + " resample -s x%(r)f x%(r)f x%(r)f -k tent -o %(out)s"
  tmp_command = tmp_command % {'in':im, 'out':out,'sigma':sigma,'r':rate}
  print tmp_command
  subprocess.call( tmp_command, shell=True)
for im in [insp_mask]:
  out = os.path.join(tmp_dir,os.path.basename(im))
  tmp_command = unu + " resample -s x%(r)f x%(r)f x%(r)f -k cheap -i %(in)s -o %(out)s"
  tmp_command = tmp_command % {'in':im, 'out':out,'r':rate}
  print tmp_command
  subprocess.call( tmp_command, shell=True)

  
#Define region labels and variables
regions=[(5,7),(5,5),(6,6),(7,7)]
regions_labels=['Global','Upper','Middle','Lower']

#Define phenotypes labels
phenos_labels=['fSAD','RMperc','Jac']
phenos=dict()

# Compute Gas Trapping metrics based on Galban's paper

insp_im , insp_header = nrrd.read(insp_tmp)
reg_exp_im ,  reg_exp_header = nrrd.read(exp_to_insp_tmp)
insp_mask_im , insp_mask_header = nrrd.read(insp_mask)

fSAD=list()
gastrapping_mask=  np.logical_and(insp_im > -950, reg_exp_im < -856)
for ii,rr in enumerate(regions):
  region_mask = np.logical_and(insp_mask_im>=rr[0],insp_mask_im<=rr[1])
  #print ii,gastrapping_mask[region_mask].sum(),region_mask.sum()
  fSAD.append(100*gastrapping_mask[region_mask].sum()/float(region_mask.sum()));
  print "Gas trapping region "+ str(rr[0]) + " is "+ str(fSAD[ii])

phenos[phenos_labels[0]]=fSAD

# Compute Gas Trapping metric using Jacobian
tmp_command = "CreateJacobianDeterminantImage 3 %(warp)s %(out)s 0 1"
tmp_command = tmp_command % {'warp': elastic_tfm, 'out': jacobian_tmp}
tmp_command = os.path.join(path['ANTS_PATH'],tmp_command)
print tmp_command
subprocess.call( tmp_command, shell=True )

#tmp_command = "c3d %(in)s -o %(out)s"
#tmp_command = tmp_command % {'in': jacobian_nifti_tmp, 'out': jacobian_tmp}
#print tmp_command
#subprocess.call( tmp_command, shell=True )

tmp_command = unu + " resample -k tent -s %(x)d %(y)d %(z)d -i %(in)s -o %(out)s"
tmp_command = tmp_command % {'x':insp_header['sizes'][0],'y':insp_header['sizes'][1],'z':insp_header['sizes'][2],'in':jacobian_tmp,'out':jacobian_tmp}
print tmp_command
subprocess.call( tmp_command, shell=True )

jac_im, jac_header = nrrd.read(jacobian_tmp)

#Compute residual mass image:
sp_dir=insp_header['space directions']
voxel_vol=sp_dir[0][0]*sp_dir[1][1]*sp_dir[2][2]

mass_th = [50,75,100]
mass_im = (reg_exp_im - insp_im) * jac_im
#mass2_im = (insp_im - jac_im* reg_exp_im) *(1-jac_im)
mass2_im = ((insp_im+1000) - jac_im * (reg_exp_im+1000))*voxel_vol
#mass3_im = (2* insp_im - jac_im*(insp_im+reg_exp_im))

#Get lung mask
tmp_command = "ExtractChestLabelMap -i %(lm)s -r WholeLung -o %(out-lm)s"
tmp_command = tmp_command % {'lm': insp_mask_tmp,'out-lm': insp_wl_mask}
print tmp_command
subprocess.call( tmp_command, shell=True )

wl_mask_im,wl_mask_header = nrrd.read(insp_wl_mask)

#Mass mass2 and save
print "Masking residual mass map"
#2. Remove vessels
mass2_im[insp_im > -500]=0
#3. Clamp mass outside range
mass2_im[mass2_im<-15]=0
mass2_im[mass2_im>15]=0
#1. Isolate lung
mass2_im[wl_mask_im == 0]=1000
#mass2_im[np.logical_and(mass2_im<-20,mass2_im>20)]=0
#3. Create gain/loss mask
mass2_mask=np.zeros(mass2_im.shape)
#Mass gain: Label 2
mass2_mask[mass2_im>3]=2
#Mass loss: label 1
mass2_mask[mass2_im<-3]=1
mass2_mask[mass2_im==1000]=0

print "Saving residual mask map"
nrrd.write(mass_file,mass2_im,insp_header)
nrrd.write(mass_mask_file,mass2_mask,insp_header)


exit 

resmass = list()
for th in mass_th:
  mass_mask = np.logical_and(mass_im < th, insp_im > -950)
  tmplist = list()
  for ii,rr in enumerate(regions):
    region_mask = np.logical_and(insp_mask_im>=rr[0],insp_mask_im<=rr[1])
    tmplist.append(100*mass_mask[region_mask].sum()/float(region_mask.sum()))
    print "Residual mask % "+ str(rr[0]) + " for th " + str(th) + " is " + str(tmplist[ii])
  resmass.append(tmplist)

phenos[phenos_labels[1]]=resmass



# Obtain histogram metrics from the Jacobian
jacstats = list()
for ii,rr in enumerate(regions):
  region_mask = np.logical_and(insp_mask_im>=rr[0],insp_mask_im<=rr[1])
  Jmean = np.mean(jac_im[region_mask])
  Jstd = np.std(jac_im[region_mask])
  Jkur = stats.kurtosis(jac_im[region_mask])
  Jskew = stats.skew(jac_im[region_mask])
  jacstats.append([Jmean,Jstd,Jkur,Jskew])
  print "Residual mask % "+ str(rr[0]) + " is " + str(jacstats[ii])

phenos[phenos_labels[2]]=jacstats

# Save results to CSV table
title=list()
data=list()
for ii,rr in enumerate(regions_labels):
  title.append(rr + " " + phenos_labels[0])
  data.append(phenos[phenos_labels[0]][ii])

for ii,rr in enumerate(regions_labels):
  for jj,th in enumerate(mass_th):
    title.append(rr + " " + phenos_labels[1] + "(" + str(th) + ")")
    data.append(phenos[phenos_labels[1]][jj][ii])

for ii,rr in enumerate(regions_labels):
  for jj,statsL in enumerate(['Mean','Std','Kurtosis','Skewness']):
    title.append(rr + " " + phenos_labels[2] + " " + statsL)
    data.append(phenos[phenos_labels[2]][ii][jj])

ff=open(out_filename, 'wb')
csv_writer=csv.writer(ff,delimiter=',')
csv_writer.writerows([title,data])
ff.close()
