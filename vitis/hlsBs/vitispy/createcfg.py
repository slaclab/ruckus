# ----------------------------------------------------------------------------
# This file is part of the 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'SLAC Firmware Standard Library', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
# ----------------------------------------------------------------------------

import os
import argparse
import vitis
import component
import configuration


# ==============================================================================
# BEGIN: Local methods
# ------------------------------------------------------------------------------
def get_args():
    parser = argparse.ArgumentParser(
        prog='create_configuration',
        description='Create a configuration file',
        epilog='')

    configuration.add_arguments(parser, True)
    component.add_arguments(parser, False)

    args = parser.parse_args()
    return args
# ------------------------------------------------------------------------------


# ------------------------------------------------------------------------------
def compose_component_name(cmp_name, net_file):

    if (cmp_name is None):
        basename = os.path.basename(net_file)
        cmp_name = os.path.splitext(basename)[0]

    return cmp_name
# ------------------------------------------------------------------------------


# ------------------------------------------------------------------------------
def print_cfg(cfg, comp):

    # Header
    print(f"\n{'-'*78}\n"
          f"Creating Configuration\n"
          f"----------------------")

    # Values
    comp.print()
    cfg.print()

    # Footer
    print(f"{'-'*78}\n")
    return
# ------------------------------------------------------------------------------
# END  : Local methods
# ==============================================================================


# ==============================================================================
# BEGIN: Main execution
# ------------------------------------------------------------------------------

# Get the command line parameters
args = get_args()

# SNL network definition
network = configuration.network(args.net_file, args.net_name)

# Fpga attributes
fpga = configuration.fpga(args.fpga, args.clock, args.uncertainty)

# CSim and CoSim arguments
exe_args = configuration.exe_args(configuration.file_and_type(args.ifile, args.itype),
                                  configuration.file_and_type(
                                      args.cfile, args.ctype),
                                  configuration.file_and_type(
                                      args.gfile, args.gtype),
                                  args.ntests,
                                  args.csim)

client = vitis.create_client()
client.set_workspace(args.workspace)

# --------------------------------------------------------------------------
# If not present, compose the component name from net_file
# --------------------------------------------------------------------------
cmp_name = compose_component_name(args.component, args.net_file)


# -----------------------------------------------------------------------------
# If not present, compose full configuration file path from the component name
# -----------------------------------------------------------------------------
cfg_path = configuration.compose_path(args.workspace,  cmp_name, args.cfg_file)


# --------------------------------------------------------------------------
# Construct the configuration and component classes
# --------------------------------------------------------------------------
cfg = configuration.configuration(
    client, cfg_path, args.snl_root, network,     fpga, exe_args)
comp = component.component(client, args.workspace,   cmp_name, cfg_path)


# --------------------------------------------------------------------------
# This seems backwards, but the Vitis component class seems to want a
# clean component directory.  This will not be the case if the configuration
# file is placed in the component directory.
# --------------------------------------------------------------------------
comp.create()
cfg.create()

print_cfg(cfg, comp)

# ------------------------------------------------------------------------------
# END  : Main execution
# ==============================================================================
