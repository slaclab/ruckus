# ----------------------------------------------------------------------------
# This file is part of the 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'SLAC Firmware Standard Library', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
# ----------------------------------------------------------------------------

from vitispy.targets import Targets
from vitispy.project import Project
from vitispy.printer import Printer
from vitispy.dry_run import DryRun
import vitispy.ip as hlsIp
import vitispy.configuration as hlsCfg
from vitispy.category import Category
from vitispy.action import Action
from vitispy.workspace import Workspace
from vitispy.manpage import display_manpage
import vitis
import argparse
import os
import sys
import runpy

# -------------------------------------------------------
# Add the VITIS HLS python paths, remove nonexistent ones
# ------------------------------------------
runpy.run_path(os.getenv('HLSBS_IMPORT_PYPATHS'),
               run_name='add_paths ' + str(sys.path))


# ==============================================================================
# BEGIN: Local methods
# ------------------------------------------------------------------------------

def add_arguments(parser):

    parser.add_argument('-h',
                        '--help',
                        action='store_true',
                        help='Show custom help')

    Workspace.add_arguments(parser)
    Action   .add_arguments(parser, 'Configuration')
    hlsIp.Ip .add_arguments(parser)
    DryRun.   add_arguments(parser)
    Project.  add_arguments(parser)

    parser. add_argument('--no-components',
                         help='Inhibit component(s) in any action',
                         action='store_true',
                         default=False,
                         dest='no_components')

    parser. add_argument('--components',
                         nargs='*',
                         help='The target component(s)')

    parser.add_argument('parameters',
                        help="The list of ' + target_name",
                        action='store',
                        nargs='*',
                        default=None)

    parser.add_argument('--verbose',
                        help='Verbose output',
                        action='store_true',
                        default=False)

    return
# ------------------------------------------------------------------------------


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
def check_for_lock(spath):
    from pathlib import Path

    # Count the number of lock files
    nlocks = 0

    # Match all .txt files recursively starting from the current directory
    spath = Path(spath).rglob('*')
    for file in spath:
        if os.path.isdir(file):
            continue

        # Open the file to get a file descriptor
        with open(file, 'r+') as f:
            fd = f.fileno()
            try:
                # F_TEST checks for existing locks without blocking
                os.lockf(fd, os.F_TEST, 0)
                continue

            except OSError:
                nlocks += 1  # Locked by another process
                print("ERROR: Locked file\n"
                      f"       {file} is locked")

    return nlocks
# ------------------------------------------------------------------------------


# ------------------------------------------------------------------------------
'''
  Performs a specified action (list, clean) on a target

  Args:
     exe:          Method to execute the action (here list and clean)
     printer:      Captures the indentation and field widths to ensure
                   consistent printing
     project:      Instantiation of the project class
     cmp:          Instantiation of the component class
     labels:       Labels to be applied to the categories
     print_target: Flag indicating whether to print the target or just
                   the cfg_path and cmp_path
'''
# ------------------------------------------------------------------------------


class DoAction:
    def __init__(self, exe, printer, project, cmp, labels, print_target):
        self.exe = exe
        self.printer = printer
        self.project = project
        self.cmp = cmp
        self.labels = labels
        self.print_target = print_target
        return
    # --------------------------------------------------------------------------

    # --------------------------------------------------------------------------

    def byCategory(self, category, category_label, seps):
        print()
        self.printer.line(category_label)
        left = len(category)
        if left == 0:
            self.printer.itemPlain("None", '')

        idx = 0

        for target in category:
            idx += 1
            left -= 1
            cmp_path = target.cmp_path if self.cmp else None

            if self.print_target and self.verbose:
                if self.project.spc_print and self.project.spc_print.target_label:
                    target_label = self.project.spc_print.target_label
                    self.printer.item(idx, target_label, target.tgt_name)

                self.exe(None, target.cfg_path, cmp_path, seps)
            else:
                self.exe(idx,  target.cfg_path, cmp_path, seps)

            if cmp_path and left:
                print()

        return
        # ----------------------------------------------------------------------

    # --------------------------------------------------------------------------
    def byCategories(self, categories):

        if self.opts & Category.Existing:
            self.byCategory(categories.existing, self.labels[0], [':', '*'])

        if self.opts & Category.Missing:
            self.byCategory(categories.missing,  self.labels[1], [':', '*'])

        if self.opts & (Category.CruftLo | Category.CruftHi):
            print()
            self.printer.line(self.labels[2])

            idx = 0
            nhi = len(categories.cruft_hi)
            nlo = len(categories.cruft_lo)

            left = nhi
            if self.opts & Category.CruftLo:
                left += nlo

            if left == 0:
                self.printer.itemPlain("None", None)
                return

            if self.opts & Category.CruftHi:

                for cruft in categories.cruft_hi:
                    idx += 1
                    left -= 1
                    self.exe(idx,  cruft.cfg_path, cruft.cmp_path, [':', '*'])
                    if left and self.cmp:
                        print()

            if self.opts & Category.CruftLo:
                for cruft in categories.cruft_lo:
                    idx += 1
                    left -= 1
                    self.exe(idx,  cruft.cfg_path, cruft.cmp_path, ['?', '*'])
                    if left and self.cmp:
                        print()

        return
    # --------------------------------------------------------------------------


