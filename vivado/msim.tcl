##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

## \file vivado/msim.tcl
# \brief This script performs a Modelsim/Questa simulation

# Get variables and procedures
source -quiet $::env(RUCKUS_DIR)/vivado/env_var.tcl
source -quiet $::env(RUCKUS_DIR)/vivado/proc.tcl

#####################################################################################################
## Procedures and Checks
#####################################################################################################

## Get ModelSim/Questa install name
proc GetModelsim-QuestaName { } {

    # Is ModelSim/Questa in PATH?
    set err_ret_l1 [catch {
        exec bash -c "command -v vsim"
    } grepCmd]

    # Or set as env variable?
    if { ${err_ret_l1} != 0} {
        set err_ret [catch {
            exec bash -c "command -v $::env(MSIM_PATH)/vsim"
        } grepCmd]

        if { ${err_ret} != 0} {
            puts "\n\n*********************************************************"
            puts "vsim: Command not found."
            puts "Please setup MSIM_PATH in your Modelsim/Questa setup script"
            puts "Example: export MSIM_PATH=/tools/questasim/bin"
            puts "*********************************************************\n\n"
            exit -1
        } else {
            set MSIM_PATH $::env(MSIM_PATH)
        }
    } else {
        set MSIM_PATH [file dirname $grepCmd]
    }

    # Is it ModelSim or Questa?
    set err_ret [catch {
        exec ${MSIM_PATH}/vsim -version
    } grepVersion]

    if {[string first "Questa" ${grepVersion}] != -1} {
        set Simulator "Questa"
    } elseif {[string first "ModelSim" ${grepVersion}] != -1} {
        set Simulator "ModelSim"
    } else {
        puts "\n\n*********************************************************"
        puts "Simulator not found."
        puts "*********************************************************\n\n"
        exit -1
    }

    while {[scan $grepVersion %s%n word length] == 2 && $word != {vsim}} {set grepVersion [string range $grepVersion $length end]}
    scan $grepVersion "%s %s Simulator%s" blowoff1 VersionNumber blowoff2

    return [list ${Simulator} ${VersionNumber} ${MSIM_PATH}]
}

## Checks for ModelSim/Questa Sim versions that ruckus supports
proc Modelsim-QuestaVersionCheck { } {
    set retVar -1

    # List of supported ModelSim/QuestaSim versions
    set supported "2019.2 2021.1_2"

    # Get Version Name
    set SimInfo [GetModelsim-QuestaName]
    set Simulator [lindex $SimInfo 0]
    set VersionNumber [lindex $SimInfo 1]

    # Generate error message
    set errMsg "\n\n*********************************************************\n"
    set errMsg "${errMsg}Your ${Simulator} version   = ${VersionNumber}\n"
    set errMsg "${errMsg}However, supported ${Simulator} version = ${supported}\n"
    set errMsg "${errMsg}You should change your ${Simulator} software to one of these versions\n"
    set errMsg "${errMsg}*********************************************************\n"

    # Loop through the different support version list
    foreach pntr ${supported} {
        if { ${VersionNumber} == ${pntr} } {
            set retVar 0
        }
    }

    # Check for no support version detected
    if { ${retVar} < 0 } {
        puts ${errMsg}
    }

    return ${retVar}
}

#####################################################################################################
## Open project and some ModelSim/Questa Sim checking
#####################################################################################################

# Check for version 2016.4 (or later)
if { [VersionCheck 2016.4] < 0 } {
    close_project
    exit -1
}

# Check for supported ModelSim/Questa version
if { [Modelsim-QuestaVersionCheck] < 0 } {
    #exit -1
    puts -nonewline "Sim version not supported, do you want to continue? (y/n): "
    flush stdout
    set Cont [gets stdin]
    if { ${Cont} == "n" } {
        exit -1
    }
}

# Open the project
open_project -quiet ${VIVADO_PROJECT}

# Check project configuration for errors
if { [CheckPrjConfig sim_1] != true } {
    exit -1
}

# Target specific ModelSim/Questa script
SourceTclFile ${VIVADO_DIR}/pre_msim.tcl

#####################################################################################################
## Set the local variables
#####################################################################################################
set SimInfo [GetModelsim-QuestaName]
set Simulator [lindex $SimInfo 0]
set VersionNumber [lindex $SimInfo 1]
set MSIM_PATH [lindex $SimInfo 2]
set simLibOutDir ${VIVADO_INSTALL}/msim-${VersionNumber}

#####################################################################################################
## Compile the Questa Simulation Library
#####################################################################################################
if { [file exists ${simLibOutDir}] != 1 } {

    # Make the directory
    exec mkdir -p ${simLibOutDir}

    # Compile the simulation libraries
    set CompSimLibComm "compile_simlib -simulator [string tolower ${Simulator}] -simulator_exec_path { ${MSIM_PATH} } -family all -language all -library all -dir ${simLibOutDir}"
    eval ${CompSimLibComm}
}


####################################################################################################
## Setup Vivado's ModelSim/Questa environment
#####################################################################################################

# Set target_simulator
set_property target_simulator "${Simulator}" [current_project]
set_property compxlib.[string tolower ${Simulator}]_compiled_library_dir ${simLibOutDir} [current_project]

# Configure ModelSim/Questa settings
set VIVADO_PROJECT_SIM_TIME "set_property -name {[string tolower ${Simulator}].simulate.runtime} -value {$::env(VIVADO_PROJECT_SIM_TIME)} -objects \[\get_filesets \sim_1\]"
eval ${VIVADO_PROJECT_SIM_TIME}
set_property nl.process_corner fast [get_filesets sim_1]
set_property unifast true [get_filesets sim_1]

# Update the compile order
update_compile_order -quiet -fileset sim_1

# Check for mixed-simulation
set fileList [get_files -compile_order sources -used_in simulation]
set mixedSim false
foreach filePntr ${fileList} {
   if { [file extension ${filePntr}] ne {.vhd} } {
      set mixedSim true
   }
}

#####################################################################################################
## Run Questa simulation
#####################################################################################################
set errMsg "\n\n*********************************************************\n"
set errMsg "${errMsg}Error in ${Simulator}. Check the errors in the console\n"
   set errMsg "${errMsg}*********************************************************\n\n"

set sim_rc [catch {

    # Set sim properties
    set_property top ${VIVADO_PROJECT_SIM} [get_filesets sim_1]
    set_property top_lib xil_defaultlib [get_filesets sim_1]

    # Launch the msim
    launch_simulation -install_path ${MSIM_PATH}

} _SIM_RESULT]

########################################################
# Check for error return code during the process
########################################################
if { ${sim_rc} } {
    puts ${errMsg}
    exit -1
}
