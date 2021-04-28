#!/bin/sh

# Apply generated transforms to register to reference

${ANTs_path}/antsApplyTransforms \
	-d 3 \
	-v 1 \
	--float 1 \
	-n WelchWindowedSinc \
	-f 0 \
	-i ${nthChannelIn} \
	-r ${fixed} \
	-o registration/${nthChannelOut} \
	-t ${final_transformation_files}

# registration/${output}1Warp.nii.gz \
# 	-t registration/${output}0GenericAffine.mat


# Convert to 16bit from 32bit
if [[ $outputAs16 -gt 0 ]] ; then
	echo ""
	echo "Converting to 16bit"
	echo ""
	ConvertImagePixelType registration/${nthChannelOut} registration/${nthChannelOut} 3
fi
