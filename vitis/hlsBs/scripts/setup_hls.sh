## ----------------------------------------------------------------------------
## This file is part of the 'SLAC Firmware Standard Library'. It is subject to
## the license terms in the LICENSE.txt file found in the top-level directory
## of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of the 'SLAC Firmware Standard Library', including this file, may be
## copied, modified, propagated, or distributed except according to the terms
## contained in the LICENSE.txt file.
## ----------------------------------------------------------------------------

function setup {
    ### --------------------------------
    ### Get the full path of this script
    ### --------------------------------
    called=${BASH_SOURCE[0]}

    ### ------------------------------
    ### Make sure the file was sourced
    ### ------------------------------
    if [ $called != $0 ]; then

        local script_fn

        ### ---------------------------------------
        ### Correctly called by sourcing the script
        ### Get the absolute path to the script
        ### ---------------------------------------
        if [ `uname` == Linux ];
        then
            script_fn=`readlink -fn $called`
        else
            script_fn=`perl -e "use Cwd 'abs_path'; print abs_path('$called')"`;
        fi

    else

        ### ---------------------------------------------------
        ### Incorrectly called by directly executing the script
        ### ---------------------------------------------------
        echo "Error: This file must be sourced"
        return -1

    fi

    local script_dir=`dirname $script_fn`
    export HLSBS_ROOT=`dirname $script_dir`
}

setup
unset setup

# ------------------------------------------------------------------------------
function hlsCheck ()
{
    if [[ -z "${HLSBS_XILINX_VERSION}" ]] ; then
        echo -e \
          "\nERROR: HLS project has not been setup\n"\
             "      Try\n"\
             "          $ hlsVersion <vitis_version>\n"\
             "      ..or..\n"\
             "          $ hlsVer <vitis_version>\n"\
             "          $ hlsVersion\n"

        return -1 ; exit
    fi

    # ---------------------------------------
    # Ensure the vitis command has been setup
    # ---------------------------------------
    if [[ -z `which vitis` ]]; then
        echo -e \
          "\nERROR: vitis command was not found\n"\
             "      This likely because the HLS vitis setup has not been done\n"\
             "      Try\n"\
             "          $ hlsVersion <vitis_version>\n"
        return -1 ; exit

    fi

    return 0
}
# ------------------------------------------------------------------------------



# ------------------------------------------------------------------------------
function hlsVer ()
{
    if [[ "$1" == @(-h|--h|--he|--hel|--help) ]]; then
        man hlsVer
        return
    fi

    local version=$1

    if [[ -z "${HLSBS_XILINX_SETUP}" ]] ; then
        echo -e \
          '\n'\
          'ERROR: HLSBS_XILINX_SETUP is not set\n'\
          '       For example\n'\
          '       $ export HLSBS_XILINX_SETUP=${XILINX_INSTALL_DIR}/{version}\n'

        return -1
    fi

    eval local ypath=\"${HLSBS_XILINX_SETUP}/Vitis\"
    local settings64=$(find $ypath -name settings64.sh -prune -print -quit 2>/dev/null)

    if [[ -z "${settings64}" ]] ; then
        "ERROR:  Unable to find settings64.sh in path ${ypath}"
        return -1
    else
        echo   Setting Xilinx to version = ${version}
        source ${settings64}
        export HLSBS_XILINX_VERSION=${version}
        return 0
    fi
}
# ------------------------------------------------------------------------------


function hlsPrj ()
{
    local s=''

    if [[ -n "${HLSBS_INI}"  ]] ; then
        IFS=':' read -ra arr <<< "${HLSBS_INI}"
        local tarr=("${arr[@]/#/@}")
        s+=${tarr[@]}
    fi

    if [[ -n "${HLSBS_PROJECT}" ]]; then
        s+=' --project='${HLSBS_PROJECT}
    fi

    if [[ -n "${HLSBS_WORKSPACE}" ]] ; then
        s+=' --workspace='${HLSBS_WORKSPACE}
    fi

    if [[ -n "${HLSBS_PRODUCTS}" ]] ; then
        s+=' --products-root='${HLSBS_PRODUCTS}
    fi

    echo ${s}
}
# ------------------------------------------------------------------------------


# ------------------------------------------------------------------------------
function hlsCtx ()
{
    if [[ "$1" == @(-h|--h|--he|--hel|--help) ]]; then
        man hlsCtx
        return
    fi

    echo "HLSBS Project environment variables"

    if [[ -n "${HLSBS_ROOT}"          ]] ; then
        echo   "HLSBS_ROOT           = ${HLSBS_ROOT}"
    fi

    if [[ -n "${HLSBS_XILINX_SETUP}"   ]] ; then
        echo   "HLSBS_XILINX_SETUP   = ${HLSBS_XILINX_SETUP}"
    fi

    if [[ -n "${HLSBS_XILINX_VERSION}" ]] ; then
        echo   "HLSBS_XILINX_VERSION = ${HLSBS_XILINX_VERSION}"
    fi

    if [[ -n "${HLSBS_INI}"            ]] ; then
        echo   "HLSBS_INI            = ${HLSBS_INI}"
    fi

    if [[ -n "${HLSBS_PROJECT_ROOT}"   ]] ; then
        echo   "HLSBS_PROJECT_ROOT   = ${HLSBS_PROJECT_ROOT}"
    fi

    if [[ -n "${HLSBS_PROJECT}"       ]]; then
        echo   "HLSBS_PROJECT        = ${HLSBS_PROJECT}"
    fi

    if [[ -n "${HLSBS_PRODUCTS}"      ]] ; then
        echo   "HLSBS_PRODUCTS       = ${HLSBS_PRODUCTS}"
    fi

    if [[ -n "${HLSBS_WORKSPACE}"     ]] ; then
        echo   "HLSBS_WORKSPACE      = ${HLSBS_WORKSPACE}"
    fi
}
# ------------------------------------------------------------------------------


