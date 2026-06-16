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
    export HLS_BS_ROOT=`dirname $script_dir`
}

setup
unset setup

# ------------------------------------------------------------------------------
function hlsCheck ()
{
    if [[ -z "${HLS_PROJECT_XILINX_VERSION}" ]] ; then
        echo -e \
          "\nERROR: HLS project has not been setup\n"\
             "      Try\n"\
             "          $ hlsProject <vitis_version>\n"\
             "      ..or..\n"\
             "          $ hlsVer <vitis_version>\n"\
             "          $ hlsProject\n"

        return -1 ; exit
    fi

    # ---------------------------------------
    # Ensure the vitis command has been setup
    # ---------------------------------------
    if [[ -z `which vitis` ]]; then
        echo -e \
          "\nERROR: vitis command was not found\n"\
             "      This likely because the HLS vitis setup has not been done\n"\
             "      Try either\n"\
             "          $ hlsVer     <vitis_version>\n"\
             "          $ hlsProject <vitis_version>\n"
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

    if [[ -z "${HLS_PROJECT_XILINX_SETUP}" ]] ; then
        echo -e \
          '\n'\
          'ERROR: HLS_PROJECT_XILINX_SETUP is not set\n'\
          '       For example\n'\
          '       $ export HLS_PROJECT_XILINX_SETUP=${XILINX_INSTALL_DIR}/{version}\n'

        return -1
    fi

    eval local ypath=\"${HLS_PROJECT_XILINX_SETUP}/Vitis\"
    local settings64=$(find $ypath -name settings64.sh -prune -print 2>/dev/null)

    if [[ -z "${settings64}" ]] ; then
        "ERROR:  Unable to find settings64.sh in path ${ypath}"
        return -1
    else
        echo   Setting Xilinx to version = ${version}
        source ${settings64}
        export HLS_PROJECT_XILINX_VERSION=${version}
        return 0
    fi
}
# ------------------------------------------------------------------------------


function hlsPrj ()
{
    local s=''

    if [[ -n "${HLS_PROJECT_INI}"  ]] ; then
        IFS=':' read -ra arr <<< "${HLS_PROJECT_INI}"
        local tarr=("${arr[@]/#/@}")
        s+=${tarr[@]}
    fi

    if [[ -n "${HLS_PROJECT_PRJ}" ]]; then
        s+=' --project='${HLS_PROJECT_PRJ}
    fi

    if [[ -n "${HLS_PROJECT_WORKSPACE}" ]] ; then
        s+=' --workspace='${HLS_PROJECT_WORKSPACE}
    fi

    if [[ -n "${HLS_PROJECT_PRODUCTS}" ]] ; then
        s+=' --products-root='${HLS_PROJECT_PRODUCTS}
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

    echo "HLS Project environment variables"

    if [[ -n "${HLS_PROJECT_XILINX_SETUP}"   ]] ; then
        echo   "HLS_PROJECT_XILINX_SETUP   = ${HLS_PROJECT_XILINX_SETUP}"
    fi

    if [[ -n "${HLS_PROJECT_XILINX_VERSION}" ]] ; then
        echo   "HLS_PROJECT_XILINX_VERSION = ${HLS_PROJECT_XILINX_VERSION}"
    fi

    if [[ -n "${HLS_PROJECT_INI}"            ]] ; then
        echo   "HLS_PROJECT_INI            = ${HLS_PROJECT_INI}"
    fi

    if [[ -n "${HLS_PROJECT_ROOT}"           ]] ; then
        echo   "HLS_PROJECT_ROOT           = ${HLS_PROJECT_ROOT}"
    fi

    if [[ -n "${HLS_PROJECT_PRJ}"            ]]; then
        echo   "HLS_PROJECT_PRJ            = ${HLS_PROJECT_PRJ}"
    fi

    if [[ -n "${HLS_PROJECT_PRODUCTS}"      ]] ; then
        echo   "HLS_PROJECT_PRODUCTS}      = ${HLS_PROJECT_PRODUCTS}"
    fi

    if [[ -n "${HLS_PROJECT_WORKSPACE}"     ]] ; then
        echo   "HLS_PROJECT_WORKSPACE      = ${HLS_PROJECT_WORKSPACE}"
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

    (export LD_LIBRARY_PATH=$HLS_PROJECT_LD_LIBRARY_PATH; set -f; \
     $hlsPython ${HLS_BS_ROOT}/vitispy/hlsWs.py  $(hlsPrj) $@)
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

    (export LD_LIBRARY_PATH=$HLS_PROJECT_LD_LIBRARY_PATH; set -f; \
     $hlsPython ${HLS_BS_ROOT}/vitispy/hlsGui.py $(hlsPrj) $@)
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

    (export LD_LIBRARY_PATH=$HLS_PROJECT_LD_LIBRARY_PATH; set -f; \
     $hlsPython  ${HLS_BS_ROOT}/vitispy/hlsCfg.py $(hlsPrj) $@)
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

    (export LD_LIBRARY_PATH=$HLS_PROJECT_LD_LIBRARY_PATH; set -f; \
     $hlsPython ${HLS_BS_ROOT}/vitispy/hlsComp.py $(hlsPrj) $@)
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
    # Technically HLS_PROJECT_LD_LIBRARY_PATH is only for the
    # python build code, not the run code.
    #
    # The trade-off is that this contains the kludge to this file.
    # ------------------------------------------------------------
    if [[ $HLS_PROJECT_XILINX_VERSION == "2023.2" ]] ; then
        lpath=${HLS_PROJECT_LD_LIBRARY_PATH}:${XILINX_HLS}/lnx64/tools/fpo_v7_1
    else
        lpath=${HLS_PROJECT_LD_LIBRARY_PATH}
    fi

    (export LD_LIBRARY_PATH=${lpath}; set -f; \
     $hlsPython ${HLS_BS_ROOT}/vitispy/hlsRun.py $(hlsPrj) $@)
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
    if [[ $HLS_PROJECT_XILINX_VERSION == "2023.2" ]] ; then
        export LD_LIBRARY_PATH=${XILINX_HLS}/lnx64/tools/fpo_v7_1
    fi

    csim_exe=$(${HLS_BS_ROOT}/vitispy/hlsExe.py $(hlsPrj) $@)
    status=$?
    if test $status -ne 0
    then
        if test $status -eq 1
        then
            man ${HLS_BS_ROOT}/man1/hlsExe.1
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

    csim_exe=$(${HLS_BS_ROOT}/vitispy/hlsGdb.py $(hlsPrj) $@)
    status=$?
    if test $status -ne 0
    then
        if test $status -eq 1
        then
            man ${HLS_BS_ROOT}/man1/hlsGdb.1
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
        if [[ $HLS_PROJECT_XILINX_VERSION == "2023.2" ]] ; then
            export LD_LIBRARY_PATH=${XILINX_HLS}/lnx64/tools/fpo_v7_1
        fi
        gdb --args ${csim_exe} $@
    fi
}
# ----------------------------------------------------------------------


