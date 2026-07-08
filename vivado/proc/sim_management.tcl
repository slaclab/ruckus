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
   puts "\t\$ ./simv -verdi& (or ./simv -gui=dve&)"
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

## Return the Rogue co-sim source files (RogueTcpStream/Memory/SideBand) in the
## simulation fileset, or "" if none -- the shared detector for whether a
## project uses the Rogue co-sim. Pass "vcs" to surface the get_files warning
## when absent, or "xsim" to suppress it (the xsim pre-compile hook runs for
## every xsim project, so a non-Rogue project must stay quiet). Called from
## vivado/vcs.tcl, vivado/xsim.tcl, vivado/sources.tcl, vivado/run/pre/xsim.tcl.
proc RogueSimSources {backend} {
   set rogueFiles {RogueTcpStream.vhd RogueTcpMemory.vhd RogueSideBand.vhd}
   if { ${backend} == "vcs" } {
      return [get_files -compile_order sources -used_in simulation ${rogueFiles}]
   } else {
      return [get_files -quiet -compile_order sources -used_in simulation ${rogueFiles}]
   }
}

## Verify libzmq >= 4.1.0 is available via pkg-config for the Rogue co-sim,
## printing a clear diagnostic and exiting on failure. Called by the VCS flow
## (vivado/vcs.tcl) and the xsim pre-compile hook (vivado/run/pre/xsim.tcl).
proc RogueCheckLibZmq {} {
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
}

## LD_PRELOAD a libstdc++.so.6 new enough for the Rogue xsim co-sim's libzmq.
## Vivado's loader wrapper prepends its bundled libstdc++ (e.g. GLIBCXX 3.4.25
## in 2025.2) to LD_LIBRARY_PATH, which is too old for a libzmq built against a
## newer GCC. LD_PRELOAD takes precedence over LD_LIBRARY_PATH, so it forces the
## newer GLIBCXX regardless of the loader's path injection (a plain
## LD_LIBRARY_PATH prepend would lose to the loader). Called from both the GUI
## pre-compile hook (vivado/run/pre/xsim.tcl) and the batch simulate path
## (vivado/xsim.tcl). Exits with an error if no suitable libstdc++ is found.
proc RoguePreloadLibStdCpp {} {
   set candidates {}
   # 1) libstdc++ from the prefix that ships libzmq (most ABI-consistent)
   if { [catch {exec pkg-config --variable=libdir libzmq} zmqLibDir] == 0 && ${zmqLibDir} != "" } {
      lappend candidates ${zmqLibDir}/libstdc++.so.6
   }
   # 2) active gcc's libstdc++ (distro-layout agnostic)
   if { [catch {exec gcc -print-file-name=libstdc++.so.6} gccLib] == 0 && [file exists ${gccLib}] } {
      lappend candidates ${gccLib}
   }
   # 3) common system locations: RHEL/Rocky, then Debian/Ubuntu
   lappend candidates /usr/lib64/libstdc++.so.6
   lappend candidates /usr/lib/x86_64-linux-gnu/libstdc++.so.6
   # Prepend the first existing candidate, preserving any existing LD_PRELOAD
   foreach lib ${candidates} {
      if { [file exists ${lib}] } {
         if { [info exists ::env(LD_PRELOAD)] && $::env(LD_PRELOAD) != "" } {
            set ::env(LD_PRELOAD) "${lib}:$::env(LD_PRELOAD)"
         } else {
            set ::env(LD_PRELOAD) ${lib}
         }
         return
      }
   }
   # Fail loudly rather than let the sim die with an opaque GLIBCXX loader error
   puts "\n\n\n\n\n********************************************************"
   puts "ERROR: no libstdc++.so.6 with a modern GLIBCXX found for the Rogue xsim co-sim."
   puts "Install a newer libstdc++ or source the rogue setup scripts, then retry."
   puts "********************************************************\n\n\n\n\n"
   exit -1
}
