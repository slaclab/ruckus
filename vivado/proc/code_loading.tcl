##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

package require cmdline

## Returns the FPGA family string
proc getFpgaFamily { } {
   return [get_property FAMILY [get_property {PART} [current_project]]]
}

## Returns the FPGA family string
proc getFpgaArch { } {
   return [get_property ARCHITECTURE [get_property {PART} [current_project]]]
}

## Returns true is Versal
proc isVersal { } {
   if { [getFpgaArch] != "versal" } {
      return false;
   } else {
      return true;
   }
}

## Open ruckus.tcl file
proc loadRuckusTcl { filePath {flags ""} } {
   puts "loadRuckusTcl: ${filePath} ${flags}"
   # Make a local copy of global variable
   set LOC_PATH $::DIR_PATH
   # Make a local copy of global variable
   set ::DIR_PATH ${filePath}
   # Open the TCL file
   if { [file exists ${filePath}/ruckus.tcl] == 1 } {
      if { ${flags} == "debug" } {
         source ${filePath}/ruckus.tcl
      } else {
         source ${filePath}/ruckus.tcl -notrace
      }
   } else {
      puts "\n\n\n\n\n********************************************************"
      puts "loadRuckusTcl: ${filePath}/ruckus.tcl doesn't exist"
      puts "********************************************************\n\n\n\n\n"
      exit -1
   }
   # Revert the global variable back to orginal value
   set ::DIR_PATH ${LOC_PATH}
   # Keep a history of all the load paths
   set ::DIR_LIST "$::DIR_LIST ${filePath}"
}

