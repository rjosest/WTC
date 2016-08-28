
filelist=`cat RenameInspToExpCaseList.txt`

for bb in $filelist; do

from=`echo $bb | cut -d "," -f1`
to=`echo $bb | cut -d "," -f2`

#cmd="perl -p -i -e "s/$from/$to/g" WTCaseList.txt"
#echo $bb

#perl -p -i -e "s/$from/$to/g" WTCaseList.txt

#perl -p -i -e "s/$from/$to/g" WTINSPCaseList.txt

#perl -p -i -e "s/$from/$to/g" WTEXPCaseList.txt

perl -p -i -e "s/$from/$to/g" WTINSP-EXPCaseList.txt


done

