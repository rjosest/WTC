from os import listdir
from os.path import isfile, join, basename
import shutil
import dicom
import pandas as pd

from optparse import OptionParser

parser = OptionParser()

parser.add_option("-i",dest="in_path",help="input directory with DICOM images")
parser.add_option("-o",dest="out_path",help="output directory")
(options, args) = parser.parse_args()

in_path=options.in_path
out_path=options.out_path

dicom_files = [ f for f in listdir(in_path) if isfile(join(in_path,f)) ]

objects=['PatientName','SeriesInstanceUID','SeriesNumber','SeriesDate','ConvolutionKernel','SliceThickness']

dict1=dict()
row_list=[]
for ff in dicom_files:
    dh = dicom.read_file(join(in_path,ff))
    dict1['File']=join(in_path,ff)
    for oo in objects:
        dict1[oo]=dh.get(oo)
    row_list.append(pd.Series(dict1))
    
df = pd.DataFrame(row_list)

for patient,group_p in df.groupby('PatientName'):
  for date,group_d in group_p.groupby('SeriesDate'):
    print patient,date
    vv = group_d.groupby('SeriesInstanceUID')['SeriesNumber'].count()
    vv.sort(0)
    
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
      
      #Create directory for each group
      case_name=df_series['PatientName'].values[0]+'_'+df_series['SeriesDate'].values[0]+'_'+ cycle+'_Ser' \
                  + str(df_series['SeriesNumber'].values[0])
      
      if os.path.isdir(out_path) == True:
        os.mkdir(join(out_path,case_name))
      
      for src in df_series['File']:
        dest = join(out_path,case_name,basename(src))
        shutil.copy(src,dest)

