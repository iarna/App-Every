#!/bin/sh
INSCRIPT=bin/every
OUTSCRIPT=packed/every

[ ! -d packed ] && mkdir packed

fatpack tree $(fatpack packlists-for $(fatpack trace --to=- $INSCRIPT)) && \
fatpack file > fatlib.pl 2>/dev/null && \
perl -pe 's{#\s*__FATPACK__\s*}{qx( cat fatlib.pl )}ge; $_' $INSCRIPT > $OUTSCRIPT &&
chmod a+x $OUTSCRIPT
rm -rf fatlib fatlib.pl
