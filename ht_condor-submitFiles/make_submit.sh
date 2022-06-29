#!/bin/bash

# TODO:
# 1. check if mask is set, that a mask exists

Usage() {
    cat <<USAGE
Usage:
`basename $0` -f [Template/Fixed Image] -a ANTsCallFile <other options>
Compulsory arguments:
-f: File name (including file type) of the template (fixed) image to be used as the 
	target space for the registration. [not implemented:'-a' can be substituted for '-f' if a bridging
	transformation is already fully computed for this input file.]
-a: antsCall file to used for the registration
-------------------------------------------------------
Optional arguments:

-s: The semantic indicator for the reference channel. All files must end as '_xxx.nrrd' where 'xxx' is
	and indicator of the channel. This could be 'tERK' if the reference image is the anti-tERK
	staining. Defaults to '01'.
-e: File extension for the moving images. File extensions must be the same for input files, but
	can be of any image format supported by ANTs (normally: tif, nrrd, nii.gz). Defaults to
	'nrrd'.	
-o: Output directory. Defaults to "commands".
-t: This controls the transformation of the various channels.
	0: don't run any transformations.
	1: Transform only the first channel/counterstain channel (often tERK).
	2: [Default] Transform all available channels that match the naming pattern of the 
	first channel.	
-n: Name of the output submit script. Defaults to `date=$(date '+%Y-%m-%d'); echo $date`.submit.	
-h: print the Usage message for `basename $0`
-x: A single mask file to be passed to the registration. For now, this assumes
	that the mask will be applied to the fixed image. The mask should be an 8bit binary 
	mask with 1s where the registration should be applied, and 0s where it should be 
	excluded. The masking step does not seem to apply to the initial transformation step,
	so be careful when using it.
-p: The path to the ANTs binaries. Default is '/usr/bin/'.
-T: [Default=12] Thread number. Set to the number of physical cores in the computer. On the cluster
	this could be 12 or more. On a personal laptop this is likely to be 4.
-M: [Default=128000] Memory to request per process. In megabytes.
-d: Docker image. Defaults to 'docker-registry.champalimaud.pt/ants'

-------------------------------------------------------
Not Implemented, but possible:
-B: Set the bit depth of the transformed images to 16 bits.
	0: Use the native 32bit output of the ANTs transformation.
	1: (Default) Convert to 16bit output images.
-b: The bridging warp file to be used.
-w: A warp file that was previously generated by ANTs/ITK. This will be used to transform
	and images passed along with this. The file should be in '.nii.gz' format. Must be 
	passed with the -r option. **Note that the file stem for the warp must match the filestem
	for the moving image; arbitrary file names cannot currently be used.**
	
-r: A rigid initial alignment file previously generated with ANTs/ITK. This will be used to 
	transform and images passed along with this. The file can be in '.mat' or '.txt' format,
	though it's much more likely you'll have it as a '.mat'. 
	Must be passed with the -w option.
-A: The atlas template that is being bridged to. If '-b' is not set, this does nothing.

	
USAGE
    exit 1
}

# Defaults
thread_number=12
memory_requested=128000
fileExtension="nrrd"
# ANTs_path="/usr/bin/"
outputName=`date=$(date '+%Y-%m-%d'); echo $date`
outputDir=`pwd`/commands
dockerImage="docker-registry.champalimaud.pt/ants"
semanticChannelPrimary="01"
logsFolder="logs"
numChannels=2

while getopts ":hjf:x:a:p:T:M:t:o:n:s:e:d:t:" OPT; do
	case $OPT in
		h)
			Usage >&2
			exit 0
		;;
		f)
			fixed=$OPTARG
		;;
		x)
			mask=$OPTARG
		;;
		a)
			antsCallFile=$OPTARG
		;;
		t)
			numChannels=$OPTARG
		;;
		s)
			semanticChannelPrimary=$OPTARG
		;;
		e)
			fileExtension=$OPTARG
		;;
		p)
			ANTs_path=$OPTARG
		;;
		T)
			thread_number=$OPTARG
		;;
		M)
			memory_requested=$OPTARG
		;;
		o)
			outputDir=`pwd`/$OPTARG
		;;
		n)
			outputName=$OPTARG
		;;
		d)
			dockerImage=$OPTARG
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

