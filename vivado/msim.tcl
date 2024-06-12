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
            puts "Please add ModelSim/Questa installation directory to your PATH"
            puts "or setup MSIM_PATH variable in your Modelsim/Questa setup script"
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
    set supported "2019.2 2019.3_2 2021.1_2"

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

# Setup variables
set SimInfo [GetModelsim-QuestaName]
set Simulator [lindex $SimInfo 0]
set VersionNumber [lindex $SimInfo 1]
set MSIM_PATH [lindex $SimInfo 2]
if { [info exists ::env(MSIM_LIB_PATH)] } {
    set simLibOutDir $::env(MSIM_LIB_PATH)
} else {
    set simLibOutDir ${VIVADO_INSTALL}/msim-${VersionNumber}
}
set simTbOutDir ${OUT_DIR}/${PROJECT}_project.sim/sim_1/behav
set simTbFileName [get_property top [get_filesets sim_1]]
set hopeTopFile [lindex [find_top -fileset [get_filesets sim_1] -return_file_paths] 1]
set simTbLibName [get_property -quiet LIBRARY [get_files -quiet $hopeTopFile]]

# Set the compile/elaborate options
if { [info exists ::env(MSIM_CARGS_VERILOG)] } {
    set vlogOpt $::env(MSIM_CARGS_VERILOG)
} else {
    set vlogOpt ""
}
if { [info exists ::env(MSIM_CARGS_VHDL)] } {
    set vcomOpt $::env(MSIM_CARGS_VHDL)
} else {
    set vcomOpt ""
}
if { [info exists ::env(MSIM_ELAB_FLAGS)] } {
    set elabOpt $::env(MSIM_ELAB_FLAGS)
} else {
    set elabOpt ""
}
if { [info exists ::env(MSIM_RUN_FLAGS)] } {
    set runOpt $::env(MSIM_RUN_FLAGS)
} else {
    set runOpt ""
}
# Run vsim with GUI
if { [info exists ::env(MSIM_RUN_GUI)] } {
    set msimGui $::env(MSIM_RUN_GUI)
} else {
    set msimGui false
}

#####################################################################################################
## Compile the Questa Simulation Library
#####################################################################################################