## Function to load RTL files
proc loadSource args {
   set options {
      {sim_only         "flag for tagging simulation file(s)"}
      {path.arg      "" "path to a single file"}
      {dir.arg       "" "path to a directory of file(s)"}
      {lib.arg       "" "library for file(s)"}
      {fileType.arg  "" "library for file(s)"}
   }
   set usage ": loadSource \[options] ...\noptions:"
   array set params [::cmdline::getoptions args $options $usage]
   set has_path      [expr {[string length $params(path)]     > 0}]
   set has_dir       [expr {[string length $params(dir)]      > 0}]
   set has_lib       [expr {[string length $params(lib)]      > 0}]
   set has_fileType  [expr {[string length $params(fileType)] > 0}]
   if { $params(sim_only) } {
      set fileset "sim_1"
   } else {
      set fileset "sources_1"
   }
   # Check for error state
   if {${has_path} && ${has_dir}} {
      puts "\n\n\n\n\n********************************************************"
      puts "loadSource: Cannot specify both -path and -dir"
      puts "********************************************************\n\n\n\n\n"
      exit -1
   # Load a single file
   } elseif {$has_path} {
      # Check if file doesn't exist
      if { [file exists $params(path)] != 1 } {
         puts "\n\n\n\n\n********************************************************"
         puts "loadSource: $params(path) doesn't exist"
         puts "********************************************************\n\n\n\n\n"
         exit -1
      } else {
         # Check the file extension
         set fileExt [file extension $params(path)]
         if { ${fileExt} eq {.vhd} ||
              ${fileExt} eq {.vhdl}||
              ${fileExt} eq {.v}   ||
              ${fileExt} eq {.vh}  ||
              ${fileExt} eq {.sv}  ||
              ${fileExt} eq {.svh} ||
              ${fileExt} eq {.dat} ||
              ${fileExt} eq {.coe} ||
              ${fileExt} eq {.mem} ||
              ${fileExt} eq {.edif}||
              ${fileExt} eq {.dcp} } {
            # Check if file doesn't exist in project
            if { [get_files -quiet $params(path)] == "" } {
               # Add the RTL Files
               set src_rc [catch {add_files -fileset ${fileset} $params(path)} _RESULT]
               if {$src_rc} {
                  puts "\n\n\n\n\n********************************************************"
                  puts ${_RESULT}
                  set gitLfsCheck "Runs 36-335"
                  if { [ string match *${gitLfsCheck}* ${_RESULT} ] } {
                     puts "Here's what the .DCP file looks like right now:"
                     puts [exec cat $params(path)]
                     puts "\nPlease do the following commands:"
                     puts "$ git-lfs install"
                     puts "$ git-lfs pull"
                     puts "$ git submodule foreach git-lfs pull"
                  }
                  puts "********************************************************\n\n\n\n\n"
                  exit -1
               }
               if { ${has_lib} } {
                  # Check if VHDL file
                  if { ${fileExt} eq {.vhd} ||
                       ${fileExt} eq {.vhdl} } {
                     set_property LIBRARY $params(lib) [get_files $params(path)]
                  }
               }
               if { ${has_fileType} } {
                  set_property FILE_TYPE $params(fileType) [get_files $params(path)]
               }
            }
         } else {
            puts "\n\n\n\n\n********************************************************"
            puts "loadSource: $params(path) does not have a \[.vhd,.vhdl,.v,.vh,.sv,.svh,.dat,.coe,.mem,.edif,.dcp\] file extension"
            puts "********************************************************\n\n\n\n\n"
            exit -1
         }
      }
   # Load all files from a directory
   } elseif {$has_dir} {
      # Check if directory doesn't exist
      if { [file exists $params(dir)] != 1 } {
         puts "\n\n\n\n\n********************************************************"
         puts "loadSource: $params(dir) doesn't exist"
         puts "********************************************************\n\n\n\n\n"
         exit -1
      } else {
         # Get a list of all RTL files
         set list ""
         set list_rc [catch {
            set list [glob -directory $params(dir) *.vhd *.vhdl *.v *.vh *.sv *.svh *.dat *.coe *.mem *.edif *.dcp]
         } _RESULT]
         # Load all the RTL files
         if { ${list} != "" } {
            foreach pntr ${list} {
               # Check if file doesn't exist in project
               if { [get_files -quiet ${pntr}] == "" } {
                  # Add the RTL Files
                  set src_rc [catch {add_files -fileset ${fileset} ${pntr}} _RESULT]
                  if {$src_rc} {
                     puts "\n\n\n\n\n********************************************************"
                     puts ${_RESULT}
                     set gitLfsCheck "Runs 36-335"
                     if { [ string match *${gitLfsCheck}* ${_RESULT} ] } {
                        puts "Here's what the .DCP file looks like right now:"
                        puts [exec cat ${pntr}]
                        puts "\nPlease do the following commands:"
                        puts "$ git-lfs install"
                        puts "$ git-lfs pull"
                        puts "$ git submodule foreach git-lfs pull"
                     }
                     puts "********************************************************\n\n\n\n\n"
                     exit -1
                  }
                  if { ${has_lib} } {
                     # Check if VHDL file
                     set fileExt [file extension ${pntr}]
                     if { ${fileExt} eq {.vhd} ||
                          ${fileExt} eq {.vhdl} } {
                        set_property LIBRARY $params(lib) [get_files ${pntr}]
                     }
                  }
                  if { ${has_fileType} } {
                     set_property FILE_TYPE $params(fileType) [get_files ${pntr}]
                  }
               }
            }
         } else {
            puts "\n\n\n\n\n********************************************************"
            puts "loadSource: $params(dir) directory does not have any \[.vhd,.vhdl,.v,.vh,.sv,.svh,.dat,.coe,.mem,.edif,.dcp\] files"
            puts "********************************************************\n\n\n\n\n"
            exit -1
         }
      }
   }
}
# Helper: import/upgrade/regenerate one IP XCI/XCIX using import_ip
proc _import_and_refresh_ip {xci_path} {
   # Nominal IP name from filename (common case)
   set ip_name [file rootname [file tail $xci_path]]

   # If not already in the project, import it into sources_1
   set ip_obj [get_ips -quiet $ip_name]
   if { $ip_obj eq "" } {
      if {[catch { import_ip -srcset sources_1 $xci_path } err]} {
         puts "WARNING: import_ip failed for $xci_path: $err"
      }
      set ip_obj [get_ips -quiet $ip_name]
   }

   # If module_name differs from filename, find by matching FILE_NAME to our XCI
   if { $ip_obj eq "" } {
      set candidates [get_ips -quiet *]
      foreach c $candidates {
         set files [list]
         catch { set files [get_files -of_objects $c] }
         foreach f $files {
            if { [file normalize $f] eq [file normalize $xci_path] } {
               set ip_obj $c
               break
            }
         }
         if { $ip_obj ne "" } { break }
      }
   }

   if { $ip_obj eq "" } {
      puts "WARNING: Could not locate IP object after import for $xci_path."
      return
   }

   # Upgrade/retarget to current project part & Vivado version (clears 'locked')
   catch { upgrade_ip $ip_obj }

   # ---- IMPORTANT: set checkpoint property on the FILE object (not the IP) ----
   # Grab the .xci file object associated with this IP
   set xci_files [get_files -quiet -of_objects $ip_obj]
   # Filter down to the XCI itself
   set xci_only {}
   foreach f $xci_files {
      if {[string match *.xci $f]} { lappend xci_only $f }
   }
   if { [llength $xci_only] > 0 } {
      # This is the line your log complained about when it was applied to the IP object
      catch { set_property GENERATE_SYNTH_CHECKPOINT true $xci_only }
   }

   # Regenerate all products
   catch { reset_target all $ip_obj }
   if {[catch { generate_target all $ip_obj } gen_err]} {
      puts "WARNING: generate_target failed for $ip_obj: $gen_err"
   }

   # Sync ip_user_files/* into the proj so filesets pick them up
   catch { export_ip_user_files -of_objects $ip_obj -no_script -sync -force -quiet }

   # Optional: quick status without touching IP properties that may not exist
   catch { report_ip_status -name "ip_status_[string map {:: _} $ip_obj]" }
}

