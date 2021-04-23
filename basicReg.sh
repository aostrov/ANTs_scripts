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


fixed="fakeFixed.nii.gz"
moving="fakeMoving_01.nrrd"
antsCallFile="test.antsCall"

nm1=`stripEndings ${fixed}`
nm2=`stripEndings ${moving}`
semanticChannelPrimary=`stripEndings ${nm2} | sed -E 's/.*_([[:alnum:]]*$)/\1/'`
outputStem=${nm1}_fixed_${nm2%_${semanticChannelPrimary}}_moving_$antsCallFile
affine=${outputStem}0GenericAffine.mat
warp=${outputStem}1Warp.nii.gz
warpFiles=("-t ")

# 2 = all channels
# 0 = no channels
# 1 = only reference channel
single=2

# determine if a new registration needs to be done
if [[ -s ${outputStem}_${semanticChannelPrimary}.nii.gz ]] ; then
	echo "output already exists"
	echo "if no other transforms are needed"
	echo "or no bridging is going to happen,"
	echo "exiting"
	# exit 0
elif [[ -s ${warp} ]] && [[ -s ${affine} ]] ; then
	echo "Warp and affine exist"
	echo "Skipping to transformations"
elif [[ -s ${warp} ]] ; then
	echo "There is a warp, but not an affine for this tranformation,"
	echo "please supply both."
	exit 1
else
	echo "Starting registration of ${moving} to ${fixed},"
	echo "using parameters from ${antsCallFile}"
	#######################
	# Source antsCallFile #
	#######################
	# source $antsCallFile
	echo making $affine
	command touch $affine
	command echo fake affine >> $affine
	
	echo making $warp
	command touch $warp
	command echo fake affine >> $warp
	
fi

# Determine if we want to transform

if [ $single -eq 0 ] ; then
	# we're done here
	echo "No transformations were requested."
	echo "Exiting with status 0"
	exit 0
elif [ $single -eq 1 ] ; then
	echo "Only transforming the reference channel."
	range=($moving)
else
	echo "Proceeding to tranformation of images"
	range=(`ls ${nm2}*`)
fi

# check if warp and affine exist
if [[ -s ${warp} ]] && [[ -s ${affine} ]] ; then
	echo "Using ${affine} and ${warp} for the transformation"
	warpFiles+="${warp} ${affine} "
fi

echo $warpFiles
	

# If we do, do we want to bridge to an atlas

# Are we transforming multiple images

# Run the transformations

# echo nm1: $nm1
# echo nm2: $nm2
# echo outputStem: $outputStem