# ----------------------------------------------------------------------
function hlsBs ()
{
    man ${HLS_BS_ROOT}/man1/hlsBs.1
}
# ----------------------------------------------------------------------


# ----------------------------------------------------------------------
function hlsProject ()
{
    # If passed a version, use it
    if [[ -n "$1" ]]; then
        hlsVer $1

        if [ $? -ne 0 ]; then
            return $?
        fi

    # Else maybe already setup
    elif [[ -n ${XILINX_HLS} ]]; then
        eval `python ${HLS_BS_ROOT}/vitispy/hlsVersion.py`
        export HLS_PROJECT_XILINX_VERSION=${HLS_XILINX_VERSION}
    fi


    # Check that everything is in order
    hlsCheck
    status=$?
    if  [[ $status != "0" ]] ; then
        return $? 2>/dev/null; exit
    fi


    unset HLS_PROJECT_LD_LIBRARY_PATH
    unset HLS_PROJECT_IMPORT_PYPATHS
    unset HLS_PROJECT_PYPATHS
    unset XILINX_VCXX



    eval `python ${HLS_BS_ROOT}/vitispy/hlsVersion.py`

    # ---------------------------------
    # Only works for versions > v2023.2
    # ---------------------------------
    if [[ "${HLS_PROJECT_XILINX_VERSION}" < "2023.2" ]]; then
        echo "ERROR: HLS Version ${HLS_PROJECT_XILINX_VERSION} must >= 2023.2"
        return -1
    fi

    eval `python3 ${HLS_BS_ROOT}/vitispy/hlsPythonContext.py get`

    if   [[ "${HLS_PROJECT_XILINX_VERSION}" == "2023.2" ]]; then
        export XILINX_VCXX=$XILINX_HLS/vcxx
    elif [[ "${HLS_PROJECT_XILINX_VERSION}" == "2024.1" ]]; then
        export XILINX_VCXX=$XILINX_HLS/vcxx
    elif [[ "${HLS_PROJECT_XILINX_VERSION}" == "2024.2" ]]; then
        export XILINX_VCXX=$XILINX_HLS/vcxx
    elif [[ "${HLS_PROJECT_XILINX_VERSION}" == "2025.1" ]]; then
        export XILINX_VCXX=$XILINX_HLS/lnx64/tools/vcxx
    elif [[ "${HLS_XILINX_VERSION}" == "2025.2" ]]; then
        export XILINX_VCXX=$XILINX_HLS/lnx64/tools/vcxx
    else
        export XILINX_VCXX=$XILINX_HLS/lnx64/tools/vcxx
    fi
}
# ----------------------------------------------------------------------


# ----------------------------------------------------------------------
function hlsAddManpath ()
{
    local man_path=${HLS_BS_ROOT}/

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
export -f hlsProject
export -f hlsAddManpath