# Function to load IP core files (import_ip-only, fixed)
proc loadIpCore args {
   set options {
      {path.arg "" "path to a single file"}
      {dir.arg  "" "path to a directory of files"}
   }
   set usage ": loadIpCore \[options] ...\noptions:"
   array set params [::cmdline::getoptions args $options $usage]
   set has_path [expr {[string length $params(path)] > 0}]
   set has_dir  [expr {[string length $params(dir)] > 0}]

   if {${has_path} && ${has_dir}} {
      puts "\n\n********************************************************"
      puts "loadIpCore: Cannot specify both -path and -dir"
      puts "********************************************************\n\n"
      exit -1

   } elseif {$has_path} {
      if { [file exists $params(path)] != 1 } {
         puts "\n\n********************************************************"
         puts "loadIpCore: $params(path) doesn't exist"
         puts "********************************************************\n\n"
         exit -1
      }
      set ext [file extension $params(path)]
      if { $ext ni {.xci .xcix} } {
         puts "\n\n********************************************************"
         puts "loadIpCore: $params(path) does not have a \[.xci,.xcix] file extension"
         puts "********************************************************\n\n"
         exit -1
      }

      # Track for your globals (kept from your original)
      set strip [file rootname [file tail $params(path)]]
      set ::IP_LIST  "$::IP_LIST ${strip}"
      set ::IP_FILES "$::IP_FILES $params(path)"

      _import_and_refresh_ip $params(path)

   } elseif {$has_dir} {
      if { [file exists $params(dir)] != 1 } {
         puts "\n\n********************************************************"
         puts "loadIpCore: $params(dir) doesn't exist"
         puts "********************************************************\n\n"
         exit -1
      }
      set list ""
      set list_rc [catch { set list [glob -directory $params(dir) *.xci *.xcix] } _RESULT]
      if { $list eq "" } {
         puts "\n\n********************************************************"
         puts "loadIpCore: $params(dir) has no \[.xci,.xcix] files"
         puts "********************************************************\n\n"
         exit -1
      }
      foreach pntr $list {
         set strip [file rootname [file tail $pntr]]
         set ::IP_LIST  "$::IP_LIST ${strip}"
         set ::IP_FILES "$::IP_FILES ${pntr}"
         _import_and_refresh_ip $pntr
      }
   }

   # Refresh catalogs/filesets so reorder_files won't fail later
   catch { update_ip_catalog }
   catch { export_ip_user_files -of_objects [get_ips *] -no_script -sync -force -quiet }

   # Optional: consolidated status
   catch { report_ip_status -name ip_status_post_import }
}


