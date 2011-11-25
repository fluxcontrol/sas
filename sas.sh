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
SAS_NULL="${SAS_NULL:-/dev/null}"

SAS_VERBOSE=${SAS_VERBOSE:-0}
SAS_ENDIAN="${SAS_ENDIAN:-0}"
SAS_ARCH=${SAS_ARCH:-x86}
SAS_INCODE="${SAS_INCODE:-}"
SAS_INFILE="${SAS_INFILE:-}"

if [ -z "$SAS_ARCH_DIR" ]
then
	SAS_ARCH_DIR="${0%/*}"
	[ -d "$SAS_ARCH_DIR" ] || SAS_ARCH_DIR="."
	SAS_ARCH_DIR="${SAS_ARCH_DIR}/arch"
fi


# Don't change these unless you are prepared to deal with the consequences
IFS=$(command -p printf "\n\t ")
LC_COLLATE="C"


# used for matching numerical input types (hex is always used internally)
hex="[0-9A-Fa-f]"
dec="[0-9]"
bin="[01]"
imm="*$dec 0x$hex* $hex*h $bin*b"
mref="\[*\]"

# program counter
sas_pc=0

# reserved for any necessary calculations in the ISA.set files that can't be
# handled directly by parameter substitution using core functions
sas_asm=""

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

	-e
		Flip the endianness of the assembled output. This is useful for
		ISAs that can be either big-endian or little-endian, such as
		MIPS.

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
		effect. If OUTPUT_FILE already exists, it will overwrite the
		file (cf. -O below).

	-O OUTPUT_FILE
		Same as -o, but appends to OUTPUT_FILE if it already exists.

	-v
		Verbose output: prints some diagnostic messages on what is
		currently being assembled, and what it assembles to.

EOF
	exit 1
}

array_count() {
	ret=0
	for i in $@
	do
		ret=$((ret+1))
	done
	output "$ret"
}

strip_zero() {
	num="$1"
	while [ "${num%${num#?}}" = '0' ]
	do
		num="${num#0}"
	done
	output "$num"
}

pad() {
	string=1
	[ "$1" = "-b" ] && { string=2; shift; }
	num="0"
	[ "$#" -eq 3 ] && { num="$1"; shift; }
	ret="$2"
	string=$((${1:-0} * string))
	while [ "${#ret}" -lt "${string}" ]
	do
		ret="${num}${ret}"
	done
	output "$ret"
}

