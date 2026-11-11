.. contents:: Table of Contents
   :depth: 3

.. Substition patterns
.. |hlsBs|  replace:: **hlsBs**
.. |hlsCfg| replace:: **hlsCfg**
.. |hlsRun| replace:: **hlsRun**

============================================
hlsBs -- An HLS Development and Build System
============================================

Introduction
============
Welcome to that indispensable thing called documentation. Demanded by
the many, written by the one, destined to be read by the few. Being
honest, a build system is not high on anyone's interest list.

This is a reference manual, *i.e.*, where only the truly lost and
hopelessly confused desperately seeking answers come, the land of last
resort. For those who enjoy reading the *magnifying glass required,
may cause death or blindness* fine print on warning labels, welcome home.

Quick-Start
-----------
Skip to the :ref:`Overview <overview-label>` or go to the
`hlsBs-examples <https://github.com/slaclab/hlsBs-examples>`_ github
repository which is more of a *How-To* user's manual. For many, this
is all that is needed. If the project is beyond the basics, then this
more complete manual may be of interest.

How To Read
-----------
Skim this, look at the section titles, then the first level of bullet
items, take a look at
`hlsBs-examples <https://github.com/slaclab/hlsBs-examples>`_, test drive
it, then come back and read more thoroughly.  Without hands-on experience
as grounding, reference manuals are just a blizzard of words. Learning a
new system is never linear.


Limitations
-----------
Since |hlsBs| depends on the more recent Unified Development Environment
from AMD/Xilinx, only Vitis versions 2023.2 or greater are supported.

.. caution::
   2023.2, being the first version to support the Unified Development
   Environment, has some peculiarities.  |hlsBs| has workarounds, but as
   with all workarounds, there are pitfalls.

   **Recommendation**: Use versions 2024.1 or greater unless there is a
   specific reason to use 2023.2.

Prerequisites
-------------
It is presumed the user is familar with the standard HLS development
process and concepts like the *configuration file*, what a *component*
is, and the various build stages, *i.e.* *run*, *synthesis*, *cosim*,
*etc.*.

|hlsBs| - What is it?
=====================
|hlsBs| is a command-line driven system designed to simplify the
HLS/Vitis build process and aid in the code development, particularly for
projects involving multiple components.  The utility of multiple
components falls into three categories:

- Projects composed of two or more distinct HLS components or variations.
  Here distinct means:

  - Components may run on physically different FPGAs with one
    feeding the other in a daisy-chain fashion.
  - The same project needs to run on multiple FPGA parts.

..

- Tracking the time evolution of a project where usually the components
  are the same basic code but from different *git* commits or even
  the same code using different versions of Vitis.

..

- The same component but with different algorithms or pragma
  parameters to explore the performance/resource tradeoffs.

The goal was, by making it easy to create, build, compare, catalog, and
track multiple components, to encourage experimentation and exploration.
Experience in developing HLS code has shown this is necessary to
achieve the best results. The correct algorithm and pragma
settings are rarely immediately apparent.

.. note::

   Recent advances in AI agents may be helpful in this feedback process,
   primarily in the proper *pragma* settings.  The verdict is still out
   on how much help it is in selecting the proper *algorithm*. Selecting
   the proper algorithm is generally more important than optimizing the
   wrong one.

A truly useful feature of the Vitis IDE/GUI is the ability to compare
components for resource usage and performance in a nicely laid out display.
|hlsBs| tries to leverage this by providing methods to capture and organize
the development evolution and being compatible with the Vitis IDE/GUI
development environment.

   A common theme is realizing some aspect of the resource/performance
   tradeoffs has been overlooked during development and now is far from
   where it was two days ago, *e.g.* the LUT usage has doubled. By
   capturing the steps in the form of components along the way, there is
   a chance to backtrack through these breadcrumbs and locate the
   offending random code/pragma change.

Primary Goals
=============
- Make simple projects simple and more complex projects possible.
- Be compatible with the HLS GUI/IDE build and development system.

  - One can freely mix and match, using whichever one is appropriate
    and comfortable for the task at hand.

- Accommodate building the same project using multiple Vitis versions/releases.

  - This encourages both moving forward with new Vitis versions and
    comparing their differences.

- Handling the drudgery of creating the configuration files and components.

  - This is reduced to almost a *fill-in-the-blanks* exercise.
  - Biggest advantage is when producing multiple, very similar
    components.

- Easily run all or any subset of the various build stages (*csim,
  synthesis, cosim, etc.*) on any collection of components.

More goals and design rationales are listed in the
:ref:`Design Notes <design_notes-label>`.  Understanding
why things were done as they were may prevent swimming
upstream when there may be an easier path.

.. _overview-label:

Overview
========
There are three distinct pieces to |hlsBs|.

- The obligatory environment/context setup
- The *Project* file
- The |hlsBs| commands.

Environment/Context Setup - Brief
---------------------------------
The setup itself has three distinct pieces. These establish

1. The |hlsBs| command set

  - Makes the |hlsBs| commands available to the *bash* shell.
  - There is no dependency on the Vitis version or your specific project, so
    this can be a one-time login thing.

2. The Vitis version to use

   - Once selected, viable until it is changed.

3. Your :ref:`project <project_file-label>` specific setup

.. tip::

   Even though the |hlsBs| setup need only be done at login, it is often
   convenient to include the |hlsBs| setup in your project's setup script.
   Except for the brief amount of time it takes, it is okay to execute it
   multiple times.

.. _project_brief_file-label:

Project File - Brief
--------------------
The :ref:`Project File <project_file-label>` is the source of the information
needed to produce the |hlsBs| output products. This information includes

- The location of the workspace directory containing the Vitis/HLS components.
- The set, location, and contents of the configuration files.
- The location and contents of the :ref:`IP products <get_ip-label>`,
  *i.e.* the modified .zip and .dcp files.


Commands - Brief
----------------
The commands

- use a :ref:`Project File <project_file-label>` to create, manage, and
  define the contents of:

  - The workspace
  - The configuration file and its associated component

..

- produce the output products, *i.e.* *csim*, *synthesis*, *cosim*, *etc*.

  - The :ref:`Project File <project_file-label>` can be used, or
  - Alternately, since no *Project File* is needed once the workspace,
    configuration files, and components have been created, it can be ignored.

    - All that is needed is the workspace which can be specified on the
      command-line either by

      - --workspace=<*workspace_location*> or
      - With the environment variable  **HLSBS_WORKSPACE**.

    - Useful if the workspace, configuration files, and components were
      produced by some means other than |hlsBs|, *e.g.* in a legacy project.

In keeping with the goal of being able to mix techniques, it is
permissible for the configuration files, the workspace, and components
to be generated by some other means. The most common example of this
would be legacy projects. However, not using |hlsBs| to generate
these products will limit some of its most useful features.

The *Setup* will be addressed first, then the |hlsBs| *Commands*,
saving the more complex :ref:`Project File <project_file-label>` for last.

Environment/Context Setup
=========================
If the |hlsBs| defaults are acceptable or the workspace, configuration files,
and components are created by other means, not all these steps may be
necessary.  The following will describe the most |hlsBs|\ -like usage. The first
two steps can be done in any order.

1. Define the environment variable **HLSBS_XILINX_SETUP**

   - This is usually a single path of where to look for the Xilinx
     setup script, *i.e.* the *settings64.sh* file, for the desired Vitis
     version.

   - If there is more than one search path, in the usual Linux convention,
     separate the paths with a colon (':').

   - Since the Vitis installation location is site specific, it cannot be set
     by or be a part of |hlsBs|.

   - As an example, at SLAC, all Xilinx installations are under one root
     directory, so this would be

     .. code-block:: bash

      $ export HLSBS_XILINX_SETUP='/sdf/group/faders/tools/xilinx/${version}'

     where **version** will be filled in when a version (2024.1, 2024.2, *etc.*)
     is selected.

     .. note:: The single quotes prevent the shell from translating
               **${version}** until needed.

     This can be placed in your login script, but, for good reasons,
     many prefer to keep their login scripts minimalist. However, typing that
     at the command-line is no small feat. The suggestion is to
     create a shorthand either (emphasizing that this is just a suggestion to
     make it easier to set **HLSBS_XILINX_SETUP**):

     - define an alias or bash function that can be easily remembered and
       invoked, *e.g.* *hlsToolChain*.

       .. code-block:: bash

          alias hlsToolChain='export HLSBS_XILINX_SETUP=/sdf/group/faders/tools/xilinx/\${version}'

       or

       .. code-block:: bash

          hlsToolChain()
          {
             export HLSBS_XILINX_SETUP='/sdf/group/faders/tools/xilinx/${version}'
          }

       .. tip::

          The name, here *hlsToolChain*, is entirely your own choosing.
          Pick something meaningful, unique, and short. Place it in a
          script that is executed as part of your bash login, remembering
          this is only a definition. ``hlsToolChain`` must eventually
          be executed either manually and within a script.

     The bash function is the safer choice since it better hides the
     variable *version* from being altered by the shell.

     Be as specific with the path as possible. Since this involves a
     file search, a broad search may be slow. At some sites it may be
     better to have multiple, more specific paths, than a single broad
     one.

     - The target *version* must appear somewhere in the search path.

       The assumption by |hlsBs| is that the version appears either
       in the directory path or the setting's file name.

       In the highly unusual case that the Vitis version is not part of the
       file path/name, then some other way of selecting and setting up
       the Vitis version must be used.

  - Defining this environment variable can be omitted if some other
    method of selecting and invoking the desired version specific Vitis
    setup script is preferred. However, the full functionality of the
    command ``$ hlsVersion <version>`` depends on this environment
    variable, so the convenience of easily using *hlsVersion* to switch
    versions will be lost.

2. Source the |hlsBs| setup script

   ``$ source <path/to>/ruckus/vitis/hlsBs/scripts/setup_hls.sh``

   - This merely makes the commands available to the bash shell; there is
     nothing project or Vitis version specific.

     As such, it can be a one-time step at login time, perhaps combined
     with the first step.

     .. tip::

       Commonly, *ruckus* will be a submodule of the project and it
       may be more natural to include this in the project's setup script,
       since the |hlsBs| setup script can be located relative to the project.

       Except for the time (it does not take long), it may be repeatedly
       executed.

3. Establish the Vitis version to use

   ``$ hlsVersion <vitis-version>``

   If *vitis-version* is specified, the Vitis setup script for that
   version is sourced.

     - HLSBS_XILINX_SETUP environment variable must be appropriately set.
     - This makes it very convenient for switching between Vitis versions.

   If *vitis-version* is not specified **and** the version has been established
   in some other way, **hlsVersion** will use that currently established
   version.

   - Once the Xilinx/Vitis version has been established, the internal
     |hlsBs| version dependent context is initialized.

   - Again, no project specific context is set up.

   - Example:

      ``$ hlsVersion 2025.1``

..

4. Selecting the target project is covered in the
   :ref:`Project File - Overview <project_file-label>` section.

The Commands
============
This is a listing of all the commands, presented roughly in logical usage order,
along with a brief description. All commands have a corresponding
**man** page which can be invoked by either

  .. code-block:: bash

    $ hls<Cmd> [-h | --help]
    $ man hls<Cmd>

See the `hlsBs-examples <https://github.com/slaclab/hlsBs-examples>`_
repository for more of a *How-To*.

.. list-table:: hlsBs Commands
   :header-rows: 1

   * - Command
     - Description
   * - hlsBs
     - Provides a quick summary of all the commands, the online version of this section.
   * - hlsVersion
     - Establishes the Xilinx/Vitis version to be used.
   * - hlsWs
     - Creates, removes, and provides information on the workspace.
   * - hlsCfg
     - Creates, replaces, cleans, and lists the configuration files and components.
   * - hlsComp
     - |
       | Creates, replaces, cleans, lists the components.
       | Useful when you only have the configuration file - **rarely used**.
       | Possible use: when the configuration files, but not the components, are saved to *Git*.
   * - hlsRun
     - |
       | Runs any or all build stages (*csim, synthesis, cosim, package, implementation, ip*)
       | on all or any subset of existing components.
   * - hlsExe
     - |
       | Runs *csim.exe* for a specified component.
       | Useful when changing the arguments, *e.g.* changing the test files or the number of tests.
   * - hlsGdb
     - Invokes the debugger on a specified component; the gdb version of hlsExe.
   * - hlsGui
     - Starts the IDE/GUI.
   * - hlsCtx
     - Shows the values of the environment variables in current use by |hlsBs|.

Once the workspace has been established and the configuration files and components
created (often one-time per project activities), the vast majority of the use is
|hlsRun|, with the occasional use of **hlsExe** and **hlsGdb** during
development and debugging.

.. _a_word_of_caution_parameters-label:

