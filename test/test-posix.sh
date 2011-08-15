#!/bin/sh

sources="sas.sh arch/x86.set"

self="${0%/*}"
self="${self:-.}"
check="${self}/checkbashisms.pl"

for i in $sources
do
	printf "Running $check -p -x $self/../$i ...\n"
	$check -p -x "$self/../$i"
done
