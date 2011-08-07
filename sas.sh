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
	run cat <<EOF

usage: ${0##*/} [-afhiov] <ASM> | <FILE> | <STDIN>

${0##*/} is a pure POSIX shell assembler. It accepts assembly input in one of
three forms: from a file specified via the -f flag or as the last argument on
the command-line, a single direct instruction plus any operands specified via
the -a flag or as the last arguments on the command-line, or via STDIN. If
STDIN is used, it will read STDIN until an EOF is reached. You can use this to
type an entire source file directly into STDIN using the shell's \$P1.

OPTIONS:
	-a ASSEMBLY_INSTRUCTION
		Assemble the instruction passed, plus any operands, passed in.
		For longer lists of instructions to assemble at a time, use of
		either a source file or STDIN is required. This option
		overrides later options (including the bare <ASM>, <FILE>, or
		<STDIN> inputs).

	-f INPUT_FILE
		Assemble the instructions found in file INPUT_FILE. This option
		overrides later options (including the bare <ASM>, <FILE>, or
		<STDIN> inputs).

	-h
		Prints this help message.

	-i INSTRUCTION_SET
		Selects the instruction set used to assemble the instructions.
		To get a list of the instruction sets that are available, use
		"help" as the INSTRUCTION_SET:
			-i help
	-o OUTPUT_FILE
		Write the assembled opcodes to file OUTPUT_FILE. By default,
		output is written to STDOUT. You could also leave this option
		unspecified and redirect STDOUT to a file to achieve the same
		effect.

	-v
		Verbose output: prints some diagnostic messages on what is
		currently being assembled, and what it assembles to.

EOF
	exit 1
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

get_reg() {
	eval echo \$$1
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

search_instr() {
	for arch in "$SAS_ARCH_DIR"/*.set
	do
		run printf "${arch%.set}\n"
	done
	exit 1
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
				if [ "$2" = "help" ]
				then
					search_instr
				else
					ARCH="$2"
				fi
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

