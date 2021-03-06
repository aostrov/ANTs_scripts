#!/bin/bash
#
echo "very start of the script"
# Orger Lab, 2017
# ANTs whole brain registration bash script
#
# usage: 
#     antsRunRegistration -f Template/Fixed Image -m Moving Image -a ANTsCallFile <other options>
#
#
# HARDCODED USER OPTIONS, ADJUST TO NEED
# -> ANTs_path
#   	Path to ANTs binaries
# -> thread_number
#   	Controls multi-threading. Set to the number of physical
#   	cores in the computer
# Updated 2019-2020.
# - Better/more verbose arguments
# - Usage of masks
# - Automatic transformation of Nth channels
#  - First channel image name must end in _01.[nrrd,nii.gz,tif] unless '-c' flag is used
#  - Nth channel image name must end in _0N.[nrrd,nii.gz,tif]
# Updated 2021.
# Channels are now figured out automatically, but must confirm to the patter:
#    basename_label.[nrrd,nii.gz,tif] with the '_label' being the key information.
#    'label' can be anything: '01' or 'terk' or 'a' as desired. The registration
#    will be driven by the image passed with the '-m' option.
# ~~Arbitrary warp and affine registration files cannot be used to drive transformations
# for arbitrary images, hopefully that is ready soon~~.
# Warp and affine files for their associated image can be in arbitrary locations if they are 
# passed with the '-r' and '-w' flags, otherwise the script looks at the current directory and
# the directory passed with the '-o' option
# Bridging should work, but is untested
# The script will look for files in the current directory, or in the subdirectory indicated
# by the '-o' option. Files will be saved into the current directory, or the directory
# indicated by the '-o' option.

function Usage {
    cat <<USAGE

Usage:

`basename $0` -f Template/Fixed Image -m Moving Image -a ANTsCallFile <other options>

Compulsory arguments:

-f: File name (including file type) of the template (fixed) image to be used as the 
	target space for the registration. '-a' can be substituted for '-f' if a bridging
	transformation is already fully computed for this input file.

-m: File name (including file type) of the moving image.

-a: antsCall file to used for the registration

-------------------------------------------------------

Optional arguments:

-d: Dry run. Outputs the full file names of the output images, but does not run a 
	registration.
	
-o: Output directory. Defaults to "registration".
	
-t: This controls the transformation of the various channels.
	0: don't run any transformations.
	1: Transform only the first channel/counterstain channel (often tERK).
	2: (Default) Transform all available channels that match the naming pattern of the 
	first channel.	

-h: print the Usage message for `basename $0`

-B: Set the bit depth of the transformed images to 16 bits.
	0: Use the native 32bit output of the ANTs transformation.
	1: (Default) Convert to 16bit output images.

-x: A single mask file to be passed to the registration. For now, this assumes
	that the mask will be applied to the fixed image. The mask should be an 8bit binary 
	mask with 1s where the registration should be applied, and 0s where it should be 
	excluded. The masking step does not seem to apply to the initial transformation step,
	so be careful when using it.

-p: The path to the ANTs binaries. Default is '/usr/bin/'.

-b: The bridging warp file to be used.

-w: A warp file that was previously generated by ANTs/ITK. This will be used to transform
	and images passed along with this. The file should be in '.nii.gz' format. Must be 
	passed with the -r option. **Note that the file stem for the warp must match the filestem
	for the moving image; arbitrary file names cannot currently be used.**
	
-r: A rigid initial alignment file previously generated with ANTs/ITK. This will be used to 
	transform and images passed along with this. The file should be in '.mat' format. 
	Must be passed with the -w option.

-A: The atlas template that is being bridged to. If '-b' is not set, this does nothing.

-T: Thread number. Set to the number of physical cores in the computer. On the cluster
	this could be 12. On a personal laptop this is likely to be 4.
	
USAGE
    exit 1
}

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

# some sensible default values
thread_number=3
dryRun=0
ANTs_path="/usr/bin/"
bridging=0
mask=""
single=2
outputAs16=1
regChannel=01
outputDir="registration"
warpFiles=()

# TODO: check to remove later
bridging_warp="CCU-bridging1Warp.nii.gz"
atlas="CCU.nrrd"
# end TODO


