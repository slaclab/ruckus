##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

## \file shared/verilog_proc.tcl
# \brief Vivado-free Verilog/SystemVerilog source loader shared by the
# iverilog/ and verilator/ flows: loadRuckusTcl, loadSource, an ordered
# deduplicated filelist, header include-dir collection and a VHDL hard error.

## Returns the FPGA family string
proc getFpgaFamily { } {
   # Legacy Vivado function: not-supported
   return "not-supported"
}

## Returns the FPGA family string
proc getFpgaArch { } {
   # Legacy Vivado function: not-supported
   return "not-supported"
}

## Returns true is Versal
proc isVersal { } {
   # Legacy Vivado function: not-supported
   return false;
}

###############################################################
#### Loading Source Code Functions ############################
###############################################################

## Open ruckus.tcl file
proc loadRuckusTcl { filePath {flags ""} } {
   puts "loadRuckusTcl: ${filePath} ${flags}"
   # Make a local copy of global variable
   set LOC_PATH $::DIR_PATH
   # Make a local copy of global variable
   set ::DIR_PATH ${filePath}
   # Open the TCL file
   if { [file exists ${filePath}/ruckus.tcl] == 1 } {
      source ${filePath}/ruckus.tcl
   } else {
      puts "\n\n\n\n\n********************************************************"
      puts "loadRuckusTcl: ${filePath}/ruckus.tcl doesn't exist"
      puts "********************************************************\n\n\n\n\n"
      exit -1
   }
   # Revert the global variable back to original value
   set ::DIR_PATH ${LOC_PATH}
}

## Reset the ordered source lists. Called only from load_source_code.tcl, never
## at file scope: every ruckus.tcl (including surf/simlink/ruckus.tcl) re-sources
## $::env(RUCKUS_PROC_TCL) mid-load, and a file-scope reset would silently
## discard everything loaded before that point.
proc VerilogInitSources { } {
   set ::VERILOG_SRC_LIST  {}
   set ::VERILOG_INC_LIST  {}
   set ::VERILOG_VHDL_LIST {}
}

## Classify one real path into the ordered source list, the include-dir list
## or the VHDL offender list, deduplicating each by real path.
proc VerilogAddFile {path} {
   set realPath [GetRealPath ${path}]
   set fileExt [file extension ${realPath}]
   if { ${fileExt} eq {.v} || ${fileExt} eq {.sv} } {
      if { [lsearch -exact $::VERILOG_SRC_LIST ${realPath}] == -1 } {
         lappend ::VERILOG_SRC_LIST ${realPath}
      }
   } elseif { ${fileExt} eq {.vh} || ${fileExt} eq {.svh} } {
      set incDir [file dirname ${realPath}]
      if { [lsearch -exact $::VERILOG_INC_LIST ${incDir}] == -1 } {
         lappend ::VERILOG_INC_LIST ${incDir}
      }
   } elseif { ${fileExt} eq {.vhd} || ${fileExt} eq {.vhdl} } {
      if { [lsearch -exact $::VERILOG_VHDL_LIST ${realPath}] == -1 } {
         lappend ::VERILOG_VHDL_LIST ${realPath}
      }
   }
}

## Function to load RTL files
proc loadSource args {

   # Strip out the -sim_only flag
   if {[string match {*-sim_only*} $args]} {
      set args [string map {"-sim_only" ""} $args]
   }

   # Parse the list of args
   array set params $args

   if {![info exists params(-path)]} {
      set has_path 0
   } else {
      set has_path 1
   }

   if {![info exists params(-dir)]} {
      set has_dir 0
   } else {
      set has_dir 1
   }

   # -lib is accepted and ignored: Verilog has no libraries

   # Check for error state
   if {${has_path} && ${has_dir}} {
      puts "\n\n\n\n\n********************************************************"
      puts "loadSource: Cannot specify both -path and -dir"
      puts "********************************************************\n\n\n\n\n"
      exit -1
   # Load a single file
   } elseif {$has_path} {
      # Check if file doesn't exist
      if { [file exists $params(-path)] != 1 } {
         puts "\n\n\n\n\n********************************************************"
         puts "loadSource: $params(-path) doesn't exist"
         puts "********************************************************\n\n\n\n\n"
         exit -1
      } else {
         # Check the file extension
         set fileExt [file extension $params(-path)]
         if { ${fileExt} eq {.v}   ||
              ${fileExt} eq {.sv}  ||
              ${fileExt} eq {.vh}  ||
              ${fileExt} eq {.svh} ||
              ${fileExt} eq {.vhd} ||
              ${fileExt} eq {.vhdl} } {
            VerilogAddFile $params(-path)
         } else {
            puts "\n\n\n\n\n********************************************************"
            puts "loadSource: $params(-path) does not have a \[.v,.sv,.vh,.svh\] file extension"
            puts "********************************************************\n\n\n\n\n"
            exit -1
         }
      }
   # Load all files from a directory
   } elseif {$has_dir} {
      # Check if directory doesn't exist
      if { [file exists $params(-dir)] != 1 } {
         puts "\n\n\n\n\n********************************************************"
         puts "loadSource: $params(-dir) doesn't exist"
         puts "********************************************************\n\n\n\n\n"
         exit -1
      } else {
         # Get a sorted list of all Verilog/SystemVerilog files (non-recursive)
         set list [lsort [glob -nocomplain -directory $params(-dir) \
            *.v *.sv *.vh *.svh *.vhd *.vhdl]]
         if { ${list} != "" } {
            foreach pntr ${list} {
               VerilogAddFile ${pntr}
            }
         } else {
            puts "\n\n\n\n\n********************************************************"
            puts "loadSource: $params(-dir) directory does not have any \[.v,.sv,.vh,.svh\] files"
            puts "********************************************************\n\n\n\n\n"
            exit -1
         }
      }
   }
}

