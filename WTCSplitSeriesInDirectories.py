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

df=df[df['SliceThickness']<=5]

print "Number of entries after prunning thick slices " + str(len(df.index))

case_list=list()

for patient,group_p in df.groupby('PatientName'):
  print patient
  for date,group_d in group_p.groupby('StudyInstanceUID'):
    print date
    
    group_t=group_d.groupby('SliceThickness')
    
    #Look for the group with 5mm and the thinnest group
    thickness=group_t.groups.keys()
    
    thickness.sort()
    run_thickness=list()
    for th in thickness:
         #If the smallest thickness has just a few slices, do not consider
    	if len(group_t.groups[th])>25:
	  run_thickness.append(th)
          break

     #Add the 5 mm scann if exits
     	  
    if 5.0 in thickness:
    	run_thickness.append(5.0)
    
    for th in run_thickness:
      print th
      if th == 5:
      	thickness_tag="_5mm"
      else:
        thickness_tag=""
	
      group_s = group_t.get_group(th)	
      vv = group_s.groupby('SeriesInstanceUID')['SeriesNumber'].count()
      vv.sort(0)
      print vv
      
      if vv[-1]<25:
        #This group is too small (most likely is a scout image)
	continue
      
      if len(vv) == 1:
        #Just one scan. We assume that it is INSP
	cycles=['INSP']
	cycles_index=[-1]
      else:
        #Set a minimum of slices to qualify
        #if vv[-1] < 100 or vv[-2] < 100:
        #continue
    
        #IF number of slices is equal we assume that second scan is the exp and first insp
        if vv[-1]==vv[-2]:
          cycles=['EXP','INSP']
        else:
          cycles=['INSP','EXP']
        
	cycles_index=[-1,-2]
      #Select series + get file name

      for idx,cycle in zip(cycles_index,cycles):
        df_series=df[df['SeriesInstanceUID']==vv.keys()[idx]]
        print vv.keys()[idx]
        #Create directory for each group
        case_name=df_series['PatientName'].values[0]+'_'+ str(df_series['SeriesDate'].values[0])+'_'+ cycle+thickness_tag+'_Ser' \
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