Bashing Bash - A Word of Caution on Command-Line Parameters
-----------------------------------------------------------
This is the section you didn't think you needed until the unexplainable happens.

There are a few bash shell *gotchas*. These aren't peculiar to |hlsBs|, but
it seems particularly vulnerable.

1. The target component names of the |hlsBs| commands may include wildcards,
   which the shell is all too eager to translate by finding matching patterns
   in the file names of the current working directory. Unless the current
   working directory is the target of the translation, this will not yield the
   desired results.

   Even more insidious, if there are no matching files, as per bash shell
   rules, the translation will fail and the wildcard will be passed as is,
   yielding the desired results. While this sounds like a good thing, this
   can lead to very mysterious behavior; a recalled command that previously
   worked may now not work because the current working directory has changed
   or a new file was added that now satisfies the wildcard.

   There are two methods to prevent this.

   - Always single quote any wildcarded name if the component is specified
     as a positional argument,
     *e.g.* ``'a*'``
   - Use the alternative optional argument syntax to specify the components,
     *e.g.* ``--components=a*``.
     The ``--components`` can be abbreviated to the minimum to be unique,
     *e.g.* ``--comp``.

..

2. Do not place a positional parameter immediately following an optional
   parameter that accepts a value or list of values.  Since the bash shell
   enforces no formal binding or grouping, a positional parameter juxtaposed
   to such an optional parameter will be *eaten* by that optional parameter.
   To avoid this, do one of

   - Make any positional parameter the first parameter.
   - Use the optional parameter, ``--component=a*``

   Example of what not to do:

       ``$ hlsCfg --list '*'``

       Since ``--list`` takes a list of component categories, effectively this
       will be seen as ``--list='*'``, certainly not the intent.

   .. caution::

      Use positional parameters sparingly, favoring the optional
      parameter form ``--components=*``. While the ``=`` is optional, it
      does bind the parameter list and, as a bonus, prevents the shell
      from expanding the wildcard even without the single quotes. It is
      the most foolproof method and, along with using the full keyword name
      of an optional parameter, always should be used when scripting
      these commands.

      Bottom Line: Positional parameters can be problematic.

.. _project_file-label:

Project File - Overview
=======================
The *Project File* is the source of information that makes |hlsBs| commands easy to
use at the terminal. It is Python code that gets invoked by the |hlsBs| commands.
Python was chosen because

- Python is familiar to many and is a good match for the task.
- Python can implement the simple to the complex.
- Errors are nicely reported by the Python interpreter.
- Easy to interface with the Vitis Python APIs.

Locating the Project File
-------------------------
Obviously the location of the *Project File* itself cannot be sourced from the
*Project file*. There are two ways to specify the *Project File* location:

- By setting its environment variable

  .. code-block:: bash

     # Commands will then use this environment variable as the *Project File*
     $ export HLSBS_PROJECT=<Project File location>

- Directly on the command-line

  .. code-block:: bash

     # Only this command will use this *Project File* location
     $ hlsWs --create --project=<Project File location>

The latter is an example of a command-line variable overriding the static setting
of the environment variable.

.. tip::

   Define the environment variable for normal usage.  Typically
   this would be defined in the project's setup script. The second form
   is useful to test variations of the *Project File*.

While many values in the *Project File* can be overridden on the command-line or
with :ref:`HLSBS_ environment variables <environment_variables-label>`, normal
usage is to use the values in the *Project File*. Not only does this decrease
typing at the command-line, it also ensures consistency from command to command
and helps to eliminate errors caused by typos.

An example of standard and non-standard usage might be

.. code-block:: bash

   $ hlsWs --create  # Create the workspace defined in the *Project File* specified by HLSBS_PROJECT
                     # or, if defined, HLSBS_WORKSPACE.
   $ hlsWs --create --workspace=/tmp/tmp_workspace  # Create an ad-hoc workspace as a playpen

As is true in many cases, the advantage of the first form is that this definition
is hidden and need not be remembered and the disadvantage is that this definition
is hidden and is not remembered. When in doubt about this hidden context, use
**hlsCtx** to display the implicit |hlsBs| context information.

.. _environment_variables-label:

Environment Variables
---------------------
The following environment variables are recognized. These override potential
equivalent values in the *Project File*, but they themselves can be overridden
on the command-line with explicit parameters, *e.g.*

.. code-block:: bash

   $ hlsWs --create --project=<my_project_file>

.. list-table::
   :header-rows: 1

   * - Variable
     - Meaning
   * - HLSBS_XILINX_SETUP
     - The search path(s) for the Xilinx/Vitis settings scripts
   * - HLSBS_PROJECT
     - The Project File
   * - HLSBS_PRODUCTS_ROOT
     - The products' directory
   * - HLSBS_BUILD_ROOT
     - The build root directory
   * - HLSBS_WORKSPACE
     - The workspace
   * - HLSBS_CFG_ROOT
     - The configuration files' directory
   * - HLSBS_IP_ROOT
     - The ip (modified .zip & .dcp) files' directory
   * - HLSBS_IP_VERSION
     - The IP packaging version
   * - HLSBS_PF
     - A colon-separated list of parameter files, *e.g.* @FILE1.txt:FILE2.txt

Usage
~~~~~
The **HLSBS_PRODUCTS_ROOT**, **HLSBS_BUILD_ROOT**, **HLSBS_WORKSPACE**,
**HLSBS_CFG_ROOT**, and **HLSBS_IP_ROOT** environment variables are
useful for one-off ad-hoc experimentation. Products produced during
such experimentation can be redirected so as to not pollute the
regular directories.

**HLSBS_PF** is an :ref:`advanced feature <parameter_files-label>` courtesy
of Python's *argparse* class. It allows one to collect a number of
:ref:`parameter files <parameter_files-label>` used to modify command-line
parameters in a colon-separated list of such files.

   The format of file is not ideal. It is unfortunate that *argparse* does not
   allow an include mechanism so that files with well-defined purposes can be
   mixed and matched.

All user-facing |hlsBs| environment variables begin with **HLSBS_**. These can
be listed using **hlsCtx**.

Structure
---------
The *Project File* is a piece of user-written Python. As a practical matter,
in many cases it will be cloned from a similar project with a few name
changes, *e.g.* the names of the source files, where the includes are, the
*csim.exe* command-line parameters, *etc*. Since it is Python, more complex
projects, for example projects with multiple components like the SNL Test suite
(>25 components) can be accommodated.

.. tip::

   The standard Vitis method in the GUI/IDE works fine when creating a
   single configuration/component, but creating many components is not
   only tedious, but, once created, implementing a change common to all
   is error prone. The Python *Project File* is much better suited in creating
   multiple configuration files and components.

With experience it is anticipated that a small collection of stock project
template files will be accumulated.  For example, one for a simple project with
a single testbench and *HLS* source file, reducing it to a *fill-in-the-form*
exercise.

    There is already one for SNL. Here the structure is static and
    basically all that is needed is the network definition file, the target
    FPGA, and the test files. A universal file (SNL.py) provides the
    boilerplate contained in a single class initialized with the values
    (*e.g.* the SNL network, data files, *etc.*) from the project dependent
    *Project File*.

.. warning::

   A downside of the *Project File* is only the basic HLS configuration file
   settings are available. Due to their sheer number and the fact that some
   change Vitis release to release, it was practical to implement only the
   most basic. If experience shows that a more expansive set is needed,
   a method of adding these via a user-provided Python method can be added.

.. _product_parameter-label:

Environment Variables & Product Parameters
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Environment variables (both the
:ref:`hlsBs defined ones <environment_variables-label>` and user defined
project specific ones) and *product parameters* -- think of them as
variables in a programming language -- are used extensively in the *Project
File*. This is one of the primary advantages of |hlsBs| over the standard
Xilinx/Vitis/HLS methods.  It allows for abstraction; instead of hard-coding,
environment variables and *product parameters*, such as a *product parameter*
representing the configuration file name, can be used.

Product Parameters
^^^^^^^^^^^^^^^^^^

Many *Product* classes define a set of *product parameters*.  These behave
like a Python class, having a name (generally referred to in this document as
the *prefix*) and a set of attributes. An example is *fpga.part*.
These can be used within the *Project File* as references to their actual values
for the product being constructed. For example, in a *Project File* defining
products with different FPGAs, *fpga.part* is the FPGA part for each specific
component.

Conventions: What to Name the Project File & Where to Put It
------------------------------------------------------------
While the *Project File* can go anywhere simply by defining **HLSBS_PROJECT** as its
location, using the recommended location in the directory tree is the
easiest. It should be used unless there is good reason not to.

.. tip::

   Place the *Project File* in the */project* subdirectory of the
   project's top level directory and name it after the project.
   Again, not necessary, but standard placement and usage helps others
   sharing the project.

Project File - Annotated Example
================================
To bring some concreteness to the discussion below, a hypothetical project
(called *example*) with the following directory structure will be assumed.

.. warning::

   This is not a working example. It is only meant to illustrate the basics
   of the overall structure of a |hlsBs| project.  See the
   `hlsBs-examples <https://github.com/slaclab/hlsBs-examples>`_ repository
   for complete working examples.

.. code-block:: text

   example/
   ├── project/ExampleProject.py
   ├── src/example/
   │   ├── ExampleTb.cc
   │   └── ExampleHls.cc
   └── include/example/
       ├── Example.hh
       └── opt/
           ├── Opt1.hh
           └── Opt2.hh

The |hlsBs| commands produce a variety of output products. The default layout is

.. code-block:: text

   example/
   └── products/
       ├── build/                    # Excluded from Git via .gitignore
       │   ├── ws/{vitis-version}    # Workspace for a particular Vitis version
       │   └── cfg/{vitis-version}   # Configuration files directory
       └── ip/{vitis-version}        # Modified .dcp and .zip files

The *Project File* is a handful of user-provided Python methods. These methods
break into two distinct categories:

- Those locating the directories where the output products go
- Those that define the configuration file and IP products contents

Those defining the directories of the output products are optional if their
defaults are acceptable. The default can be used by

- Omitting the method
- Returning *None*

.. tip::

   If accepting the defaults, rather than omitting the method, it may be
   helpful to specify the methods but have them return *None*. This serves as
   a visual reminder that the method can be changed if the defaults are not
   acceptable. For experienced, in-the-know users, omitting the method is
   perfectly valid.

The second set consists of 2 methods

   - :ref:`get_products <get_products-label>`
   - :ref:`get_ip <get_ip-label>`

Only *get_products* is mandatory.

.. warning::
   While :ref:`get_ip <get_ip-label>` method is optional, accepting the
   defaults could be problematic. Accepting the default implies that the
   output products are valid for all known FPGA families.

.. _product_directory-label:

Product Directory Methods
-------------------------
These methods locate the directories that receive the output products.
They all follow a common pattern.

- Omitting the method or returning *None* from the method results in the default
  directory specification.
- The examples in each are the defaults.

All the examples root the target directory using a directory within
the *project* class except the *project_root* directory, which, because
it is the anchor directory, is located relative to the *Project File*.
This keeps environment variables (which may be forgotten to be set)
and absolute file paths out of the *Project File* resulting in a
configuration file that is more self-contained and portable.

.. tip::

   Use the directory specification as it appears within the *project* class
   as the base directory.  For example, the *build* directory is located by

   ``os.path.join (project.products_root, 'build')``.

   This is because *project.products_root*, or any of the other directories,
   may be overridden either by an environment variable (*e.g.*
   **HLSBS_PRODUCTS_ROOT**) or on the command-line. Overriding is useful for
   redirecting the product to a one-off, ad-hoc directory for experimentation
   or testing purposes.

   While many of the default directories include the Vitis version, when composing
   your own directories, consider also including the Vitis version.  In addition,
   for some applications which may wish to keep directories by the Git tag or
   hash code, various *Git* attributes can be added to the directory, *.e.g.*

   .. code-block:: python

      product_root = os.path.join (project.root, 'products', '{git.hash_msg}')

      # To selectively add the tag only if exists and the hash_msg if not
      gitdir = '{git.tag}' if project.git.tag else '{git.hash_msg}'
      product_root = os.path.join (project.root, 'products', gitdir)

   Note that either the *project.git.tag* or *'{git.tag}'* form produce the same
   result. The *'{git.tag}'* nomenclature is stylistically consistent, but either
   works.  The complete listing of all *Git* *product parameters* is given
   :ref:`here <git_product_parameters-label>`.

.. _get_project_root-label:

get_project_root (project)
~~~~~~~~~~~~~~~~~~~~~~~~~~
This returns the project's root directory.

Example:

.. code-block:: python

   def get_project_root (project) : return os.path.dirname(os.path.dirname(__file__))

or the more modern and syntactically cleaner

.. code-block:: python

   def get_project_root (project) : return Path(__file__).resolve().parent.parent