## Write the ordered, deduplicated filelist consumed by iverilog -c / verilator -f.
## Hard-errors on any loaded VHDL (D-08) or an empty source list.
proc VerilogWriteFilelist {filePath} {
   if { [llength $::VERILOG_VHDL_LIST] > 0 } {
      puts "\n\n\n\n\n********************************************************"
      puts "VerilogWriteFilelist: VHDL sources are not supported by the Icarus Verilog and Verilator flows"
      foreach vhdlPath $::VERILOG_VHDL_LIST {
         puts ${vhdlPath}
      }
      puts "If this VHDL came from surf, loadRuckusTcl \$::env(MODULES)/surf/simlink instead of all of surf"
      puts "********************************************************\n\n\n\n\n"
      exit -1
   }
   if { [llength $::VERILOG_SRC_LIST] == 0 } {
      puts "\n\n\n\n\n********************************************************"
      puts "VerilogWriteFilelist: no .v or .sv sources were loaded"
      puts "********************************************************\n\n\n\n\n"
      exit -1
   }
   set out [open ${filePath} w]
   foreach incDir $::VERILOG_INC_LIST {
      puts ${out} "+incdir+${incDir}"
   }
   foreach srcPath $::VERILOG_SRC_LIST {
      puts ${out} ${srcPath}
   }
   close ${out}
   puts "VerilogWriteFilelist: wrote [llength $::VERILOG_SRC_LIST] source(s) and [llength $::VERILOG_INC_LIST] include dir(s) to ${filePath}"
}

###############################################################
#### Tool And Version Checks ###################################
###############################################################

## Resolve a tool on PATH or hard-error. Returns the resolved binary path.
proc VerilogCheckTool {tool} {
   set path [auto_execok ${tool}]
   if { ${path} eq "" } {
      puts "\n\n\n\n\n********************************************************"
      puts "VerilogCheckTool: ${tool} not found in PATH"
      puts "********************************************************\n\n\n\n\n"
      exit -1
   }
   return [lindex ${path} 0]
}

## Resolve a tool, run it to check its version string against a floor, and
## hard-error below the floor. There is no bypass variable. Never feeds the
## captured text to expr (a Verilator "020" minor would be read as octal).
proc VerilogCheckVersion {tool versionArg pattern floor} {
   set path [VerilogCheckTool ${tool}]
   catch {exec ${path} ${versionArg}} versionOutput
   if { ![regexp ${pattern} ${versionOutput} fullMatch versionText] } {
      puts "\n\n\n\n\n********************************************************"
      puts "VerilogCheckVersion: cannot parse the ${tool} version from '${path} ${versionArg}' output"
      puts "********************************************************\n\n\n\n\n"
      exit -1
   }
   scan ${versionText} "%d.%d" foundMajor foundMinor
   scan ${floor} "%d.%d" floorMajor floorMinor
   set foundTag "${foundMajor}.${foundMinor}.0"
   set floorTag "${floorMajor}.${floorMinor}.0"
   if { [CompareTags ${foundTag} ${floorTag}] == 0 } {
      puts "\n\n\n\n\n********************************************************"
      puts "VerilogCheckVersion: found ${tool} ${versionText} at ${path}"
      puts "VerilogCheckVersion: ruckus requires ${tool} ${floor} or newer"
      puts "********************************************************\n\n\n\n\n"
      exit -1
   }
   puts "VerilogCheckVersion: ${tool} ${versionText} (${path})"
}

###############################################################
#### Rogue SimLink Library Build ###############################
###############################################################

## Build the surf SimLink backend library in-tree, stage it in $OUT_DIR and
## clean the surf tree, mirroring the VCS/xsim in-tree build/copy/clean
## pattern. Skips entirely when no Rogue leaf is in the loaded filelist (D-03).
proc VerilogSimLinkBuild {artifact} {
   set rogueLeaves {RogueTcpStream.sv RogueTcpMemory.sv RogueSideBand.sv}
   set backendDir ""
   set fp [open "$::env(OUT_DIR)/$::env(PROJECT).f" r]
   while { [gets ${fp} line] >= 0 } {
      if { [string index ${line} 0] eq {+} } {
         continue
      }
      if { [lsearch -exact ${rogueLeaves} [file tail ${line}]] != -1 } {
         set backendDir [file dirname ${line}]
         break
      }
   }
   close ${fp}

   if { ${backendDir} eq "" } {
      puts "VerilogSimLinkBuild: no Rogue SimLink sources loaded, skipping the SimLink library build"
      return
   }

   if { ![file exists ${backendDir}/Makefile] } {
      puts "\n\n\n\n\n********************************************************"
      puts "VerilogSimLinkBuild: ${backendDir} has no Makefile"
      puts "********************************************************\n\n\n\n\n"
      exit -1
   }

   VerilogCheckTool gcc
   VerilogCheckTool pkg-config
   RogueCheckLibZmq

   cd ${backendDir}
   set buildRc [catch {exec make >@stdout 2>@stderr} buildResult]
   if { ${buildRc} } {
      puts "\n\n\n\n\n********************************************************"
      puts "VerilogSimLinkBuild: make failed in ${backendDir}"
      puts "********************************************************\n\n\n\n\n"
      exit -1
   }
   if { ![file exists "${backendDir}/${artifact}"] } {
      puts "\n\n\n\n\n********************************************************"
      puts "VerilogSimLinkBuild: ${backendDir}/${artifact} was not produced by make"
      puts "********************************************************\n\n\n\n\n"
      exit -1
   }
   file copy -force "${backendDir}/${artifact}" $::env(OUT_DIR)
   exec make clean >@stdout 2>@stderr
   cd $::env(PROJ_DIR)
}
