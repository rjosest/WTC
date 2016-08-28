import csv
import pandas as pd


from optparse import OptionParser

parser = OptionParser()

parser.add_option("-i",dest="case_list",help="input case list to mach INSP and EXP")
(options, args) = parser.parse_args()
case_list=options.case_list
#table=list()
#with open('WTCaseList.txt', 'rb') as csvfile:
# spamreader = csv.reader(csvfile, delimiter='_')
#  for row in spamreader:
#    table.append(row)
#df=pd.DataFrame(table,columns=['CID','Date','Cycle','Series'])

df=pd.read_csv(case_list,sep="_",header=0,names=['CID','Date','Cycle','Series'])
df=df.astype(str)
for cid,group_cid in df.groupby('CID'):
  for date,group_date in group_cid.groupby('Date'):
    insp=group_date[group_date['Cycle']=='INSP']
    exp=group_date[group_date['Cycle']=='EXP']
      
    if len(insp.index)!=1 or len(exp.index)!=1:
      continue
    print "_".join(list(insp.values[0])) + "," + "_".join(list(exp.values[0]))
