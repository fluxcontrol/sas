#!/bin/sh

# shell script x86 assembler
#   for now, only basic mnemonics.
#   more will be added later

################################################################################
# each ASM instruction is encoded as a function
# each such instr_calls out to a generic assemble() function
# the assemble() instr_writes the bytes out to $SASS_OUTPUT, which defaults
# to STDOUT, but can be anything (file, process, etc.)
#
# oh yeah, it automatically converts numbers from whatever to hex, and then to
# separated bytes for the assemble() instr_to use
#
# to the extent possible, I am keeping this purely POSIX compliant so that it
# will be as portable as possible
################################################################################


################################################################################
### DATA SECTION
###   configuration values, placeholder variables, etc.
################################################################################
SAS_OUTPUT="${SAS_OUTPUT:-/dev/stdout}"

DEBUG=${DEBUG:-0}
ARCH=${ARCH:-x86}
CODE="${CODE:-}"

ARCH_DIR=$(readlink -e "$0")
ARCH_DIR="${ARCH_DIR%/*}/arch"

IFS=$(command /bin/printf "\n\t ")


################################################################################
### CODE
###   this is the code that actually assembles the instructions
################################################################################
sas_help () {
	cat <<EOF
	usage: ${0##*/} [-adhi] [-f infile] [-o outfile] [STDIN]
EOF
}

array_count() {
	count=0
	for i in $@
	do
		count=$((count+1))
	done
	echo "$count"
}

convert_dec_hex() {
	command /bin/printf "%x" "$1"
}

convert_bin_hex() {
	hex=""
}

convert_num2bytes() {
	echo "$1" | sed 's/\(..\)/\1 /g'
}

num() {
	num="$1"

	case "$num" in
		*d) num=$(echo "$num" | sed 's/b$//' | convert_dec_hex) ;;
		*b) num=$(echo "$num" | sed 's/b$//' | convert_bin_hex) ;;
		0x*) num=$(echo "$num" | sed 's/^0x//') ;;
		*h) num=$(echo "$num" | sed 's/h$//') ;;
	esac

	for byte in $(convert_num2bytes "$num")
	do
		if [ "${#byte}" -eq 2 ]
		then
			printf "%s " "$byte"
		else
			printf "0%s " "$byte"
		fi
	done
}

endian() {
	echo "$@" | tr " " "\n" | tac
}

hexadd() {
	ret="0"

	while [ "$#" -gt 0 ]
	do
		ret=$(command /bin/printf "%x" $((0x$ret + 0x$1)))
		shift
	done

	echo "$ret"
}

hexmult() {
	ret="1"

	while [ "$#" -gt 0 ]
	do
		ret=$(command /bin/printf "%x" $((0x$ret * 0x$1)))
		shift
	done

	echo "$ret"
}

assemble() {
	if [ "$DEBUG" -eq 1 ]
	then
		string="$@"
		command /bin/printf "assemble: <%s> " "$string"
	fi

	for byte in $@
	do
		command /bin/printf "\x$byte" >> "$SAS_OUTPUT" ||
			return 1
	done

	[ "$DEBUG" -eq 1 ] && echo ''

	return 0
}

args() {
	[ $(array_count "$arguments") -ne "$1" ] && return 1
	return 0
}

decomment() {
	echo "$1" | sed 's/;.*//'
}

invalid() {
	echo "error: unrecognized instruction: $@"
	return 1
}

exec_instr() {
	op="$1"
	shift
	arguments=$(echo "$@" | tr ',' ' ')
	
	if [ -n "$op" ]
	then
		"instr_$op" $arguments || invalid "$op $arguments"
	else
		invalid "$op $arguments"
	fi
}

process_cmdline() {
	count=0
	while [ "$#" -gt 0 ]
	do
		case "$1" in
			-a)
				CODE="$2"
				shift 2
				count=$((count+2))
				;;
			-d)
				DEBUG="1"
				shift 1
				count=$((count+1))
				;;
			-f)
				FILE="$2"
				shift 2
				count=$((count+2))
				;;
			-h)
				sas_help
				shift 1
				count=$((count+1))
				;;
			-i)
				ARCH="$2"
				shift 2
				count=$((count+2))
				;;
			-o)
				SAS_OUTPUT="$2"
				shift 2
				count=$((count+2))
				;;
			*)
				shift
				;;
		esac
	done
	return $count
}

load_instr() {
	. "$ARCH_DIR/$ARCH.set"
}

assemble_file() {
	if [ "$#" -eq 1 ]
	then
		while read input
		do
			input=$(decomment "$input")
			[ -n "$input" ] && exec_instr $input
		done < "$1"
	else
		while read input
		do
			input=$(decomment "$input")
			[ -n "$input" ] && exec_instr $input
		done
	fi
}

assemble_direct() {
	input="${CODE:-$@}"
	input=$(decomment "$input")
	[ -n "$input" ] && exec_instr $input
}

process_cmdline "$@"
shift "$?"
load_instr

if [ -f "${FILE:-$1}" ]
then
	assemble_file "${FILE:-$1}"
elif [ -n "$CODE" ] || [ "$#" -gt 0 ]
then
	assemble_direct "$@"
else
	assemble_file
fi

