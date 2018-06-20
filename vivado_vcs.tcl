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
   set git_rc [catch {
      exec vcs -ID | grep version
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
   if  { ${retVar} < 0 } {
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

#####################################################################################################
## Compile the VCS Simulation Library
#####################################################################################################  

# Compile the libraries for VCS
if { [file exists ${simLibOutDir}] != 1 } {  
 
   # Make the directory
   exec mkdir ${simLibOutDir}
   
   # Compile the simulation libraries
   compile_simlib -directory ${simLibOutDir} -family [getFpgaFamily] -simulator vcs_mx -no_ip_compile
   
   # Configure Vivado to generate the VCS scripts
   set_property target_simulator "VCS" [current_project]
   set_property compxlib.vcs_compiled_library_dir ${simLibOutDir} [current_project]   
   
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
   cd $::DIR_PATH

}

#####################################################################################################   
## Customization of the executable bash (.sh) script 
#####################################################################################################   

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
      
      # By default: Mask off warnings during elaboration
      set line [string map {"vlogan_opts=\"-full64\""   "vlogan_opts=\"-full64 -nc -l +v2k -xlrm\""} ${line}]          
      set line [string map {"vhdlan_opts=\"-full64\""   "vhdlan_opts=\"-full64 -nc -l +v2k -xlrm\""} ${line}]          
      set line [string map {"vcs_elab_opts=\"-full64\"" "vcs_elab_opts=\"-full64 +warn=none\""}      ${line}]     

      # Change the glbl.v path (Vivado 2017.2 fix)
      set replaceString "behav/vcs/glbl.v glbl.v"
      set line [string map ${replaceString}  ${line}]  
      
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
