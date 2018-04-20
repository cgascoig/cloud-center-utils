#!/bin/bash

source /usr/local/osmosix/etc/userenv

FILENAME="$1"
shift

echo "Replacing tokens in $FILENAME"

for VARNAME in "$@"
do
	echo "  replacing %$VARNAME% with '${!VARNAME}'"
	sed -e "s/%$VARNAME%/${!VARNAME}/g" --in-place=.bak $FILENAME
done

