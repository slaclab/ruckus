##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the 
## top-level directory of this distribution and at: 
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
## No part of 'SLAC Firmware Standard Library', including this file, 
## may be copied, modified, propagated, or distributed except according to 
## the terms contained in the LICENSE.txt file.
##############################################################################

# Get variables and procedures
source -quiet $::env(RUCKUS_DIR)/vivado_env_var.tcl
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

proc VcsVersionCheck { } {
   # List of supported VCS versions
   set supported "M-2017.03"
   
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
   scan $grepVersion "vcs script version : %s\n%s" VersionNumber blowoff
   set retVar -1
   
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

# Setup variables
set simLibOutDir ${OUT_DIR}/vcs_library
set simTbOutDir ${OUT_DIR}/${PROJECT}_project.sim/sim_1/behav
set simTbFileName [get_property top [get_filesets sim_1]]

# Set the compile/elaborate options
set compOpt "-nc -l +v2k -xlrm"
set elabOpt "+warn=none"

#####################################################################################################
## Compile the VCS Simulation Library
#####################################################################################################  

# Compile the libraries for VCS
if { [file exists ${simLibOutDir}] != 1 } {  
 
   # Make the directory
   exec mkdir ${simLibOutDir}
   
   # Compile the simulation libraries
   compile_simlib -directory ${simLibOutDir} -family [getFpgaFamily] -simulator vcs_mx -no_ip_compile
   
   # Set VCS as target_simulator
   set_property target_simulator "VCS" [current_project]
   set_property compxlib.vcs_compiled_library_dir ${simLibOutDir} [current_project]
   
   # Configure VCS settings
   set_property -name {vcs.compile.vhdlan.more_options} -value ${compOpt} -objects [get_filesets sim_1]
   set_property -name {vcs.compile.vlogan.more_options} -value ${compOpt} -objects [get_filesets sim_1]   
   set_property -name {vcs.elaborate.vcs.more_options}  -value ${elabOpt} -objects [get_filesets sim_1]
   set_property -name {vcs.elaborate.debug_pp}          -value {false}    -objects [get_filesets sim_1]
   set_property nl.process_corner fast [get_filesets sim_1]   
   set_property unifast true [get_filesets sim_1]
   
   ##################################################################
   ##                synopsys_sim.setup bug fix
   ##################################################################

   # Enable the LIBRARY_SCAN parameter in the synopsys_sim.setup file
   set LIBRARY_SCAN_OLD "LIBRARY_SCAN                    = FALSE"
   set LIBRARY_SCAN_NEW "LIBRARY_SCAN                    = TRUE"

   # open the files
   set in  [open ${OUT_DIR}/vcs_library/synopsys_sim.setup r]
   set out [open ${OUT_DIR}/vcs_library/synopsys_sim.temp  w]

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
   exec mv -f ${OUT_DIR}/vcs_library/synopsys_sim.temp ${OUT_DIR}/vcs_library/synopsys_sim.setup

}

#####################################################################################################
## Export the Simulation
#####################################################################################################  

# Update the compile order
update_compile_order -quiet -fileset sim_1

# Export Xilinx & User IP Cores
generate_target {simulation} [get_ips]
export_ip_user_files -no_script

# Launch the scripts generator 
set include [get_property include_dirs   [get_filesets sim_1]]; # Verilog only
set define  [get_property verilog_define [get_filesets sim_1]]; # Verilog only
export_simulation -absolute_path -force -simulator vcs -include ${include} -define ${define} -lib_map_path ${simLibOutDir} -directory ${simTbOutDir}/   

#####################################################################################################
## Build the simlink directory (required for softrware co-simulation)
#####################################################################################################   
set rogueSimPath [get_files -compile_order sources -used_in simulation {RogueStreamSim.vhd}]
set rogueSimEn false
if { ${rogueSimPath} != "" } {

   # Set the flag true
   set rogueSimEn true 
   
   # Check the zeromq library exists and its version
   set err_ret [catch {exec pkg-config --exists {libzmq >= 4.2.0} --print-errors} libzmq]   
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
   set LD_LIBRARY_PATH "setenv LD_LIBRARY_PATH ${simTbOutDir}:$::env(LD_LIBRARY_PATH)"
   puts  ${envScript} ${LD_LIBRARY_PATH} 
   close ${envScript} 

   # Create the setup environment script: S-SHELL
   set envScript [open ${simTbOutDir}/setup_env.sh  w]
   puts  ${envScript} "ulimit -S -s 60000"
   set LD_LIBRARY_PATH "export LD_LIBRARY_PATH=$::env(LD_LIBRARY_PATH):${simTbOutDir}"
   puts  ${envScript} ${LD_LIBRARY_PATH} 
   close ${envScript}          

   # Find the surf/axi/simlink/src directory
   set simTbDirName [file dirname ${rogueSimPath}]
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

set vlogan_opts_new   "${vlogan_opts_old} ${compOpt}"
set vhdlan_opts_new   "${vhdlan_opts_old} ${compOpt}"
set vcs_elab_opts_new "${vcs_elab_opts_old} ${elabOpt}"

# open the files
set in  [open ${simTbOutDir}/vcs/${simTbFileName}.sh r]
set out [open ${simTbOutDir}/sim_vcs_mx.sh  w]

# Find and replace the AFS path 
while { [eof ${in}] != 1 } {
   
   gets ${in} line

   set simString "  simulate"
   if { ${line} == ${simString} } {
      set simString "  source ${simTbOutDir}/setup_env.sh"
      puts ${out} ${simString}
   } else {              
         
      # Replace ${simTbFileName}_simv with the simv
      set replaceString "${simTbFileName}_simv simv"
      set line [string map ${replaceString}  ${line}]
      
      # Update the compile options (fix bug in export_simulation not including more_options properties)
      set line [string map [list ${vlogan_opts_old}   ${vlogan_opts_new}]   ${line}]
      set line [string map [list ${vhdlan_opts_old}   ${vhdlan_opts_new}]   ${line}]
      set line [string map [list ${vcs_elab_opts_old} ${vcs_elab_opts_new}] ${line}]      

      # Change the glbl.v path (Vivado 2017.2 fix)
      set replaceString "behav/vcs/glbl.v glbl.v"
      set line [string map ${replaceString}  ${line}]  
      
      # Check if only a VHDL simulation
      if { ${vList}   == "" &&
           ${vhList}  == "" &&
           ${svList}  == "" } {
         # Remove xil_defaultlib.glbl (bug fix for Vivado compiling VCS script)
         set line [string map { "xil_defaultlib.glbl" "" } ${line}]
      }
      
      # Write to file
      puts ${out} ${line}
   }      
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

# Close the project (required for cd function)
close_project

# Target specific VCS script
SourceTclFile ${VIVADO_DIR}/vcs.tcl

# VCS Complete Message
VcsCompleteMessage ${simTbOutDir} ${rogueSimEn}
