#!/bin/sh
INSCRIPT=bin/every
OUTSCRIPT=packed/every

[ ! -d packed ] && mkdir packed

DEPENDENCIES="App/Every.pm Digest/MD5.pm Digest/base.pm Digest/Perl/MD5.pm"

fatpack tree $(fatpack packlists-for $DEPENDENCIES) && \
fatpack file > fatlib.pl 2>/dev/null && \
perl -pe 's{#\s*__FATPACK__\s*}{qx( cat fatlib.pl )}ge; $_' $INSCRIPT > $OUTSCRIPT &&
chmod a+x $OUTSCRIPT
rm -rf fatlib fatlib.pl
