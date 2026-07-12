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

import shutil

from .dry_run import DryRun
from .workspace import Workspace

# ------------------------------------------------------------------------------


class Component:

    def compose_cfg_file(cfg_file, cmp_name):
        if (cfg_file):
            return cfg_file
        else:
            return cmp_name + '.cfg'

    def get_cfg_path(self):
        return self.cfg_path

    # ------------------------------------------------------------------------------

    def __init__(self, project, args, workspace=None):

        self.configurations = project.configurations
        self.workspace = workspace if (
            workspace is not None) else Workspace.get(project.workspace)
        self.replace = args.replace is not None
        self.clean = args.clean is not None
        self.dry_run = DryRun(args.dry_run)

        return
    # ------------------------------------------------------------------------------

    @staticmethod
    def printList(caption, string, printer):
        if isinstance(string, list):
            clist = string
        else:
            clist = string.split(',')

        printer.line(caption)
        for item in clist:
            printer.itemPlain(item, None)
            caption = ' '
        return

    # ------------------------------------------------------------------------------
    def print(self, printer, print_cfg_file):
        printer.line('Workspace', self.workspace)

        if (self.clean):
            comp_label = 'Component     name'
            if (not self.configurations):
                printer.line(comp_label, os.path.join(self.workspace, '*'))

        if (print_cfg_file and self.configurations):
            printer.line("Configurations", self.configurations)
#               self.printList ('Configuration', self.configurations, printer)

        if (self.replace is True):
            action = 'Replace'
        elif (self.clean is True):
            action = 'Clean'
        else:
            action = 'Create'

        printer.line('Action', action)
        self.dry_run.print(printer)
        return
    # ------------------------------------------------------------------------------

    # ------------------------------------------------------------------------------

    def _create_hls_component(self, client):
        self.comp = client.create_hls_component(name=self.cmp_name,
                                                cfg_file=[self.cfg_file],
                                                template="empty_hls_component")
        return True
    # ------------------------------------------------------------------------------

    # ------------------------------------------------------------------------------

    def execute(self, client, cmp_name, cfg_path):

        # -----------------------------------------------------------------
        # If no component name is specified, take it from the cfg_file name
        # -----------------------------------------------------------------
        self.cmp_name = cmp_name
        self.cfg_file = cfg_path

        # -------------------------------------
        # Check if the component already exists
        # -------------------------------------
        self.cmp_dir = os.path.join(self.workspace, self.cmp_name)
        if os.path.exists(self.cmp_dir):

            # ---------------------
            # If only doing a clean
            # ---------------------
            if (self.clean):
                if (not self.dry_run):
                    client.delete_component(self.cmp_name)
                return True, True, "Cleaned"

            # -----------------------------------------------------
            # It already exists, but replace has not been specified
            # so do not remove the current configuration
            # -----------------------------------------------------
            if (not self.replace):
                return False, True, "WARNING: Using existing, (add --replace to replace)"

            # --------------------------------------------------
            # Before removing the component,
            # check that a configuration file has been specified
            # --------------------------------------------------
            if (self.cfg_file is None):
                return False, True, "No configuration file specified"
            else:
                if (not self.dry_run):
                    shutil.rmtree(self.cmp_dir)
                    self._create_hls_component(client)
                return True, True, "Replaced"

        else:

            # ---------------------------------------------------
            # Check a valid configuration file has been specified
            # ---------------------------------------------------
            if (self.cfg_file is None):
                return False, False, "No configuration file specified"

            if (self.clean):
                return False, False, "Clean failed, component does not exist"

            # Create component in the workspace
            if (not self.dry_run):
                self._create_hls_component(client)
            return True, False, "Created"

# ------------------------------------------------------------------------------
