# ----------------------------------------------------------------------------
# This file is part of the 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'SLAC Firmware Standard Library', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
# ----------------------------------------------------------------------------

# ------------------------------------------------------------------------------
'''
Starts the HLS Gui at the specified workspace, or with no workspace.
'''
# ------------------------------------------------------------------------------


import argparse
import sys
import os
import subprocess
import runpy


# -------------------------------------------------------
# Add the VITIS HLS python paths, remove nonexistent ones
# ------------------------------------------
runpy.run_path(os.getenv('HLSBS_IMPORT_PYPATHS'),
               run_name='add_paths ' + str(sys.path))

from vitispy.manpage import display_manpage  # noqa: E402
from vitispy.project import Project  # noqa: E402
from vitispy.workspace import Workspace  # noqa: E402


# ------------------------------------------------------------------------------
def nonExistentWorkspace(workspace):
    print("\n"
          "ERROR: Workspace does not exist\n"
          "       To avoid typos causing spurious creation, use hlsWs to "
          "create it\n"
          "       or specify --no-workspace to start the HLS Gui/Ide without "
          "a workspace\n\n"
          "  -->  " + workspace + "\n", file=sys.stderr)
    return -1
# ------------------------------------------------------------------------------


# ------------------------------------------------------------------------------
def add_arguments(parser):

    parser.add_argument('-h', '--help',
                        help='Show custom help',
                        action='store_true')

    parser.add_argument('--no-workspace',
                        help='Start the HLS Gui/IDE without a workspace',
                        dest='no_workspace',
                        action='store_true')

    parser.add_argument('--verbose',
                        help='Verbose output',
                        action='store_true')

    Project  .add_arguments(parser)
    Workspace.add_arguments(parser)
# ------------------------------------------------------------------------------


# ------------------------------------------------------------------------------
def startGui():

    # ------------------------------------------
    # Specify and get the command line parameters
    # -------------------------------------------
    parser = argparse.ArgumentParser(add_help=False,
                                     fromfile_prefix_chars='@')

    add_arguments(parser)

    args = parser.parse_args()

    if args.help:
        display_manpage(__file__)
        return 0

    # ----------------------------------------------------------------------
    # Have explicitly asked for no workspace
    # --------------------------------------
    if args.no_workspace:

        if args.verbose:
            print("Starting GUI with no workspace")
        cmd = ['vitis']

    else:

        project = Project(Project.Need.Workspace,
                          args.project,
                          args.root,
                          args.products_root,
                          args.workspace)
        workspace = Workspace.get(project.workspace)

        # Check existence
        if workspace:
            exists = Workspace.exists(workspace)
            if not exists:
                return nonExistentWorkspace(workspace)

            if args.verbose:
                print(f"Starting GUI in {workspace}")
            cmd = ['vitis', '-w', workspace]
        else:
            print("ERROR: Could not determine a workspace; use --no-workspace "
                  "to start the HLS Gui/IDE without one", file=sys.stderr)
            return -1
    # ----------------------------------------------------------------------

    # Execute the cmd command
    with subprocess.Popen(cmd,
                          stdout=subprocess.PIPE,
                          text=True,
                          bufsize=1) as process:
        for line in process.stdout:
            if args.verbose:
                print(line, end='')
            else:
                pass

        # Wait for the process to fully complete and get the return code
        status = process.wait()

        return status

# ------------------------------------------------------------------------------


# ------------------------------------------------------------------------------
if __name__ == "__main__":
    status = startGui()
    sys.exit(status)
# ------------------------------------------------------------------------------