# ------------------------------------------------------------------------------
'''
   The list action class
'''
# ------------------------------------------------------------------------------


class Lister (DoAction):

    # --------------------------------------------------------------------------
    def __init__(self, printer, project, cmp, verbose, opts):
        labels = ['Existing', 'Missing', 'Cruft', 'Cruft']
        super().__init__(self.list, printer, project, cmp, labels, verbose)
        self.verbose = verbose
        self.opts = opts
        return
    # --------------------------------------------------------------------------

    # --------------------------------------------------------------------------

    def list(self, idx, cfg_path, cmp_path, seps):

        exists = (cfg_path is not None and os.path.isfile(cfg_path))
        sep = seps[0] if exists else seps[1]

        if not cfg_path:
            cfg_path = "None Found"
        self.printer.item(idx, "Configuration", cfg_path, sep)

        if self.cmp and cmp_path:
            # Extract the name of the component and component path
            cmp_exists = os.path.isdir(cmp_path)

            if cmp_exists:
                sep = seps[0]
            else:
                sep = seps[1]
            self.printer.itemPlain("Component", cmp_path, sep)

        return
# ------------------------------------------------------------------------------


# ------------------------------------------------------------------------------
'''
   The configuration list action method

   Args:
     project:    The project parameters
     cmpList:    The target list of components
     categories: The categories (existing & cruft) of targets to clean
     cmp:        Include components in the cleaning
     verbose:    Verbose output
     opts:       The target categories
'''
# ------------------------------------------------------------------------------


def listConfigurations(project, cmpList, categories, cmp, verbose, opts):

    printer = Printer(20, 78, 15)
    action = Lister(printer, project, cmp, verbose, opts)

    what = "Listing Configurations"
    if cmp:
        what += " & Components"
    printer.header(f"{what}")

    if (project.workspace):
        printer.line("Workspace", project.workspace)

    project.print_project(printer, verbose)
    printer.line("Components", cmpList)

    action.byCategories(categories)
    printer.footer()

    return
# ------------------------------------------------------------------------------


# ------------------------------------------------------------------------------
'''
   The cleaner's action class
'''
# ------------------------------------------------------------------------------


class Cleaner (DoAction):

    # --------------------------------------------------------------------------
    def __init__(self, printer, project, cmp, dry_run, verbose, opts):
        labels = [" Cleaning Existing -> Missing",
                  " Missing",
                  " Cruft",
                  " Cruft"]
        super().__init__(self.clean, printer, project, cmp, labels, True)
        self.dry_run = dry_run
        self.verbose = verbose
        self.opts = opts
        return
    # --------------------------------------------------------------------------

    # --------------------------------------------------------------------------

    def clean(self, idx, cfg_path, cmp_path, seps):

        # Check existence of cfg
        if cfg_path:
            cfg_exists = os.path.isfile(cfg_path)
        else:
            cfg_exists = False
            cfg_path = "None"

        sep = seps[0] if cfg_exists else seps[1]
        self. printer.item(idx, "Configuration", cfg_path, sep)

        if not cfg_exists:
            if self.verbose:
                self.printer.itemPlain(
                    'Fate',
                    'WARNING: Does not exist, "clean" ignored', '*')

        elif not self.dry_run:
            os.unlink(cfg_path)

        # Only clean the components if requested and it exists
        if cmp_path and self.cmp:

            # Extract the name of the component and component path
            cmp_exists = os.path.exists(cmp_path)

            sep = seps[0] if cmp_exists else seps[1]
            self.printer.itemPlain("Component", cmp_path, sep)

            if not cmp_exists:
                if self.verbose:
                    self.printer.itemPlain('Fate',
                                           'WARNING: Does not exist, "clean" ignored', '*')
            else:
                # -----------------------------------------------------------
                # Ambivalent about this
                #
                #  PROs: Makes an attempt to ensure all can be deleted
                #  CONs: Somewhat expensive for something that rarely happens
                # -----------------------------------------------------------
                # nlocks = check_for_lock (cmp_path)
                # if nlocks : exit (-1)

                if not self.dry_run:
                    import shutil
                    try:
                        shutil.rmtree(cmp_path)
                    except OSError as e:
                        print()
                        self.printer.itemPlain("ERROR", e.strerror)
                        self.printer.itemPlain("",      e.filename)
                        exit(-1)
        return
