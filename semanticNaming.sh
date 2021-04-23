#!/bin/bash


stripEndings(){
	localEnding=`basename $1`
	if [[ $localEnding == *.gz ]] || [[ $localEnding == *.tar ]]; then
		myName=`echo $localEnding | sed -E 's/.gz|.tar//'`
		stripEndings $myName
		return 0
	fi
	myName=`echo $localEnding | sed 's/\.[[:alnum:]]*$//'`
	echo $myName
}

moving="semanticMoving_terk.nrrd"

movingBase=`stripEndings ${moving}`
echo file extenstion stripped: $movingBase

semanticStripped=`echo $movingBase | sed 's/_[[:alnum:]]*$//'`
echo semantic information stripped: $semanticStripped

myFiles=(`ls ${semanticStripped}*`)
myFiles+=(" text ")
for i in ${myFiles[@]} ; do
	echo $i
done

