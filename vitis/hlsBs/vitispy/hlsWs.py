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
    Creates/Replaces/Removes a HLS workspace

    Args:
       -project       :  Gives the default workspace
       -w, --workspace:  Specify  the workspace, overriding the default
       --create       :  Creates  the workspace
       --list         :  List the contents of the workspace
       --replace      :  Replaces the workspace, effective --remove and --create
       --remove       :  Removes  the workspace
       --status       :  Status of the workspace
       --dry-run      :  Go through the motions but do not perform the action

   Restrictions:
      Only one of [create,replace,remove,status] may be specified

   Returns:
      Status code:
         0 = Success
         1 = Dry-Run, likely would have been successful
         2 = Dry-Run, likely would have failed
        -1 = Failure, things such as trying to create an existing workspace
'''
# ------------------------------------------------------------------------------


import argparse
import sys
import os
import runpy
import glob

sys.path.append (os.path.split (os.path.split (__file__)[0])[0])
from vitispy.manpage import display_manpage
from vitispy.files   import is_creatable

# -------------------------------------------------------
# Add the VITIS HLS python paths, remove nonexistent ones
# ------------------------------------------
runpy.run_path (os.getenv ('HLSBS_IMPORT_PYPATHS'),
                run_name = 'add_paths ' + str(sys.path))

import vitis
from   vitispy.dry_run   import DryRun
from   vitispy.printer   import Printer
from   vitispy.workspace import Workspace
from   vitispy.project   import Project

# ------------------------------------------------------------------------------
def print_ws (title, ws, dry_run, state_msg, dry_run_msg=True) :
    report = Printer (10)

    report.header (title)
    report.line   ("Workspace", ws)

    if dry_run and dry_run_msg:
        state_msg += " <-- would have been if not a dry-run"
    report.line   ("State",  state_msg)

    if dry_run : report.line ("Dry run", "<-- Note", '*')

    report.footer ()
    return
# ------------------------------------------------------------------------------


# ------------------------------------------------------------------------------
def doit () :
# ------------------------------------------------------------------------------
    # Get the command line parameters
    parser   = argparse.ArgumentParser (add_help              = False,
                                    fromfile_prefix_chars =   '@')

    Project  .add_arguments (parser)
    Workspace.add_arguments  (parser)
    parser.add_argument('-h', '--help',
                        action='store_true',
                        help='Show custom help')

    action = parser.add_mutually_exclusive_group()
    action.add_argument ('--create',  action='store_true', default = False)
    action.add_argument ('--replace', action='store_true', default = False)
    action.add_argument ('--remove',  action='store_true', default = False)
    action.add_argument ('--list',    action='store_true', default = False)
    action.add_argument ('--status',  action='store_true', default = False)

    parser.add_argument ('--no-project',
                         dest    = 'no_project',
                         help    = 'Disables the use of a project file',
                         action  = 'store_true',
                         default = False)

    DryRun.add_arguments (parser)

    args = parser.parse_args ()
    if args.help :
        display_manpage (__file__)
        return 0

    needs        = Project.Need.Workspace
    project_file = None if args.no_project else args.project
    project      = Project (needs,
                            project_file,
                            args.root,
                            args.products_root,
                            args.workspace)
    workspace     = project.workspace


    if not workspace :
        print ("\nERROR: No workspace specified either\n"
               "       a) --workspace=<workspace>\n"
               "       b) specify one in an indirect file or project file\n"
               "       c) set HLS_WORKSPACE\n")
        sys.exit (-1)


    ws            = Workspace.get (workspace)
    dry_run       = DryRun (args.dry_run)

    exists  = Workspace.exists (ws)
    if exists : msg = "Removed"
    else      : msg = "Failed, does not exist "

    if args.remove :
        # ----------------------------------------------------------------------
        if exists :
            msg  = "Removed"
            flag = True
        else      :
            msg = "Cannot remove, does not exist"
            flag = False


        if not dry_run :
            if exists : Workspace.remove (ws)
            print_ws ("Workspace - Removing", ws, dry_run, msg, flag)
            status = 0

        else       :
            print_ws ("Workspace - Removing",
                      ws,
                      dry_run,
                      msg, flag)
            status = 1

        return status
        # ----------------------------------------------------------------------

    elif args.replace :
        # ----------------------------------------------------------------------
        if exists:
            if not dry_run :
                client = vitis.create_client ()
                Workspace.replace (client, ws)
                status = 0

            else :
                status = 1

            print_ws ("Workspace - Replace", ws, dry_run, "Replaced")

        else :
            if not dry_run :
                client = vitis.create_client ()
                Workspace.create (client, ws)
                status = 0

            else :
                status = 2

            print_ws ("Workspace - Replace", ws, dry_run, "Created")

        return status
        # ----------------------------------------------------------------------

    elif args.status :
        # ----------------------------------------------------------------------
        state_msg = "Exists" if exists else "Does not exist"
        print_ws ("Workspace - Status", ws, False, state_msg)
        if exists : status =  0
        else      : status = -1
        return status
        # ----------------------------------------------------------------------

    elif args.list :
        # ----------------------------------------------------------------------
        printer = Printer (15)
        printer.header ("Workspace - list")
        printer.line   ("Workspace",    ws)

        if not exists :
            printer.line   ("State", 'Does not Exist', '*')
            printer.footer ()
            status = -1
        else :
            printer.line   ("State", 'Exists', ':')
            printer.separator ('-')

            printer.line ("Components", '')
            wc   = os.path.join (ws, '*')
            cmps = glob.glob (wc)
            if len (cmps) == 0 :
                printer.itemPlain ("None", '')
                status = 0
                printer.footer ()
                return status

            # Make a list of the stuff found and the longest one
            cmp_names = []
            max       = 0
            for cmp in cmps :
                cmp_name = os.path.split (cmp)[1]
                cmp_names.append (cmp_name)
                n = len (cmp_name)
                if n > max : max = n
            cmp_names.sort ()

            # -------------------------------------------------------------
            # Fill a line nuntil it can no longer completely hold a new entry
            # --------------------------------------------------------------
            per_line = 80 // max
            left     = per_line
            line     = ''
            cnt  = len (cmps)
            for cmp_name in cmp_names :
                line += f"{cmp_name:{max}s} "
                cnt  -= 1
                left -= 1
                if left <= 0 or cnt == 0 :
                    print (line)
                    if cnt == 0 : break
                    line = ''
                    left = per_line


            printer.footer ()
            status = 0

        return status
        # ----------------------------------------------------------------------

    elif args.create :
        # ----------------------------------------------------------------------
        if not exists :
            # --------------------------------------
            # Check if the directory can be created
            # The vitis code gives an obscure error if the path is not valid
            # --------------------------------------------------------------
            check = is_creatable (ws)

            if not check :
                print_ws ("Workspace - Create", ws, dry_run, check,
                          "Failed, the workspace is an invalid path", False)
                if dry_run : status = 2
                else       : status = 1

            elif not dry_run :
                client = vitis.create_client ()
                Workspace.create (client, ws)

                print_ws ("Workspace - Create", ws, dry_run, "Created")
            else :
                  print_ws ("Workspace - Create", ws, dry_run, "Created")

            if dry_run : status = 1
            else       : status = 0

        else :

            print_ws ("Workspace - Create",
                      ws,
                      dry_run,
                      "Already Exists, use --replace", False)
            if dry_run : status =  2
            else       : status =  1

        return status
        # ----------------------------------------------------------------------

    else :
        # ----------------------------------------------------------------------
        print (
        "WARNING: No action was specified. Select from \n"
        "         --help, --create, --replace, --remove, --list or --status",
               file = sys.stderr)
        status = -1
        return status
    # --------------------------------------------------------------------------


# ------------------------------------------------------------------------------


if __name__ == '__main__' :
    status = doit ()
    sys.exit (status)
