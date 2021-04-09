#!/bin/sh

# Apply generated transforms to register to reference

if [[ $bridging -eq 0 ]] ; then
	${ANTs_path}/antsApplyTransforms \
		-d 3 \
		-v 1 \
		--float 1\
		-n WelchWindowedSinc \
		-f 0 \
		-i ${nthChannelIn} \
		-r ${fixed} \
		-o registration/${nthChannelOut} \
		-t registration/${output}1Warp.nii.gz \
		-t registration/${output}0GenericAffine.mat
elif [[ $bridging -eq 1 ]] ; then
	${ANTs_path}/antsApplyTransforms \
		-d 3 \
		-v 1 \
		--float 1\
		-n WelchWindowedSinc \
		-f 0 \
		-i ${nthChannelIn} \
		-r ${atlas} \
		-o ${nthChannelOut} \
		-t registration/${bridging_warp} \
		-t registration/${output}1Warp.nii.gz \
		-t registration/${output}0GenericAffine.mat
else
	echo "You've hit some weird state."
	echo "Bridging should only have a value of 1 or 0"
fi


# Convert to 16bit from 32bit
if [[ $outputAs16 -gt 0 ]] ; then
	echo ""
	echo "Converting to 16bit"
	echo ""
	ConvertImagePixelType registration/${nthChannelOut} registration/${nthChannelOut} 3
fi
