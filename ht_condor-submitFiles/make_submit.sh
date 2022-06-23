#!/bin/bash

if [[ $1 == "" ]]; then
	semanticChannelPrimary="01"
else
	semanticChannelPrimary=$1
fi

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

initialdir=`pwd`
cpus=11
requestedMemory=36000
images=`ls images/*.nrrd | tr "\n" "," | sed -E s/,$//`
refbrain="refbrain/giant.nrrd"
antscall="commands/test.antsCall"
# transferFiles=${images},${refbrain},${antscall}
outdir="registration"

# write header info
echo "universe = docker" > test.submit
echo "docker_image = docker-registry.champalimaud.pt/ants" >> test.submit
echo "executable = ${initialdir}commands/ants_registration.sh" >> test.submit
echo "request_cpus = ${cpus}" >> test.submit
echo "request_memory = ${requestedMemory}" >> test.submit
echo "Error = output/logs/\$(Cluster).\$(Process).err" >> test.submit
echo "Output = output/logs/\$(Cluster).\$(Process).out" >> test.submit
echo "Log = output/logs/\$(Cluster).\$(Process).log" >> test.submit
echo "initialdir = ${initialdir}" >> test.submit
echo ""

# loop through _01/primary images
moving_images=`ls images/*_${semanticChannelPrimary}.nrrd`

for image in $moving_images; do
	thisImage=`stripEndings $image`
	imageStem=${thisImage%_$semanticChannelPrimary}
	transferImageFiles=`ls images/$imageStem* | tr "\n" "," | sed -E s/,$//`
	transferFiles=${transferImageFiles},${refbrain},${antscall}
	echo "" >> test.submit
	echo "transfer_input_files = ${transferFiles}" >> test.submit
	echo "transfer_output_files = ${outdir}" >> test.submit
	args="arguments = -f `basename $refbrain` -m `basename $image` -a `basename $antscall`"
	echo $args >> test.submit
	echo "" >> test.submit
	echo "queue" >> test.submit
done
