##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

########################################################
## Set Common Environmental variables
########################################################

# Project Variables
set MAX_CORES        $::env(MAX_CORES)
set DIG_TECH         $::env(DIG_TECH)
set STD_CELL_LIB     $::env(STD_CELL_LIB)
set TLU_PLUS_FILES   $::env(TLU_PLUS_FILES)
set DESIGN           $::env(PROJECT)
set PROJECT          $::env(PROJECT)
set PRJ_VERSION      $::env(PRJ_VERSION)
set PROJ_DIR         $::env(PROJ_DIR)
set TOP_DIR          $::env(TOP_DIR)
set IMAGES_DIR       $::env(IMAGES_DIR)
set IMAGENAME        $::env(IMAGENAME)
set OUT_DIR          $::env(OUT_DIR)
set SYN_DIR          $::env(SYN_DIR)
set SYN_OUT_DIR      $::env(SYN_OUT_DIR)
set RUCKUS_DIR       $::env(RUCKUS_DIR)

set design  ${DESIGN}
set pdk_dir ${DIG_TECH}
