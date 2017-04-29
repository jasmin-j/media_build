#!/bin/bash

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

if [ $# -lt 1 ] ; then
	echo "Usage: $0 <kernelsourcedir>"
	exit 1
fi

echo Running full media_build for kernel sources at ${1}

if [ -n ${VER} ] ; then
	# generate first ./v4l/.version, which is used by all other scripts
	make VER=${VER} release
fi

cd linux
make tar DIR=../${1}
make untar
cd ..

make stagingconfig

disable_opt CONFIG_DVB_DEMUX_SECTION_LOSS_LOG
disable_opt CONFIG_DVB_DDBRIDGE_MSIENABLE
disable_opt CONFIG_VIDEOBUF2_MEMOPS
disable_opt CONFIG_FRAME_VECTOR
disable_opt CONFIG_DVB_AF9033
disable_opt CONFIG_VIDEO_ET8EK8
set_opt_value CONFIG_DVB_MAX_ADAPTERS 32

make -j3
