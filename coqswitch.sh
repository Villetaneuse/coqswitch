##  Copyright (C) Pierre Rousselin
#  
#  This file is free software; you can redistribute it and/or
#  modify it under the terms of the GNU Lesser General Public
#  License as published by the Free Software Foundation; either
#  version 3 of the License, or (at your option) any later version.
#  
#  This library is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
#  COPYING file for more details.

# This file is meant to be sourced in one of the shell's configuration file

__COQBIN_SUFFIX="_build/install/default/bin/"
__COQLIB_SUFFIX="_build/install/default/lib/"

__coqswitch_usage()
{
	cat <<EOF
Usage: coqswitch [--show]
   or: coqswitch OPAM_SWITCH_NAME
   or: coqswitch --dev
   or: coqswitch --help
Display or set Coq's development environment

coqswitch [--show]
	display various informations about Coq's development environment, such
	as the current opam switch, the values of COQBIN, OCAMLPATH, the current
	version of Coq, ...
coqswitch --dev
	Set and export COQBIN to a value corresponding to Coq's local repository
	COQREP, switch to the opam switch OPAMCOQDEV used for Coq development,
	and add COQBIN to the PATH and the corresponding directory to the
	OCAMLPATH.
	The variables COQREP and OPAMCOQDEV need to be set to, respectively,
	the path of the local Coq repository and the name of the opam switch
	used for Coq development.
coqswitch OPAM_SWITCH_NAME
	Switch to the opam switch OPAM_SWITCH_NAME if it exists or to an 
	existing switch whose name contains OPAM_SWITCH_NAME.
	If COQREP is set and non-null, also removes COQBIN from the PATH,
	empties COQBIN, and removes the reference to COQREP in OCAMLPATH.
EOF
}

__coqswitch_show()
{
	printf 'opam switch is: %s\n' "$(opam switch show)"
	printf 'ocaml version is: %s\n' "$(ocamlc --version)"
	printf 'COQBIN is: %s\n' "$COQBIN"
	printf 'OCAMLPATH is: %s\n' "$OCAMLPATH"
	__coqpath=$(type -p coqc)
	case $? in
	0)
		printf 'coqc is: %s\n' "$__coqpath"
		coqc --version
		;;
	*)
		printf '%s: coqc: command not found\n' "$0"
	esac
	return 0
}

# NOTE: The PATH is itself quite a strange beast.
# See: https://pubs.opengroup.org/onlinepubs/9699919799/
# We interpret it in the following way:
# PATH := emptyPath | nonEmptyPath
# nonEmptyPath := nonEmptyElement | : | element:nonEmptyPath
# where an element is a string without ':' or '\0' characters
# 
# These are all acceptable PATHs:
# - the empty PATH, which completely disables external commands search
# - "/usr/bin:/bin"
# - "/usr/bin:/bin:" has an empty element in the end, which will trigger
#   searching for external commands in the current working directory (same as
#   "/usr/bin:/bin:."
# - ":/usr/bin/:/bin" same with the current working directory first
# - ":/usr/bin/:::bin:" same with the current working directory appearing
#   four times
# - ":" here there is room for interpretation, but it's probably simpler to
#   think of it as a PATH containing only one element: the current working
#   directory

# Add the first argument to the front of a  column-separated list (its second
# argument)
# The result is stored in the variable __add
# precondition: $1 does not include any ':' or '\0' character
__coqswitch_add()
{
	if [ -z "$2" ] && [ -n "$1" ]; then
		__add="$1"
	elif [ -z "$2" ] && [ -z "$2" ]; then
		__add=":"
	else
		__add="$1:$2"
	fi
	return 0
}

# Add the first argument at the end of a column-separated list (its second
# argument)
# The result is stored in the variable __add
# precondition: $1 does not include any ':' or '\0' character
__coqswitch_add_last()
{
	if [ -z "$2" ] && [ -n "$1" ]; then
		__add_last="$1"
	elif [ -z "$2" ] && [ -z "$2" ]; then
		__add_last=":"
	else
		__add_last="$2:$1"
	fi
	return 0
}

