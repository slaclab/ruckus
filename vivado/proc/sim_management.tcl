##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

## Generate Verilog simulation models for a specific .dcp file
proc DcpToVerilogSim {dcpName} {
   source -quiet $::env(RUCKUS_DIR)/vivado/env_var.tcl
   set filePntr [get_files ${dcpName}.dcp]
   if { [file extension ${filePntr}] == ".dcp" } {
      ## Open the check point
      open_checkpoint ${filePntr}
      ## Generate the output file path
      set simName [file tail ${filePntr}]
      set simName [string map {".dcp" "_sim.v"} ${simName}]
      set simFile ${OUT_DIR}/${PROJECT}_project.sim/${simName}
      ## Write the simulation model to the build tree
      write_verilog -force -mode funcsim -file ${simFile}
      ## close the check point
      close_design
      # Add the Simulation Files
      add_files -quiet -fileset sim_1 ${simFile}
      # Force Absolute Path (not relative to project)
      set_property PATH_MODE AbsoluteFirst [get_files ${simFile}]
   }
}

## Generate .vho files for all .DCP in a project
proc CreateDcpVhoFiles {} {
   # Get a list of .bd files
   set dcpList [get_files {*.dcp}]
   # Check if any .bd files exist
   if { ${dcpList} != "" } {
      # Loop through the has block designs
      foreach dcppath ${dcpList} {
         # Get the base name
         set fbasename [file rootname ${dcppath}]
         # Open the check point
         open_checkpoint ${dcppath}
         # Write the simulation model to the build tree
         write_vhdl -force -mode pin_planning ${fbasename}.vho
         # close the check point
         close_design
         # Put the .vho file in a list and remove "extra" spaces and remove lines with `-`
         set vhoFile [lsearch -regexp -inline -all [lreplace [split [read [open ${fbasename}.vho r]] "\n"] end end] {^[^-]}]
         # Format for component declaration
         set vhoFile [string map {entity component} $vhoFile]
         set vhoFile [string map {end "end component"} $vhoFile]
         # Remove the first 3 lines and last 3 lines
         set vhoFile [lreplace [lreplace $vhoFile 0 3] end-2 end]
         # Write to overwrite the existing .vho file
         set fp [open ${fbasename}.vho w]
         foreach vhoLine ${vhoFile} {puts $fp $vhoLine}
         close $fp
      }
   }
}

## Print the VCS build complete message
proc VcsCompleteMessage {dirPath rogueSim} {
   puts "\n\n********************************************************"
   puts "The VCS simulation script has been generated."
   puts "To compile and run the simulation:"
   puts "\t\$ cd ${dirPath}/"
   if { ${rogueSim} == true } {
      if { $::env(SHELL) != "/bin/bash" } {
         puts "\t\$ source setup_env.csh"
      } else {
         puts "\t\$ source setup_env.sh"
      }
   }
   puts "\t\$ ./sim_vcs_mx.sh"
   puts "\t\$ ./simv -verdi &"
   puts "********************************************************\n\n"
}

## Print the MSIM build complete message
proc MsimCompleteMessage {dirPath rogueSim} {
   puts "\n\n********************************************************"
   puts "The Modelsim/Questa simulation script has been generated."
   puts "To compile and run the simulation:"
   puts "\t\$ cd ${dirPath}/"
   if { ${rogueSim} == true } {
      if { $::env(SHELL) != "/bin/bash" } {
         puts "\t\$ source setup_env.csh"
      } else {
         puts "\t\$ source setup_env.sh"
      }
   }
   puts "\t\$ ./sim_msim.sh"
   puts "********************************************************\n\n"
}
