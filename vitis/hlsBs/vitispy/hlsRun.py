# ----------------------------------------------------------------------------
# This file is part of the 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'SLAC Firmware Standard Library', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
# ----------------------------------------------------------------------------

import vitispy.files as files
from vitispy.project import Project
from vitispy.printer import Printer
from vitispy.workspace import Workspace
from vitispy.dry_run import DryRun
from vitispy.run import ComponentInfo
from vitispy.run import Run
from vitispy.component import Component
from vitispy.manpage import display_manpage
import argparse
import sys
import os
import runpy


# -------------------------------------------------------
# Add the VITIS HLS python paths, remove nonexistent ones
# ------------------------------------------
runpy.run_path(os.getenv('HLSBS_IMPORT_PYPATHS'),
               run_name='add_paths ' + str(sys.path))


# ------------------------------------------------------------------------------
class SplitArgs(argparse.Action):
    def __call__(self, parser, namespace, values, option_string=None):
        if values:
            setattr(namespace, self.dest, values[0].split(','))
        else:
            setattr(namespace, self.dest, [])
        return
# ------------------------------------------------------------------------------


# ------------------------------------------------------------------------------
def add_arguments(parser):

    parser.add_argument('-h',
                        '--help',
                        action='store_true',
                        help='Show custom help')

    Workspace.add_arguments(parser)

    parser.add_argument('parameters',
                        help="The list of components",
                        nargs='*',
                        default=None)

    parser.add_argument('--verbose',
                        help='Minimum ouput',
                        action='store_true',
                        default=False)

    parser.add_argument('--components',
                        nargs='*',
                        default=None,
                        help='The target component(s)')

    parser.add_argument('--list',
                        help='List available components to run',
                        action='store_true',
                        default=False)

    parser.add_argument('--csim',
                        help='run csim',
                        nargs='*',
                        const='--no_value--',
                        action=SplitArgs)

    parser.add_argument('--synthesis',
                        help='run synthesis',
                        action='store_true',
                        default=False)

    parser.add_argument('--cosim',
                        help='run cosim',
                        nargs='*',
                        const='--no_value--',
                        action=SplitArgs)

    parser.add_argument('--package',
                        help='run package',
                        action='store_true',
                        default=False)

    parser.add_argument('--implementation',
                        help='run implementation',
                        action='store_true',
                        default=False)

    parser.add_argument('--ip',
                        help='create ip packaging',
                        nargs='*',
                        const='--no_value--',
                        action=SplitArgs)

    parser.add_argument('--all',
                        help='run all',
                        nargs='*',
                        const='--no_value--',
                        action=SplitArgs)

    parser.add_argument('--exclude',
                        help='list of run options to exclude')

    parser.add_argument('--slow',
                        help='make using the fast method',
                        action='store_true',
                        default=False)

    DryRun.add_arguments(parser)

    Project.    add_arguments(parser)
    Project.Ip. add_arguments(parser)

    return
# ------------------------------------------------------------------------------


# ------------------------------------------------------------------------------
def report(verbose, printer, project, workspace, components, run):

    printer.separator('=')
    if run == 'List':
        run = None
        printer.line('List by Component', '')

    project.git = Project.Git(project.root)

    printer.line("Workspace", workspace)
    printer.line('Component', components)
    project.print_project(printer, verbose)

    print()
    if run:
        run.print(printer)
    printer.separator('-', 40)

    return
# ------------------------------------------------------------------------------


# ------------------------------------------------------------------------------
'''
   Merges x, y into a list, where x,y can either by a list or a comma separated
   string
'''


def merge(x, y):
    if x:
        # Insure X is a list
        if len(x) == 1:
            lst = x[0].split(',')
        else:
            lst = x
    else:
        lst = []

    if y:
        if len(y) == 1:
            lst += y[0].split(',')
        else:
            lst += y

    return lst
# ------------------------------------------------------------------------------


