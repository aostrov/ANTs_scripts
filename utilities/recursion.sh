#!/bin/bash

filename=$1
globalName=""
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

returned=`stripEndings $filename`
echo $myName
echo returned: $returned