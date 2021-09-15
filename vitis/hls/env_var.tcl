##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

## \file vitis/hls/env_var.tcl
# \brief This script set all the common ruckus environmental variables for Vitis HLS

set PROJ_DIR         $::env(PROJ_DIR)
set TOP_DIR          $::env(TOP_DIR)
set PROJECT          $::env(PROJECT)
set OUT_DIR          $::env(OUT_DIR)
set VIVADO_VERSION   $::env(VIVADO_VERSION)
set RUCKUS_DIR       $::env(RUCKUS_DIR)
set ARGV             $::env(ARGV)
set CFLAGS           $::env(CFLAGS)
set LDFLAGS          $::env(LDFLAGS)
set MFLAGS           $::env(MFLAGS)
set SKIP_CSIM        $::env(SKIP_CSIM)
set SKIP_COSIM       $::env(SKIP_COSIM)
set SKIP_EXPORT      $::env(SKIP_EXPORT)
