#!/bin/bash

file_list=$1
shift

nstars_min=5
inst=coatli
thresh=1.5

while [ $# -gt 0 ] ; do eval $1 ; shift ; done

[ -s $file_list ] || { echo "No file $file_list" ; exit 1 ; }

go_iter=0
function gonogo() {
    ((go_iter++))
    [ "$((go_iter%NBATCH))" -eq 0 ] && wait
}

echo find_stars.sh $file_list inst=$inst nstars_min=$nstars_min thresh=$thresh
find_stars.sh $file_list inst=$inst nstars_min=$nstars_min thresh=$thresh
mv stars_$file_list $file_list
nfiles=`cat $file_list | wc -l`

align_ref_file=align_file.txt
if [ "$nfiles" -gt 0 ]; then
    [ -f "$align_ref_file" ] || {
        afile=`gethead NSTARS @$file_list | sort -n -k 2 | awk '{if(NR==int('$nfiles'/2)+1) print $1}'`
        sethead MATCHED=1 $afile
        echo "# $afile" > $align_ref_file
        if [ -f "$afile" ]; then
            base=${afile%'.fits'}
            cat ${base}_dir/${base}_radec.txt >> $align_ref_file
        fi
    }
fi

if [ -s "$align_ref_file" ]; then

    rm report$$.txt 2>/dev/null
    afile=`head -1 $align_ref_file | awk '{print $2}'`
    nfiles1=`cat $file_list | grep -v $afile | wc -l`
    for file in `cat $file_list | grep -v $afile`; do
        base=${file%'.fits'}
        sexlist_cc.py $file ${base}_dir/${base}_radec.txt $align_ref_file X 0 0 0 25 $nstars_min >> report$$.txt 2>/dev/null &
        gonogo
    done
    wait; go_iter=0

    nmatch=`cat report$$.txt | wc -l`
    echo "Matched $nmatch of $nfiles1 files..."
    cat report$$.txt

    grep $afile $file_list > ${file_list}.tmp
    awk '{print $6}' report$$.txt | awk -F/ '{print $2}' | sed -e 's/_radec\.txt/\.fits/g' >> ${file_list}.tmp
    mv ${file_list}.tmp $file_list
    sethead MATCHED=1 @$file_list

fi