## Function to load block design files
proc loadBlockDesign args {
   set options {
      {path.arg "" "path to a single file"}
      {dir.arg  "" "path to a directory of files"}
   }
   set usage ": loadBlockDesign \[options] ...\noptions:"
   array set params [::cmdline::getoptions args $options $usage]
   set has_path [expr {[string length $params(path)] > 0}]
   set has_dir  [expr {[string length $params(dir)] > 0}]
   # Check for error state
   if {${has_path} && ${has_dir}} {
      puts "\n\n\n\n\n********************************************************"
      puts "loadBlockDesign: Cannot specify both -path and -dir"
      puts "********************************************************\n\n\n\n\n"
      exit -1
   # Load a single file
   } elseif {$has_path} {
      # Check if file doesn't exist
      if { [file exists $params(path)] != 1 } {
         puts "\n\n\n\n\n********************************************************"
         puts "loadBlockDesign: $params(path) doesn't exist"
         puts "********************************************************\n\n\n\n\n"
         exit -1
      } else {
         # Check the file extension
         set fileExt [file extension $params(path)]
         if { ${fileExt} eq {.bd} ||
              ${fileExt} eq {.tcl} } {
            # Update the global list
            set fbasename [file rootname $params(path)]
            set ::BD_FILES "$::BD_FILES ${fbasename}.bd"
            # Check for .bd extension
            if { ${fileExt} eq {.bd} } {
               # Check if the block design file has already been loaded
               if { [get_files -quiet [file tail $params(path)]] == ""} {
                  # Add block design file
                  set locPath [import_files -force -norecurse $params(path)]
                  export_ip_user_files -of_objects [get_files ${locPath}] -force -quiet
               }
            # Else it's a .TCL extension
            } else {
               # Always load the block design TCL file
               source $params(path)
            }
         } else {
            puts "\n\n\n\n\n********************************************************"
            puts "loadBlockDesign: $params(path) does not have a \[.bd,.tcl\] file extension"
            puts "********************************************************\n\n\n\n\n"
            exit -1
         }
      }
   # Load all files from a directory
   } elseif {$has_dir} {
      # Check if directory doesn't exist
      if { [file exists $params(dir)] != 1 } {
         puts "\n\n\n\n\n********************************************************"
         puts "loadBlockDesign: $params(dir) doesn't exist"
         puts "********************************************************\n\n\n\n\n"
         exit -1
      } else {
         # Get a list of all block design files
         set list ""
         set list_rc [catch {
            set list [glob -directory $params(dir) *.bd *.tcl]
         } _RESULT]
         # Load all the block design files
         if { ${list} != "" } {
            foreach pntr ${list} {
               # Update the global list
               set fbasename [file rootname ${pntr}]
               set ::BD_FILES "$::BD_FILES ${fbasename}.bd"
               # Check for .bd extension
               set fileExt [file extension ${pntr}]
               if { ${fileExt} eq {.bd} } {
                  # Check if the block design file has already been loaded
                  if { [get_files -quiet [file tail ${pntr}]] == ""} {
                     # Add block design file
                     set locPath [import_files -force -norecurse ${pntr}]
                     export_ip_user_files -of_objects [get_files ${locPath}] -force -quiet
                  }
               # Else it's a .TCL extension
               } else {
                  # Always load the block design TCL file
                  source ${pntr}
               }
            }
         } else {
            puts "\n\n\n\n\n********************************************************"
            puts "loadBlockDesign: $params(dir) directory does not have any \[.bd,.tcl\] file extension"
            puts "********************************************************\n\n\n\n\n"
            exit -1
         }
      }
   }
}

