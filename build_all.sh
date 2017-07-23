#!/bin/bash

function usage {
	echo "Usage: $0 <kernelsourcedir> [-l][-v][-c][-db][-dc][--help]"
	echo "  -c ... clean"
	echo "  -l ... make linux"
	echo "  -v ... make v4l"
	echo "  -db .. DKMS build"
	echo "  -dc .. DKMS clean"
	echo " Note: If -l and -v are not present, both are executed."
	echo "       The order of the options needs to be as written above."
	echo "       If -db or -dc are present, -c, -l and -v are ignored."
	exit 1
}

function disable_opt {
	echo Disabling ${1}
	sed -i \
		-e s/${1}=[y\|m]/#\ ${1}\ is\ not\ set/ \
		v4l/.config
}

function set_opt_y {
	echo Enabling Y ${1}
	sed -i \
		-e s/#\ ${1}\ is\ not\ set/${1}=y/ \
		v4l/.config
}

function set_opt_m {
	echo Enabling M ${1}
	sed -i \
		-e s/#\ ${1}\ is\ not\ set/${1}=m/ \
		v4l/.config
}

function set_opt_value {
	echo Setting ${1} to ${2}
	sed -i \
		-e s/${1}=.*/${1}=${2}/ \
		v4l/.config
}

function make_linux {
	cd linux

	if [ "${do_clean}" = "y" ] ; then
		make ${linux_clean}
		# mm remains, should be reportded to media_build maintainers
		rm -rf mm
	else
		if [ "${do_dkms}" != "y" ] ; then
			make tar DIR=../${1}
		fi
		make untar
	fi

	cd ..
}

function import_options {
	# we need the list sorted according to the number prefix
	inc_files=$(find . -name "*.inc"  | sort -u)
	if [ -n "${inc_files}" ] ; then
		for incfile in ${inc_files} ; do
			# we allow only the functions we define in this script
			rm -f ${incfile}.tmp
			sed -n -e '/^disable_opt/p' -e '/^set_opt_y/p' -e '/^set_opt_m/p' \
			       -e '/^set_opt_value/p' ${incfile} > ${incfile}.tmp
			source ${incfile}.tmp
			rm ${incfile}.tmp
		done
	fi
}

function make_v4l {
	if [ "${do_clean}" = "y" ] ; then
		make ${v4l_clean}
	else
		make stagingconfig

		import_options

		make -j${job_num}
	fi
}

if [ $# -lt 1 ] ; then
	usage
fi

if [ "${1}" = "-c" ] ; then
	usage
fi

if [ "${1}" = "--help" ] ; then
	usage
fi

# determine num of available cores for make job control
nProc=$(getconf _NPROCESSORS_ONLN)
job_num=$(( nProc + 1 ))

kernelsourcedir=${1}
shift

linux_clean="distclean"
v4l_clean="distclean"
do_dkms="d"
do_linux="d"
do_v4l="d"

if [ "${1}" = "-l" ] ; then
	do_linux="y"
	do_v4l="n"
	shift
fi

if [ "${1}" = "-v" ] ; then
	do_v4l="y"
	if [ "${do_linux}" = "d" ] ; then
		do_linux="n"
	fi
	shift
fi

if [ "${1}" = "-c" ] ; then
	do_clean="y"
	do_linux="d"
	do_v4l="d"
	shift
fi

if [ "${1}" = "-db" ] ; then
	do_clean="n"
	do_linux="d"
	do_v4l="d"
	do_dkms="y"
	shift
fi

if [ "${1}" = "-dc" ] ; then
	do_clean="y"
	do_linux="d"
	do_v4l="d"
	# keep the linux tree tar.bz2 file
	linux_clean="clean"
	do_dkms="y"
	shift
fi

# needs to be last
if [ "${1}" = "--help" ] ; then
	usage
fi

if [ $# -gt 0 ] ; then
	usage
fi

echo Running full media_build for kernel sources at ${1}

if [ -n "${VER}" -a "${do_clean}" != "y" ] ; then
	# generate first ./v4l/.version, which is used by all other scripts
	make VER=${VER} release
fi

if [ "${do_linux}" = "y" -o "${do_linux}" = "d" ] ; then
	make_linux ${kernelsourcedir}
fi

if [ "${do_v4l}" = "y" -o "${do_v4l}" = "d" ] ; then
	make_v4l
fi