# ------------------------------------------------------------------------------


# ------------------------------------------------------------------------------
'''
   The configuration clean action method

   Args:
     project:    The project parameters
     cmpList:    The target list of components
     categories: The categories (existing & cruft) of targets to clean
     cmp:        Include components in the cleaning
     dry_run:    Whether to do a dry_run
     verbose:    Verbose output
     opts:       The target categories
'''
# ------------------------------------------------------------------------------


def cleanConfigurations(project,
                        cmpList,
                        categories,
                        cmp,
                        dry_run,
                        verbose,
                        opts):

    printer = Printer(15, 78, 15)
    action = Cleaner(printer, project, cmp, dry_run, verbose, opts)

    what = "Cleaning Configurations"
    if cmp:
        what += " & Components"

    printer.header(f"{what} by Components")

    if (project.workspace):
        printer.line("Workspace", project.workspace)

    project.print_project(printer, verbose)
    printer.line("Components", cmpList)

    if dry_run:
        if dry_run:
            printer.line('Dry Run', '<-- NOTE')

    action.byCategories(categories)
    printer.footer()

    return
# ------------------------------------------------------------------------------


# ------------------------------------------------------------------------------
'''
   Creates the HLS configuration files and optionally components for a list
   of targets

   Args:
     cfg:        Instantiation of the configuration class
     cmpList:    the target list of components
     categories: The categories (existing, missing to create the
                 configurations and, optionally the components
     dry_run:    Whether to do a dry_run
     verbose:    Verbose output
     opts:       The target categories
     replace:    Flag to replace rather than create
'''
# ------------------------------------------------------------------------------


def createConfigurations(cfg,
                         cmpList,
                         categories,
                         dry_run,
                         verbose,
                         opts,
                         replace):

    printer = Printer(14, 78, 14)
    cfg.print_common(printer, verbose)
    printer.line("Components", cmpList)
    if dry_run:
        if dry_run:
            printer.line('Dry Run', '<-- NOTE')

    if opts & Category.Existing:
        print()
        if not replace:
            printer.line(("Error: Creating existing: Will fail, "
                          "use --replace to replace existing configurations"))
        else:
            printer.line("Replacing Existing")

        idx = 1
        targets = categories.existing
        left = len(targets)
        for target in targets:
            if idx != 1 and cfg.comp:
                print()
            status, message = cfg.execute(target)
            cfg.print(printer, idx, target, status,
                      [':', '*'], message, verbose)
            idx += 1

    if opts & Category.Missing:
        print()
        printer.line('Creating Missing -> Existing')
        idx = 1
        targets = categories.missing
        left = len(targets)
        if left == 0:
            printer.itemPlain('None Missing', '')
        else:
            for target in targets:
                if idx != 1 and cfg.comp:
                    print()
                status, message = cfg.execute(target)
                cfg.print(printer, idx, target, status,
                          [':', '-'], message, verbose)
                idx += 1

    printer.footer()

    vitis.dispose()
    return
# ------------------------------------------------------------------------------


# ------------------------------------------------------------------------------
'''
   Merges x, y list, where x,y can either be a list or a comma separated string
   which is then split and returned as a list

   Args:
      xl:  The first  comma-separated string to merge
      yl:  The second comma-separated string to merge

   Returns
     list: A list which is formed by splitting the merged comma separated list

'''
# ------------------------------------------------------------------------------


def merge(xl, yl):

    if not xl and not yl:
        return None
    xy = ''
    if xl:
        # Ensure xl is a list
        if isinstance(xl, list):
            left = len(xl)
            for x in xl:
                left -= 1
                if left:
                    xy += x + ','
                else:
                    xy += x
        else:
            xy = xl

    if yl:
        if isinstance(yl, list):
            left = len(yl)
            for y in yl:
                left -= 1
                if left:
                    xy += y + ','
                else:
                    xy += y
        else:
            if xy:
                xy += ',' + yl
            else:
                xy = yl

    return xy.split(',')
# ------------------------------------------------------------------------------


# ------------------------------------------------------------------------------
def nonExistentWorkspace(workspace):
    print(
        "ERROR: Workspace does not exist\n"
        "       To avoid typos causing spurious creation, use hlsWs to create it\n"
        "\n"
        "  -->  " + workspace + "\n", file=sys.stderr)
    return -1
# ------------------------------------------------------------------------------
# END  : Local methods
# ==============================================================================


