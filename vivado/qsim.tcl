##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

## \file vivado/qsim.tcl
# \brief This script performs a Questa simulation

# Get variables and procedures
source -quiet $::env(RUCKUS_DIR)/vivado/env_var.tcl
source -quiet $::env(RUCKUS_DIR)/vivado/proc.tcl

#####################################################################################################
## Procedures and Checks
#####################################################################################################

## Get Questa install name
proc GetQuestaName { } {

    # Get the Questa version
    set err_ret [catch {
        exec bash -c "command -v $::env(QSIM_PATH)/vsim"
    } grepCmd]

    if { ${err_ret} != 0} {
        puts "\n\n*********************************************************"
        puts "vsim: Command not found."
        puts "Please setup QSIM_PATH in your Questa setup script"
        puts "Example: export QSIM_PATH=/tools/questasim/bin"
        puts "*********************************************************\n\n"
        exit -1
    }

    set err_ret [catch {
        exec $::env(QSIM_PATH)/vsim -version
    } grepVersion]

    scan $grepVersion "Questa Sim-64 vsim %s Simulator%s" VersionNumber blowoff

    return ${VersionNumber}
}

## Checks for Questa Sim versions that ruckus supports
proc QuestaVersionCheck { } {
    set retVar -1

    # List of supported QuestaSim versions
    set supported "2021.1_2"

    # Get Version Name
    set VersionNumber [GetQuestaName]

    # Generate error message
    set errMsg "\n\n*********************************************************\n"
    set errMsg "${errMsg}Your Questa Sim Version   = ${VersionNumber}\n"
    set errMsg "${errMsg}However, Questa Sim Version Lock = ${supported}\n"
    set errMsg "${errMsg}You need to change your Questa Sim software to one of these versions\n"
    set errMsg "${errMsg}*********************************************************\n\n"

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
## Open project and some Questa Sim checking
#####################################################################################################

# Check for version 2016.4 (or later)
if { [VersionCheck 2016.4] < 0 } {
    close_project
    exit -1
}

# Check for supported Questa version
if { [QuestaVersionCheck] < 0 } {
    exit -1
}

# Open the project
open_project -quiet ${VIVADO_PROJECT}

# Check project configuration for errors
if { [CheckPrjConfig sim_1] != true } {
    exit -1
}

# Target specific Questa script
SourceTclFile ${VIVADO_DIR}/pre_qsim.tcl

#####################################################################################################
## Set the local variables
#####################################################################################################

# Setup variables
set VersionNumber [GetQuestaName]
set simLibOutDir ${VIVADO_INSTALL}/qsim-${VersionNumber}

#####################################################################################################
## Compile the Questa Simulation Library
#####################################################################################################

# Compile the libraries for Questa Sim
if { [file exists ${simLibOutDir}] != 1 } {

    # Make the directory
    exec mkdir -p ${simLibOutDir}

    # Compile the simulation libraries
    set CompSimLibComm "compile_simlib -simulator questa -simulator_exec_path {$::env(QSIM_PATH)} -family all -language all -library all -dir ${simLibOutDir}"
    eval ${CompSimLibComm}
}


#####################################################################################################
## Setup Vivado's Questa environment
#####################################################################################################

# Set Questa as target_simulator
set_property target_simulator "Questa" [current_project]
set_property compxlib.questa_compiled_library_dir ${simLibOutDir} [current_project]

# Configure Questa settings
set VIVADO_PROJECT_SIM_TIME "set_property -name {questa.simulate.runtime} -value {$::env(VIVADO_PROJECT_SIM_TIME)} -objects \[\get_filesets \sim_1\]"
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
   set errMsg "${errMsg}Error in Questa Simulation. Check the errors in the console\n"
   set errMsg "${errMsg}*********************************************************\n\n"

set sim_rc [catch {

    # Set sim properties
    set_property top ${VIVADO_PROJECT_SIM} [get_filesets sim_1]
    set_property top_lib xil_defaultlib [get_filesets sim_1]

    # Launch the xsim
    launch_simulation -install_path $::env(QSIM_PATH)

} _SIM_RESULT]

########################################################
# Check for error return code during the process
########################################################
if { ${sim_rc} } {
    puts ${errMsg}
    exit -1
}