# Compile the libraries for ModelSim/Questa Sim
if { [file exists ${simLibOutDir}] != 1 } {

    # Make the directory
    exec mkdir -p ${simLibOutDir}

    # Compile the simulation libraries
    set CompSimLibComm "compile_simlib -simulator [string tolower ${Simulator}] -simulator_exec_path ${MSIM_PATH} -family all -language all -library all -dir ${simLibOutDir}"
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
set_property -name {[string tolower ${Simulator}].compile.vcom.more_options}    -value ${vcomOpt}   -objects [get_filesets sim_1]
set_property -name {[string tolower ${Simulator}].compile.vlog.more_options}    -value ${vlogOpt}   -objects [get_filesets sim_1]
set_property -name {[string tolower ${Simulator}].elaborate.vopt.more_options}  -value ${elabOpt}   -objects [get_filesets sim_1]
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
## Export the Simulation
#####################################################################################################
# Export Xilinx & User IP Cores
generate_target -force {simulation} [get_ips]
export_ip_user_files -force -no_script

# Launch the scripts generator
set include [get_property include_dirs   [get_filesets sim_1]]; # Verilog only
set define  [get_property verilog_define [get_filesets sim_1]]; # Verilog only
export_simulation -force -absolute_path -simulator [string tolower ${Simulator}] -include ${include} -define ${define} -lib_map_path ${simLibOutDir} -directory ${simTbOutDir}/

#####################################################################################################
## Customization of the executable bash (.sh) script
#####################################################################################################

set err_ret [catch {get_files -compile_order sources -used_in simulation {*.v}}  vList]
set err_ret [catch {get_files -compile_order sources -used_in simulation {*.vh}} vhList]
set err_ret [catch {get_files -compile_order sources -used_in simulation {*.sv}} svList]

# Copy of all the Xilinx IP core datafile
set list ""
set list_rc [catch {
    set list [glob -directory ${simTbOutDir}/[string tolower ${Simulator}]/ *.dat *.coe *.mem *.edif *.mif]
} _RESULT]
if { ${list} != "" } {
   foreach pntr ${list} {
      exec cp -f ${pntr} ${simTbOutDir}/.
   }
}

# open the main file
set in  [open ${simTbOutDir}/[string tolower ${Simulator}]/${simTbFileName}.sh r]
set out [open ${simTbOutDir}/sim_msim.sh  w]

# Find and replace the AFS path
while { [eof ${in}] != 1 } {

    gets ${in} line

    # Do not execute the simulation in sim_msim.sh build script
    if { [string match "*simulate.do*" ${line}] } {
        if { ${msimGui} } {
            set line "echo \"\vsim -64 ${runOpt} -do \\\"do \{simulate.do\}\\\" -lib xil_defaultlib ${simTbFileName}_opt\" > vsim\n"
            append line "chmod 0755 ${simTbOutDir}/simv\n"
            append line   echo \"Ready to simulate\""
        } else {
            set line "echo \"vsim -64 -c ${runOpt} -do \\\"do \{simulate.do\}\\\" -lib ${simTbLibName} ${simTbFileName}_opt\" > simv\n"
            append line "chmod 0755 ${simTbOutDir}/simv\n"
            append line "echo \"Ready to simulate\""
        }
    }

    # Replace ${simTbFileName}_simv with the simv
    set replaceString "${simTbFileName}_simv simv"
    set line [string map ${replaceString}  ${line}]

    # Change the glbl.v path (Vivado 2017.2 fix)
    set replaceString "behav/[string tolower ${Simulator}]/glbl.v glbl.v"
    set line [string map ${replaceString}  ${line}]

    # Write to file
    puts ${out} ${line}
}

# Close the files
close ${in}
close ${out}

# Update the permissions
exec chmod 0755 ${simTbOutDir}/sim_msim.sh

# Update the compile options (fix bug in export_simulation not including more_options properties)
if { [VersionCompare 2022.1] <= 0 } {
    # open the compile file
    set in  [open ${simTbOutDir}/[string tolower ${Simulator}]/compile.do r]
    set out [open ${simTbOutDir}/compile.do  w]

    # Set substitutions
    set vcom_new_sub "-64 -93 ${vcomOpt} "
    set vcom_old_sub "-64 -93 "

    set vlog_new_sub "-incr -mfcu ${vlogOpt} "
    set vlog_old_sub "-incr -mfcu "

    # Find and replace the AFS path
    while { [eof ${in}] != 1 } {
        gets ${in} line

        set line [regsub -- ${vcom_old_sub} $line ${vcom_new_sub}]
        set line [regsub -- ${vlog_old_sub} $line ${vlog_new_sub}]

        puts ${out} ${line}
    }

    # Close the files
    close ${in}
    close ${out}

    # open the elaborate file
    set in  [open ${simTbOutDir}/[string tolower ${Simulator}]/elaborate.do r]
    set out [open ${simTbOutDir}/elaborate.do  w]

    # Set substitutions
    set velab_new_sub "-64 ${elabOpt} "
    set velab_old_sub "-64 "

    # Find and replace the AFS path
    while { [eof ${in}] != 1 } {
        gets ${in} line

        set line [regsub -- ${velab_old_sub} $line ${velab_new_sub}]
        set line [regsub -- ${velab_old_sub} $line ${velab_new_sub}]

        # Check if only a VHDL simulation
   if { ${vList}   == "" &&
        ${vhList}  == "" &&
        ${svList}  == "" } {
      # Remove xil_defaultlib.glbl (bug fix for Vivado compiling Msim script)
       set line [string map { "xil_defaultlib.glbl" "" } ${line}]
   }

        puts ${out} ${line}
    }

    # Close the files
    close ${in}
    close ${out}

} else {
    # Copy the compile.do file
    if { [file exists ${simTbOutDir}/[string tolower ${Simulator}]/compile.do] == 1 } {
        exec cp -f ${simTbOutDir}/[string tolower ${Simulator}]/compile.do ${simTbOutDir}/compile.do
    }

    # Copy the elaborate.do file
    if { [file exists ${simTbOutDir}/[string tolower ${Simulator}]/elaborate.do] == 1 } {
        exec cp -f ${simTbOutDir}/[string tolower ${Simulator}]/elaborate.do ${simTbOutDir}/elaborate.do
    }
}

# Copy the simulation file
set in  [open ${simTbOutDir}/[string tolower ${Simulator}]/simulate.do r]
set out [open ${simTbOutDir}/simulate.do  w]

# Find and replace the AFS path
while { [eof ${in}] != 1 } {
    gets ${in} line
    # Delete vsim command
    if { [string match "*vsim*" ${line}] } {
        set line ""
    }
    # Delete need for .udo files
    if { [string match "*.udo\}" ${line}] } {
        set line "# Insert custom action here"
    }
    puts ${out} ${line}
}

# Close the files
close ${in}
close ${out}

# Copy the wave.do file
if { [info exists ::env(MSIM_DUMP_VCD)] } {
    set msimVcdDump $::env(MSIM_DUMP_VCD)
} else {
    set msimVcdDump false
}

if { ${msimVcdDump} } {
    set in  [open ${simTbOutDir}/[string tolower ${Simulator}]/wave.do r]
    set out [open ${simTbOutDir}/wave.do  w]

    # Find and replace the AFS path
    while { [eof ${in}] != 1 } {
        # copy files
        gets ${in} line
        puts ${out} ${line}
    }
    puts ${out} "vcd file ${simTbFileName}.vcd"
    puts ${out} "vcd add -r *"

    # Close the files
    close ${in}
    close ${out}
} else {
    if { [file exists ${simTbOutDir}/[string tolower ${Simulator}]/wave.do] == 1 } {
        exec cp -f ${simTbOutDir}/[string tolower ${Simulator}]/wave.do ${simTbOutDir}/wave.do
    }
}

#####################################################################################################
#####################################################################################################
#####################################################################################################

# Copy the glbl.v file
if { [file exists ${simTbOutDir}/[string tolower ${Simulator}]/glbl.v] == 1 } {
    # Change the glbl.v path (Vivado 2017.2 fix)
    exec cp -f ${simTbOutDir}/[string tolower ${Simulator}]/glbl.v ${simTbOutDir}/../glbl.v
    exec cp -f ${simTbOutDir}/[string tolower ${Simulator}]/glbl.v ${simTbOutDir}/glbl.v
}

# Target specific MSIM script
SourceTclFile ${VIVADO_DIR}/post_msim.tcl

# Close the project (required for cd function)
close_project

# Set rogue Sim
set rogueSimEn false

# MSIM Complete Message
MsimCompleteMessage ${simTbOutDir} ${rogueSimEn}