# ------------------------------------------------------------------------------
class Options:
    def __init__(self,
                 all,
                 exclude,
                 csim,
                 synthesis,
                 cosim,
                 package,
                 implementation,
                 ip,
                 slow,
                 dry_run,
                 verbose):

        self.slow = slow
        self.dry_run = dry_run
        self.verbose = verbose
        self.stages = 0

        if all is not None:
            self.stages = Run.Stage.All

        else:
            if csim is not None:
                self.stages |= Run.Stage.CSim
            if synthesis:
                self.stages |= Run.Stage.Synthesis
            if cosim is not None:
                self.stages |= Run.Stage.CoSim
            if package:
                self.stages |= Run.Stage.Package
            if implementation:
                self.stages |= Run.Stage.Implementation

        if all is not None:
            if csim is None:
                csim = 'all'
            if cosim is None:
                cosim = 'all'
            if ip is None:
                ip = 'all'
            self. csim_set(csim)
            self.cosim_set(cosim)
            self.stages |= self.ip_set(ip)

        else:
            if self.stages & Run.Stage.CSim:
                self.csim_set(csim)

            if self.stages & Run.Stage.CoSim:
                self.cosim_set(cosim)

            self.stages |= self.ip_set(ip)

        # Exclude unwanted actions
        self.exclude = exclude
        if exclude:
            exclude_list = exclude.split(',')
            for item in exclude_list:
                unique = item[0:2]
                if (unique == 'cs'):
                    self.stages &= ~Run.Stage.CSim
                if (unique == 'sy'):
                    self.stages &= ~Run.Stage.Synthesi
                if (unique == 'co'):
                    self.stages &= ~Run.Stage.CoSim
                if (unique == 'pa'):
                    self.stages &= ~Run.Stage.Package
                if (unique == 'im'):
                    self.stages &= ~Run.Stage.Implementation
                if (unique == 'ip'):
                    self.stages &= ~Run.Ip
                if (unique == 'dc'):
                    self.stages &= ~Run.Dcp

        return
    # --------------------------------------------------------------------------

    # --------------------------------------------------------------------------

    def csim_set(self, list):

        # Hold on to the original request
        msk = self.action_msk(list, Run.Msk.Make | Run.Msk.Run)
        self.csim = msk != 0
        self.csim_msk = msk

        # -------------------------------------------------------
        # Modify the mask for limitations of the slow HLS actions
        # The fast modification only disallows Clean | Run combo
        # -------------------------------------------------------
        self.csim_fast_msk = Run.Msk.CSimFastValid[msk]
        self.csim_slow_msk = Run.Msk.CSimSlowValid[msk]

        return
    # --------------------------------------------------------------------------

    # --------------------------------------------------------------------------

    def cosim_set(self, list):

        # Hold on to the original request
        msk = self.action_msk(list, Run.Msk.Make | Run.Msk.Run)
        self.cosim = msk != 0

        # --------------------------------------------------
        # Modify the mask for limitations of the HLS actions
        # --------------------------------------------------
        self.cosim_msk = Run.Msk.CoSimValid[msk]

        return
    # --------------------------------------------------------------------------

    # --------------------------------------------------------------------------

    @staticmethod
    def ip_set(ip_list):

        msk = 0

        if ip_list is None:
            return msk

        if not isinstance(ip_list, list):
            if ip_list == '--no-value--':
                msk = Run.Stage.Ip_Zip | Run.Stage.Ip_Dcp
                return msk
            else:
                ip_list = [ip_list]
        elif len(ip_list) == 0:
            msk = Run.Stage.Ip_Zip | Run.Stage.Ip_Dcp
            return msk

        if Options.is_in('z', ip_list):
            msk |= Run.Stage.Ip_Zip
        if Options.is_in('d', ip_list):
            msk |= Run.Stage.Ip_Dcp
        if Options.is_in('a', ip_list):
            msk = Run.Stage.Ip_Zip | Run.Stage.Ip_Dcp

        return msk
    # --------------------------------------------------------------------------

    # --------------------------------------------------------------------------

    @staticmethod
    def is_in(s, list):
        n = len(s)
        for member in list:
            if s == member[0:n]:
                return True
        return False
    # --------------------------------------------------------------------------

    # --------------------------------------------------------------------------

    @staticmethod
    def action_msk(list, default_msk):

        # If List is None, no action
        if list is None:
            return 0

        msk = 0

        # If empty list, return the default action mask
        if len(list) == 0:
            msk = default_msk
            return msk

        all = Options.is_in('a', list)
        if all:
            msk = Run.Msk.Clean | Run.Msk.Make | Run.Msk.Run
        else:
            if Options.is_in('c', list):
                msk |= Run.Msk.Clean
            if Options.is_in('m', list):
                msk |= Run.Msk.Make
            if Options.is_in('r', list):
                msk |= Run.Msk.Run

            # Default the action if clean or run not specified
            if not (msk & Run.Msk.Clean) and not (msk & Run.Msk.Run):
                msk |= Run.Msk.Make

        return msk
    # --------------------------------------------------------------------------
# ------------------------------------------------------------------------------


