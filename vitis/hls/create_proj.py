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

# Verify that the configuration file exists
if not os.path.exists(cfg_file):
    raise FileNotFoundError(f"The configuration file {cfg_file} does not exist.")

# Check if component directory does not exist yet
if not (os.path.isdir( f'{workspace}/{comp_name}' )):

    # Create a client object
    client = vitis.create_client()

    # Set workspace
    client.set_workspace(workspace)

    # Create hls component with existing cfg file
    hls_test_comp = client.create_hls_component(
        name     = comp_name,
        cfg_file = cfg_file,
    )

    # Print component information
    hls_test_comp.report()

    # Close the client connection and terminate the vitis server
    vitis.dispose()