## Function to load constraint files
proc loadConstraints args {
   set options {
      {path.arg "" "path to a single file"}
      {dir.arg  "" "path to a directory of files"}
   }
   set usage ": loadConstraints \[options] ...\noptions:"
   array set params [::cmdline::getoptions args $options $usage]
   set has_path [expr {[string length $params(path)] > 0}]
   set has_dir  [expr {[string length $params(dir)] > 0}]
   # Check for error state
   if {${has_path} && ${has_dir}} {
      puts "\n\n\n\n\n********************************************************"
      puts "loadConstraints: Cannot specify both -path and -dir"
      puts "********************************************************\n\n\n\n\n"
      exit -1
   # Load a single file
   } elseif {$has_path} {
      # Check if file doesn't exist
      if { [file exists $params(path)] != 1 } {
         puts "\n\n\n\n\n********************************************************"
         puts "loadConstraints: $params(path) doesn't exist"
         puts "********************************************************\n\n\n\n\n"
         exit -1
      } else {
         # Check the file extension
         set fileExt [file extension $params(path)]
         if { ${fileExt} eq {.xdc} ||
              ${fileExt} eq {.tcl} } {
            # Check if file doesn't exist in project
            if { [get_files -quiet $params(path)] == "" } {
               # Add the constraint Files
               add_files -fileset constrs_1 $params(path)
            }
         } else {
            puts "\n\n\n\n\n********************************************************"
            puts "loadConstraints: $params(path) does not have a \[.xdc,.tcl\] file extension"
            puts "********************************************************\n\n\n\n\n"
            exit -1
         }
      }
   # Load all files from a directory
   } elseif {$has_dir} {
      # Check if directory doesn't exist
      if { [file exists $params(dir)] != 1 } {
         puts "\n\n\n\n\n********************************************************"
         puts "loadConstraints: $params(dir) doesn't exist"
         puts "********************************************************\n\n\n\n\n"
         exit -1
      } else {
         # Get a list of all constraint files
         set list ""
         set list_rc [catch {
            set list [glob -directory $params(dir) *.xdc *.tcl]
         } _RESULT]
         # Load all the block design files
         if { ${list} != "" } {
            # Load all the constraint files
            foreach pntr ${list} {
               # Check if file doesn't exist in project
               if { [get_files -quiet ${pntr}] == "" } {
                  # Add the RTL Files
                  add_files -fileset constrs_1 ${pntr}
               }
            }
         } else {
            puts "\n\n\n\n\n********************************************************"
            puts "loadConstraints: $params(dir) directory does not have any \[.xdc,.tcl\] files"
            puts "********************************************************\n\n\n\n\n"
            exit -1
         }
      }
   }
}

## Function to check if the component.xml is different for new user ZIP IP core
## Returns True if they are different of IP not loaded yet
proc checkComponentXml { newIpPath repoPath } {
   # Define paths for the existing and new component.xml files
   set ipName [file rootname [file tail $newIpPath]]
   set oldComponentPath "${repoPath}/${ipName}/component.xml"
   set tempComponentPath "$::env(OUT_DIR)/component.xml"

   # Check if the old component.xml exists in the repository
   if { ![file exists $oldComponentPath] } {
      # Return TRUE if the old component.xml does not exist
      return true
   }

   # Check if the ZIP file exists
   if { ![file exists $newIpPath] } {
      puts "\n\n\n\n\n********************************************************"
      puts "checkComponentXml: ZIP file does not exist at $newIpPath"
      puts "********************************************************\n\n\n\n\n"
      exit -1
   }

   # Try extracting component.xml from the ZIP file
   if {[catch {exec unzip -p $newIpPath component.xml > $tempComponentPath} result]} {
      puts "\n\n\n\n\n********************************************************"
      puts "checkComponentXml: Failed to extract component.xml from ZIP file. Details: $result"
      puts "********************************************************\n\n\n\n\n"
      exit -1
   }

   # Verify the extracted file exists
   if { ![file exists $tempComponentPath] } {
      puts "\n\n\n\n\n********************************************************"
      puts "checkComponentXml: component.xml could not be found in the extracted ZIP content"
      puts "********************************************************\n\n\n\n\n"
      exit -1
   }

   # Read both files for comparison
   set oldFile [open $oldComponentPath]
   set oldContent [read $oldFile]
   close $oldFile

   set newFile [open $tempComponentPath]
   set newContent [read $newFile]
   close $newFile

   # Clean up the temporary file
   file delete $tempComponentPath

   # Compare the content of both files
   if { $oldContent ne $newContent } {

      # Delete the old content
      exec rm -rf  ${repoPath}/${ipName}
      update_ip_catalog -rebuild -scan_changes

      # Return TRUE if files are different
      return true

   }

   # Return FALSE if files are identical
   return false
}