mkdir -p ${logsFolder}

stripEndings(){
	# remove path information
	localEnding=`basename $1`
	# check if any compression file extensions are appended
	if [[ $localEnding == *.gz ]] || [[ $localEnding == *.tar ]]; then
		# if so, remove them
		myName=`echo $localEnding | sed -E 's/.gz|.tar//'`
		# recurse to remove any other file extensions
		stripEndings $myName
		return 0
	fi
	myName=`echo $localEnding | sed 's/\.[[:alnum:]]*$//'`
	# bash can't return things, but it can echo them to 
	# be captured at the call site
	echo $myName
}

relative2myArea(){
        localEnding=`basename $1`
        previousEnding=$2
        if [ $localEnding != "my_area" ]; then
                dir=`dirname $1`
                newPath="${localEnding}/${previousEnding}"
                relative2myArea $dir $newPath
                return 0
        fi
        echo "${localEnding}/${previousEnding}"
}


initialdir=`pwd`
# relativeRootDir='my_area'
execDir=`relative2myArea $initialdir`
execDir2="`echo $initialdir | sed 's/^[\/[[:alnum:]]*\/]*\(my_area[\/[[:alnum:]]*]*$\)/\1/'`/"

cpus=$thread_number
requestedMemory=$memory_requested
images=`ls images/*.${fileExtension} | tr "\n" "," | sed -E s/,$//`
refbrain="refbrain/${fixed}"
antscall="commands/${antsCallFile}"
# transferFiles=${images},${refbrain},${antscall}
dockerOutdir="registration"
outfile="${outputDir}/${outputName}.submit"

# write header info
echo "universe = docker" > ${outfile}
echo "docker_image = ${dockerImage}" >> ${outfile}
echo "executable = ${execDir}commands/ants_registration.sh" >> ${outfile}
echo "request_cpus = ${cpus}" >> ${outfile}
echo "request_memory = ${requestedMemory}" >> ${outfile}
echo "Error = ${logsFolder}/\$(Cluster).\$(Process).err" >> ${outfile}
echo "Output = ${logsFolder}/\$(Cluster).\$(Process).out" >> ${outfile}
echo "Log = ${logsFolder}/\$(Cluster).\$(Process).log" >> ${outfile}
echo "initialdir = ${initialdir}" >> ${outfile}
echo "" >> ${outfile}

# loop through _01/primary images
moving_images=`ls images/*_${semanticChannelPrimary}.${fileExtension}`

for image in ${moving_images}; do
	thisImage=`stripEndings $image`
	imageStem=${thisImage%_$semanticChannelPrimary}
	transferImageFiles=`ls images/$imageStem* | tr "\n" "," | sed -E s/,$//`
	transferFiles="${transferImageFiles},${refbrain},${antscall}"
	if [[ ! -z $mask ]]; then transferFiles="${transferFiles},masks/${mask}"; fi
	echo "" >> ${outfile}
	echo "transfer_input_files = ${transferFiles}" >> ${outfile}
	echo "transfer_output_files = ${dockerOutdir}" >> ${outfile}
	args="arguments = -f `basename $refbrain` -m `basename $image` -a `basename $antscall` -T $cpus -t $numChannels"
	if [[ ! -z ${mask} ]]; then  args="${args} -x $mask"; fi
	if [[ ! -z ${ANTs_path} ]]; then args="${args} -p ${ANTs_path}"; fi
	echo $args >> ${outfile}
	echo "" >> ${outfile}
	echo "queue" >> ${outfile}
done