# ------------------------------------------------------------------------------
function hlsWs ()
{
    hlsCheck
    status=$?
    if  [[ $status != "0" ]] ; then
        return $? 2>/dev/null; exit
    fi

    (export LD_LIBRARY_PATH=$HLSBS_LD_LIBRARY_PATH; set -f; \
     $hlsPython ${HLSBS_ROOT}/vitispy/hlsWs.py  $(hlsPrj) $@)
}
# ------------------------------------------------------------------------------


# ------------------------------------------------------------------------------
function hlsGui ()
{
    hlsCheck
    status=$?
    if  [[ $status != "0" ]] ; then
        return $? 2>/dev/null; exit
    fi

    (export LD_LIBRARY_PATH=$HLSBS_LD_LIBRARY_PATH; set -f; \
     $hlsPython ${HLSBS_ROOT}/vitispy/hlsGui.py $(hlsPrj) $@)
}
# ------------------------------------------------------------------------------


# ------------------------------------------------------------------------------
# Creates the HLS configuration + (optionally) it component
# ---------------------------------------------------------
function hlsCfg ()
{
    hlsCheck
    status=$?
    if  [[ $status != "0" ]] ; then
        return $? 2>/dev/null; exit
    fi

    (export LD_LIBRARY_PATH=$HLSBS_LD_LIBRARY_PATH; set -f; \
     $hlsPython  ${HLSBS_ROOT}/vitispy/hlsCfg.py $(hlsPrj) $@)
}
# ------------------------------------------------------------------------------


# ------------------------------------------------------------------------------
# Creates the HLS component
# -------------------------
function hlsComp ()
{
    hlsCheck
    status=$?
    if  [[ $status != "0" ]] ; then
        return $? 2>/dev/null; exit
    fi

    (export LD_LIBRARY_PATH=$HLSBS_LD_LIBRARY_PATH; set -f; \
     $hlsPython ${HLSBS_ROOT}/vitispy/hlsComp.py $(hlsPrj) $@)
}
# ------------------------------------------------------------------------------


# ----------------------------------------------------------------------
# Do
# ----------------------------------------------------------------------
function hlsRun ()
{
    hlsCheck
    status=$?
    if  [[ $status != "0" ]] ; then
        return $? 2>/dev/null; exit
    fi

    # ---------------------------------------------------------------
    # !!! KLUDGE:
    # This covers some problem that I couldn't fathom is 2023.2
    # It looks like the Makefile correctly sets the rpath to this
    # but the image activator fails to find it.  Both Makefile.rules
    # and an readelf -d on the image shows the rpath correctly set.
    # I'm mystified.
    #
    # The more correct kludge (is there such a thing) is to set
    # this in run.py just before is spawns the subprocess.
    # Technically HLSBS_LD_LIBRARY_PATH is only for the
    # python build code, not the run code.
    #
    # The trade-off is that this contains the kludge to this file.
    # ------------------------------------------------------------
    if [[ $HLSBS_XILINX_VERSION == "2023.2" ]] ; then
        lpath=${HLSBS_LD_LIBRARY_PATH}:${XILINX_HLS}/lnx64/tools/fpo_v7_1
    else
        lpath=${HLSBS_LD_LIBRARY_PATH}
    fi

    (export LD_LIBRARY_PATH=${lpath}; set -f; \
     $hlsPython ${HLSBS_ROOT}/vitispy/hlsRun.py $(hlsPrj) $@)
}
# ----------------------------------------------------------------------


# ----------------------------------------------------------------------
# Executes the csim.exe
# ----------------------------------------------------------------------
function hlsExe ()
{
    hlsCheck
    status=$?
    if  [[ $status != "0" ]] ; then
        return $? 2>/dev/null; exit
    fi

    # ------------------------------------------------------------
    # !!! KLUDGE:
    # This covers some problem that I couldn't fathom is 2023.2
    # It looks like the Makefile correctly sets the rpath to this
    # but the image activator fails to find it.
    # -----------------------------------------------------------
    if [[ $HLSBS_XILINX_VERSION == "2023.2" ]] ; then
        export LD_LIBRARY_PATH=${XILINX_HLS}/lnx64/tools/fpo_v7_1
    fi

    csim_exe=$(${HLSBS_ROOT}/vitispy/hlsExe.py $(hlsPrj) $@)
    status=$?
    if test $status -ne 0
    then
        if test $status -eq 1
        then
            man ${HLSBS_ROOT}/man1/hlsExe.1
        fi
        return ${status}
    else
        ${csim_exe} $@
        return $?
    fi
}
# ----------------------------------------------------------------------


