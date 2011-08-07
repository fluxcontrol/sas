#!/bin/sh
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

SAS_VERBOSE=${SAS_VERBOSE:-0}
SAS_ARCH=${SAS_ARCH:-x86}
SAS_INCODE="${SAS_INCODE:-}"
SAS_INFILE="${SAS_INFILE:-}"

SAS_ARCH_DIR="${SAS_ARCH_DIR:-$(command -p readlink -e $0 | sed s#$0\$#arch#)}"


# Don't change this unless you are prepared to deal with the consequences
IFS=$(command -p printf "\n\t ")


################################################################################
### CODE
###   this is the code that actually assembles the instructions
################################################################################
run() {
	command -p "$@"
}

output() {
	run printf "%s" "$1"
}

output_nl() {
	run printf "%s\n" "$1"
}

output_hex() {
	run printf "%x" "$1"
}

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
	output "$count"
}

convert_dec_hex() {
	ret=$(output_hex "$1")
	[ ${#ret} -eq 1 ] && ret="0$ret"
	output "$ret"
}

convert_bin_hex() {
	ret=""
}

# this is ugly, but avoids a call to sed '/\(..\)/\1 /g'
# makes the program faster by about 0.04s (real),
# which is roughly a 10% increase in speed
convert_num2bytes() {
	string=" $1"
	count="$((${#1}/2))"
	i="0"
	ret=""

	while [ "$i" -lt "$count" ]
	do
		ret="${ret}${string%${string##* ??}}"
		string=" ${string##* ??}"
		i="$(($i+1))"
	done

	output "$ret"
}

num() {
	num="$1"

	case "$num" in
		*d) num=$(output "${num%d}" | convert_dec_hex) ;;
		*b) num=$(output "${num%b}" | convert_bin_hex) ;;
		0x*) num=$(output "${num#0x}") ;;
		*h) num=$(output "${num%h}") ;;
	esac

	for byte in $(convert_num2bytes "$num")
	do
		[ "${#byte}" -eq 1 ] && byte="0$byte"
		output "$byte "
	done
}

endian() {
	string="$@"
	output_nl "$string" | run tr " " "\n" | run tac
}

hexadd() {
	ret="0"

	while [ "$#" -gt 0 ]
	do
		ret=$(output_hex $((0x$ret + 0x$1)))
		shift
	done

	[ "${#ret}" -eq 1 ] && ret="0$ret"
	output "$ret"
}

hexmult() {
	ret="1"

	while [ "$#" -gt 0 ]
	do
		ret=$(output_hex $((0x$ret * 0x$1)))
		shift
	done

	[ "${#ret}" -eq 1 ] && ret="0$ret"
	output "$ret"
}

get_reg() {
	while [ "$#" -gt 0 ]
	do
		eval string="\$$1"
		[ "${#string}" -eq 1 ] && string="0$string"
		output "$string "
		shift
	done
}

assemble() {
	if [ "$SAS_VERBOSE" -eq 1 ]
	then
		string="$@"
		output "assemble: <$string> "
	fi

	for byte in $@
	do
		run printf "\x$byte" >> "$SAS_OUTPUT" ||
			return 1
	done

	[ "$SAS_VERBOSE" -eq 1 ] && output_nl

	return 0
}

args() {
	[ $(array_count "$arguments") -ne "$1" ] && return 1
	return 0
}

decomment() {
	output "${1%%;*}"
}

invalid() {
	output_nl "error: unrecognized instruction: $@"
	return 1
}

exec_instr() {
	op="$1"
	shift
	string="$@"
	arguments=$(output "$string" | tr ',' ' ')
	
	if [ -n "$op" ]
	then
		"instr_$op" $arguments || invalid "$op $arguments"
	else
		invalid "$op $arguments"
	fi
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
	input="${SAS_INCODE:-$@}"
	input=$(decomment "$input")
	[ -n "$input" ] && exec_instr $input
}

load_instr() {
	. "$SAS_ARCH_DIR/$SAS_ARCH.set"
}

search_instr() {
	for arch in "$SAS_ARCH_DIR"/*.set
	do
		output_nl "${arch%.set}"
	done
	exit 1
}

process_cmdline() {
	count=0
	while [ "$#" -gt 0 ]
	do
		case "$1" in
			-a)
				shift 1
				SAS_INCODE="$@"
				shift 1
				count=$((count+2))
				;;
			-d)
				SAS_VERBOSE="1"
				shift 1
				count=$((count+1))
				;;
			-f)
				SAS_INFILE="$2"
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
					SAS_ARCH="$2"
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

process_cmdline "$@"
shift "$?"
load_instr

if [ -f "${SAS_INFILE:-$1}" ]
then
	assemble_file "${SAS_INFILE:-$1}"
elif [ -n "$SAS_INCODE" ] || [ "$#" -gt 0 ]
then
	assemble_direct "$@"
else
	assemble_file
fi

