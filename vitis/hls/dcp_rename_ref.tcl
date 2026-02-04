##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

# Paths and filenames
set cfg_file "$::env(PROJ_DIR)/hls_config.cfg"
set dcp_name "bd_0_hls_inst_0.dcp"

# Does the file exists
set found_files [split [exec find $::env(OUT_DIR) -type f -name $dcp_name] "\n"]
if {[llength $found_files] > 0 && [string length [lindex $found_files 0]] > 0} {
   set dcp_file [lindex $found_files 0]

   # Open the .DCP file
   open_checkpoint $dcp_file

   # Change the .DCP to match the project's name (not bd_0_hls_inst_0)
   rename_ref -ref [get_property TOP [current_design]] -to $::env(PROJECT)_0

   # Write the .DCP into the project's IP dir
   write_checkpoint $::env(PROJ_DIR)/ip/$::env(PROJECT).dcp -force

} else {
   puts "$dcp_name not detected $::env(OUT_DIR)"
}
