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
from pathlib import Path
import glob
from types import SimpleNamespace
from vitispy.version import Version


def add_version(string):
    d = { 'vitis' : SimpleNamespace (version = Version.version) }
    fstr = string.format_map (d)
    return fstr


def expand(string):
    return os.path.expandvars(string)


# ------------------------------------------------------------------------------
def is_creatable(path):
    '''
    Checks that the specified path can be created

    Args:
       path  : The path to check

    Return
       True  if the path can be created
       False if the path cannot be created
    '''
    path = os.path.abspath(path)

    # If it already exists, technically it's "creatable" or already there
    if os.path.exists(path):
        return os.path.isdir(path)

    # Find the closest existing parent directory
    parent = path
    while not os.path.exists(parent):
        new_parent = os.path.dirname(parent)
        if new_parent == parent:  # Reached the root directory
            break
        parent = new_parent

    # Check if that parent is a directory and writable
    return os.path.isdir(parent) and os.access(parent, os.W_OK)
# ------------------------------------------------------------------------------


# ------------------------------------------------------------------------------
# Add '/' if file begins with '${', i.e. a logical to be translated
# -----------------------------------------------------------------
def sanitize(file, rel_path):
    if file[0:1] == "$":
        return os.path.join(os.sep, file)

    elif ((file[0:1] == '/') or (file[0:1] == '\\')):
        return file

    elif rel_path:
        return os.path.relpath(os.path.realpath(os.path.expandvars(file)), rel_path)

    else:
        return os.path.realpath(os.path.expandvars(file))
# ------------------------------------------------------------------------------

# --------------------------------------------------------------------------
# Compose the path to the csim executable directory
# --------------------------------------------------------------------------


def compose_build_dir(workspace):
    build_path = os.path.join(workspace, 'xxx', 'hls', 'csim', 'build')
    return build_path
# ------------------------------------------------------------------------------


# ------------------------------------------------------------------------------
# Get file path of 'file' relative to 'relative'
def get_relative(file, relative):

    relative_path = os.path.relpath(file, relative)
    return relative_path
# ------------------------------------------------------------------------------


# ------------------------------------------------------------------------------
def __is_candidate(file, candidates):
    for candidate in candidates:
        if candidate == file:
            return True
    return False
# ------------------------------------------------------------------------------


# ------------------------------------------------------------------------------
# Return a unique list of files matching the extension
# ----------------------------------------------------
def get_files(string, template):

    # ----------------------------------------
    # Initialize the return file list to empty
    # ----------------------------------------
    file_list = []
    if (not string):
        string = template

    # ----------------------------------------
    # Split a potential comma separated string
    # ----------------------------------------
    if isinstance(string, list):
        clist = string
    else:
        clist = string.split(',')

    if template:
        template = os.path.expandvars(template)
        if os.path.isdir(template):
            template_dir = template
            template_nam = '*'
            template_ext = None
        else:
            template_dir, fname = os.path.split(template)
            template_nam, template_ext = os.path.splitext(fname)
    else:
        # Have neither a string nor a template
        if not string:
            return file_list

    # Get all candidate files as realpaths
    candidates = [os.path.realpath(candidate)
                  for candidate in glob.glob(template)]
    for file in clist:

        # ------------------------------------------------------
        # Only need to expand if there was an input string
        # If there wasn't the list consists only of the template
        # which has already been expanded
        # -------------------------------------------------------
        if string:
            file = os.path.expandvars(file)

        if os.path.isdir(file):
            file_dir = file
            file_nam = None
            file_ext = None
        else:
            file_dir, fname = os.path.split(file)
            file_nam, file_ext = os.path.splitext(fname)

        if not file_dir:
            file_dir = template_dir
        if not file_nam:
            file_nam = template_nam
        if not file_ext:
            file_ext = template_ext

        file = os.path.join(file_dir, file_nam) + file_ext
        fs = glob.glob(file, recursive=True)

        # ------------------------------
        # Get all the files in this list
        # ------------------------------
        for f in fs:

            if not __is_candidate(os.path.realpath(f), candidates):
                continue

            # --------------------
            # Ignore if not a file
            # --------------------
            if (not os.path.isfile(f)):
                continue

            f = os.path.abspath(f)

            # -----------------------------------
            # Only add if not already in the list
            # -----------------------------------
            if (f not in file_list):
                file_list.append(f)

    return file_list
# ------------------------------------------------------------------------------


# ------------------------------------------------------------------------------
def get_components(workspace, components):

    if (not components):
        components = ['*']

    # ---------------------------------------------
    # Initialize the return component list to empty
    # ---------------------------------------------
    cmp_list = []

    # ----------------------------------------
    # Split a potential comma separated string
    # ----------------------------------------
    if isinstance(components, list):
        clist = components
    else:
        clist = components.split(',')

    for cmp in clist:

        # -------------------------------------------------
        # If not an absolute path, default to the workspace
        # -------------------------------------------------
        if (not os.path.isabs(cmp)):
            cmp = os.path.join(workspace, cmp)
        cs = glob.glob(cmp)

        # ------------------------------
        # Get all the files in this list
        # ------------------------------
        for c in cs:

            # -------------------------
            # Ignore if not a directory
            # -------------------------
            if (not os.path.isdir(c)):
                continue

            # -----------------------------------------------------------
            # Ignore if the directory does not contain vitis-compile.json
            # -----------------------------------------------------------
            vitis_comp = Path(os.path.join(c, 'vitis-comp.json'))
            if (not vitis_comp.is_file()):
                continue

            # --------------------------------------------------------------
            # Ignore if the directory does not contain compile_commands.json
            # --------------------------------------------------------------
            compile_commands = Path(os.path.join(c, 'compile_commands.json'))
            if (not compile_commands.is_file()):
                continue

            # Only add if not already in the list
            # -----------------------------------
            if (c not in cmp_list):
                cmp_list.append(c)

    return cmp_list
# ------------------------------------------------------------------------------
