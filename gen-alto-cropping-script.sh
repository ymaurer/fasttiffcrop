#!/bin/bash

if [ "$#" -lt 1 ]; then
	echo "usage: gen-alto-cropping-script.sh directory [blocktype]"
	echo "  directory is a directory which contains tif and alto files"
	echo "    the assumption is that the directory layout is the"
	echo "    same as in data.bnl.lu's METS opendata"
	echo "    that means that TIF files are in an 'images' subfolder"
	echo "    and ALTO files are in a 'text' subfolder"
	echo "    the filenames for tif and alto are the same, except the extension"
	echo "  blocktype is the type of block that should be extracted"
	echo "    for ALTO, valid types are:"
	echo "      - <TextBlock"
	echo "      - <ComposedBlock"
	echo "      - <String"
	echo "      - <Textline"
	echo "      - <Illustration"
	echo "    they can be combined with a pipe"
	echo "    default is <TextBlock|<Illustration"
	exit
fi

DIR=$1
IMGFILES=`find $DIR -type f -name '*.tif'`
ALTOFILES=`echo $IMGFILES | sed 's/\/images\//\/text\//g' | sed 's/\.tif/.xml/g'`
EXTRACT="<TextBlock|<Illustration"

if [ "$#" -eq 2 ]; then
	EXTRACT=$2
fi

function generate_fasttiffcrop
{
	IMG=$1
	ALTO=$2

	B=`egrep "$EXTRACT" $ALTO`
	REG_HPOS=".*HPOS=\"([0-9]*)"
	REG_VPOS=".*VPOS=\"([0-9]*)"
	REG_WIDTH=".*WIDTH=\"([0-9]*)"
	REG_HEIGHT=".*HEIGHT=\"([0-9]*)"

	COUNTER=1
	EXT="."${ALTO##*.}
	BASE=`basename $ALTO $EXT`

	echo "source: $IMG"
	while IFS= read -r line
	do
		if [[ $line =~ $REG_HPOS ]]; then	X=${BASH_REMATCH[1]}; fi
		if [[ $line =~ $REG_VPOS ]]; then	Y=${BASH_REMATCH[1]}; fi
		if [[ $line =~ $REG_WIDTH ]]; then	W=${BASH_REMATCH[1]}; fi
		if [[ $line =~ $REG_HEIGHT ]]; then	H=${BASH_REMATCH[1]}; fi
		X=$((X*300/254))
		Y=$((Y*300/254))
		W=$((W*300/254))
		H=$((H*300/254))
		echo "crop ${W}x$H+$X+$Y $BASE-$COUNTER.jpg"
		COUNTER=$((COUNTER + 1))
	done < <(printf '%s\n' "$B")

	echo "docrop"
}

I=($IMGFILES)
A=($ALTOFILES)

for (( i=0; i < ${#I[@]}; i++))
do
	IMG="/mnt/c/Dev/databnl/${I[$i]}"
	ALTO="${A[$i]}"
	generate_fasttiffcrop $IMG $ALTO
done