.. tip::

   Locate the *project_root* directory relative to the *Project File*.

.. _get_products_root-label:

get_products_root (project)
~~~~~~~~~~~~~~~~~~~~~~~~~~~
This returns the umbrella directory where the various products (workspace,
configuration files, ip diagnostic/log files) are placed.  While |hlsBs|
provides the ability to individually place these anywhere, it is convenient
to place these within a common directory. Doing so allows one to remove all
products with a simple ``rm -rf <products_dir>``.

Environment Variable: **HLSBS_PRODUCTS_ROOT**

Example:

.. code-block:: python

   def get_products_root (project) : return os.path.join (project.root, 'products')

.. tip::

  Locate the *products_root* directory relative to the *project.root*
  directory.

  .. _get_build-label:

get_build_root (project)
~~~~~~~~~~~~~~~~~~~~~~~~
This returns the build directory. It is customary to place output products
that will not be committed to *Git* in this directory or subdirectories of it.
Typically, the *build* directory is excluded by an entry in *.gitignore*.

Environment Variable: **HLSBS_BUILD_ROOT**

Example:

.. code-block:: python

   def get_build_root (project) : return os.path.join (project.products_root, 'build')

.. tip::

   Locate the build directory relative to the *project.products_root*
   directory.

.. _get_workspace-label:

get_workspace (project)
~~~~~~~~~~~~~~~~~~~~~~~
This returns the location of the workspace directory.

Environment Variable: **HLSBS_WORKSPACE**

Example:

.. code-block:: python

   def get_workspace (project) : return os.path.join (project.build, 'ws', '{vitis.version}')

Here *'{vitis.version}'* is the first encounter of a
:ref:`product parameter <product_parameter-label>`.  This allows the workspace
to be distinguished by the Vitis version which will be resolved to the
current Vitis version, typically set by **hlsVersion**, when the workspace
is referenced.

.. tip::

   Locate the workspace relative to the build directory and include the Vitis version.

.. _get_cfg_root-label:

get_cfg_root (project)
~~~~~~~~~~~~~~~~~~~~~~
This returns the root directory where all configuration files will be stored.

Environment Variable: **HLSBS_CFG_ROOT**

Example:

.. code-block:: python

   def get_cfg_root (project) : return os.path.join (project.build, 'cfg', '{vitis.version}')

.. tip::

   Locate the configuration directory relative to the project.build directory
   and include the Vitis version.

A reason not to locate it relative to the build directory is if you wish
the configuration files to be committed to *Git*.  This is unusual, but
because |hlsCfg| ensures that all file references that can be made relative to
the project directory are, it can be useful. If the resulting configuration
contains no absolute file paths, project can be checked out of *Git* and used as
is.

In this case, a reasonable alternative is to locate the configuration directory
relative to the *project.products_root* directory so that it may be saved in
*Git*.

.. _get_ip_root-label:

get_ip_root (project)
~~~~~~~~~~~~~~~~~~~~~
This returns the root directory where *ip* products, the modified *.dcp*
and *.zip* files will be written.

Environment Variable: **HLSBS_IP_ROOT**

Example:

.. code-block:: python

   def get_ip_root (project) : return os.path.join (project.products_root, 'ip', '{vitis.version}')

.. tip::

   Locate the *ip* directory relative to the *project.products_root*
   directory and include the Vitis version.

.. warning::

   The produced *.dcp* and *.zip* files can be large.  If committing to *Git*, consider
   adding

   .. code-block:: text

     *.dcp filter=lfs diff=lfs merge=lfs -text
     *.zip filter=lfs diff=lfs merge=lfs -text

   to the *.gitattributes* file.

As in the *workspace* and *cfg*, the version allows the IP products file to
be distinguished by the Vitis version and will be resolved when the
*ip root* directory is referenced.

.. _get_products-label:

Product Definition Method
-------------------------
This specifies all the information needed to define the configuration files
and components. As such, there is a lot more to it.

.. tip::
   Look over the contents of :ref:`get_products <get_products_code-label>`.
   This will give you the big picture and use the annotated version to
   clarify.

   Try not to get lost in details. Keep these necessary ingredients in mind
   when building HLS code:

      - The testbench and synthesis/HLS files
      - Their -I include paths
      - Any -D macro definitions
      - The top level function name
      - The arguments to *csim* and *cosim*
      - Where to put the configuration files and the workspace

   In general, there is a Python class for each of these.

   Do not let the following amount of text deter you. Documenting even
   simple concepts at the level needed to code against is necessarily
   lengthy.

..

Stylistic Choices
~~~~~~~~~~~~~~~~~
In the following example, many Python local variables are used to make the
intent clearer.  Whether that has been achieved is up for debate.

In addition, the example specifies all the parameters by their keyword.
The parameters have been listed in the call order so that as one becomes more
familiar with the classes, the keywords can be omitted.

Both make the *Project File* more wordy than one in practice would be.

.. tip::

   Given that performance is not an issue, clarity suggests using the keywords.
   Using keywords adds to the robustness -- keyword usage protects against
   possible changes to the parameter ordering in a future |hlsBs| release.

Conventions
~~~~~~~~~~~

The parameter names used in various |hlsBs| Python classes use the plural
when said parameter can accept a single, list, or tuple. This is sometimes
ambiguous when the parameter naturally references a single *set* of things.

Many of the parameters in the *Product* classes can be omitted
or specified as *None*, in which case |hlsBs| will provide defaults.
For each class's defaulting options see the
:ref:`Product Class <class_documentation-label>` documentation or the
explicit examples in

- `ex0 Project File <https://github.com/slaclab/hlsBs-examples/tree/main/firmware/ex0/project/Streams.py>`_  - a very minimalist version

- `ex1 Project File <https://github.com/slaclab/hlsBs-examples/tree/main/firmware/ex1/project/Streams.py>`_ - explicitly specifies parameters as their defaulted values.

get_products - An example
~~~~~~~~~~~~~~~~~~~~~~~~~
A line-by-line annotation follows the *get_products* listing.

.. _get_products_code-label:

.. code-block:: python

   # ------------------------------------------------------------------------------
   def get_products (project) :

       # ------------------------
       # Shorthand to save typing
       # ------------------------
       Product       = project.Product

       # -------------------------------------------------------------------
       # The directory source and include file paths will be referenced from
       # -------------------------------------------------------------------
       code_root     = project.root

       # -------------------------------------------
       # Define the include path <code_root>/include
       # -------------------------------------------
       include_paths = Product.IncludePaths (root  = code_root,
                                             paths = 'include',
                                             type  = 'rel_path')

       # ----------------------------------------------
       # Adds a #define VERBOSE true to the source code
       # ----------------------------------------------
       verbose       = Product.DefineValue  (name  = 'VERBOSE',
                                             value = 'true')

       # -----------------------------------------------------------
       # Includes an explicitly named file to the source code via an
       # #include IMPORT_FILE(OPT_FILE)
       # -----------------------------------------------------------
       opt_file      = Product.IncludeFile  (name     = 'OPT_FILE',
                                             inc_path = 'opt/Opt1.hh',
                                             rel_path = include_paths)

       # -------------------------------------------------------
       # Defines the testbench and hls/synthesis source files
       # -------------------------------------------------------
       tb_srcs       = Product.Sources (root     = code_root,
                                        files    = 'src/example/ExampleTb.cc',
                                        includes = include_paths,
                                        defines  = (verbose, opt_file))

       syn_srcs      = Product.Sources (root     = code_root,
                                        files    = 'src/example/ExampleHls.cc',
                                        includes = include_paths,
                                        defines  = opt_file)

       # ---------------
       # Creates a build
       # ---------------
       build         = Product.Build (id         = 'example',
                                      top        = 'doit',
                                      tb         = tb_srcs,
                                      syn        = syn_srcs,
                                      csim_argv  = '--ntests=10',
                                      cosim_argv = '--ntests=100')

       # ------------------------
       # Defines two target FPGAs
       # ------------------------
       fpgas         = (Product.Fpga (id          = '6ns',
                                      part        = 'xcku115-flvb2104-2-i',
                                      clock       = '6',
                                      uncertainty = None),

                        Product.Fpga (id          = '5ns',
                                      part        = 'xcku115-flvb2104-2-i',
                                      clock       = '5',
                                      uncertainty = None))

       # ----------------------------------
       # Creates the component contributors
       # ----------------------------------
       ctb_builds    = Product.CtbBuilds (prefix  = 'build',
                                          builds  =  build)

       ctb_fpgas     = Product.CtbFpgas  (prefix  = 'fpga',
                                          fpgas   =  fpgas)

       # --------------------------------------------------------------------
       # Defines the list of contributors to be used in defining a component.
       # --------------------------------------------------------------------
       contributors = Product.Contributors (builds = ctb_builds,
                                            fpgas  = ctb_fpgas)

       # -------------------------------------------------------------------
       # Defines the component template which uniquely names the components.
       # This is the default.
       # -------------------------------------------------------------------
       cmp_template = Product.CmpTemplate  (prefix   = 'cmp',
                                            template = '{build.id}-{fpga.id}')

       # -----------------------------------------------------------
       # Defines the configuration template which uniquely names the
       # configuration file path. This is the default.
       # -----------------------------------------------------------
       cfg_template = Product.CfgTemplate  (prefix   = 'cfg',
                                            template = '{cmp.name}')

       # -----------------------
       # Define an HLS component
       # -----------------------
       components     = Product.Components  (contributors = contributors,
                                             cmp_template = cmp_template,
                                             cfg_template = cfg_template)

       # --------------------
       # The Vitis Package IP
       # --------------------
       package_ip     = Product.Package.Ip     (name     = '{cfg.name}',
                                                vendor   = 'SLAC',
                                                version  = '1.0.0',
                                                library  = 'hls')

       # ------------------------
       # The Vitis Package Output
       # ------------------------
       package_output = Product.Package.Output (format  = 'ip_catalog',
                                                syn     = 'false')

       # -------------
       # The Packaging
       # -------------
       package        = Product.Package        (ip      = package_ip,
                                                output  = package_output)

       # --------------------
       # Vivado Specification
       # --------------------
       vivado         = Product.Vivado         (flow    ='syn',
                                                syn_dcp = '1')

       # ------------------------------------------------------
       # Returns a single, list, or tuple of product instances.
       # ------------------------------------------------------
       return Product (project    = project,
                       components = components,
                       package    = package,
                       vivado     = vivado)
   # ------------------------------------------------------------------------------

Convenience Declarations
~~~~~~~~~~~~~~~~~~~~~~~~
Since this is Python, defining variables and symbols to both shorten
typing, capture common concepts, or make the code more readable is
encouraged.

.. code-block:: python

      Product = project.Product

*Product* is merely a shorthand used to access the inner classes defined in
the Project class. It avoids having to do an explicit import which
would require either modifying the **PYTHONPATH** or some other way of
locating it. This keeps the user's *Project File* free of unnecessary details.

.. code-block:: python

   code_root = project.root

*code_root* is a convenience variable used to locate the source code and
include file paths relative to it. If there were source code or include files
pulled from other directories, additional variables locating those could
be defined.

.. tip::
   There is nothing mandatory or magical about these two definitions.
   Use or omit them in your *Project File* as you see fit.

.. _class_documentation-label:

Product Definition Classes
--------------------------

.. _product_classes-label:

.. _include_paths-label:

IncludePaths
~~~~~~~~~~~~
This class defines one or more include paths to search when resolving
include files.

.. code-block:: python

   include_paths = Product.IncludePaths (root  = code_root,
                                         paths = 'include',
                                         type  = 'rel_path')

.. list-table:: IncludePaths Parameters
   :header-rows: 1

   * - Parameter
     - Meaning
   * - root
     - |
       | The directory path for all *paths* that are not absolute file paths.
       | May be specified as *None* if all the paths are absolute.
   * - paths
     - A single path or a list or tuple of paths.
   * - type
     - |
       | '*rel_path*': Makes the include path relative to the source file including it.
       | or
       | '*abs_path*': Uses the include path as is.

.. tip::

   Use *rel_path* when the include path is in the same directory tree as the
   source files it will be used with. This keeps absolute file paths out of
   the generated configuration file.

   - Use *'rel_path'* for all *in package* includes.
   - Use *'rel_path'* whenever possible.

   It is the default and can be set to *None* or omitted.

   Use '*abs_path*' when the include file is not in the same directory tree.

     - An example is including files from an external package.
     - Here using an environment variable to locate the external package
       is reasonable.

The *include_paths* may be a single path, list, or tuple of paths.
This would be necessary if, for example, there are multiple include paths
for the project. In general, external include paths can not be added to
this common instance of *paths* if

- They are not absolute paths, so they would likely incorrectly use *root*
  as the base directory.
- They may wish to use a different *type* (*i.e.* *abs_path*, not *rel_path*)

