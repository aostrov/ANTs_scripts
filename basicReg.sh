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

echo "################"


fixed="fakeFixed.nii.gz"
moving="fakeMoving_01.nrrd"
antsCallFile="test.antsCall"

nm1=`stripEndings ${fixed}`
nm2=`stripEndings ${moving}`
semanticChannelPrimary=`echo ${nm2} | sed -E 's/.*_([[:alnum:]]*$)/\1/'`
outputStem=${nm1}_fixed_${nm2%_${semanticChannelPrimary}}_moving_$antsCallFile

affine=${outputStem}0GenericAffine.mat
warp=${outputStem}1Warp.nii.gz
warpFiles=()

bridging=0
bridging_warp="CCU-bridging1Warp.nii.gz"
atlas="CCU.nrrd"


dryRun=1

# 2 = all channels
# 0 = no channels
# 1 = only reference channel
single=2

outputDir=""

if [[ ${outputDir} != "" ]] ; then
	outputDir=`echo ${outputDir}/ | sed 's/ //g'`
	# echo ${outputDir}
	mkdir -p ${outputDir}
	
	# rename affine and warp if there is a registration dir with the files
	# in it...
	if [[ -s ${outputDir}${warp} ]] ; then warp=${outputDir}${warp} ; fi
	if [[ -s ${outputDir}${affine} ]] ; then affine=${outputDir}${affine} ; fi
fi


# determine if a new registration needs to be done
if [[ -s ${outputStem}_${semanticChannelPrimary}.nii.gz ]] ; then
	echo "output already exists"
	if [ $bridging -eq 0 ] ; then
		echo "if no other transforms are needed"
		echo "or no bridging is going to happen,"
		echo "exiting"
		exit 0
	else
		echo "Moving on to bridging transformation"
	fi
elif ([[ -s ${warp} ]] && [[ -s ${affine} ]]) ; then
	echo "Warp and affine exist"
	echo "Skipping to transformations"
elif [[ -s ${warp} ]] ; then
	echo "There is a warp, but not an affine for this tranformation,"
	echo "please supply both."
	exit 1
elif [[ -s ${affine} ]] ; then
	echo "You've passed a single affine transformation."
	echo "Hopefully all you want is to perform an affine transformation."
	echo "Skipping to transformations"
else
	echo ""
	echo "Starting registration of ${moving} to ${fixed},"
	echo "using parameters from ${antsCallFile}"
	echo ""
	#######################
	# Source antsCallFile #
	#######################
	# source $antsCallFile
	echo making $affine
	affine=${outputDir}$affine
	command echo fake affine >> $affine
	
	echo making $warp
	warp=${outputDir}$warp
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
	echo "Proceeding to tranformation of all input images"
	range=(`ls ${nm2%_${semanticChannelPrimary}}*`)
fi

# check if warp and affine exist
if [[ -s ${warp} ]] && [[ -s ${affine} ]] ; then
	echo "Using ${affine} and ${warp} for the transformation"
	warpFiles+="${warp} ${affine} "
elif [[ -s ${warp} ]] ; then
	echo "You only seem to have ${warp} available,"
	echo "which is rather strange."
	echo "Proceeding anyway"
	warpFiles+="${warp} "
elif [[ -s ${affine} ]] ; then
	echo "You only seem to have ${affine} available,"
	echo "hopefully this is what you wanted."
	echo "Proceeding"
	warpFiles+="${affine} "
else
	echo "You've reached a weird state and have no transformations"
	echo "to apply to your image."
	echo "Exiting"
	exit 2
fi

# If we do, do we want to bridge to an atlas
# # confirm atlas and warp-to-atlas exist
if [ $bridging -eq 1 ] ; then
	if [[ -s ${atlas} ]] && [[ -s ${bridging_warp} ]] ; then 
		echo "bridging ${moving} to ${atlas} using ${bridging_warp}"
	else
		echo "You want to perform a bridging registration but you have"
		echo "not provided a target atlas image and a bridging registration"
		exit 3
	fi
	# # update fixed image to reflect the atlas
	fixed=${atlas}
	# # prepend warp-to-atlas to warpFiles
	final_transformation_files=(${bridging_warp})
	final_transformation_files+=" ${warpFiles}"
	
	final_outputStem=`stripEndings ${atlas}`_via_${outputStem}
else
	final_transformation_files=${warpFiles}
	final_outputStem=${outputStem}
fi
echo "final transformation: -t ${final_transformation_files}"
echo ""

# Are we transforming multiple images
# it doesn't matter, we have our range and we can work with it

# Run the transformations
for i in ${range[@]}; do
	echo $i
	nthChannelIn=$i
	semanticChannel=`stripEndings ${i} | sed -E 's/.*_([[:alnum:]]*$)/\1/'`
	nthChannelOut=${final_outputStem}_${semanticChannel}.nii.gz
	
	if [[ -s $nthChannelOut ]] ; then 
		mv $nthChannelOut ${outputDir}${nthChannelOut}
	fi
	
	nthChannelOut=${outputDir}${nthChannelOut}
		
	if [[ ! -s $nthChannelOut ]] ; then
		
		echo ""
		echo "Transforming ${nthChannelOut}"
		echo ""
	
		if [[ $dryRun -gt 0 ]] ; then
			echo nthChannelIn: $nthChannelIn
			echo nthChannelOut: $nthChannelOut
			command echo nthChannelOut >> $nthChannelOut
		else
			#############################
			# Source antsTransformation #
			#############################
			
			source antsTransformation.sh		
		fi
		
	else
		echo ""
		echo "${nthChannelOut} already exists."
		echo "Skipping"
		echo ""
	fi
done

# echo nm1: $nm1
# echo nm2: $nm2
# echo outputStem: $outputStem