# ----------------------------------------------------------------------
# Invokes GDB on csim.exe
# ----------------------------------------------------------------------
function hlsGdb ()
{
    hlsCheck
    status=$?
    if  [[ $status != "0" ]] ; then
        return $? 2>/dev/null; exit
    fi

    csim_exe=$(${HLSBS_ROOT}/vitispy/hlsGdb.py $(hlsPrj) $@)
    status=$?
    if test $status -ne 0
    then
        if test $status -eq 1
        then
            man ${HLSBS_ROOT}/man1/hlsGdb.1
        fi
        return ${status}
    else
        set +f
        # ------------------------------------------------------------
        # !!! KLUDGE:
        # This covers some problem that I couldn't fathom is 2023.2
        # It looks like the Makefile correctly sets the rpath to this
        # but the image activator fails to find it.
        # -----------------------------------------------------------
        if [[ $HLSBS_XILINX_VERSION == "2023.2" ]] ; then
            export LD_LIBRARY_PATH=${XILINX_HLS}/lnx64/tools/fpo_v7_1
        fi
        gdb --args ${csim_exe} $@
    fi
}
# ----------------------------------------------------------------------


# ----------------------------------------------------------------------
function hlsBs ()
{
    man ${HLSBS_ROOT}/man1/hlsBs.1
}
# ----------------------------------------------------------------------


# ----------------------------------------------------------------------
function hlsVersion ()
{
    if [[ "$1" == @(-h|--h|--he|--hel|--help) ]]; then
        man hlsVersion
        return 0
    fi

    # If passed a version, use it
    if [[ -n "$1" ]]; then
        hlsVer $1

        if [ $? -ne 0 ]; then
            return $?
        fi

    # Else maybe already setup
    elif [[ -n ${XILINX_HLS} ]]; then
        eval `python ${HLSBS_ROOT}/vitispy/hlsSetVersion.py`
        echo "Using existing Xilinx version = ${HLS_XILINX_VERSION}"
        export HLSBS_XILINX_VERSION=${HLS_XILINX_VERSION}
    fi


    # Check that everything is in order
    hlsCheck
    status=$?
    if  [[ $status != "0" ]] ; then
        return $? 2>/dev/null; exit
    fi


    unset HLSBS_LD_LIBRARY_PATH
    unset HLSBS_PROJECT_IMPORT_PYPATHS
    unset HLSBS_PROJECT_PYPATHS
    unset XILINX_VCXX

    eval `python ${HLSBS_ROOT}/vitispy/hlsSetVersion.py`

    # ---------------------------------
    # Only works for versions > v2023.2
    # ---------------------------------
    if [[ "${HLSBS_XILINX_VERSION}" < "2023.2" ]]; then
        echo "ERROR: HLS Version ${HLSBS_XILINX_VERSION} must >= 2023.2"
        return -1
    fi

    eval `python3 ${HLSBS_ROOT}/vitispy/hlsPythonContext.py get`

    if   [[ "${HLSBS_XILINX_VERSION}" == "2023.2" ]]; then
        export XILINX_VCXX=$XILINX_HLS/vcxx
    elif [[ "${HLSBS_XILINX_VERSION}" == "2024.1" ]]; then
        export XILINX_VCXX=$XILINX_HLS/vcxx
    elif [[ "${HLSBS_XILINX_VERSION}" == "2024.2" ]]; then
        export XILINX_VCXX=$XILINX_HLS/vcxx
    elif [[ "${HLSBS_XILINX_VERSION}" == "2025.1" ]]; then
        export XILINX_VCXX=$XILINX_HLS/lnx64/tools/vcxx
    elif [[ "${HLSBS_XILINX_VERSION}" == "2025.2" ]]; then
        export XILINX_VCXX=$XILINX_HLS/lnx64/tools/vcxx
    else
        export XILINX_VCXX=$XILINX_HLS/lnx64/tools/vcxx
    fi
}
# ----------------------------------------------------------------------


# ----------------------------------------------------------------------
function hlsAddManpath ()
{
    local man_path=${HLSBS_ROOT}/

    # Eliminate duplicates
    mod_path=$(echo "$MANPATH" | tr ':' '\n' | awk '!seen[$0]++' | paste -sd: -)

    # See if already on MANPATH
    if [[ ":${MANPATH}:" == *":${man_path}:"* ]]; then
        export MANPATH=${mod_path}
    elif [[ -z $MANPATH ]] ; then
        export MANPATH=${man_path}
    else
        export MANPATH=${man_path}:${MANPATH}
    fi
}
# ----------------------------------------------------------------------


hlsAddManpath

export -f hlsCheck
export -f hlsVer
export -f hlsPrj
export -f hlsCtx
export -f hlsWs
export -f hlsGui
export -f hlsCfg
export -f hlsComp
export -f hlsRun
export -f hlsExe
export -f hlsGdb
export -f hlsBs
export -f hlsVersion
export -f hlsAddManpath
