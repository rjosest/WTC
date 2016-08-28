import dicom

from os import listdir
from os.path import isfile, join



def fix_dicom(mypath,cid):


  onlyfiles = [join(mypath,f) for f in listdir(mypath) if isfile(join(mypath, f))]

  for ff in onlyfiles:
    try:
      ds=dicom.read_file(ff)
    except:
      continue
    
    tags=cid.split('_')

    ds.PatientName=tags[0]
    ds.PatientID=tags[0]

    ds.StudyDescription=tags[0]+'_'+tags[1]
    ds.SeriesDescription=cid

    inst_num=ds.InstanceNumber

    ds.SOPInstanceUID=ds.SOPInstanceUID+'.'+str(inst_num)

    ds.save_as(ff)

from optparse import OptionParser
if __name__ == "__main__":
  desc = """Fix Dicom header"""
    
  parser = OptionParser(description=desc)
  parser.add_option('-d',help='Directory with Dicom files',
                    dest='mypath',metavar='<string>',default=None)
  parser.add_option('-c',help='CaseID',
                    dest='cid',metavar='<string>',default=None)


  (options,args) = parser.parse_args()

  fix_dicom(options.mypath,options.cid)