The solution in either of these cases is to define another instance of
:ref:`Product.IncludePaths <include_paths-label>` with appropriate *root*
and *type* values. Any number of
:ref:`Product.IncludePaths <include_paths-label>` may be included in
:ref:`Product.Sources <sources-label>` class.

.. warning::

   While environment variables can be used in specifying the
   include file paths, please see :ref:`A Word of Caution on
   Environment Variables <caution_environment_variables-label>`.

.. _define_value-label:

DefineValue
~~~~~~~~~~~
This class results in a preprocessor macro definition, *i.e.*
``#define MACRO_NAME value``, in the source code.

.. code-block:: python

   verbose = Product.DefineValue (name  = 'VERBOSE',
                                  value = 'true')

.. list-table:: Define Value Parameters
   :header-rows: 1

   * - Parameter
     - Meaning
   * - name
     - The macro name to represent the value
   * - value
     - The value to be assigned to *name*

It is made available to the relevant source code files via the
``defines =`` parameter in the instantiation of the
:ref:`Product.Sources <sources-label>` class.

    In :ref:`Beyond the Basics<beyond_basics-label>`,
    :ref:`Product.CtbValues <product_ctb_values-label>` shows how
    to use per-component *product parameter* values, replacing the explicit
    *value*, to leverage :ref:`Product.DefineValue <define_value-label>` into
    generating multiple components, each with a different value of the macro
    name. The defines are drawn from a list or tuple of
    :ref:`Product.Value <product_value-label>` instances.

.. _include_file-label:

IncludeFile
~~~~~~~~~~~
This class forces a preprocessor *#include* of the specified into the
source file.

.. code-block:: python

   opt_file = Product.IncludeFile (name     = 'OPT_FILE',
                                   inc_path = 'opt/Opt1.hh',
                                   rel_path = include_paths)

.. list-table:: IncludeFile Parameters
   :header-rows: 1

   * - Parameter
     - Meaning
   * - name
     - The #define macro name used to represent the file
   * - inc_path
     - The path of the file to be included
   * - rel_path
     - The file is located relative to this path

This introduces a ``#define OPT_FILE opt/Opt<X>.hh`` into the
:ref:`Product.Sources <sources-label>` by specifying the
`defines = opt_file` parameter. It is a variation of
:ref:`Product.DefineValue <define_value-label>` for including files
which has special semantics when explicitly including a file with a
macro name.

   In the source file, the file must be included by

   .. code-block:: c++

      #include IMPORT_FILE(OPT_FILE)

   .. note::

      Unfortunately due to Vitis/HLS's inconsistent handling of quoted strings in
      the make file and the Vitis utility to drive the cosim, the IMPORT_FILE
      macro is necessary.

The key point here is that the file name is not explicit in the source
file, but instead is represented by a macro name in the source file set
by :ref:`Product.IncludeFile <include_file-label>`.

.. tip::

   In :ref:`Beyond the Basics<beyond_basics-label>`,
   :ref:`Product.CtbFiles <product_ctb_files-label>` shows how to use a
   per-component *product parameter* value instead of an explicit
   file name to leverage :ref:`Product.IncludeFile <include_file-label>`
   to generate multiple components from a set of include files, usually
   defined by a wildcard, *i.e.* *'\*.hh*'.

      A possible usage is to define coherent sets of different optimization
      parameters, data types, and even complete methods in separate include
      files. By using wildcards to specify the include files, the configuration
      files/components would be created without modifying the source code
      nor the *Project File*, being driven entirely by the set of include files.
      Using the files within a dedicated directory is a common idiom used to
      create a list of files.

.. _sources-label:

Sources
~~~~~~~
This class is used to define both the testbench and **HLS** synthesis files
along with any necessary include paths and macro definitions.

.. _product_sources-label:

.. code-block::  python

   tb_srcs  = Product.Sources (root     = code_root,
                               files    = 'src/example/ExampleTb.cc',
                               includes = include_paths,
                               defines  = (verbose, opt_file))

   syn_srcs = Product.Sources (root     = code_root,
                               files    = 'src/example/ExampleHls.cc',
                               includes = include_paths,
                               defines  = opt_file)

.. list-table:: Sources Parameters
   :header-rows: 1

   * - Parameter
     - Meaning
   * - root
     - Used as the directory path for all *files* that are not absolute file
       paths
   * - files
     - The single, list, or tuple of files
   * - includes
     - The include paths to be used for all *files*
   * - defines
     - |
       | Introduces ``#define`` macro names and/or files that will be
       | included at compile time. These values and/or included files
       | can be *hard-coded*, as in this example, but can come from a
       | list of values or a file list, *e.g.* a wildcard list, with
       | each value or file generating a new build/component. See
       |
       | :ref:`Product.CtbValues <product_ctb_values-label>` and
       | :ref:`Product.CtbFiles <product_ctb_files-label>`

Multiple instances of :ref:`Product.Sources <sources-label>` may be defined
if the source files

- Have a different root directory.
- Have a different set of include paths and/or defines.

.. tip::

   If a source file has a different set of include paths and/or defines,
   instantiate another instance of :ref:`Product.Sources <sources-label>`
   using the values appropriate to those sources.

   The problem of sponging off existing definitions is that overly broad
   include paths and irrelevant defines can lead to

   - slowing the compilation down as many search paths are explored
   - finding an incorrect include file
   - unwittingly and incorrectly setting/using a #define macro name

   This is just clean coding. In 90% of the cases, a little time typing can be
   saved, but in 10%, if the wrong file is included or a #define macro name is
   incorrectly used, it can take hours or days to find the root cause.

.. _build-label:

Build
~~~~~
This class defines all the ingredients necessary to build the *csim*, *synthesis*,
*cosim*, *etc.*.

.. code-block:: python

    build        = Product.Build (id         = 'example',
                                  top        = 'doit',
                                  tb         = tb_srcs,
                                  syn        = syn_srcs,
                                  csim_argv  = '--ntests=10',
                                  cosim_argv = '--ntests=100')

.. list-table:: Build Parameters
   :header-rows: 1

   * - Key
     - Meaning
   * - id
     - Identifier of this build
   * - top
     - Name of the top-level HLS method
   * - tb
     - The single, list, or tuple of testbench *Product.Sources*
   * - syn
     - The single, list, or tuple of HLS/synthesis *Product.Sources*
   * - csim_argv
     - The command-line parameters to pass to *csim.exe*
   * - cosim_argv
     - The command-line parameters to pass to *cosim.exe*

.. note::

   Even though *'tb'* and *'syn'* can accept a list or tuple,
   they are not specified as plurals on the (debatable) idea that the testbench
   and synthesis are singular entities that *may* be composed of more
   than one thing.  There are not multiple testbenches and HLS syntheses.

.. _fpga-label:

FPGA
~~~~
This class defines the target FPGA or FPGAs.

  - Here the simplicity of defining just a single FPGA has been abandoned
    to illustrate how easy it is to generate code targeting multiple FPGAs.

.. code-block:: python

       fpgas = (Product.Fpga (id          = '6ns',
                              part        = 'xcku115-flvb2104-2-i',
                              clock       = '6',
                              uncertainty = None),

                Product.Fpga (id          = '5ns',
                              part        = 'xcku115-flvb2104-2-i',
                              clock       = '5',
                              uncertainty =  None))

.. list-table:: FPGA Product Parameters
   :header-rows: 1

   * - Parameter
     - Meaning
   * - id
     - A string identifying this FPGA
   * - part
     - The Xilinx FPGA part designator
   * - clock
     - The FPGA clock, can include all the usual units like MHz, ns, *etc.*
   * - uncertainty
     - | The uncertainty in absolute time units or percentage.
       | If *None*, then the default (15%, this may be Vitis version dependent)

The *id* needs further explanation. One of the key aspects of
creating a component is that, since all component definitions reside
in the workspace directory, the components must be uniquely named.  The intent
in this example is that the same code is built targeting two different
FPGA specifications, resulting in two components. The *id* is useful
in uniquely and meaningfully naming the components.

   The *id* can, as can the *part*, *clock*, and *uncertainty*, be
   used as *product parameters* to generate a unique component name.  Here the
   *clock* could serve the same purpose since it is different. The
   *id* serves as a convenient user-chosen nickname for the FPGA specification.

.. tip::

   Choose a meaningful name for the *id* so it is apparent from the component
   name what it means.  *ids* such as 'f0' and 'f1' convey little.

.. _ctb_builds-label:

CtbBuilds
~~~~~~~~~
This class defines a single build, list, or tuple of builds.

   - A build includes an identifying name and much of the information needed
     to generate the *csim.exe*, *synthesis*, *cosim*, *etc.* products;
     essentially what goes into the *MakeFile*.

.. code-block:: python

   ctb_builds = Product.CtbBuilds (prefix = 'build',
                                   builds =  build)

.. list-table:: CtbBuilds
   :header-rows: 1

   * - Parameter
     - Meaning
   * - prefix
     - The prefix used when referencing the build's identifier, *i.e.* *{build.id}*
   * - builds
     - A single :ref:`Product.Build <build-label>`, list, or tuple of
       :ref:`Product.Build <build-label>` instances

.. _ctb_fpgas-label:

CtbFpgas
~~~~~~~~

This class defines a single FPGA, list, or tuple of FPGAs to target.

.. code-block:: python

   ctb_fpgas  = Product.CtbFpgas  (prefix = 'fpga',
                                   fpgas  =  fpgas)

.. list-table:: CtbFpgas Parameters
   :header-rows: 1

   * - Parameter
     - Meaning
   * - prefix
     - The prefix used when referencing the attributes of the FPGA
   * - fpgas
     - A single :ref:`Product.Fpga <fpga-label>`, list, or tuple of
       :ref:`Product.Fpga <fpga-label>` instances

.. _contributors-label:

Contributors
~~~~~~~~~~~~

This class collects all the contributors to be used in defining a
*component*.

.. code-block:: python


   contributors = Product.Contributors (builds = ctb_builds,
                                        fpgas  = ctb_fpgas)

.. list-table:: Contributors Parameters
   :header-rows: 1

   * - Parameter
     - Meaning
   * - builds
     - A single, list, or tuple of :ref:`Product.CtbBuilds <ctb_builds-label>`
       instances
   * - fpgas
     - A single, list, or tuple of :ref:`Product.CtbFpgas <ctb_fpgas-label>`
       instances

A component is composed of a number of contributors. The minimum component
must include one :ref:`Product.CtbBuilds <ctb_builds-label>` and one
:ref:`Product.CtbFpgas <ctb_fpgas-label>` contributor.

The first contributor **must** be an instance of
:ref:`Product.CtbBuilds <ctb_builds-label>` and the second **must** an
instance of :ref:`Product.CtbFpgas <ctb_fpgas-label>`.

   More contributors can be added as additional parameters after the mandatory
   :ref:`Product.CtbBuilds <ctb_builds-label>` and
   :ref:`Product.CtbFpgas <ctb_fpgas-label>`. These additional contributors can
   be each one or more of the more advanced
   :ref:`contributors <additional_contributors-label>`,
   :ref:`Product.CtbValues <product_ctb_values-label>` and
   :ref:`Product.CtbFiles <product_ctb_files-label>`. See the examples
   labeled *ex3*, *ex4*, and *ex5* in the
   `hlsBs-examples <https://github.com/slaclab/hlsBs-examples>`_ repository.

To aid in composing unique names for the configuration file paths and
components, attributes of the build and FPGAs can be accessed using the
*build* and *fpga* prefix strings that appear in the above specification
to form :ref:`product parameters <product_parameter-label>`. Think of the
*prefix* as an instantiated class in Python or C++ with the attributes as
its field members.

In this example, *product parameters* with the following attributes are
constructed.

.. list-table:: Builds
   :header-rows: 1

   * - Prefix
     - Attribute
     - Product Parameter
     - Value
   * - build
     - id
     - build.id
     - 'example'

.. list-table:: FPGAs
   :header-rows: 1

   * - Prefix
     - Attribute
     - Product Parameter
     - FPGA 0 Value
     - FPGA 1 Value
   * - fpga
     - part
     - fpga.part
     - xcku115-flvb2104-2-i
     - xcku115-flvb2104-2-i
   * -
     - clock
     - fpga.clock
     - 6
     - 5
   * -
     - uncertainty
     - fpga.uncertainty
     - None
     - None
   * -
     - id
     - fpga.id
     - 6ns
     - 5ns

.. tip::

   The prefixes *'build'* and *'fpga'*, while meaningful, are user-chosen.
   In more complex builds, these prefixes may need to be different to avoid
   name clashes.

   To be safe, limit prefixes to characters used to form legitimate Python variables.

.. warning::

   All prefixes must be unique. This may be relaxed if necessary.

.. _component_name-label:
.. _cmp_template-label:

