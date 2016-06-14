#!/bin/bash

TITLE="spark-gotchas"
BASEDIR=$(pwd)
OUTPUTDIR="$BASEDIR/output"
METADATA="metadata.yaml"
BIBLIOGRAPHY="bibliography.bib"
CHAPTERS="$BASEDIR/[0-9]*.md"
LICENSE="$BASEDIR/LICENSE.md"
PANDOC_OPTS="--filter pandoc-citeproc --toc --chapters --base-header-level=1 --number-sections"
TOC_OPTS="--template=$BASEDIR/templates/toc.txt --toc --chapters --base-header-level=1 -t markdown"


function toc {
  for f in $CHAPTERS ; do
    FILENAME=$(basename $f .md)
		pandoc $TOC_OPTS $f -o $OUTPUTDIR/$FILENAME.toc ;
		sed -i "s@#@$f#@g"  $OUTPUTDIR/$FILENAME.toc ;
	done ;
	cat $OUTPUTDIR/*.toc > $BASEDIR/README.md ;
	rm  $OUTPUTDIR/*.toc
}

FORMAT=${1:-pdf}

if [ "$FORMAT" == "toc" ]
then
  echo "Creating TOC."
  toc
else
  echo "Creating spark-gotchas in $FORMAT format."
  pandoc $PANDOC_OPTS $CHAPTERS $LICENSE $METADATA -o $OUTPUTDIR/$TITLE.$FORMAT
fi

echo "DONE!"