while getopts ":hdf:A:m:x:a:p:T:b:w:r:t:B:o:" OPT; do
	case $OPT in
		h)
			Usage >&2
			exit 0
		;;
		f)
			fixed=$OPTARG
		;;
		A)
			atlas=$OPTARG
		;;
		m)
			moving=$OPTARG
		;;
		x)
			mask=$OPTARG
		;;
		a)
			antsCallFile=$OPTARG
		;;
		p)
			ANTs_path=$OPTARG
		;;
		T)
			thread_number=$OPTARG
		;;
		d)
			dryRun=1
		;;
		b)
			bridging_warp=$OPTARG
			bridging=1
		;;
		w)
			warp=$OPTARG
		;;
		r)
			affine=$OPTARG
		;;
		t)
			single=$OPTARG
			if [ $single -gt 2 ] ; then
				echo "-s is outside of range"
				echo "Please choose from 0, 1, or 2"
				echo use `basename $0` -h to see a list of valid inputs
				exit
			fi
		;;
		B)
			outputAs16=$OPTARG
			if [ $outputAs16 -gt 1 ] ; then
				echo "-B is greater than 1,"
				echo "it must be either 0 (32bit output image) or 1 (16bit output image)"
				echo use `basename $0` -h to see a list of valid inputs
				exit
			fi
		;;
		o)
			outputDir=$OPTARG
		;;
		\?)
			echo "#########################################"
			echo "    -${OPTARG} is not a valid input!"
			echo "#########################################"
			echo
			echo use `basename $0` -h to see a list of valid inputs
			echo
			exit 0
		;;
	esac
done
if [[ $OPTIND -eq 1 ]]; then
	echo
	echo "##########################" 
	echo "# No options were passed #"
	echo "##########################"
	echo
	Usage >&2
	exit 0
fi

if [[ ! -s $fixed ]] && [[ ! -s ${atlas} ]]; then 
	echo "No reference image ${fixed}, or atlas image"
	exit 
elif  [[ ! -s ${fixed} ]] && [[ -s ${atlas} ]] ; then
	echo "Setting fixed to: ${atlas}"
	fixed=${atlas}
else
	# do nothing?
	echo ""
fi

if [[ ! -s $moving ]] ; then echo "No moving image $moving" ; exit ; fi
if [[ -z $antsCallFile ]] ; then echo "No antsCall $antsCallFile" ; exit; fi
if [[ ! -f $antsCallFile ]] ; then
  antsCallFile=$antsCallFile.antsCall
  if [[ ! -f $antsCallFile ]] ; then
    echo "ANTs call file -a ${antsCallFile} was not found"
    exit
  fi
fi


########################################################################
########################################################################
# Set ANTs path
export ANTS_PATH=${ANTs_path}
# Set multi-threading
export ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=$thread_number


nm1=`stripEndings ${fixed}`
nm2=`stripEndings ${moving}`
semanticChannelPrimary=`echo ${nm2} | sed -E 's/.*_([[:alnum:]]*$)/\1/'`
outputStem=${nm1}_fixed_${nm2%_${semanticChannelPrimary}}_moving_$antsCallFile

if [[ $affine == "" ]] ; then
	echo "affine is undefined"
	affine=${outputStem}0GenericAffine.mat
	echo "setting affine to ${affine}"
fi

if [[ ${warp} == "" ]] ; then
	echo "warp is undefined"
	warp=${outputStem}1Warp.nii.gz
	echo "setting warp to ${warp}"
fi


warpFiles=()


if [[ ${outputDir} != "" ]] ; then
	# not sure if I need to strip white spaces, in fact,
	# it could confuse things later on. Maybe better to just
	# be careful with how I call outputDir in all future calls
	outputDir=${outputDir}/
	echo ${outputDir}
	mkdir -p ${outputDir}
	
	# rename affine and warp if there is a registration dir with the files
	# in it...
	if [[ -s ${outputDir}${warp} ]] ; then warp=${outputDir}${warp} ; fi
	if [[ -s ${outputDir}${affine} ]] ; then 
		affine=${outputDir}${affine}
		echo $affine
	fi
fi
registrationOutput=${outputDir}${outputStem}

# determine if a new registration needs to be done
if [[ -s ${registrationOutput} ]] ; then
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
	source $antsCallFile
	
	# echo making $affine
	affine=${outputDir}${affine}
	# command echo fake affine >> $affine
	#
	# echo making $warp
	warp=${outputDir}${warp}
	# command echo fake affine >> $warp
	
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
			############################
			###### Transformation ######
			############################
			
			${ANTs_path}/antsApplyTransforms \
				-d 2 \
				-v 1 \
				--float 1 \
				-n WelchWindowedSinc \
				-f 0 \
				-i ${nthChannelIn} \
				-r ${fixed} \
				-o ${nthChannelOut} \
				-t ${final_transformation_files}

			# Convert to 16bit from 32bit
		    # TYPE-OPTION  :  TYPE
		    #  0  :  char
		    #  1  :  unsigned char
		    #  2  :  short
		    #  3  :  unsigned short
		    #  4  :  int
		    #  5  :  unsigned int
			
			if [[ $outputAs16 -gt 0 ]] ; then
				echo ""
				echo "Converting to 16bit"
				echo ""
				ConvertImagePixelType ${nthChannelOut} ${nthChannelOut} 3
			fi
					
		fi
		
	else
		echo ""
		echo "${nthChannelOut} already exists."
		echo "Skipping"
		echo ""
	fi
done
