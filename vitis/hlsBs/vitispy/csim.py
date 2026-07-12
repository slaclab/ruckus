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
    Get the HLS build directory for the specified component

    Args:
       --project      :  Get the default workspace
       -w, --workspace:  Specify  the workspace, overriding the default
       --component    :  The target component

   Returns:
      0   On success
     -1   If the workspace was not found
     -2   If the component was not found
     -3   If csim executable was not found
 '''
# ------------------------------------------------------------------------------

from vitispy.project import Project
from vitispy.workspace import Workspace
from vitispy.componentInfo import ComponentInfo
import argparse
import sys
import os

import runpy
runpy.run_path(os.getenv('HLSBS_IMPORT_PYPATHS'),
               run_name='add_paths ' + str(sys.path))


# -------------------------------------------------------
# Augment the python path with the directory of this file
dir = os.path.split(os.path.split(__file__)[0])[0]
sys.path.append(dir)

# ------------------------------------------------------


# ------------------------------------------------------------------------------
def check_project_file(project_file):
    '''
    Check if the project file has been specified and exists

    Args:
       project_file : The project file to check

    Returns
      True,  if project file is specified and exists
      False, otherwise
    '''
    # --------------------------------------------------------------------------
    if not project_file:
        print("ERROR: No project file specified, either \n"
              "       a) Define HLSBS_PROJECT or\n"
              "       b) --project=<project_file>\n")
        return False

    if not os.path.isfile(os.path.expandvars(project_file)):
        print("ERROR: Project file not found\n"
              f"       {project_file}")
        return False

    return True
# ------------------------------------------------------------------------------


# ------------------------------------------------------------------------------
'''
   Returns the full component path

   Args:
     workspace:  The workspace directory.
     component:  The component, either its name or its full directory
                 specification

  Returns
     The full component path or exits with an error
'''
# ------------------------------------------------------------------------------


def get_component_path(workspace, component):

    # ------------------------------------------------------------
    # Check if the target component is a fully specified directory
    # ------------------------------------------------------------
    exists = os.path.isdir(component)
    if exists:
        return component

    # ------------------------------------------------------
    # Not a fully specified directory, tack on the workspace
    # ------------------------------------------------------
    ws = Workspace.get(workspace)
    exists = Workspace.exists(ws)
    if not exists:
        print(f"ERROR: Workspace {ws} was not found", file=sys.stderr)
        sys.exit(-1)

    componentPath = os.path.join(ws, component)
    exists = os.path.isdir(componentPath)
    if not exists:
        print(
            f"ERROR: Component {componentPath} was not found", file=sys.stderr)
        sys.exit(-2)
    else:
        return componentPath
# ------------------------------------------------------------------------------


# ------------------------------------------------------------------------------
def get(org_file, command):

    parser = argparse.ArgumentParser(prog='hlsCsimGet',
                                     add_help=False,
                                     fromfile_prefix_chars='@',
                                     epilog='',
                                     description='''
    Returns the csim.exe command complete with argv as a string to be
    executed at the command line. This is generally not invoked directly but
    used as a utility function for other shell commands''')

    Project  .add_arguments(parser)
    Workspace.add_arguments(parser)
    parser.   add_argument('components',
                           nargs='?',
                           help="The target component")
    parser.   add_argument('-h',
                           '--help',
                           action='store_true',
                           help='Show custom help')

    args, unknown = parser.parse_known_args()

    if args.help:
        sys.exit(1)

    workspace = args.workspace
    components = args.components

    # ----------------------------------------
    # Extract the project specific information
    # ----------------------------------------
    if not check_project_file(args.project):
        sys.exit(-1)
    needs = Project.Need.Workspace
    project = Project(needs,
                      args.project,
                      args.root,
                      args.products_root,
                      args.workspace)
    if project.error:
        status = project.report(needs)
        return status

    workspace = project.workspace

    if not workspace:
        print("ERROR: No workspace provide, specify one in\n"
              "       either: --workspace on the command line or\n"
              "       or    : in the project file",
              file=sys.stderr)
        sys.exit(-1)

    if not components:
        print("ERROR: No component to run provided\n"
              "       try " + command + " --help", file=sys.stderr)
        sys.exit(-1)

    componentPath = get_component_path(workspace, components)
    info = ComponentInfo(componentPath)
    exists = os.path.isfile(info.csim_exe)

    if not exists:
        print(f"ERROR: Executable {info.csim_exe} was not found",
              file=sys.stderr)
        sys.exit(-3)

    cmd = info.csim_exe + ' ' + os.path.expandvars(info.csim_argv)
    print(cmd)
    sys.exit(0)
# ------------------------------------------------------------------------------