CmpTemplate
~~~~~~~~~~~

This class defines a template of how to name the component.

.. code-block:: python

   cmp_template = Product.CmpTemplate (prefix   = 'cmp',
                                       template = '{build.id}-{fpga.id}')



.. list-table:: CmpTemplate Parameters
   :header-rows: 1

   * - Parameter
     - Meaning
   * - prefix
     - The prefix to be used when accessing the attributes
   * - template
     - The component template

The component prefix (*'cmp'*) and the template (*'{build.id}-{fpga.id}'*)
for this example are the defaults.  As such they can be specified as *None*
or omitted. The *template* must include a *product parameter* from each
contributor to ensure uniqueness.

   Technically this last condition applies only to contributors that have
   more than one member. With only one member, there is no ambiguity. Still,
   it is suggested to included such contributors in the *template*; it allows
   for easy expansion.

   The default will always include an appropriate *product parameter* for each
   additional contributor. For example, if the contributors include both an
   additional :ref:`Product.CtbFiles <ctb_files-label>` and
   :ref:`Product.CtbValues <ctb_values-label>`, and assuming
   the prefixes for the :ref:`CtbBuilds <ctb_builds-label>`,
   :ref:`CtbFpgas <ctb_fpgas-label>`, :ref:`CtbFiles <ctb_files-label>`, and
   :ref:`CtbValues <ctb_values-label>` contributors are *build*, *fpga*,
   *file*, and *def*, the default template will be

   .. code-block:: python

      template = '{build.id}-{fpga.id}-{file.name}-{def.id}'

   Also note that the template can include any text that may help add meaning,
   *e.g.* ``'Bld_{build.id}-Fpga_{fpga.id}'``. Purely user discretion.

.. list-table:: CmpTemplate Product Parameters
   :header-rows: 1

   * - Prefix
     - Attribute
     - Product Parameter
     - Meaning
   * - <prefix>
     - name
     - <prefix>.name
     - Component's name

A few differences from the :ref:`configuration file template <cfg_template-label>`
are noted here:

- There is no directory or file extension

  - The component *is always* a subdirectory of the workspace.

..

- Since all components are first level subdirectories of the workspace, the
  component name must be unique.

  - Contrast this with the configuration file where only the configuration
    *path* name, not the configuration *file* name, needs to be unique.

.. note::

   The component file could just as easily have been named after the
   configuration file provided it is unique.
   Naming the configuration file after the component is somewhat more
   natural, but, in the end, is just a matter of choice. Choose whichever
   works best.

.. _cfg_template-label:

CfgTemplate
~~~~~~~~~~~

This class defines a template of how to name the full path of the
configuration file.

.. code-block:: python

       cfg_template = Product.CfgTemplate (prefix   = 'cfg',
                                           template = '{cmp.name}')

.. list-table:: CfgTemplate Parameters
   :header-rows: 1

   * - Parameter
     - Meaning
   * - prefix
     - The prefix to be used when accessing the attributes
   * - template
     - The configuration template

Here the configuration file's name is the component's name.

- If the template is not an absolute file path, the *project.cfg_root* is used
  as the directory.
- If no file extension has been provided, *.cfg* is used.
- The values, *'cfg'* and *'{cmp.name}'*, are the defaults if the parameter
  is specified as *None* or omitted.

Configuration file attributes and their derived *product parameters* are as
follows. These are useful in naming other products such as the component and
the IP products. In this example ``<prefix> = 'cfg'``,

.. list-table:: CfgTemplate Product Parameters
   :header-rows: 1

   * - Prefix
     - Attribute
     - Product Parameter
     - Meaning
   * - <prefix>
     - path
     - <prefix>.path
     - Full path of the configuration file
   * -
     - dir
     - <prefix>.dir
     - Configuration file's first level directory
   * -
     - name
     - <prefix>.name
     - Configuration file's name
   * -
     - ext
     - <prefix>.ext
     - Configuration file's extension

Things to note:

- The configuration file *path* must be unique.

  - By implication, the configuration file *name* need not be unique.
  - While not recommended, the configuration file can be placed in a
    distinguishing directory, allowing the file *name* to be reused.

..

- A possible usage of the configuration file name is to name the component,
  see :ref:`CmpTemplate <component_name-label>`, although in this example
  the component name is used as the configuration file name. For example

  .. code-block:: python

     Product.CmpTemplate (prefix   = 'cmp',
                          template = '{cfg.name}')

- |hlsBs| gracefully handles

  - the component named after the configuration file name
  - the configuration file name named after the component
  - either or both being defaulted or explicitly specified

..

- If the configuration file name is not unique, only a *product parameter*
  for the first subdirectory is provided to help in making it unique.

  - If this is insufficient to make the component name unique, some other
    method must be used.

.. tip::

   Use *product parameters* to generate the component/configuration templates
   even in a simple HLS project consisting of a single component. This
   accommodates future changes.

   If needed:

   - Any missing file pieces in the configuration file template (directory,
     file name, extension) will be filled in with their defaults.


   - Any arbitrary text may be added to the template, *i.e.*
     ``Bld_{build.id}-Fpga_{fpga.id}`` to add meaning or increase clarity.

.. _components-label:

Components
~~~~~~~~~~

This class defines a fully specified component. A *component* is the
identifying unit of an HLS product.

.. code-block:: python

   components  = Product.Components (contributors = contributors,
                                     cmp_template = cmp_template,
                                     cfg_template = cfg_template)

.. list-table:: Component Parameters
   :header-rows: 1

   * - Parameter
     - Meaning
   * - contributors
     - A single :ref:`Product.Contributors <contributors-label>` instance
   * - cmp_template
     - The template used to generate the component name
   * - cfg_template
     - The template used to generate the configuration file name

Either or both the *cmp_template* and *cfg_template* may be specified as
*None* or completely omitted. The defaulting rules for these templates
will then be used.

In this example, two configuration files along with their two components are
generated:

.. list-table:: Example Configuration & Component Names
   :header-rows: 1

   * - Configuration File
     - Component
   * - <project.cfg_root>/example-5ns.cfg
     - <project.workspace>/example-5ns
   * - <project.cfg_root>/example-6ns.cfg
     - <project.workspace>/example-6ns

.. _package_ip-label:

Package.Ip
~~~~~~~~~~

This specifies packaging identification information.

.. code-block:: python

   package_ip = Product.Package.Ip (name     = '{cfg.name}',
                                    vendor   = 'SLAC',
                                    version  = '1.0.0',
                                    library  = 'hls')

.. list-table::  Ip Parameters
   :header-rows: 1

   * - Parameter
     - Meaning
   * - name
     - The name to give the package. This need not be unique.
   * - vendor
     - An arbitrary string identifying the producing entity.
   * - version
     - A version string or a tuple/list of strings
   * - library
     - Defaults to: 'hls'

Two noteworthy things:

- *name* has been chosen to be the configuration file name.

  - It could have been the component name or the git product parameters

    - *{git.repo}*
    - *{git.tag}*
    - *{git.branch}*
    - *{git.hash_short}*
    - *{git.hash_long}*
    - *{git.hash_msg}*

    or the Vitis version

    - *vitis.version.version* or '{vitis.version}'

    or any of the the per-component *product parameters*, *e.g.* as in
    this example, *cfg.name*.

    .. warning::

       It is recommended, of the *Git* *product parameters*, to use only the
       *git.branch* since it is the only one guaranteed to always be available.

       The others, *git.tag*, *git.hash_short*, *git.hash_long*, and
       *git.hash_msg* are only valid after a *git* commit. These will come up
       as *None* or *Dirty* if the current code has not been committed. These
       also seem inappropriate for a package name, since they mark an instance,
       not an identifying name.  They are more appropriate for the *version*.

- *version* can be specified in multiple ways

   .. list-table:: Version
      :header-rows: 1

      * - Option
        - Specification
        - Explanation
      * - 1
        - Explicit String
        - May include environment variables or *product parameters*
      * - 2
        - A tuple or list
        - | May include
          |   explicit string
          |   environment variables
          |   product parameters
          | First non-*None* will be used
      * - 3
        - None
        - Use ${HLSBS_IP_VERSION} if it is defined
      * - 4
        - None
        - | Use (*'{git.tag}'*, *'{git.hash_msg}'*, '*--None--*')
          | Note: This is just an explicit tuple as in option #2

   For *Git*-tracked packages, typically **${HLSBS_IP_VERSION}** is not defined
   and the *version* is set to *None*, resulting in the version being:

   - The git tag, if defined
   - The git hash_msg, if defined
   - '--None--' if no git repo

 ..

   .. note::

      In this case, since *Git* is a global concept, the actual Python class
      can be used, *i.e.* *project.git.tag*, as while as the *product parameter*
      version, *i.e.* *'{git.tag}'*. The latter is more in keeping the same
      stylist tone of the project file.

.. _package_output-label:

Package.Output
~~~~~~~~~~~~~~
This class defines the standard output packaging.

.. code-block:: python

       package_output = Product.Package.Output (format = 'ip_catalog',
                                                syn    = 'false')

.. list-table::  Output Parameters
   :header-rows: 1

   * - Parameter
     - Meaning
   * - format
     - Defaults to: *'ip_catalog'*
   * - syn
     - Defaults to: *'false'*

The values in the example are almost always the correct values and
are the defaults. They are provided here for completeness.

.. _package-label:

Package
~~~~~~~

This class combines :ref:`Product.Package.Ip <package_ip-label>` and
:ref:`Product.Package.Output <package_output-label>` into a single class.

.. code-block:: python

   package = Product.Package (ip      = package_ip,
                              output  = package_output)

