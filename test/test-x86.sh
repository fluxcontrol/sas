#!/bin/sh

self="${0%/*}"
self="${self:-.}"
sas="${self}/../sas.sh"
source="${self}/x86.asm"
target="${self}/.test"
base="${self}/x86.bin"

printf "Building $source to $target\n"
/bin/sh "$sas" -f "$source" > "$target"

printf "Checking for errors by comparing $target to $base\n"
if diff "$base" "$target"
then
	printf "\tno errors\n"
	rm "$target"
else
	printf "\tERROR FOUND!\n"
fi