convert_dec_hex() {
	ret=$(output_hex $(strip_zero "$1"))
	[ ${#ret} -eq 1 ] && ret="0$ret"
	output "$ret"
}

convert_bin_hex() {
	num=$(strip_zero "$1")
	i=1
	ret=""
	while [ "${#num}" -gt 0 ]
	do
		ret=$(($ret + i*${num#${num%?}}))
		num="${num%?}"
		i=$((i*2))
	done
	output_hex "$ret"
}

tobin() {
	num=$(output "$((0x$1))")
	ret=""
	while [ "$num" -gt 0 ]
	do
		ret="$(($num % 2))$ret"
		num="$(($num / 2))"
	done
	output "$ret"
}

tobytes() {
	num=" $1"
	i="0"
	ret=""
	while [ "$i" -lt "$((${#1}/2))" ]
	do
		ret="${ret}${num%${num##* ??}}"
		num=" ${num##* ??}"
		i="$(($i+1))"
	done
	output "$ret"
}

tohex() {
	case "$1" in
		*${bin}b) num=$(convert_bin_hex "${1%b}") ;;
		 0x*$hex) num="${1#0x}" ;;
		*${hex}h) num=$(strip_zero "${1%h}") ;;
		*${dec}) num=$(convert_dec_hex "$1") ;;
	esac
	[ -z "$2" ] && output "$num" && return 0
	[ "$((${#num} % 2))" -eq 1 ] && num="0$num"
	[ "$((${#num}/2))" -eq "${2:-$((${#num}/2))}" ] || return 1
}

num() {
	tobytes $(tohex "$1")
}

endian() {
	num=" $@"
	ret=""
	while [ -n "$num" ]
	do
		ret="$ret${num##* } "
		num="${num% *}"
	done
	output "${ret% }"
}

hexadd() {
	ret="0"
	while [ "$#" -gt 0 ]
	do
		ret=$(output_hex $((0x$ret + 0x$1)))
		shift
	done
	[ "$((${#ret} % 2))" -eq 1 ] && ret="0$ret"
	output "$ret"
}

hexsub() {
	ret="$1"
	[ -z "$ret" ] && return 1
	shift
	while [ "$#" -gt 0 ]
	do
		ret=$(output_hex $((0x$ret - 0x$1)))
		shift
	done
	[ "$((${#ret} % 2))" -eq 1 ] && ret="0$ret"
	output "$ret"
}

hexmult() {
	ret="$1"
	[ -z "$ret" ] && return 1
	shift
	while [ "$#" -gt 0 ]
	do
		ret=$(output_hex $((0x$ret * 0x$1)))
		shift
	done
	[ "$((${#ret} % 2))" -eq 1 ] && ret="0$ret"
	output "$ret"
}

hexdiv() {
	ret="$1"
	[ -z "$ret" ] && return 1
	shift
	while [ "$#" -gt 0 ]
	do
		ret=$(output_hex $((0x$ret / 0x$1)))
		shift
	done
	[ "$((${#ret} % 2))" -eq 1 ] && ret="0$ret"
	output "$ret"
}

offset() {
	hexsub $(tohex "$1") $(hexadd $sas_pc "$2")
}

get_reg() {
	num=""
	[ "$1" = '-b' ] && { num=1; shift; }
	ret=""
	while [ "$#" -gt 0 ]
	do
		eval ret="\$$1"
		[ -n "$num" ] &&
			[ "$((${#ret} % 2))" -eq 1 ] && ret="0$ret"
		output "$ret"
		shift
	done
}

get_lsb() {
	ret="$1"
	if [ "${#ret}" -gt 2 ]
	then
		[ -n "${ret#${ret%% *}}" ] || ret=$(tobytes "$ret")
	fi
	output "${ret##* }"
}

get_msb() {
	ret="$1"
	if [ "${#ret}" -gt 2 ]
	then
		[ -n "${ret#${ret%% *}}" ] || ret=$(tobytes "$ret")
	fi
	output "${ret%% *}"
}

assemble() {
	num="$@"
	[ "$SAS_ENDIAN" -eq 1 ] && num=$(endian "$num")

	[ "$SAS_VERBOSE" -eq 1 ] &&
		output "assemble: $(pad -b 4 $sas_pc): <$num> "

	for ret in $num
	do
		run printf "\x$ret" >> "$SAS_OUTPUT" ||
			return 1
		sas_pc=$(tohex "$((0x$sas_pc + 0x1))")
	done

	[ "$SAS_VERBOSE" -eq 1 ] && output_nl

	return 0
}

args() {
	[ $(array_count "$arguments") -ne "$1" ] && return 1
	return 0
}

substr() {
	ret="${2%%$1*}"
	num="${2#*$1}"
	[ "$ret$1$num" != "$2" ] && return 1
	return 0
}

replace() {
	[ "$#" -eq 3 ] || return 1
	ret="$1"
	while $(substr "$2" "$ret")
	do
		ret="${ret%%$2*}$3${ret#*$2}"
	done
	output "$ret"
}

check_type() {
	string="$2 "
	while [ -n "$string" ]; do
		ret="${string%% *}"
		case "$1" in $ret) return 0; string="" ;; esac
		string="${string#* }"
	done
	return 1
}

check_size() {
	if [ "$1" = "-b" ]
	then
		shift
		ret=$(address $1 $2)
	else
		ret=$(address $(($1/2)) $2)
	fi
	[ -n "$ret" ] || return 1
}

memref() {
	ret="${1#?}"
	ret="${ret%?}"
	[ "[$ret]" != "$1" ] && return 1
	output "$ret"
}

address() {
	ret=$(pad -b "$1" $(tohex "$2"))
	[ "${#ret}" -eq $(($1*2)) ] || return 1
	tobytes "$ret"
}

decomment() {
	output "${1%%;*}"
}

invalid() {
	output_nl "error: unrecognized instruction: $@"
	exit 1
}

exec_instr() {
	op="$1"
	shift
	string="$@"
	arguments=$(replace "$string" ',' ' ')
	
	if [ -n "$op" ]
	then
		"instr_$op" $arguments 2>"$SAS_NULL" || invalid "$op $arguments"
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
		ret="${arch##*/}"
		output_nl "${ret%.set}"
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
				SAS_INCODE="$1"
				shift 1
				count=$((count+2))
				;;
			-e)
				SAS_ENDIAN="1"
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
				output "" > "$SAS_OUTPUT"
				shift 2
				count=$((count+2))
				;;
			-O)
				SAS_OUTPUT="$2"
				shift 2
				count=$((count+2))
				;;
			-v)
				SAS_VERBOSE="1"
				shift 1
				count=$((count+1))
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
elif [ -n "$SAS_INCODE" ]
then
	assemble_direct "$SAS_INCODE"
elif [ "$#" -gt 0 ]
then
	assemble_direct "$@"
else
	assemble_file
fi