# Give the head and the tail of a non-empty column-separated list (its only
# argument). The head is stored in the __head variable and the tail is stored
# in the __tail variable.
__coqswitch_head_tail()
{
	if [ -z "$1" ]; then
		printf '%s\n' 2>&1 "__coqswitch_head_tail: error, empty list"
		return 1
	elif [ "$1" = ":" ]; then
		__head=""
		__tail=""
	else
		__head=${1%%:*}
		if [ "$__head" = "$1" ]; then
			__tail=""
		else
			__tail=${1#$__head:}
			if [ "$__tail" = "" ]; then
				# We are in the case "/bin:" for instance
				__tail=:
			fi
		fi
	fi
	return 0
}

# Concatenate two lists.
# The result is stored in the __concat variable
__coqswitch_concat()
{
	if [ -z "$1" ]; then
		__concat=$2
	elif [ -z "$2" ]; then
		__concat=$1
	else
		__concat=$1:$2
	fi
}

# A directory name (normally the elements of the lists we manipulate) has
# infinitely many string representations: there can be repetitions of '/' and
# trailing '/' characters or not

# Return 0 if both arguments refer (syntactically) to the same directory, 1
# otherwise
__coqswitch_equal_dir()
{
	__dir1=$(printf '%s\n' "$1" | sed -E -e 's!/+!/!g' -e 's!/$!!g')
	__dir2=$(printf '%s\n' "$2" | sed -E -e 's!/+!/!g' -e 's!/$!!g')
	[ "$__dir1" = "$__dir2" ]
}

# Search an element (its first argument) in a list (its second argument)
# Return 0 if the element is found, 1 otherwise
__coqswitch_is_in()
{
	if [ -z "$2" ]; then
		return 1
	else
		__coqswitch_head_tail "$2"
		__coqswitch_equal_dir "$__head" "$1" || __coqswitch_is_in "$1" "$__tail"
	fi
}

# Remove the first occurrence of its first argument in a list (its second
# argument)
# The result is stored in the __remove variable
__coqswitch_remove()
{
	__remove=""
	__rest=$2
	while [ -n "$__rest" ]; do
		__coqswitch_head_tail "$__rest"
		if __coqswitch_equal_dir "$__head" "$1"; then
			__coqswitch_concat "$__remove" "$__tail"
			__remove=$__concat
			return 0
		else
			__coqswitch_add_last "$__head" "$__remove"
			__remove=$__add_last
			__rest=$__tail
		fi
	done
	return 1
}

# Remove all the occurrences of its first argument in a list (its second
# argument)
# The result is stored in the __remove_all variable
__coqswitch_remove_all()
{
	__remove_all=""
	__rest=$2
	__status=1
	while [ -n "$__rest" ]; do
		__coqswitch_head_tail "$__rest"
		if __coqswitch_equal_dir "$__head" "$1"; then
			__status=0
		else
			__coqswitch_add_last "$__head" "$__remove_all"
			__remove_all=$__add_last
		fi
			__rest=$__tail
	done
	return $__status
}

# Return 0 if the first argument appears in the rest of the arguments,
# otherwise, return 1
__coqswitch_search_exact_switch()
{
	__elt=$1
	shift
	for __arg; do
		case $__arg in
		"$__elt")
			return 0
		esac
	done
	return 1
}

# Search its first argument in the rest of the arguments. The first of the other
# arguments to *contain* the first is stored in the __switch variable.
# Return 0 if one of $2, $3, ... contains $1 as a substring, 1 otherwise.
__coqswitch_search_partial_switch()
{
	__elt=$1
	shift
	for __arg; do
		case $__arg in
		*"$__elt"*)
			__switch=$__arg
			return 0
		esac
	done
	return 1
}

__coqswitch_dev()
{
	if [ -z "$COQREP" ] || ! [ -d "$COQREP" ]; then
		cat 2>&1 <<EOF
coqswitch: The COQREP variable needs to be set to the path of your local Coq
repository in order to use coqswitch --dev.
EOF
		return 1
	fi

	if [ -z "$OPAMCOQDEV" ]; then
		cat 2>&1 <<EOF
coqswitch: The OPAMCOQDEV variable needs to be set to the name of the switch
used for your Coq development in order to use coqswitch --dev.
EOF
		return 1
	fi

	case $0 in
	zsh)
		# zsh disables field splitting by default
		__coqswitch_search_exact_switch "$OPAMCOQDEV" $(=opam switch list -s)
		;;
	*)
		__coqswitch_search_exact_switch "$OPAMCOQDEV" $(opam switch list -s)
	esac

	if [ $? -ne 0 ]; then
		cat 2>&1 <<EOF
coqswitch: The OPAMCOQDEV variable needs to be set to the name of the switch
used for your Coq development in order to use coqswitch --dev.
EOF
		return 1
	fi

	opam switch "$OPAMCOQDEV" >/dev/null
	eval $(opam env)

	export COQBIN=$COQREP/$__COQBIN_SUFFIX
	__coqswitch_remove_all "$COQBIN" "$PATH"
	__coqswitch_add "$COQBIN" "$__remove_all"
	PATH=$__add

	__COQLIB=$COQREP/$__COQLIB_SUFFIX
	__coqswitch_remove_all "$__COQLIB" "$OCAMLPATH"
	__coqswitch_add "$__COQLIB" "$__remove_all"
	export OCAMLPATH=$__add

	__coqswitch_show
	return 0
}

__coqswitch_switch()
{
	__sw=
	case $0 in
	zsh)
		# zsh disables field splitting by default
		if __coqswitch_search_exact_switch "$1" $(=opam switch list -s); then
			__sw=$1
		elif __coqswitch_search_partial_switch "$1" $(=opam switch list -s); then
			__sw=$__switch
		fi
		;;
	*)
		if __coqswitch_search_exact_switch "$1" $(opam switch list -s); then
			__sw=$1
		elif __coqswitch_search_partial_switch "$1" $(opam switch list -s); then
			__sw=$__switch
		fi
	esac

	if [ -z "$__sw" ]; then
		cat <<EOF
coqswitch: $1 does not correspond to any of the installed opam switch.
EOF
		return 1
	fi

	if [ -n "$COQREP" ]; then
		__coqswitch_remove_all "$COQREP/$__COQBIN_SUFFIX" "$PATH"
		PATH=$__remove_all
		COQBIN=
		__coqswitch_remove_all "$COQREP/$__COQLIB_SUFFIX" "$OCAMLPATH"
		export OCAMLPATH=$__remove_all
	fi
	opam switch "$__sw" 1>/dev/null
	eval $(opam env)
	__coqswitch_show
	return 0
}

coqswitch()
{
	case $# in
	0)
		__coqswitch_show
		return 0
	esac
	
	case $# in
	1)
		:
		;;
	*)	
		__coqswitch_usage
		return 2
	esac

	case $1 in
	--help)
		__coqswitch_usage
		;;
	--show)
		__coqswitch_show
		;;
	--dev)
		__coqswitch_dev
		;;
	*)
		__coqswitch_switch "$1"
	esac
}
