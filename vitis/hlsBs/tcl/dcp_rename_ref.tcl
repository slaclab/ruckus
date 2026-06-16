##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################


# ==============================================================================
# Input parameters
#   hls_dcp_dir  : Directory tree to look for the .dcp file
#   dcp_name     : DCP new name
#   dcp_path     : Full path to the new dcp file
#   level        : Either -quiet or -verbose
# ------------------------------------------------------------------------------
set   hls_dcp_dir  [lindex $argv 0]
set   hls_dcp_name "bd_0_hls_inst_0.dcp"
set   dcp_name     [lindex $argv 1]
set   dcp_path     [lindex $argv 2]
set   level        [lindex $argv 3]


#puts "hls_dcp_name = $hls_dcp_name"
#puts "hls_dcp_dir  = $hls_dcp_dir"
#puts "dcp_name     = $dcp_name"
#puts "dcp_path     = $dcp_path"

# ------------------------------------------------------------------------------
# Look for the .dcp file within the hls_dcp_dir directory tree
# ------------------------------------------------------------------------------
set found_files [split [exec find $hls_dcp_dir -type f -name $hls_dcp_name] "\n"]
if {[llength $found_files] > 0 && [string length [lindex $found_files 0]] > 0} {
   set hls_dcp_file [lindex $found_files 0]

    #puts "hls_dcp_name = $hls_dcp_name"
    #puts "hls_dcp_file = $hls_dcp_file"
    
    # Open the .DCP file
    open_checkpoint $hls_dcp_file  ${level}
        
    # Change the .DCP to match the project's name (not bd_0_hls_inst_0)
    rename_ref ${level} -ref [get_property TOP [current_design]] -to $dcp_name

    # Write the .DCP into the project's IP dir
    write_checkpoint $dcp_path -force ${level}

} else {
    puts "$dcp_name not detected $hls_dcp_dir"
}
# ==============================================================================
