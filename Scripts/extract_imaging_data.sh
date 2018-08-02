
ff=$1

cid=`basename $ff | cut -d . -f1`
sid=`echo $cid | cut -d _ -f1`

unu="/mad/store-replicated/clients/copd/Software/teem-build/unu"
dx=`$unu head $ff | grep sizes | cut -d : -f2 | cut -d " " -f2`
dy=`$unu head $ff | grep sizes | cut -d : -f2 | cut -d " " -f3`
dz=`$unu head $ff | grep sizes | cut -d : -f2 | cut -d " " -f4`

sx=`$unu head $ff | grep directions | cut -d " " -f3 | cut -d "(" -f2 | cut -d ")" -f1 | cut -d , -f1`
sy=`$unu head $ff | grep directions | cut -d " " -f4 | cut -d "(" -f2 | cut -d ")" -f1 | cut -d , -f2`
sz=`$unu head $ff | grep directions | cut -d " " -f5 | cut -d "(" -f2 | cut -d ")" -f1 | cut -d , -f3`

echo "$sid,$cid,$dx,$dy,$dz,$sx,$sy,$sz" >> ~/WTCData