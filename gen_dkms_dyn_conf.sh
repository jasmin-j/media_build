#!/bin/bash

# base for the final installation in "/lib/modules/..." (might be changed
# for different distributions)
# Note: DKMS handles most if the distribution specific part already!
mod_dest_loc_base="/kernel"

# base where media build does install all the modules (defined by media
# build scripts; do not change!)
mod_build_loc_base='/kernel'

# Valid dummy to be used for the build location (not used by DKMS)
mod_dir='./v4l'

mod_pattern='*.ko'


err_ok=0
err_usage=1
err_dir_not_found=2
err_default=10

# Index 0 is the dvb-core.ko module defined in the top DKMS
# configuration file. We override this default by the dynamically
# generated DKMS configuration.
mod_idx=0

module_copy_script_name="mod_copy.sh"
module_copy_script="${module_copy_script_name}"

mod_build_loc=""

function exit_print {
    if [ -z "${2}" ] ; then
        code=${err_default}
    else
        code=${2}
    fi

    echo "${1}"
    exit ${code}
}

function err_exit {
    exit_print "Error: ${1}" ${2}
}

function usage {
	echo "Usage: $0 <module_dir> <media_inst_dir> <dkms_dyn_conf> [--help]"
    echo " <module_dir>: directory where the modules are stored by"
    echo "               DKMS after the build step."
    echo " <media_inst_dir>: directory where the media build has installed all"
    echo "                   the modules with their right location"
    echo " <dkms_dyn_conf>: filename of the dynamic part of the DKMS config"
    echo "                  file generated by this script."
    echo " Options:"
    echo "   --help: This text"
	exit_print "" ${err_usage}
}

# Note: This function gets executed in a sub-shell (pipe in find_modules),
#       so it is not possible to use mod_idx later!
function found_module {
    mod_name=$(basename -s .ko ${1})
    mod_build_dir=$(dirname ${1})
    if [[ ${mod_build_dir} =~ (.*)${mod_build_loc_base}(.*) ]] ; then
        mod_dest_location="${mod_dest_loc_base}${BASH_REMATCH[2]}"
        echo "BUILT_MODULE_NAME[${mod_idx}]=${mod_name}"             >> ${dkms_dyn_conf}
        echo "BUILT_MODULE_LOCATION[${mod_idx}]=${mod_dir}"          >> ${dkms_dyn_conf}
        echo "DEST_MODULE_LOCATION[${mod_idx}]=${mod_dest_location}" >> ${dkms_dyn_conf}

        echo "cp -af ${mod_build_dir}/${mod_name}.ko ${module_dir}/${mod_name}.ko" >> ${module_copy_script}

        mod_idx=$((mod_idx + 1))
    fi
}

function find_modules {
    find ${mod_build_loc} -name ${mod_pattern} | while read file; do found_module "$file"; done
}

function arg_check_help {
    if [ "${1}" = "--help" ] ; then
        usage
    fi
}

# main

if [ $# -lt 3 ] ; then
    usage
fi

arg_check_help "${1}"

module_dir="${1}"
shift

arg_check_help "${1}"

media_inst_dir="${1}"
shift

arg_check_help "${1}"

dkms_dyn_conf="${1}"
shift

# First check, if the target module directory to store also the dynamically
# generated files, does already exist
if [ ! -d ${module_dir} ] ; then
	err_exit "Target module directory ${module_dir} doesn't exist!" ${err_dir_not_found}
fi

# Check if the media build has been installed the new modules
if [ ! -d ${media_inst_dir} -a -f "${media_inst_dir}/DKMS_INST" ] ; then
	err_exit "Installed media build modules not found in ${media_inst_dir}!" ${err_dir_not_found}
fi

# Now check, if the directory of the generated file
# does already exist
dkms_dyn_conf_dir=$(dirname ${dkms_dyn_conf})
if [ ! -d ${dkms_dyn_conf_dir=} ] ; then
	err_exit "Target directory for dynamic DKMS config doesn't exist!" ${err_dir_not_found}
fi

module_copy_script="${dkms_dyn_conf_dir}/${module_copy_script_name}"
mod_build_loc="${media_inst_dir}"

# we generate it always new
rm -f ${dkms_dyn_conf}
echo "#"                                > ${dkms_dyn_conf}
echo "# Generated by $(basename ${0})" >> ${dkms_dyn_conf}
echo "# at $(date -R)"                 >> ${dkms_dyn_conf}
echo "#"                               >> ${dkms_dyn_conf}

rm -f ${module_copy_script}
echo "#!/bin/bash"                      > ${module_copy_script}
echo "#"                               >> ${module_copy_script}
echo "# Generated by $(basename ${0})" >> ${module_copy_script}
echo "# at $(date -R)"                 >> ${module_copy_script}
echo "#"                               >> ${module_copy_script}

find_modules

# copy the generated modules
source ${module_copy_script}

exit_print "Done!" ${err_ok}

