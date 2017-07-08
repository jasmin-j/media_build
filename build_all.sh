#!/bin/bash

function usage {
	echo "Usage: $0 <kernelsourcedir> [-c][-l][-v][--help]"
	echo "  -c .. clean"
	echo "  -l .. make linux"
	echo "  -v .. make v4l"
	echo " Note: If -l and -v are not present, both are executed."
	exit 1
}

function disable_opt {
	echo Disabling ${1}
	sed -i \
		-e s/${1}=[y\|m]/#\ ${1}\ is\ not\ set/ \
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
		make distclean
		# mm remains, should be reportded to media_build maintainers
		rm -rf mm
	else
		make tar DIR=../${1}
		make untar
	fi

	cd ..
}

function make_v4l {
	if [ "${do_clean}" = "y" ] ; then
		make distclean
	else
		make stagingconfig

		disable_opt CONFIG_DVB_DEMUX_SECTION_LOSS_LOG
		disable_opt CONFIG_DVB_DDBRIDGE_MSIENABLE
		disable_opt CONFIG_VIDEOBUF2_MEMOPS
		disable_opt CONFIG_FRAME_VECTOR
		disable_opt CONFIG_DVB_AF9033
		disable_opt CONFIG_VIDEO_ET8EK8
		set_opt_value CONFIG_DVB_MAX_ADAPTERS 32

		make -j3
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

kernelsourcedir=${1}
shift

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