# ==============================================================================
# BEGIN: Main execution
# ------------------------------------------------------------------------------
'''
   Reads the project files and with the command line parameters creates the
   necessary data structures to optionally, list, clean or create the
   configuration files and optionally the component files.
'''
# ------------------------------------------------------------------------------


def main():

    # -------------------------------------------------------------------
    # lambda to print an error when an implicit '*' is used when cleaning
    # -------------------------------------------------------------------
    noCompleteClean = (lambda:
                       print(
                           "\n"
                           "ERROR: To avoid cleaning more than intended, hlsCfg requires that\n"
                           "       postional args or --targets='*' must be specified, e.g.\n"
                           "\n"
                           "        $ hlsCfg '*' --clean             or\n"
                           "        $ hlsCfg --components='*'\n",
                           file=sys.stderr))

    # -------------------------------
    # Get the command line parameters
    # -------------------------------
    parser = argparse.ArgumentParser(add_help=False,
                                     fromfile_prefix_chars='@')
    add_arguments(parser)
    args = parser.parse_args()
    if args.help:
        display_manpage(__file__)
        exit(0)

    # ----------------------------------------
    # Extract the project specific information
    # ----------------------------------------
    if not check_project_file(args.project):
        sys.exit(-1)
    needs = (Project.Need.Root |
             Project.Need.Workspace |
             Project.Need.Products)
    project = Project(needs,
                      args.project,
                      args.root,
                      args.products_root,
                      args.workspace)
    if project.error:
        status = project.report(needs)
        return status

    # ----------------------------------------------------------------
    # Kludge since argparse for python < 3.9 does not support negation
    # ----------------------------------------------------------------
    create_components = False if args.no_components else True

    project.get_products()
    project.replace(args)

    # ---------------------------------------------------
    # Merge the positional parameters and the --components
    # ---------------------------------------------------
    cmpList = merge(args.parameters, args.components)
    if not cmpList:
        if args.clean is not None and not len(args.clean):
            noCompleteClean()
            sys.exit(-1)
        else:
            # Default list, create, replace to all
            cmpList = '*'

    targets = [None] * 2

    # ---------------------------------------------------------
    # Assign a string to the action, mainly for error reporting
    # ---------------------------------------------------------
    if args.list is not None:
        op = "Listing"
    elif args.clean is not None:
        op = "Cleaning"
    elif args.replace is not None:
        op = "Replacing"
    else:
        op = "Creating"

    msg = op + " Configurations"

    workspace = project.workspace
    exists = os.path.isdir(workspace)
    if not exists:
        return nonExistentWorkspace(workspace)

    # ---------------------------------------------------
    # Get all the possible targets & check there are some
    # ---------------------------------------------------
    targets = Targets(workspace, project.products).targets
    if not len(targets):
        return Targets.no_candidate_targets(targets, msg, project)

    categories = Targets.classify(workspace,
                                  project.products,
                                  targets,
                                  cmpList,
                                  project.configurations)
    if not categories:
        return -1

    # --------------------------------------------------------------------------
    # Cleaning
    # --------
    if args.clean is not None:
        opts = Category.categorize(args.clean,
                                   Category.Existing | Category.Cruft)
        # --------------------------------------
        # Removing the configuration without
        # removing the component is nonsensical
        # --------------------------------------
        cleanConfigurations(project,
                            cmpList,
                            categories,
                            create_components,
                            args.dry_run,
                            args.verbose,
                            opts)
        return 0
    # --------------------------------------------------------------------------

    # --------------------------------------------------------------------------
    # Listing
    # -------
    elif args.list is not None:
        opts = Category.categorize(args.list, Category.All)

        listConfigurations(project,
                           cmpList,
                           categories,
                           create_components,
                           args.verbose,
                           opts)
        return 0
    # --------------------------------------------------------------------------

    # --------------------------------------------------------------------------
    # Creating/Replacing, this is the default
    # ---------------------------------------
    else:
        replace = args.replace is not None
        if replace:
            opts = Category.categorize(args.replace, Category.Existing)
        else:
            if args.create is None:
                args.create = []
            opts = Category.categorize(args.create,  Category.Missing)

        for product in project.products:
            cfg = hlsCfg.Configuration(args,
                                       create_components,
                                       project,
                                       product)
            createConfigurations(cfg,
                                 cmpList,
                                 categories,
                                 args.dry_run,
                                 args.verbose,
                                 opts,
                                 replace)
        return 0
# ------------------------------------------------------------------------------


# ------------------------------------------------------------------------------
if __name__ == '__main__':
    status = main()
    sys.exit(status)
# ------------------------------------------------------------------------------
# END  : Main execution
# ==============================================================================
