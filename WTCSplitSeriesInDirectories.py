from os import listdir, mkdir
from os.path import isfile, join, basename, isdir
import os
import shutil
import dicom
import pandas as pd
import csv

from optparse import OptionParser

parser = OptionParser()

parser.add_option("-i",dest="in_path",help="input directory with DICOM images")
parser.add_option("-o",dest="out_path",help="output directory")
parser.add_option("-v",dest="caselist_filename",help="CSV files with directory names that are generated")
(options, args) = parser.parse_args()

in_path=options.in_path
out_path=options.out_path
caselist_filename = options.caselist_filename

dicom_files = [ f for f in listdir(in_path) if isfile(join(in_path,f)) ]

objects=['PatientName','StudyInstanceUID','SeriesInstanceUID','SeriesNumber','SeriesDate','ConvolutionKernel','SliceThickness']

dict1=dict()
row_list=[]
print "Ready to read dicom ..." + str(len(dicom_files))

for ff in dicom_files:
  dict1=dict()
  dh = dicom.read_file(join(in_path,ff))
  dict1['File']=join(in_path,ff)
  for oo in objects:
    dict1[oo]=dh.get(oo)
  row_list.append(dict1)

df = pd.DataFrame(row_list)

print "Number of entries " + str(len(df.index))

case_list=list()

for patient,group_p in df.groupby('PatientName'):
  print patient
  for date,group_d in group_p.groupby('StudyInstanceUID'):
    print date
    vv = group_d.groupby('SeriesInstanceUID')['SeriesNumber'].count()
    vv.sort(0)
    print vv
    #Set a minimum of slices to qualify
    if vv[-1] < 100 or vv[-2] < 100:
      continue
    
    #IF number of slices is equal we assume that second scan is the exp and first insp
    if vv[-1]==vv[-2]:
      cycles=['EXP','INSP']
    else:
      cycles=['INSP','EXP']

    #Select series + get file name

    for idx,cycle in zip([-1,-2],cycles):
      df_series=df[df['SeriesInstanceUID']==vv.keys()[idx]]
      print vv.keys()[idx]
      #Create directory for each group
      case_name=df_series['PatientName'].values[0]+'_'+ str(df_series['SeriesDate'].values[0])+'_'+ cycle+'_Ser' \
                  + str(df_series['SeriesNumber'].values[0])
      print "Packing " + case_name + " from series " + str(vv.keys()[idx])
      case_list.append([case_name])
      if isdir(join(out_path,case_name)) == False:
        os.mkdir(join(out_path,case_name))
      
      for src in df_series['File']:
        dest = join(out_path,case_name,basename(src))
        shutil.copy(src,dest)


with open(caselist_filename, 'w') as csvfile:
  writer = csv.writer(csvfile)
  writer.writerows(case_list)