## Function to load ZIP IP cores
proc loadZipIpCore args {
   set options {
      {path.arg       "" "path to a single file"}
      {dir.arg        "" "path to a directory of files"}
      {repo_path.arg  "" "path to a repo directory"}
   }
   set usage ": loadZipIpCore \[options] ...\noptions:"
   array set params [::cmdline::getoptions args $options $usage]
   set has_path [expr {[string length $params(path)] > 0}]
   set has_dir  [expr {[string length $params(dir)] > 0}]
   set has_repo [expr {[string length $params(repo_path)] > 0}]

   # Check for error state
   if {${has_path} && ${has_dir}} {
      puts "\n\n\n\n\n********************************************************"
      puts "loadZipIpCore: Cannot specify both -path and -dir"
      puts "********************************************************\n\n\n\n\n"
      exit -1
   } elseif {$has_repo} {
      # Load a single file
      if {$has_path} {
         # Check if file doesn't exist
         if { [file exists $params(path)] != 1 } {
            puts "\n\n\n\n\n********************************************************"
            puts "loadZipIpCore: $params(path) doesn't exist"
            puts "********************************************************\n\n\n\n\n"
            exit -1
         } else {
            # Check the file extension
            set fileExt [file extension $params(path)]
            if { ${fileExt} eq {.zip} ||
                 ${fileExt} eq {.ZIP} } {
               # Check the component.xml file
               if { [checkComponentXml $params(path) $params(repo_path)] } {
                  # Add achieved .zip to repo path
                  update_ip_catalog -add_ip $params(path) -repo_path $params(repo_path)
               }
            } else {
               puts "\n\n\n\n\n********************************************************"
               puts "loadZipIpCore: $params(path) does not have a \[.zip,.ZIP\] file extension"
               puts "********************************************************\n\n\n\n\n"
               exit -1
            }
         }
      # Load all files from a directory
      } elseif {$has_dir} {
         # Check if directory doesn't exist
         if { [file exists $params(dir)] != 1 } {
            puts "\n\n\n\n\n********************************************************"
            puts "loadZipIpCore: $params(dir) doesn't exist"
            puts "********************************************************\n\n\n\n\n"
            exit -1
         } else {
            # Get a list of all constraint files
            set list ""
            set list_rc [catch {
               set list [glob -directory $params(dir) *.zip *.ZIP]
            } _RESULT]
            # Load all the block design files
            if { ${list} != "" } {
               # Load all the constraint files
               foreach pntr ${list} {
                  # Check the component.xml file
                  if { [checkComponentXml ${pntr} $params(repo_path)] } {
                     # Add achieved .zip to repo path
                     update_ip_catalog -add_ip ${pntr} -repo_path $params(repo_path)
                  }
               }
            } else {
               puts "\n\n\n\n\n********************************************************"
               puts "loadZipIpCore: $params(dir) directory does not have any \[.zip,.ZIP\] files"
               puts "********************************************************\n\n\n\n\n"
               exit -1
            }
         }
      }
   } else {
      puts "\n\n\n\n\n********************************************************"
      puts "loadZipIpCore: -repo_path not defined"
      puts "********************************************************\n\n\n\n\n"
      exit -1
   }
}
