#from urllib2 import Request, urlopen, URLError
#import json
#
#
#remote='http://54.208.95.22/'
#
#query='patients'
#
#request = Request(remote+query)
#
#try:
#    response = urlopen(request)
#    return json.loads(response.read())
#
#except URLError, e:
#    print 'No patient', e


import requests
import pandas as pd
from optparse import OptionParser


desc = """Find missing case IDs in orthanc server for an input target list of CaseIDs. The tool
    uses the REST API to check the series description with the case list.
    """

parser = OptionParser(description=desc)
parser.add_option('-i',help='Input case list with target cases',
                        dest='in_caselist',metavar='<string>',default=None)
parser.add_option('-m',help='Output case list with missing cases in orthanc server',
                  dest='missing_caselist',metavar='<string>',default=None)
parser.add_option('-c',help='Output case list with data stored in orthanc',
                  dest='store_caselist',metavar='<string>',default=None)
parser.add_option('--hostname',help='Orthanc hostname',
                        dest='hostname',metavar='<string>',default='54.208.95.22')
parser.add_option('--port',help='Orthanc HTTP port',
                        dest='port',metavar='<string>',default=80)
parser.add_option('--user',help='Orthanc username',
                        dest='username',metavar='<string>',default=None)
parser.add_option('--pass',help='Orthanc password',
                        dest='password',metavar='<string>',default=None)


def DECAMP_cid_mapping(cid_orthanc):
    fields=cid_orthanc.split('_')
    sid=fields[0].split('-')
    cid='_'.join([sid[0]]+fields[1:5]+[sid[1]]+[fields[5]])
    return cid

def WTC_cid_mapping(cid_orthanc):
    return cid_orthanc

(options,args) = parser.parse_args()

api_url='http://'+options.hostname+':'+str(options.port)+'/'
auth=(options.username,options.password)


#Request series
r=requests.get(api_url+'series',auth=auth)
series_list=r.json()

cid_list=list()
cidnew_list=list()
for ss in series_list:
    #print 'Series '+ss
    r=requests.get(api_url+'series/'+ss,auth=auth)
    sinfo=r.json()
    cid=sinfo['MainDicomTags']['SeriesDescription']
    #Unique mapping of cid for DECAMP
    cid_list.append(WTC_cid_mapping(cid))
    cidnew_list.append(cid)


if options.store_caselist:
    outTable=dict()
    outTable['patient_id']=[cid.split('_')[0] for cid in cidnew_list]
    outTable['series_id']=series_list
    outTable['series_description']=cidnew_list

    pd.DataFrame(outTable).to_csv(options.store_caselist,index=False)


if options.in_caselist and options.missing_caselist:
    #Load file with list
    df=pd.read_csv(options.in_caselist,header=None)

    missing=list()
    for ee in list(df[0]):
        if unicode(ee) not in cid_list:
            missing.append(ee)

    pd.DataFrame(missing).to_csv(options.missing_caselist,index=False,header=False)