.. list-table:: Package Parameters
   :header-rows: 1

   * - Parameter
     - Meaning
   * - ip
     - | The instantiation of :ref:`Product.Package.Ip <package_ip-label>`
       | No default
   * - output
     - | The instantiation of :ref:`Product.Package.Output <package_output-label>`
       | Defaults to:
       |  Product.Package.Output
       |   (format = None, # 'ip_catalog'
       |    syn    = None, # 'false')

.. _vivado-label:

Vivado
~~~~~~
This class defines the Vivado parameters.

.. code-block:: python

       vivado  = Product.Vivado  (flow    ='syn',
                                  syn_dcp =  '1')

.. list-table::  Vivado Parameters
   :header-rows: 1

   * - Parameter
     - Meaning
   * - flow
     - Defaults to: 'syn'
   * - syn_dcp
     - Defaults to: '1'

The values in the example are almost always the correct values and
are the defaults. They are provided here for completeness.


.. tip::

   Even though **flow** has been deprecated as of 2026.1, specifying it
   keeps the configuration file compatible with previous versions. In
   order to maintain backward compatibility with earlier versions,
   |hlsBs| will continue to require **flow** be specified. The goal
   is that the same *Project File* can be used with all Vitis versions
   supported by |hlsBs|.

.. _product-label:

Product
~~~~~~~
This class returns a single, list, or tuple of *Product* instances.

.. code-block:: python

       return Product (project    = project,
                       components = components,
                       package    = package,
                       vivado     = vivado)

.. list-table::  Product Parameters
   :header-rows: 1

   * - Parameter
     - Meaning
   * - project
     - The controlling project
   * - components
     - The target components
   * - package
     - The IP and output packaging information
   * - vivado
     - | The Vivado information, defaults to:
       |  Product.Vivado (
       |          flow    = None,  # 'syn',
       |          syn_dcp = None)  # '1')

Returning a list or tuple of products can be useful when the
components use very different input files or FPGAs, *e.g.* in a
pipelined/daisy-chained application.

IP Products
===========

These are optional modified Vitis products produced by |hlsBs|. They
have proven to be useful in overcoming limitations of the Vitis products
they are derived from.

There are two such products:

- DCP renaming
- Expanding the permissible FPGA target families on the *.zip* file.

DCP Renaming
------------
All standard Vitis/Vivado produced *.dcp* files have the same embedded
name. This makes it impossible to combine multiple *.dcp* files when
producing a single FPGA image.  This modification allows unique names
to be assigned to the *.dcp* files.

FPGA Family Augmentation
------------------------
Using a Vivado utility, the *.zip* file is repackaged to include a
specified list of allowable FPGA families.

  Instead of generating multiple components, one for each FPGA, the
  existing *.zip* file is augmented.  This saves the lengthy implementation
  stage.  Of course, allowing an FPGA image to target an incompatible
  FPGA carries risk.

.. _get_ip-label:

Annotated get_ip
----------------

.. code-block:: python

   # ------------------------------------------------------------------------------
   def get_ip (project, info) :
       ip = project.Ip (

           # -------------------------------
           # All the values are the defaults
           # -------------------------------
           family     = ('artix7,kintex7,virtex7,zynq,kintexu,virtexu,kintexuplus,'
                         'virtexuplus,virtexuplusHBM,zynqplus,zynquplusRFSOC,versal'),
           dcp_rename = '{cmp.name}',

           # ---------------------------------------------------------
           # Placing the .dcp and .zip in the 'products/' directory
           # will generally mean these files are committed to Git.
           # Given that these files are likely dependent on the
           # Vitis version that produced them, including the Vitis
           # version is sensible.
           # ---------------------------------------------------------
           dir      =  os.path.join (project.products_root,
                                     'ip', '{vitis.version}'),
           zip_file = '{cmp.name}',

           # ----------------------------------------------------------------
           # These are the defaults and can be omitted or set to None
           # The 'dcp' prefix is defined by hlsBs
           # ----------------------------------------------------------------
           dcp_file = '{dcp.rename}',

           # --------------------------------------------------------
           # Place the journal and log files, two files that have only
           # marginal interest, in the project.build/ip/dgn directory
           # The <project.build>/ip directory is the default stem.
           # By placing them in the build directory, they will
           # not (if the *build* directory is set in '.gitignore')
           # be committed to Git.
           # -----------------------------------------------------
           dgn_dir  = 'dgn/',
           jou_file = '{dcp.name}',
           log_file = '{dcp.name}'
       )

       return ip
   # ------------------------------------------------------------------------------

.. _project_ip-label:

Project Ip
~~~~~~~~~~
This class defines the composition of the *IP* products (*i.e.* the modified
*dcp* and *zip* files) and where they are placed.

.. list-table:: Project.Ip
   :header-rows: 1

   * - Attribute
     - Meaning
   * - family
     - A comma-separated list of the augmented FPGA families
   * - dcp_rename
     - The new embedded name
   * - dir
     - The common ip output directory for the *.dcp* and *.zip* files
   * - zip_file
     - The name of the new zip file with the modified FPGA families
   * - dcp_file
     - The name of the modified dcp file
   * - dgn_dir
     - The common directory where the Vivado journal and log file are written
   * - jou_file
     - The name of the dcp journal file
   * - log_file
     - The name of the dcp log file

The values shown are all the defaults and can be specified by setting the
parameter value to *None*. To accept *all* the defaults, either

- Omit the definition of *get_ip* altogether
- Return *None*

By default, these output files are collected in the *ip/* subdirectory
of the *products/* directory.  As usual, these may be placed anywhere
by suitably defining the appropriate file paths. Typically the various
file path specifications are defined as only the file name, but these
can be complete file paths or any subset of the directory path, the
file name, and the file extension. Any missing pieces will be filled in
from the defaults.

All the values are sensibly defaulted, except for the *'family'*.
While it does have a default value, it may not be what is wanted.

.. tip::

   If the defaults are acceptable, rather than omitting them, set the values to
   *None*. This will serve as a reminder that they can be altered.

   Unless there is a good reason, use the defaults, except for possibly the
   *family*. Here it might be wise to trim the *family* to only the required
   and permissible set.

Trimming the FPGA Families
~~~~~~~~~~~~~~~~~~~~~~~~~~
One can use members of the *info* parameter to selectively trim the *family*.

   .. list-table:: Info Members
      :header-rows: 1

      * - Member
        - Meaning
      * - info.cmp_name
        - The component name
      * - info.pkg_name
        - The package name
      * - info.hls_top
        - The HLS top-level method
      * - info.fpga.part
        - The FPGA part name
      * - info.fpga.clock
        - The FPGA clock specification
      * - info.fpga.uncertainty
        - The FPGA clock uncertainty

For example (this is totally unrealistic):

   .. code-block:: python

      def get_ip(project, info):

         if info.fpga.part == 'xcku115-flvb2104-2-i':
            # Trim the set for this FPGA
            family = 'kintex7,kintexu'
         else:
            # Else use the default
            family = None

         # Accept the defaults for all other parameters
         ip = project.Ip (family = family)

         return ip

.. note::
   The default ip directory is in the *products/* directory. Without
   a special entry in *.gitignore*, the *.dcp* and *.zip* files will be committed
   to *Git*.  This is usually the desired behavior. Since these files can be
   large, add the following to the *.gitattributes* file.

   .. code-block:: text

     *.dcp filter=lfs diff=lfs merge=lfs -text
     *.zip filter=lfs diff=lfs merge=lfs -text

.. warning::
   |hlsRun| was advertised to be able to execute needing only
   the workspace, no *Project File* necessary. However, for *--ip*
   a *Project File* is needed if the defaults are not acceptable.

   This is fixable, but requires some thought.

Global Product Parameters
=========================
In addition to configuration- and component-specific *product parameters*
there are two global *product parameters*.

- :ref:`Vitis Version <vitis_version-label>`
- :ref:`Git <git_product_parameters-label>`

Below shows how to reference these either

- Directly as a member of the *project*
- As a *product parameter*

To keep the project file stylistic consistent, the recommendation is to use

- Directly, when testing for a value, *i.e.* ``project.git.repo is None``
- As a *product parameter*, when using as a string, *i.e.* ``version = '{git.tag}'``

.. _vitis_version-label:

Vitis Version
-------------
These *product parameters* and its *project* class members are

.. list-table:: Vitis Version Product Parameters
   :header-rows: 1

   * - Prefix
     - Attribute
     - Product Parameter
     - Direct
     - Meaning
   * - vitis
     - version
     - '{vitis.version}'
     - project.git.vitis.version.full
     - Full version, *e.g.* 2024.2
   * -
     - major
     - N/A
     - project.git.vitis.major
     - Major version, *e.g.* 2024
   * -
     - minor
     - N/A
     - project.git.vitis.minor
     - Minor version, *.e.g.* 2

.. _git_product_parameters-label:

Git
---
This gives information about the *Git* repository. It can be used anywhere, but
its most common usage will likely be in setting the project name and/or version.

.. list-table:: Git Product Parameters
   :header-rows: 1

   * - Prefix
     - Attribute
     - Product Parameter
     - Direct
     - Meaning
   * - git
     - repo
     - '{git.repo}'
     - project.git.repo
     - Name of *Git* repository
   * -
     - branch
     - '{git.branch}'
     - project.git.branch
     - The current Git branch
   * -
     - tag
     - '{git.tag}'
     - project.git.tag
     - The *Git* tag
   * -
     - dirty
     - '{git.dirty}'
     - project.git.dirty
     - "True"/"False" (Python strings)
   * -
     - hash_long
     - '{git.hash_long}'
     - project.git.hash_long
     - The long form of the *Git* hash code
   * -
     - hash_short
     - '{git.hash_short}'
     - project.git.hash_short
     - The short form of the *Git* hash code
   * -
     - hash_msg
     - '{git.hash_msg}'
     - project.git.hash_msg
     - | If *Git* is not dirty, hash_long
       | If *Git* is dirty, "Dirty"

If there is no *Git* repository, these return as *None*.

.. _beyond_basics-label:

Beyond the Basics
The above covers the basics, but with usage, common repeating patterns occur.
While the first (but not the second) of the following could be done with what
has already been given, formalizing these patterns makes usage easier and more
robust.

The patterns are

- :ref:`Additional Product Contributors <additional_contributors-label>`
- :ref:`Deferring Environment Variables Translation <deferred_translation-label>`

  - This is relevant only for runtime values such as file specifications
    in *csim_argv* and *cosim_argv*.

  - Any environment variables in the project that would be used in composing the
    configuration file *must* be translated by |hlsCfg|.  For the most part,
    untranslated environment variables are not allowed by *Vitis HLS* in configuration
    files. The exceptions, as noted, are *csim_argv* and *cosim_argv* where |hlsCfg| uses
    special handling to preserve translation until runtime if desired.

In order to maintain full capability with the IDE/GUI, support within both the
configuration file generation and the C++ runtime is needed to support these features,
so these require more work on the user's part.  Hopefully the gains justify what
amounts to a one-time investment of fairly simple code.

.. _additional_contributors-label:

Additional Component Contributors
---------------------------------
There are two other contributor classes not illustrated in the simple
example. These leverage the C++ preprocessor to add information at
compile-time. Their big advantage is they can generate
additional components without modifying either the *Project File* or the
source code. In an imperfect analogy, they act as traditional plug-ins,
extending the functionality with minimal impact.

These two contributors are:

- :ref:`Product.CtbValues <ctb_values-label>`  - adds the value of a
  *#define* macro to the source code

  - See *ex4* in `hlsBs-examples <https://github.com/slaclab/hlsBs-examples>`_
- :ref:`Product.CtbFiles <ctb_files-label>`   - forces a named include file
  into the source code

  - See *ex3* in `hlsBs-examples <https://github.com/slaclab/hlsBs-examples>`_

These definitions can be used in the instantiation of
:ref:`Product.Contributors <contributors-label>`.

- Multiple times with different definitions
- Together or separately

Just add them to the list of parameters after the
:ref:`Product.CtbBuilds <ctb_builds-label>` and
:ref:`Product.CtbFpgas <ctb_fpgas-label>`.

Since the total number of components generated is the product of all the
contributions, the number of components can get very large, very quickly.
Consider a :ref:`Product.Components <components-label>` definition with

- A :ref:`CtbBuilds <ctb_builds-label>` specifying 2 distinct builds
- A :ref:`CtbFpgas <ctb_fpgas-label>` containing 3 target FPGAs
- A :ref:`CtbValues <ctb_values-label>` with a list of 4 values
- A :ref:`CtbFiles <ctb_files-label>` with 5 files

The number of generated components will be 2 * 3 * 4 * 5 = 120. This may
take a while to build all the output products. However, it is this ability
to easily generate many components that enables experimentation and testing
of a large number of variations of a package.

   Even with potentially many components being defined, one would typically
   trim the target set of components at the command-line. For example, today
   only interested in the set for a particular *build* and *FPGA*.

.. _product_ctb_values-label:

Product.CtbValues
~~~~~~~~~~~~~~~~~

Motivation
^^^^^^^^^^
The simple example produced a component with a ``#define VERBOSE true``.
An obvious extension is to produce two components, one with
*VERBOSE true*, the other with *VERBOSE false*.

*Product.CtbValues* instantiates a single or list or tuple of bound
*(id, value)* pairs as created by :ref:`Product.Value <product_value-label>`,
each producing a component.

How
^^^
This uses two Python classes

.. _product_value-label:

- *Product.Value*     - creates a value with an identifier which is useful
  in the *cfg* and *cmp* templates

  .. code-block:: python

     values     = Product.Value (id    = '<ID>',
                                 value = '<VALUE>')

.. _ctb_values-label:

- *Product.CtbValues*  - creates a contributor which will produce 1 component
  per supplied *Product.Value*


  .. code-block:: python

     ctb_values = Product.CtbValues (prefix = '<PREFIX>',
                                     values =  <VALUES>)

.. note::

   The same result could have been achieved using multiple *Product.Build*\ s,
   perhaps using a loop, each with its own *#define value* and a unique
   *build id*. The usage here just makes this easier and more manageable.

.. _defvalues_example-label:

Example:

1.  Instantiate a single, list, or tuple of *Product.Value* instances.

    .. code-block:: python

         quiet   = Product.Value (id = 'Quiet',   value = 'false')
         verbose = Product.Value (id = 'Verbose', value =  'true')
         levels  = (quiet, verbose)

    .. list-table:: Value Product Parameters
       :header-rows: 1

       * - Parameter
         - Meaning
       * - id
         - A string identifying this value
       * - value
         - A string giving the value

    The *id* serves as an identifier/nickname for the value. Its main use is
    in generating a unique configuration and component file name. Using the
    *value* may not always be suitable.

      For example, the value may be an initializer for an array, ``[1,2,3,4]``
      which would be awkward if used as part of the configuration file or
      component path.  The *id* provides an alternative.

    The *id* must be one of

    - A string
    - An empty string
    - *None*

    If an empty string or *None*, the *id* will be the *value*. This should only
    be used in very simple cases, since the default of using the *value* may be
    awkward or may fail to convey meaning when used to generate a configuration
    or component name.

2.  Instantiate the value contributors using the previously
    created *Product.Value* instances.

    .. code-block:: python

       values  = Product.CtbValues (prefix = 'verbose',
                                    values =    levels)

    .. list-table::
       :header-rows: 1

       * - Parameter
         - Meaning
       * - prefix
         - The prefix used in referencing the two attributes, *id* & *value*
       * - values
         - A single, list, or tuple of *Product.Value* instances

    For this example, the following are defined:

    .. list-table::  CtbValues Example Product Parameters
       :header-rows: 1

       * - Prefix
         - Attribute
         - Product Parameter
         - Value0
         - Value1
       * - verbose
         - id
         - verbose.id
         - Quiet
         - Verbose
       * -
         - value
         - verbose.value
         - false
         - true

..

3. As in the original *Project File* example

   - Instantiate a :ref:`Product.DefineValue <define_value-label>` to be
     used in :ref:`Product.Source <sources-label>`

   .. code-block:: python

      verbose       = Product.DefineValue  (name  = 'VERBOSE',
                                            value = '{verbose.value}')

   Note the only difference is the use of the *product parameter*

   - Uses ``{verbose.value}`` instead of the explicit ``'true'`` in
     *Product.DefineValue*

..

4. Modify the cmp_template

   .. code-block:: python

       cmp_template = Product.CmpTemplate (prefix   = 'cmp',
                                           template = '{build.id}-{fpga.id}-{verbose.id}')

   The  *{verbose.id}* has been added to distinguish the components generated
   with the *true* and *false* values.

   Also note this is the default that |hlsBs| will generate if no component
   template is specified.

5. In the C++ code, make use of the *#define*

   .. code-block:: c++

      static constexpr auto Verbose = VERBOSE;

   Each value in the list of values generates a new component.  Here one
   component will be generated with ``Verbose = true`` and another with
   ``Verbose = false``.

      In this example, the list of *Product.Value* instances (id, value pairs) is
      hard-coded into the *Project File*.  A useful technique may be to read
      these from a file.

      This allows new values, and hence new components, to be added simply by
      editing a file containing the list of *(id, value)* pairs.

..

   .. tip::

      The use of *Product.CtbValues* should be limited to simple applications,
      *e.g.* specifying a different numeric value for the *REUSE* pragma
      parameter.  This is in keeping with the *#define*'s limitations:

        - lack of name space protection, they are effectively file-scope globals
        - no type checking, completely against the concept of a statically
          typed language such as C++.
        - very fragile rules on using quotes and parentheses

      For more involved cases, such as

      - steering the code, this would involve littering the source code with
        many *#ifdef*\ s.
      - redefining many data types as a coherent set.
      - the extreme case of defining completely different implementations of
        a C++ function to explore which gives the best results.

      consider using :ref:`Product.CtbFiles <product_ctb_files-label>`.

   .. warning::

      Due to AMD/Xilinx/HLS's inconsistent handling of quoted strings and other
      characters deemed *special* by the shell, when defining a string as a
      macro value, the string must be *requoted* in the C++ code, *e.g.* as
      follows

      .. code-block:: c++

         static const char BuildName[] = HLSHELPER_QUOTE(BUILD_STRING);

      It is suggested to use :ref:`Product.CtbFiles <product_ctb_files-label>`
      to capture such strings in an include file.  It is cleaner and more
      extensible.

.. _product_ctb_files-label:

Product.CtbFiles
~~~~~~~~~~~~~~~~
This contributor allows one to include a file, named not in the source code,
but in the *Project File* at compile-time.

   There is a lot of verbiage that follows, but except for defining the
   *Product.CtbFiles* contributor, it is just a novel use of previously
   introduced concepts. *Product.CtbFiles* usage strongly parallels
   :ref:`Product.CtbValues <product_ctb_values-label>` usage.

While the file or files to be included can be named explicitly, a useful
technique is to include them by wildcarding them from a specific directory
or directories. *Product.CtbFiles* accepts any single, list, or tuple of
explict file names and wildcarded files, including environment variables.

Example
^^^^^^^
Suppose there is a directory, *opt/*, which includes a family of files with
different optimization strategies. For example, they may include different
pragma values or data types. A component for each of these files can be
generated by the following

.. _ctb_files-label:

1. Defining the files as a wildcard specification:

   .. code-block:: python

      ctb_files = Product.CtbFiles (prefix = 'opt',
                                    files  = os.path.join (code_root, 'opt', '*.hh'))

   The following product parameters are made available:

   .. list-table:: CtbFiles Product Parameters
      :header-rows: 1

      * - Prefix
        - Attribute
        - Product Parameter
        - Meaning
      * - opt
        - path
        - opt.path
        - The file's full path
      * -
        - dir
        - opt.dir
        - The file's directory
      * -
        - name
        - opt.name
        - The file's name
      * -
        - ext
        - opt.ext
        - The file's extension

   - The *name*  attribute can be useful in constructing the configuration file
     path and the component name, *i.e.* ``{<prefix>.name}``
   - The *path* is used in the *Product.IncludeFile* to reference the full path
     name, *i.e.* ``{<prefix>.path}``. It is the value of the defined macro
     name.

..

2. Adding *ctb_files* to the *Product.Contributors* class after the
   *Product.CtbBuilds* and *CtbFpgas* contributors.

   .. code-block:: python

      contributors = Product.Contributors (ctb_builds,
                                           ctb_fpgas,
                                           ctb_files)

..

3. Instantiating *Product.IncludeFile*

   .. code-block:: python

      opt_file  = Product.IncludeFile (name     = "MY_OPT",      # Name of #define
                                       inc_path = '{opt.path}',  # File to include
                                                                 # (from the attribute table)
                                       rel_path = include_paths) # Reference by a relative path

   Note that the only difference in *Product.IncludeFile* from the example
   *Project File* is the *product parameter*, *'{opt.path}'*, instead of an
   explicit file name.

4. Just as in the original *Product.Sources*, include this in the ``defines =``
   parameter list

   .. code-block:: python

      syn_srcs = Product.Sources (root     = code_root,
                                  files    = 'src/example/ExampleHls.cc',
                                  includes = include_paths,
                                  defines  = opt_file)

..

5. Modify the cmp_template

   .. code-block:: python

      cmp_template = Product.CmpTemplate (prefix   = 'cmp',
                                          template = '{build.id}-{fpga.id}-{opt.name}')

   The  *{opt.name}*, *i.e.* the include file name, has been added to
   distinguish the components generated by each different include file.

   Also note this is the default template that |hlsBs| will generate if no component
   template is specified.

6. In the C++ code

   .. code-block:: c++

      #include IMPORT_FILE(MY_OPT)

   Each file satisfying the wildcard generates a new component.

      SNL uses this to great advantage. All SNL networks use the same testbench
      and HLS synthesis code with only the network definition changing. SNL
      network definitions are entered into a user-provided directory. The
      ``files``   parameter of *Product.CtbFiles* is then specified as a
      wildcard, *e.g.* *<network>/\*.hh*.

      The *project* file then generates a component for each network
      specification. The code is thus customized without touching the actual
      text of the code or the *Project File*. One can add a new network simply
      by adding it to the network directory.

.. _parameter_files-label:

Parameter Files
---------------
Python's *argparse* has a nice feature that any number of command-line
parameters can be included in a named file which is referenced as *@FILE* on
the command-line. The format of this file is very simple, one command-line
option on each line. For example

.. code-block:: text

   --workspace=<alternate_workspace>
   --cfg_dir=<alternate_cfg>

This is a convenient way to both experiment and capture coherent sets of
commonly used overrides.

While simple, it may be too simple

  - no blank lines
  - no trailing whitespace
  - no include feature

.. tip::

   Parameter files offer a number of advantages over adding parameters
   directly on the **hlsExe/hlsGdb** commands.

   - Coherency

     - a number of related options can be grouped in a file

   - Naming

     - a file can have a name reflecting its purpose

   - Lifetime

     - a file can exist over login sessions
     - a file can be committed to *Git*

   - Versatility

     - including a :ref:`parameter file <parameter_files-label>`
       specified as an environment variable in *csim_argv* or *cosim_argv* allows
       parameters to be modified when the command is executed:

     .. code-block:: shell

        $ hlsRun --csim=r
        $ hlsRun --cosim

     or with the HLS GUI.

  - Flexibility

    - can be specified directly on the command line,

      .. code-block:: bash

         $ hlsExe <component> @Optimization1

.. note::

   For *cosim*, this is the only flexible alternative. As opposed
   to *csim*, there is no equivalent of *hlsExe/hlsGdb* for *cosim* where
   command-line parameters can be added.

Usage
~~~~~
Since C++ has no native support for this feature, |hlsBs| provides it. In the
testbench code, add the following:

.. code-block:: c++

   // Make the utility available
   #include "hlsHelpers/ExpandArgs.hh"

and

.. code-block:: c++

   // Create and use the expanded set of command-line parameters
   hlsHelpers::ExpandArgs cl (argc, argv);
   getopt (cl.m_argc, cl.m_argv);

Suggestion
~~~~~~~~~~
As a workaround to having no include facility, a suggestion is to define
the multiple files as a colon-separated list and, to make it easy to
reference, use an environment variable:

.. code-block:: bash

   $ export MyMods=File1.txt:File2.txt:File3.txt
   .
   .
   $ hlsExe <component> @$MyMods

.. warning::

   *Parameter Files* are generally available only if |hlsCfg| was used to
   create the configuration file.  |hlsCfg| adds the *ExpandArgs.hh* include
   file to the user's configuration directory as part of creating the
   configuration file. This is so user code, once created, does not depend on
   code in *ruckus*.

   If the configuration file is not created by |hlsCfg|, either

   - Do not use this feature

     - This is the recommended action

   - Copy the *ExpandArgs.hh* include file into your project and
     add any necessary *-I include_path* to it in the configuration file.

     - The file is in *<path_to>/ruckus/vitis/hlsBs/include*
     - This is not recommended, too fragile.

.. _deferred_translation-label:

Deferred Environment Variable Translation
-----------------------------------------
A common desire is to defer translation of environment variables until
runtime. Practically speaking, this applies only to the strings in the *csim_argv*
and *cosim_argv* values.

   For example, referring to various test data files either individually
   by environment variables or using an environment variable to specify just
   the root directory.  Other usages may be to refer to the number of tests to
   run with an environment variable.

However, using environment variables directly, specifying them as
${ENV} in *csim_argv* and *cosim_argv*, is problematic at best. They are
translated at different stages by *csim* and *cosim*. As a workaround |hlsBs|
provides two classes to encode the environment variables, one for
variables and one for files, so that behavior in *csim* and *cosim* is the same.

.. code-block:: python

   # Encode a bare string as an environment variable
   var  = Product.EnvString.preserve ("NTESTS")

   # Encode a string containing traditional environment variables
   vstr = Product.EnvString.preserveAll ("${BUILD_NAME} - ${DATE}")

The first encodes a single string, while the latter encodes all instances of
the form *${var}* contained in a string.

If the string is a file, for uniformity, it is suggested to use one of

.. code-block:: python

   f0 = Product.File.absolute (file)           # Return an absolute file path
   f1 = Product.File.relative (file, rel_file) # Return a relative path
   f2 = Product.File.preserve (file)           # Preserve environment vars

Suggestions
~~~~~~~~~~~
The first two will translate any environment variables during the
creation of the configuration file.  They are mentioned here because
this set of three methods provides all the choices of how to present
the file paths in the configuration file.

- Absolute file paths should be avoided if possible. They make the
  configuration file less modular, but there are cases where this
  is necessary and/or appropriate.

- Relative file paths are equally dicey.  In their simplest form,
  the executable would have to be run from a particular directory. A
  more modular approach would be to modify/tack-on the directory when
  processing the file name in, say, getopts.

- Preserving the environment variables offers the most flexibility.
  For example, all test files could be in various data directories
  which could be located at runtime with *${DATA_DIR}*.

Usage
~~~~~
Since the shell cannot translate these modified environment variables,
a C++ utility has been provided.

.. code-block:: c++

   // This contains the method
   // std::string hlsHelpers::expand_envs (std::string string)
   #include "hlsHelpers/ExpandEnvs.hh"

   // Example:
   // Translate an environment variable in my_string
   tvar = hlsHelpers::expand_envs (my_string);

.. note::

   Presuming all the environment variables have been defined, the
   resulting *csim.exe* and *cosim.exe* will use the values of the
   environment variables at execution time, not configuration file
   creation time. This can be either directly from the command-line

   .. code-block:: bash

      $ hlsRun <components> --csim=run
      $ hlsRun <components> --cosim
      $ hlsExe <component>
      $ hlsGdb <component>

   or from the HLS GUI.

   However, there is a potential *gotcha* with the GUI.  The translated
   values of the environment variables are what they were when the GUI
   was started, not in the shell it was started from (they may have
   changed since the GUI was launched) or some random shell one is
   currently active in.   Once the GUI is launched, there is no way to
   change the values of the environment variables.  Recovering this
   deferred translation flexibility was a motivating goal for |hlsBs|.

.. warning::

   This is generally available only if |hlsCfg| was used to create the
   configuration file.  |hlsCfg| makes the include file, *ExpandEnvs.hh*, as
   part of creating the configuration file.

   If the configuration file is not created by |hlsCfg|, either

   - Do not use this feature

     - This is the recommended action

   - Copy the include file from *ruckus* into your project and add the
     *-I include_path* to it in the configuration file.

     - The file is in *ruckus/vitis/hlsBs/include*
     - This is not recommended, too fragile.

.. _caution_environment_variables-label:

Project Class Summary
=====================
This is a brief summary of the project classes.

Product Directory Methods
-------------------------
These are the :ref:`methods <product_directory-label>` that determine
the directory layout for the products.

- :ref:`get_project_root <get_project_root-label>` ``(project)``
- :ref:`get_products_root <get_products_root-label>` ``(project)``
- :ref:`get_build_root <get_build-label>` ``(project)``
- :ref:`get_workspace <get_workspace-label>` ``(project)``
- :ref:`get_cfg_root <get_cfg_root-label>` ``(project)``
- :ref:`get_ip_root <get_ip_root-label>` ``(project)``

Product Definition Classes
--------------------------
These are the :ref:`classes <product_classes-label>` that determine
the product definition, *i.e.* exactly what makes up an HLS component/product.

- :ref:`Product.IncludePaths <include_paths-label>` ``(root, paths, type)``
- :ref:`Product.DefineValue <define_value-label>` ``(name, value)``
- :ref:`Product.IncludeFile <include_file-label>` ``(name, file, rel_path)``
- :ref:`Product.Sources <sources-label>` ``(root, files, includes, defines)``
- :ref:`Product.Build <build-label>` ``(id, top, tb, syn, csim_argv, cosim_argv)``
- :ref:`Product.Fpga <fpga-label>` ``(id, part, clock, uncertainty)``
- :ref:`Product.Value <product_value-label>` ``(id, values)``
- :ref:`Product.CtbBuilds <ctb_builds-label>` ``(prefix, builds)``
- :ref:`Product.CtbFpgas <ctb_fpgas-label>` ``(prefix, fpgas)``
- :ref:`Product.CtbValues <ctb_values-label>` ``(prefix, values)``
- :ref:`Product.CtbFiles <ctb_files-label>` ``(prefix, files)``
- :ref:`Product.Contributors <contributors-label>` ``(builds, fpgas, <other contributors>)``
- :ref:`Product.CmpTemplate <cmp_template-label>` ``(prefix, template)``
- :ref:`Product.CfgTemplate <cfg_template-label>` ``(prefix, template)``
- :ref:`Product.Components <components-label>` ``(contributors, cmp_template, cfg_template)``
- :ref:`Product.Package.Output <package_output-label>` ``(format, syn)``
- :ref:`Product.Package.Ip <package_ip-label>` ``(name, vendor, version, library)``
- :ref:`Product.Package <package-label>` ``(ip, output)``
- :ref:`Product.Vivado <vivado-label>` ``(flow, syn_dcp)``
- :ref:`Product <product-label>` ``(project, components, package, vivado)``

Product Ip
----------
- :ref:`Project Ip <project_ip-label>` ``(family, dcp_rename, dir, zip_file, dcp_file, dgn_dir, jou_file, log_file)``

A Word of Caution on Environment Variables
==========================================
Values in the *Project File*, *e.g.* file paths, may include environment
variables, but because HLS configuration files do not allow environment
variables, except *almost* as in *csim_argv* and *cosim_argv* strings,
environment variables must be translated when the configuration file is
created.

Since the *testbench*, *hls/synthesis*, and *include* file paths are
generally reinterpreted as relative to the configuration file, this is
not a problem. However, for *csim_argv* and *cosim_argv*, the choice
to defer the translation to runtime is desirable and that method has been
described.  But there are dangers.

    Consider the case when the configuration file is built and the
    environment variables were not defined.  For file and include paths,
    the build will fail and certainly be noticed. This fails under
    *fatal, but not serious*, *i.e.* easy to recognize and correct. |hlsBs|
    does try to verify the existence of files used in the build of the code
    and issue an appropriate message. So, annoying, but tolerable.

    However, unless the resulting configuration file is carefully examined
    or the deferred method via *Product.File.preserve* is used, any environment
    variables in the two *argv*'s will have been translated to an empty string
    and the paths will almost assuredly be incorrect and not noticed until
    runtime.

    If the configuration is run in the IDE/GUI, the *deferred*
    values of the environment variables are whatever they were when the
    IDE/GUI was launched. While obvious, this fact can be lost in the
    immediacy of the task at hand.

    Worse, if the execution is by chance in a directory containing the test
    files where the environment variable translates to nothing and they are
    *accidentally* found by the relative path, it might succeed, but tomorrow,
    when in a different directory or with different files in that directory, it
    might mysteriously fail or produce unexpected results. This can be described
    as *serious, but (in some cases) not fatal*. Since it can come and go,
    it can difficult to track down. Because of this, |hlsBs| is very careful in
    its handling of environment variables.

    Using the |hlsBs| commands does have the advantage that commands inherit
    the context of the shell they are launched from, so it is more immediate.
    There is not the lingering context of the IDE/GUI; a spawned process whose
    environment variable values are what they were at the time the IDE/GUI was
    launched.

Git: To Commit or Not To Commit, That is the Question
=====================================================
This is a personal preference, but do be sure to think about which
products should be committed to *Git*, else some very large files and
other unintended files could be committed to your *Git* repository.

- Exclude files not to be committed using *.gitignore*.
- Set *lfs* attribute for large files that are intended to be committed.

**Recommendations**:

- Add the build or workspace directory to *.gitignore.*

  - The ambitious may wish to explore saving all but the hls/ and logs/
    directories.
  - This would preserve the component definition, saving recreating it
    on checkout and the reports, which may be used for tracking purposes.

    - Note that saving the component files themselves (a couple of
      .json files) is dicey since they almost certainly contain absolute
      file paths. So these are useless unless one is checking out
      to the same directory as the check-in.  Certainly not advised
      for shared projects.

..

- Whether to commit the configuration directory and files to the *Git* repository
  is a user choice.

  - The configuration files are constructed, whenever possible, to have
    all relative paths, so it may be convenient to commit them.

    - If your project references files not in the project root
      subdirectory, the configuration file may contain absolute paths
      making them potentially ineligible to be stored in *Git*. If in doubt,
      look at the configuration files.

  - If they are committed, their corresponding components, which are
    stored in the workspace, are generally not free of the absolute paths
    where they were constructed. Here, the components must be recreated on
    checkout using **hlsComp**. This diminishes the usefulness of committing
    the configuration files if they can easily be recreated by |hlsCfg|.
    However, there are cases where recreating the configuration files may not
    be easy.

    - Since only the basic options to compose a configuration file
      are supported by |hlsCfg|, it may be that they have been hand
      tailored to add unsupported options, making them hard to reproduce.
    - In this case, committing the configuration file is highly
      recommended to preserve these additions.

- Commit the *ip* directory and its contents to *Git*, due to the extended time
  involved in creating the contents. These are large files, so use the *lfs* attribute.

Feedback Wanted
---------------
Improvements

- Expand the number of parameters available on the command-line.

  - In developing HLS code, the ability to do ad hoc experimentation and
    then capture and catalog the useful ones is invaluable. Being able
    to experiment on the command-line goes a long way in realizing this.

  - Doing all parameters was too large a job to do all at once. Getting
    the basics was hard enough.

  - If there is interest, a 'hook' routine could be invented to add
    necessary, but currently unsupported options.

    - The hard piece is defining a user API. Just what information is
      needed?
    - This gets complicated since many of the |hlsBs| *unsupported*
      options are Vitis version dependent.

- There may be better ways to capture the common defaults

    - A common problem of defaulting is that the full functionality
      is hidden.
    - Want a solution that says "here are the usual defaults, but if
      more is needed, it is here".

Appendix
========

Manual Styles
-------------
Manuals, such as this one, are generally classified as a *Reference Manual*,
as opposed to `hlsBs-examples <https://github.com/slaclab/hlsBs-examples>`_, a
*User's Guide*.  Another classification is *descriptive* *vs.*
*prescriptive*.  Certainly reference manuals are more
*descriptive* and user manuals more *prescriptive*, but there is overlap.

Reading only the *User's Guide* (*i.e.* following
`hlsBs-examples <https://github.com/slaclab/hlsBs-examples>`_) invariably
results in aping what is there -- the sole goal is to *make* the output
products.

|hlsBs| is not only a build system (the *prescriptive, just build my
products*), but also a development system meant to aid the user on the journey
to produce the best quality code. As such, there is no one right (read
*prescriptive*) way. What |hlsBs| attempts to do is provide the tools
and techniques to define a personalized and disciplined workflow and
encourage an iterative, feedback-driven approach.

.. _design_notes-label:

Design Notes - Why it was done this way
---------------------------------------
Paraphrasing the great Joni Mitchell, "*you don't know what you need when it's
not there*". Some design principles of |hlsBs| are:

- Design the commands to be intuitive and follow the principle of
  *least surprise*.

- Commands do not depend on the current working directory.

  - They can be executed from any directory.
  - Recalled commands work the same whether the current working
    directory has been changed or not.

    - Well, almost. See the :ref:`a_word_of_caution_parameters-label` section
      for, well, a word of caution.

    .. caution::
       There is a downside to being current working directory independent.
       If one executes the |hlsBs| commands from different directories, you
       will find those directories, like pigeons do to city streets, littered
       with random and, at times, very large files since Vitis writes various
       log files to the current directory.

- Keep |hlsBs| as policy-free as possible.

  - For example, no particular directory structure or naming
    conventions are imposed.

  - Still provide sensible defaults which can be easily modified
    to suit the user's personal preferences and/or the specific
    project's needs.

    .. tip::

       Use the defaults unless there is a compelling reason not to. It
       promotes uniformity, making it easier for others to understand.

- Partition the information by where it is kept, when it is used, and its lifetime.

  - Static information, such as the workspace and configuration
    file descriptions.

    - These are kept in the :ref:`Project File <project_file-label>`
      section.

  - Quasi-static information, such as experimenting with
    parameters that affect performance/resource trade-offs.

    - These are kept in named
      :ref:`parameter files <parameter_files-label>`
      which can contain 1 or more command-line parameters.

    - They are referenced on the command-line as **@FILE**. These are
      made possible by a nice feature of Python's *argparse* methods
      which was found to be so useful, a C++ equivalent was constructed.

    - A usage might be to define alternate test sets in
      a family of such files, then selecting which one to target
      at runtime.

  - Traditional command-line runtime parameters, such as changing the
    input test data or the number of tests to run.

      A useful technique is to experiment on the command-line
      and, if a particular set of parameters is interesting,
      save them in an appropriately named
      :ref:`parameter file <parameter_files-label>` which can be referenced
      when needed.

  - This is achieved by establishing a priority ordering with
    runtime parameters overriding parameter files (depends on ordering) and
    parameter files overriding static parameters found in the *Project File*
    (always).

  ..

  - Currently not all parameters can be overridden. Experience will
    help guide expansion.

- Make the command naming consistent, short, and unique with the goals
  of minimizing details to remember, limiting typing, and avoiding name clashes.

..

- Make the commands as efficient/fast as possible

  - Mainly this involves deferring or avoiding the use of the
    underlying Vitis utilities until and unless absolutely necessary.

    An example is making and cleaning the *csim.exe*. After the
    initial build by Vitis to create the *make* file, |hlsBs| just
    uses that *make* file, bypassing the overhead of going through Vitis.

    - For the SNL test suite, cleaning and rebuilding the 28
      components using |hlsBs| takes about 1.5 minutes
      versus 11 minutes going through Vitis.

  - Even for steps where the Vitis startup overhead is small compared
    to the execution time such as synthesis, |hlsBs| sometimes can
    detect errors before invoking the costly Vitis utility.

- Provide query commands, such as listing the components and configuration
  files.

  - Given the power of these commands, unknown
    *stuff* (in |hlsBs| parlance, this is known as **cruft**) creeps in.
  - Query commands are a check on what is or will be there.
  - Closely related is almost all commands have a *--dry-run* option to
    see what would have been done.

    - Particularly valuable for destructive (*e.g.* *--clean*) actions.

- Similar command structure

  - The most commonly used commands uniformly target component(s)
    by name and category.
  - Component names may be an explicit name, a wildcarded name, or
    a list of any combination.
  - Components are classified into the following categories

    - Existing
    - Missing
    - Cruft

  - Commands, by default, target their most logical component category
    and names. Explicit selection is also possible. As a concrete
    example, the default targets for the configuration file and
    components management actions (via |hlsCfg|) are

    .. list-table:: hlsCfg Action Defaults
       :header-rows: 1

       * - Action
         - Category
         - Target Name
       * - clean
         - existing
         - None, since this is destructive, demand an explicit target
       * - list
         - all
         - '*'  (All)
       * - create
         - missing
         - '*'  (All)
       * - replace
         - existing
         - '*' (All)

Disclaimer
----------
The author is decidedly not a UI expert. This design is the product of
actually producing HLS code with all its frustrations and limitations.
Whether |hlsBs| achieves making this simpler and more flexible
remains to be seen.
