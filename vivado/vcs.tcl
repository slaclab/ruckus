##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################
# VCS + Verdi GUI + Ubuntu 19.04 Notes:
# $ sudo add-apt-repository ppa:linuxuprising/libpng12
# $ sudo apt update
# $ sudo apt install libpng12-0
##############################################################################

## \file vivado/vcs.tcl
# \brief This script generates the VCS build scripts using Vivado to determine the
# build ordering and other dependencies. This script does NOT run the VCS scripts that it generates

# Get variables and procedures
source -quiet $::env(RUCKUS_DIR)/vivado/env_var.tcl
source -quiet $::env(RUCKUS_DIR)/vivado/proc.tcl

#####################################################################################################
## Procedures and Checks
#####################################################################################################

if { [info exists ::env(VCS_VERSION)] != 1 } {
   puts "\n\n*********************************************************"
   puts "VCS_VERSION environmental variable does not exist. Please add"
   puts "VCS_VERSION environmental variable to your VCS setup script."
   puts "Example: export VCS_VERSION=2017"
   puts "*********************************************************\n\n"
   exit -1
}

## Get VCS install name
proc GetVcsName { } {

   # Get the VCS version
   set err_ret [catch {
      exec bash -c "command -v vcs"
   } grepCmd]

   if { ${err_ret} != 0} {
      puts "\n\n*********************************************************"
      puts "vcs: Command not found."
      puts "Please setup VCS in your SHELL environment"
      puts "*********************************************************\n\n"
      return -1
   }

   # Get the VCS version
   set err_ret [catch {
      exec vcs -ID | grep "vcs script version"
   } grepVersion]
   # if { ${err_ret} != 0} {
      # puts "\n\n*********************************************************"
      # puts "\"vcs -ID\" command failed:"
      # puts "${grepVersion}"
      # puts "*********************************************************\n\n"
      # return -1
   # }
   scan $grepVersion "vcs script version : %s\n%s" VersionNumber blowoff

   return ${VersionNumber}
}