# ------------------------------------------------------------------------------
def noComponentsFound(printer, workspace, components):

    import difflib
    printer.line(f"Warning: No components found using {components},"
                 "choices are", sep='*')

    # ----------
    # Candidates
    # ----------
    cmps = files.get_components(workspace, '*')
    cmp_names = []
    for cmp_path in cmps:
        cmp_name = os.path.splitext(os.path.split(cmp_path)[1])[0]
        cmp_names.append(cmp_name)

    # -----------------
    # Potential Matches
    # ----------------
    matches = []
    for cmp_name in components:
        ms = difflib.get_close_matches(cmp_name,
                                       cmp_names,
                                       n=4,
                                       cutoff=0.4)
        if len(ms):
            matches.extend(ms)

    icmp = 1
    cmps.sort()
    for cmp_name in cmp_names:
        sep = '<-----' if cmp_name in matches else ''
        printer.item(icmp, cmp_name, sep, '')
        icmp += 1

    if len(matches):
        print()
        matches.sort()
        printer.line("Perhaps you meant", '')
        icmp = 1
        for cmp_name in matches:
            printer.item(icmp, cmp_name, None)
            icmp += 1

    return
# ------------------------------------------------------------------------------


# ------------------------------------------------------------------------------
def doit():
    parser = argparse.ArgumentParser(add_help=False,
                                     fromfile_prefix_chars='@')

    add_arguments(parser)
    args = parser.parse_args()
    if args.help:
        display_manpage(__file__)
        exit(0)

    components = merge(args.parameters, args.components)
    printer = Printer(18, 78, 20)
    needs = Project.Need.Workspace
    if args.ip is not None:
        needs |= (Project.Need.Products_Root
                  | Project.Need.Ip_Root)

    project = Project(needs,
                      args.project,
                      args.root,
                      args.products_root,
                      None,                # build_root not needed
                      args.workspace,
                      None,                # cfg_root   not needed
                      args.ip_dir)

    workspace = project.workspace
    if not workspace:
        print("ERROR: No workspace specified")
        return -1

    options = Options(args.all,
                      args.exclude,
                      args.csim,
                      args.synthesis,
                      args.cosim,
                      args.package,
                      args.implementation,
                      args.ip,
                      args.slow,
                      args.dry_run,
                      args.verbose)

    # ----------------------------
    # Setup IP family augmentation
    # ----------------------------
    ip = None
    if options.stages & (Run.Stage.Ip_Zip | Run.Stage.Ip_Dcp):
        if project.has_project_file:
            ip = project.get_ip()
            if ip:
                ip.replace(args)

        if not ip:
            ip = Project.Ip(dir=args.ip_dir,
                            zip_file=args.ip_zip_file,
                            dcp_file=args.ip_dcp_file,
                            family=args.ip_family,
                            dgn_dir=args.ip_dgn_dir,
                            jou_file=args.ip_dcp_jou_file,
                            log_file=args.ip_dcp_log_file)

        if not ip.dir:
            ip.dir = os.path.join(
                project.products_root, 'ip', '{vitis_version}')

        if not ip.dgn_dir:
            ip.dgn_dir = os.path.join(
                project.build_root, 'ip', 'dgn', '{vitis_version}')

    if args.list:
        if components is None or (len(components) == 0):
            components = ['*']

        workspace = Workspace.get(workspace)
        report(args.verbose, printer, project, workspace, components, 'List')
        cmp_paths = files.get_components(workspace, components)
        if len(cmp_paths):
            idx = 1
            for cmp_path in cmp_paths:
                cmp_name = os.path.split(cmp_path)[1]
                printer.item(idx, cmp_name, '')
                idx += 1
        else:
            noComponentsFound(printer, workspace, components)

        printer.footer()

        return 0

    if options.stages == 0:
        print("ERROR: No action was specify\n"
              "       Specify one of: --csim, --synthesis, --cosim, "
              "--package, --implementation, --ip",
              file=sys.stderr)
        return -1

    run = Run(options, project.root, ip, printer)
    workspace = Workspace.get(workspace)

    report(args.verbose, printer, project, workspace, components, run)

    cmps = files.get_components(workspace, components)
    dry_run = args.dry_run

    if cmps:
        icmp = 1
        cmps = sorted(cmps)
        left = len(cmps)
        for cmp_path in cmps:
            printer.item(icmp, "Component", cmp_path)
            run.execute(cmp_path)
            left -= 1
            icmp += 1
            if left and args.verbose:
                print()
    else:
        noComponentsFound(printer, workspace, components)

    printer.footer()
# ------------------------------------------------------------------------------


if __name__ == '__main__':
    status = doit()
    sys.exit(status)
