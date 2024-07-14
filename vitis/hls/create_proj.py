#!/usr/bin/env python3
##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

import vitis
import os
import shutil

# Project variables
workspace = os.getenv("OUT_DIR")
comp_name = os.getenv("PROJECT")
cfg_file  = f'{os.getenv("PROJ_DIR")}/hls_config.cfg'
cfg_copy  = os.path.join(workspace, os.path.basename(cfg_file))

# Verify that the configuration file exists
if not os.path.exists(cfg_file):
    raise FileNotFoundError(f"The configuration file {cfg_file} does not exist.")

# Check if the previous cfg_file copy exists
if not os.path.exists(cfg_copy):
    diffCheck = 1 # Force project creation
else:
    diffCheck = os.system(f'diff {cfg_file} {cfg_copy} >/dev/null 2>&1')

# Check for any changes in cfg_file
if diffCheck > 0:

    # Create a client object
    client = vitis.create_client()

    # Delete the workspace if already exists.
    if (os.path.isdir(workspace)):
        shutil.rmtree(workspace)
        print( f'Deleted workspace {workspace}' )

    # Set workspace
    client.set_workspace(workspace)

    # Get config file object
    script_dir = os.path.dirname(os.path.abspath(__file__))
    cfg_path = os.path.join(script_dir, 'test_srcs/hls_config.cfg')

    # Create hls component with existing cfg file
    hls_test_comp = client.create_hls_component(
        name     = comp_name,
        cfg_file = cfg_file,
    )

    # Print component information
    hls_test_comp.report()

    # Close the client connection and terminate the vitis server
    vitis.dispose()

    # Copy the cfg_file to the workspace directory
    shutil.copy(cfg_file, cfg_copy)