## Checks for VCS versions that ruckus supports
proc VcsVersionCheck { } {
   set retVar -1

   # List of supported VCS versions
   set supported "M-2017.03 N-2017.12 O-2018.09 Q-2020.03 R-2020.12 S-2021.09 T-2022.06 V-2023.12"

   # Get Version Name
   set VersionNumber [GetVcsName]

   # Generate error message
   set errMsg "\n\n*********************************************************\n"
   set errMsg "${errMsg}Your VCS Version Vivado   = ${VersionNumber}\n"
   set errMsg "${errMsg}However, VCS Version Lock = ${supported}\n"
   set errMsg "${errMsg}You need to change your VCS software to one of these versions\n"
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
## Open project and some VCS checking
#####################################################################################################

# Check for version 2016.4 (or later)
if { [VersionCheck 2016.4] < 0 } {
   close_project
   exit -1
}

# Check for supported VCS version
if { [VcsVersionCheck] < 0 } {
   exit -1
}

# Open the project
open_project -quiet ${VIVADO_PROJECT}

# Check project configuration for errors
if { [CheckPrjConfig sim_1] != true } {
   exit -1
}

# Target specific VCS script
SourceTclFile ${VIVADO_DIR}/pre_vcs.tcl

#####################################################################################################
## Set the local variables
#####################################################################################################

# Setup variables
set VersionNumber [GetVcsName]
if { [info exists ::env(VCS_LIB_PATH)] } {
    set simLibOutDir $::env(VCS_LIB_PATH)
} else {
    set simLibOutDir ${VIVADO_INSTALL}/vcs-${VersionNumber}
}
set simTbOutDir ${OUT_DIR}/${PROJECT}_project.sim/sim_1/behav
set simTbFileName [get_property top [get_filesets sim_1]]

# Set the compile/elaborate options
set vloganOpt $::env(SIM_CARGS_VERILOG)
set vhdlanOpt $::env(SIM_CARGS_VHDL)
set elabOpt $::env(SIM_VCS_FLAGS)

#####################################################################################################
## Compile the VCS Simulation Library
#####################################################################################################

# Compile the libraries for VCS
if { [file exists ${simLibOutDir}] != 1 } {

   # Make the directory
   exec mkdir ${simLibOutDir}

   # Configure the simlib compiler
   config_compile_simlib -simulator vcs_mx \
   -cfgopt {vcs_mx.vhdl.unisim:   -nc -l +v2k -xlrm -kdb } \
   -cfgopt {vcs_mx.vhdl.unimacro: -nc -l +v2k -xlrm -kdb } \
   -cfgopt {vcs_mx.vhdl.unifast:  -nc -l +v2k -xlrm -kdb } \
   -cfgopt {vcs_mx.vhdl.secureip: -nc -l      -xlrm -kdb } \
   -cfgopt {vcs_mx.vhdl.xpm:      -nc -l +v2k -xlrm -kdb } \
   -cfgopt {vcs_mx.verilog.unisim:   -sverilog -nc +v2k +define+XIL_TIMING -kdb } \
   -cfgopt {vcs_mx.verilog.unimacro: -sverilog -nc +v2k +define+XIL_TIMING -kdb } \
   -cfgopt {vcs_mx.verilog.unifast:  -sverilog -nc +v2k +define+XIL_TIMING -kdb } \
   -cfgopt {vcs_mx.verilog.simprim:  -sverilog -nc +v2k +define+XIL_TIMING -kdb } \
   -cfgopt {vcs_mx.verilog.secureip: -sverilog -nc      +define+XIL_TIMING -kdb } \
   -cfgopt {vcs_mx.verilog.xpm:      -sverilog -nc +v2k +define+XIL_TIMING -kdb }

   # Compile the simulation libraries
   catch { compile_simlib -force -simulator vcs_mx -family all -language all -library all -directory ${simLibOutDir} }

   ##################################################################
   ##                synopsys_sim.setup bug fix
   ##################################################################

   # Enable the LIBRARY_SCAN parameter in the synopsys_sim.setup file
   set LIBRARY_SCAN_OLD "LIBRARY_SCAN                    = FALSE"
   set LIBRARY_SCAN_NEW "LIBRARY_SCAN                    = TRUE"

   # open the files
   set in  [open ${simLibOutDir}/synopsys_sim.setup r]
   set out [open ${simLibOutDir}/synopsys_sim.temp  w]

   # Find and replace the LIBRARY_SCAN parameter
   while { [eof ${in}] != 1 } {
      gets ${in} line
      if { ${line} == ${LIBRARY_SCAN_OLD} } {
         puts ${out} ${LIBRARY_SCAN_NEW}
      } else {
         puts ${out} ${line}
      }
   }

   # Close the files
   close ${in}
   close ${out}

   # over-write the existing file
   exec mv -f ${simLibOutDir}/synopsys_sim.temp ${simLibOutDir}/synopsys_sim.setup

}

#####################################################################################################
## Setup Vivado's VCS environment
#####################################################################################################

# Set VCS as target_simulator
set_property target_simulator "VCS" [current_project]
set_property compxlib.vcs_compiled_library_dir ${simLibOutDir} [current_project]

# Configure VCS settings
set_property -name {vcs.compile.vhdlan.more_options} -value ${vhdlanOpt} -objects [get_filesets sim_1]
set_property -name {vcs.compile.vlogan.more_options} -value ${vloganOpt} -objects [get_filesets sim_1]
set_property -name {vcs.elaborate.vcs.more_options}  -value ${elabOpt}   -objects [get_filesets sim_1]
set_property -name {vcs.elaborate.debug_pp}          -value {false}      -objects [get_filesets sim_1]
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
export_simulation -force -absolute_path -simulator vcs -include ${include} -define ${define} -lib_map_path ${simLibOutDir} -directory ${simTbOutDir}/

#####################################################################################################
## Build the simlink directory (required for softrware co-simulation)
#####################################################################################################

set rogueSimPath [get_files -compile_order sources -used_in simulation {RogueTcpStream.vhd RogueTcpMemory.vhd RogueSideBand.vhd}]
if { ${rogueSimPath} != "" } {

   # Set the flag true
   set rogueSimEn true

   # Check the zeromq library exists and its version
   set err_ret [catch {exec pkg-config --exists {libzmq >= 4.1.0} --print-errors} libzmq]
   if { ${libzmq} != "" } {
      puts "\n\n\n\n\n********************************************************"
      if { [string match "*Package libzmq was not found*" ${libzmq}] == 1 } {
         puts "libzmq package was not found"
         puts "Please make sure that you have libzmq installed"
         puts "or have sourced the necessary rogue setup scripts"
      } else {
         puts ${libzmq}
      }
      puts "********************************************************\n\n\n\n\n"
      exit -1
   }

   # Create the setup environment script: C-SHELL
   set envScript [open ${simTbOutDir}/setup_env.csh  w]
   puts  ${envScript} "limit stacksize 60000"
   set LD_LIBRARY_PATH "setenv LD_LIBRARY_PATH \${LD_LIBRARY_PATH}:${simTbOutDir}"
   puts  ${envScript} ${LD_LIBRARY_PATH}
   close ${envScript}

   # Create the setup environment script: S-SHELL
   set envScript [open ${simTbOutDir}/setup_env.sh  w]
   puts  ${envScript} "ulimit -S -s 60000"
   set LD_LIBRARY_PATH "export LD_LIBRARY_PATH=\${LD_LIBRARY_PATH}:${simTbOutDir}"
   puts  ${envScript} ${LD_LIBRARY_PATH}
   close ${envScript}

   # Find the surf/axi/simlink/src directory
   set simTbDirName [file dirname [lindex ${rogueSimPath} 0]]
   set simLinkDir   ${simTbDirName}/../src/

   # Move the working directory to the simlink directory
   cd ${simLinkDir}

   # Set up the
   set ::env(SIMLINK_PWD) ${simLinkDir}

   # Run the Makefile
   exec make

   # Copy the library to the binary output directory
   exec cp -f [glob -directory ${simLinkDir} *.so] ${simTbOutDir}/.

   # Remove the output binary files from the source tree
   exec make clean

   # Move back to simulation target directory
   cd $::env(PROJ_DIR)

} else {
   set rogueSimEn false
}


#####################################################################################################
## Customization of the executable bash (.sh) script
#####################################################################################################

set err_ret [catch {get_files -compile_order sources -used_in simulation {*.v}}  vList]
set err_ret [catch {get_files -compile_order sources -used_in simulation {*.vh}} vhList]
set err_ret [catch {get_files -compile_order sources -used_in simulation {*.sv}} svList]

set vlogan_opts_old   "vlogan_opts=\"-full64"
set vhdlan_opts_old   "vhdlan_opts=\"-full64"
set vcs_elab_opts_old "vcs_elab_opts=\"-full64"
set surf_glbl_old     "surf.glbl -o simv"

set vlogan_opts_new   "${vlogan_opts_old} ${vloganOpt}"
set vhdlan_opts_new   "${vhdlan_opts_old} ${vhdlanOpt}"
set vcs_elab_opts_new "${vcs_elab_opts_old} ${elabOpt}"
set surf_glbl_new      "-o simv"

# Copy of all the Xilinx IP core datafile
set list ""
set list_rc [catch {
   set list [glob -directory ${simTbOutDir}/vcs/ *.dat *.coe *.mem *.edif *.mif]
} _RESULT]
if { ${list} != "" } {
   foreach pntr ${list} {
      exec cp -f ${pntr} ${simTbOutDir}/.
   }
}

# open the files
set in  [open ${simTbOutDir}/vcs/${simTbFileName}.sh r]
set out [open ${simTbOutDir}/sim_vcs_mx.sh  w]

# Find and replace the AFS path
while { [eof ${in}] != 1 } {

   gets ${in} line

   # Do not execute the simulation in sim_vcs_mx.sh build script
   if { [string match "*simulate.do" ${line}] } {
      set line "  echo \"Ready to simulate\""

   }

   # Replace ${simTbFileName}_simv with the simv
   set replaceString "${simTbFileName}_simv simv"
   set line [string map ${replaceString}  ${line}]

   # Update the compile options (fix bug in export_simulation not including more_options properties)
   if { [VersionCompare 2022.1] <= 0 } {
      set line [string map [list ${vlogan_opts_old}   ${vlogan_opts_new}]   ${line}]
      set line [string map [list ${vhdlan_opts_old}   ${vhdlan_opts_new}]   ${line}]
      set line [string map [list ${vcs_elab_opts_old} ${vcs_elab_opts_new}] ${line}]
   }

   # Change the glbl.v path (Vivado 2017.2 fix)
   set replaceString "behav/vcs/glbl.v glbl.v"
   set line [string map ${replaceString}  ${line}]

   # Remove additional/redundant command line switch '-l[og]'
   set line [string map {" -l .tmp_log" ""} ${line}]
   if { [string match "*vhdlan.log 2>/dev/null" ${line}] } {
      set line "  2>&1 | tee -a vhdlan.log"
   }
   if { [string match "*vlogan.log 2>/dev/null" ${line}] } {
      set line "  2>&1 | tee -a vlogan.log"
   }

   # Check if only a VHDL simulation
   if { ${vList}   == "" &&
        ${vhList}  == "" &&
        ${svList}  == "" } {
      # Remove xil_defaultlib.glbl (bug fix for Vivado compiling VCS script)
      set line [string map { "xil_defaultlib.glbl" "" } ${line}]
   }

   if { ${mixedSim} != true } {
      set line [string map [list ${surf_glbl_old} ${surf_glbl_new}] ${line}]
   }

   # Write to file
   puts ${out} ${line}
}

# Close the files
close ${in}
close ${out}

# Update the permissions
exec chmod 0755 ${simTbOutDir}/sim_vcs_mx.sh

#####################################################################################################
#####################################################################################################
#####################################################################################################

# Copy the glbl.v file
if { [file exists ${simTbOutDir}/vcs/glbl.v] == 1 } {
   # Change the glbl.v path (Vivado 2017.2 fix)
   exec cp -f ${simTbOutDir}/vcs/glbl.v ${simTbOutDir}/../glbl.v
   exec cp -f ${simTbOutDir}/vcs/glbl.v ${simTbOutDir}/glbl.v
}

# Target specific VCS script
SourceTclFile ${VIVADO_DIR}/post_vcs.tcl

# Close the project (required for cd function)
close_project

# VCS Complete Message
VcsCompleteMessage ${simTbOutDir} ${rogueSimEn}
