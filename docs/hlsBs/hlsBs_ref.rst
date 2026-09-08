.. contents:: Table of Contents
   :depth: 100

===========================================
hlsBs -- A HLS Development and Build System
===========================================

Introduction
============
Welcome to that indispensable thing called documentation. Demanded by
many, written by one, destined to be read by few.

Being honest, a build system is not high on anyone's interest list.
This is a reference manual, *i.e.*, where only the truly lost and
hopelessly confused desperately seeking answers come, the land of last
resort. For those who enjoy reading the *magnifying glass required,
may cause death or blindness* fine print on warning labels, welcome home.

Quick-Start
-----------
One could skip to the :ref:`Overview <overview-label>` or go to the
`hlsBs-examples <https://github.com/slaclab/hlsBs-examples>`_ github
repository which is more of a *How-To* user's manual. For many, this
is all that is needed. If the project is beyond the basics, then this
more complete manual may be of interest.  The test suite for the SNL
framework, which has 20+ components whose performance, resource usage
and integrity must be tracked across multiple Vitis releases, is an example of such a project.

How To Read
-----------
Skim this, look at the section titles, then the first level of bullet
items, take a look at
`hlsBs-examples <https://github.com/slaclab/hlsBs-examples>`_ test drive it,
then come back and read more thoroughly.  Without hands-on experience as
grounding, reference manuals are just a blizzard of words. It is a feedback
process, not a core-dump.

The 'Not for Claude' Section
----------------------------
Claude should skip this section. There are no tokens of any nutritional
value here.

Manuals, such as this one, are generally classified as a *Reference Manual*,
as opposed to `hlsBs-examples <https://github.com/slaclab/hlsBs-examples>`_, a
*User's Guide*.  Another classification is *descriptive* *vs.*
*prescriptive*.  Certainly reference manuals are more
*descriptive* and user manuals more *prescriptive*, but there is overlap.

Reading only the *User's Guide* (*i.e.* following
`hlsBs-examples <https://github.com/slaclab/hlsBs-examples>`_) invariably
results in aping what is there -- the sole goal is to *make* the output
products.

**hlsBs** is not only a build system (the prescriptive, *just build my
products*), but also a development system meant to aid the user on the journey
to produce the best quality code. As such, there is no one *right* (read
prescriptive) way. What **hlsBs** attempts to do is provide the tools
and techniques to define a personalized and disciplined workflow and
encourage an iterative, feedback-driven approach. This point will be made
throughout this document. Ask, 'How does this feature help?'

Limitations
-----------
Since **hlsBs** depends on the more recent unified development framework
from AMD/Xilinx, only Vitis versions 2023.2 or greater are supported.

.. caution::
   2023.2, being the first version to support the unified development environment, has some *peculiarities*.  **hlsBs** has workarounds, but as with all workarounds, there are pitfalls.

   **Recommendation**: Use versions 2024.1 or greater unless there is a specific reason to use 2023.2.

Disclaimer
----------
The author is decidedly not a UI expert. This design is the product of
actually producing HLS code with all its frustrations and limitations.
Whether **hlsBs** actually achieves making this simpler and more flexible
remains to be seen. What can be said is the effort was there.

Goals
=====
**hlsBs** is a command line driven system designed to simplify the
HLS/Vitis build process and aid in the code development, particularly for
projects involving multiple components.  The utility of multiple
components falls into 3 categories:

- Projects composed of 2 or more distinct HLS components or variations.
  Here distinct means:

  - Components may run on physically different FPGAs with one
    feeding the other in a daisy-chain fashion.
  - The same project needs to run on multiple FPGA parts.

- Tracking the time evolution of a project where usually the components
  are the same basic code but from different *git* commits.

- The same component but with different algorithms or pragma
  parameters to explore the performance/resource tradeoffs.

The goal was, by making it easy to create, build, compare, catalog and
track multiple components, to encourage experimentation and exploration.
The cruel school of experience in developing HLS code has shown this step
is necessary to achieve the best results. The correct algorithm and pragma
settings are never immediately apparent.

.. note::

   Recent advances in AI agents can be helpful in this feedback process,
   primarily in the proper *pragma* settings.  The verdict is still out
   on how much help it is in selecting the proper *algorithm*. Selecting
   the proper algorithm is generally more important than optimizing the
   wrong one.

A truly useful feature of the Vitis IDE/GUI is the ability to compare
components in a nicely laid out display. **hlsBs** tries to leverage this
by providing methods to capture and organize the development evolution.

   A common theme is realizing some aspect of the resource/performance
   tradeoffs has been overlooked during development and now is far from
   where it was 2 days ago, *e.g.* the LUT usage has doubled. By capturing
   the steps along the way, there is a chance to backtrack through these
   breadcrumbs and locate the offending random code/pragma change.

Primary Goals
-------------
- Make simple projects simple and more complex projects possible.
- Be compatible with the HLS GUI/IDE build and development system.

  - One can freely mix and match, using whichever one is appropriate
    and comfortable for the task at hand.

- Accommodate building the same project using multiple VITIS versions.

  - This encourages both moving forward with new versions and
    comparing their differences.

- Handling the drudgery of creating the configuration files and components.

  - This is reduced to almost a 'fill-in-the-blanks' exercise.
  - Biggest advantage is when producing multiple, very similar
    components.

- Easily run all or any subset of the various build stages (*csim,
  synthesis, cosim, etc.*) on any collection of components.


Secondary, less user-facing goals
---------------------------------
Paraphrasing the great Joni Mitchell, "*you don't know what you need when it's
not there*".

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
       If one executes the **hlsBs** commands from different directories, you
       will find those directories, like city streets with pigeons, littered
       with random and, at times, very large Vitis file droppings since Vitis
       writes various log files and such to the current directory.

- Keep the **hlsBs** as policy free as possible.

  - For example, no particular directory structure or naming
    conventions are imposed.
  - Still provide sensible defaults which can be easily modified
    to suit the user's personal preferences and/or the specific
    project's needs.

    .. admonition:: Recommendation
       :class: tip

       Use the defaults unless there is a compelling reason not to. It
       promotes uniformity, making it easier for others to understand.

- Appropriately partition the needed information by where it is kept,
  when it is used and its lifetime.

  - Static information, such as the workspace and configuration
    file descriptions.

    - These are kept in the :ref:`Project File <project_file-label>`
      section.

  - Quasi-static information, such as experimenting with
    parameters that affect performance/resource trade-offs.

    - These are kept in named files which can contain 1 or
      more command line parameters.
    - They are referenced on the command line as **@FILE**;
      made possible by a nice feature of Python's *argparse* methods
      which was found to be so useful, a C++
      :ref:`equivalent <indirect_files-label>` was constructed.
    - A usage might be to define alternate test sets in
      a family of such files and selecting which one to target
      at run-time.

  - Run time parameters, such as changing the input test data or the
    number of tests to run.

      A useful technique is to experiment on the command line
      and, if a particular set of parameters is interesting,
      save them in an appropriately named quasi-
      static file which can be referenced when needed.

  - This is achieved by establishing a priority ordering with
    run time parameters overriding quasi-static parameters and
    quasi-static parameters overriding static parameters.

  ..

  - Currently not all parameters can be overridden. Experience will
    help guide expansion.

- Make the command naming consistent, short and unique with the goals
  of minimizing remembering details, limiting typing and avoiding name clashes.

..

- Make the commands as efficient/fast as possible

  - Mainly this involves deferring or avoiding the use of the
    underlying Vitis utilities until and unless absolutely necessary.

    An example is making and cleaning the *csim.exe*. After the
    initial build by Vitis to create the *make* file, **hlsBs** just
    uses that *make* file, bypassing the overhead of going through Vitis.

    - For the SNL test suite, cleaning and rebuilding the 28
      components using **hlsBs** takes about 1.5 minutes
      versus 11 minutes going through Vitis.

  - Even for steps where the Vitis startup overhead is small compared
    to the execution time such as synthesis, **hlsBs** sometimes can
    detect errors before invoking the costly Vitis utility.

- Provide query commands, such as listing the components and configuration
  files.

  - Given the power of these commands, without fail unknown
    *stuff* (in **hlsBs** parlance, this is known as **cruft**) creeps in.

- Similar command structure

  - The most commonly used commands uniformly target component(s)
    by name and category.
  - Component names may be an explicit name, a wildcarded name, or
    a list of any combination.
  - Components are classified into the following categories

    - Existing
    - Missing
    - Cruft

  - Commands, by default, target the most logical component category
    and names. Explicit selection is also possible. As a concrete
    example, the default targets for the configuration file and
    components management actions (via **hlsCfg**) are

    .. list-table::
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

.. _overview-label:

Overview
========
There are 3 distinct pieces to **hlsBs**.

- The obligatory environment/context setup
- The *Project* file
- The **hlsBs** commands.

Setup - Brief
-------------
The setup itself has 3 distinct pieces. These establish

1. The **hlsBs** command set

  - Makes the **hlsBs** commands available to the *bash* shell.
  - There is no dependency on the Vitis version or your specific project, so
    it is a one-time login thing.

2. The Vitis version to use

  - Once selected, viable until it is changed.

3. Your project specific setup

..

   .. tip::
      Even though the **hlsBs** setup need only be done at login, it is often
      convenient to include the **hlsBs** setup in your project setup script.
      Except for the brief amount of time it takes, it is okay to execute it
      multiple times.

.. _project_file-label:

Project File - Brief
--------------------
The Project File is the source of the information needed to produce the
**hlsBs** output files. This information includes

- The set, location and contents of the configuration files.
- The location of the workspace containing the Vitis/HLS components.
- The location and contents of the :ref:`ip products <get_ip-label>`,
  *i.e.* the modified .zip and .dcp files.

Commands - Brief
----------------
The commands

- Use the project file to create and manage

  - The workspace
  - The configuration file and associated components

..

- Produce the output products, *i.e.* **csim**, **synthesis**, **cosim** *etc*.

  - The project file can be used, or
  - Alternately, since no project file is needed once the workspace,
    configuration files and components have been created, it can be ignored.

    - All that is needed is the workspace which can be specified on the
      command line either by

      - --workspace=<*workspace_location*> or
      - With the environment variable  **HLSBS_WORKSPACE**.

    - Useful if the workspace, configuration files and components were
      produced by some means other than **hlsBs**, *e.g.* in a legacy project.

In keeping with the goal of being able to mix techniques, it is
permissible for the configuration files, the workspace and components
to be generated by some other means. The most common example of this
would be legacy projects. However, not using **hlsBs** to generate
these products will limit some of its most useful features.

The *Setup* will be addressed first, then the **hlsBs** *Commands*,
saving the more complex project file for last.

Setup
=====
If the **hlsBs** defaults are acceptable or the workspace, configuration files
and components are created by other means, not all these steps may be
necessary.  This will describe the most '**hlsBs**'-like usage. The first
two steps can be done in any order.

1. Define the environment variable **HLSBS_XILINX_SETUP**

   - This is usually a single path of where to look for the XILINX
     setup script, *i.e.* the *settings64.sh* file, for the desired Vitis
     version.

   - If there is more than one search path, in the usual Linux convention,
     separate the paths with a colon (':').

   - Since the Vitis installation location is site specific, it cannot be set
     by or be a part of **hlsBs**.

   - As an example, at SLAC, all XILINX installations are under one root
     directory, so this would be

     .. code-block:: bash

      $ export HLSBS_XILINX_SETUP='/sdf/group/faders/tools/xilinx/\$\{version\}'

     where **version** will be filled in when a version (2024.1,2024.2,etc)
     is selected.

     .. note:: The escapes preserve the special characters and single quotes
               to prevent the shell from translating **${version}** until
               needed.

     This can be placed in your login script, but, for good reasons,
     many like to keep their login scripts minimalist. However, typing that
     gobbledygook at the command line is no small feat. The suggestion is to
     create a shorthand either (emphasizing that this is just a suggestion to
     make it easier to set **HLSBS_XILINX_SETUP**)

     - Define an alias or bash function that can be easily remembered and
       invoked, e.g. *hlsToolChain*.


       .. code-block:: bash

          alias hlsToolChain='export HLSBS_XILINX_SETUP=/sdf/group/faders/tools/xilinx/\$\{version\}'

       or

       .. code-block:: bash

          hlsToolChain() {export HLSBS_XILINX_SETUP='/sdf/group/faders/tools/xilinx/${version}';`}

       .. admonition:: Recommendation
         :class: tip

         The name, here *hlsToolChain*, is entirely your own choosing.
         Pick something meaningful, unique and short. Place it in a
         script that is executed as part of your bash login.

     The bash function is the safer choice since it better hides the
     variable *version* from being altered by the shell.

     Be as specific with the path as possible. Since this involves a
     file search, a broad search may be slow. At some sites it may be
     better to have multiple, more specific paths, than a single broad one.

     - The target version must appear somewhere in the search path.

       The assumption by **hlsBs** is that the version appears either
       in the directory path or the settings file name.

       In the highly unusual case that the Vitis version is not part of the
       file path/name, then some other way of selecting and setting up
       the Vitis version must be used.

  - Defining this environment variable can be omitted if some other
    method of selecting and invoking the desired Vitis setup script
    is preferred. However, the full functionality of the command
    **hlsVersion** <*version*> depends on this environment variable, so
    the convenience of easily switching versions will be lost.

  ..

  - Try it, you'll like it.

2. Source the **hlsBs** setup script

   ``$ source <path/to>/ruckus/vitis/hlsBs/scripts/setup_hls.sh``

   - This merely makes the commands available to the bash shell, there is
     nothing project or Vitis version specific.

     As such, it can be a one-time step at login time, perhaps combined
     with the first step.

     .. tip::
       Commonly, *ruckus* will be a submodule of the project and it
       may be more natural to include this in the project's setup script,
       since the **hlsBs** setup script can be located relative to the project.

       Except for the time (it does not take long), it may be repeatedly
       executed.

3. Establish the Vitis version to use

   ``$ hlsVersion <vitis-version>``

   If the Vitis version is specified, the Vitis setup script for that
   version is sourced.

     - HLSBS_XILINX_SETUP environment variable must be appropriately set.
     - This makes it very convenient for switching between Vitis versions.

   If no *vitis-version* is specified **and** the version has been established
   in some other way, **hlsVersion** will use that currently established
   version.

   - Once the Xilinx/Vitis version has been established, the internal
     **hlsBs** version dependent context is initialized.

   - Again, no project specific context is setup.

   - Example:

      ``$ hlsVersion 2025.1``

..

4. Selecting the target project is covered in the **Project File** section.


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


.. list-table::
   :header-rows: 1

   * - Command
     - Descriptions
   * - hlsBs
     - Provides a quick summary of all the commands, basically the online version of this section.
   * - hlsVersion
     - Establishes the Xilinx/Vitis version to be used.
   * - hlsWs
     - Creates and provides information on the workspace.
   * - hlsCfg
     - Creates, replaces, cleans, lists the configuration files and components.
   * - hlsComp
     - | Creates, replaces, cleans, lists the components.
       | Useful when you only have the configuration file. - **rarely used**.
       | Possible use: when the configuration files are saved to git but not the components.
   * - hlsRun
     - Runs all or any build stage (csim, synthesis, cosim, package, implementation, ip).
   * - hlsExe
     - | Runs *csim.exe* for a specified component.
       | Useful when changing the arguments, *e.g.* changing the test files or the number of tests.
   * - hlsGdb
     - Invokes the debugger on a specified component.
   * - hlsGui
     - Starts the IDE/GUI.
   * - hlsCtx
     - Shows the values of the environment variables in current use by **hlsBs**.

Once the workspace has been established and the configuration files and components
created (often one-time per project activities), the vast majority of the use is
**hlsRun**, with the occasional use of **hlsExe** and **hlsGdb** during
development and debugging.

.. _a_word_of_caution_parameters-label:

A Word of Caution on Command Line Parameters
--------------------------------------------
This is the section you didn't think you needed until the unexplainable happens.

There are a few bash shell *gotchas*. These aren't peculiar to **hlsBs**, but
it seems particularly vulnerable.

1. As indicated before, the target component names may include wildcards, which the
   shell is all too eager to translate by finding matching patterns in the file names
   of the current working directory. Of course, unless the current working
   directory is the target of the translation, this will not yield the
   desired results.

   Even more insidious, if there are no matching files, as per bash shell
   rules, the translation will fail and the wildcard will be passed as is,
   yielding the desired results. While this sounds like a good thing, this
   can lead to very mysterious behavior; a recalled command that previously
   worked, may now not work because the current working directory has changed
   or a new file was added that now satisfies the wildcard.

   There are two methods to prevent this.

   - Always single quote any wildcarded name if specified as a positional
     argument,
     *e.g.* ``'a*'``
   - Use the alternative optional argument syntax to specify the components,
     *e.g.* ``--components=a*``.
     The ``--components`` can be abbreviated to the minimum to be unique,
     *e.g.* ``--com``.

..

2. Do not place a positional argument immediately following an optional
   argument that accepts a value or list of values.  Since the bash shell
   enforces no formal binding or grouping, a positional argument juxtaposed
   to such an optional argument will be *eaten* by that optional argument.
   To avoid this

   - Make any positional argument the first argument.
   - Use the optional argument, ``--component=a*``
   - Example of what not to do:

       ``$ hlsCfg --list '*'``

       Since ``--list`` takes a list of component categories, effectively this
       will be seen as ``--list='*'``, certainly not the intent.

   .. admonition:: Recommendation
      :class: tip

      Use positional arguments sparingly, favoring the optional
      argument form ``--components=*``. While the ``=`` is optional, it
      does bind the argument list and, as a bonus, prevents the shell
      from expanding the wildcard even without the single quotes. It is
      the most fool-proof method and, along with using the full keyword name
      of an optional argument, should be used when scripting these commands.

      Positional parameters are a trap waiting for a victim.

Project File - Overview
=======================
The *Project file* is the source of information that makes these commands easy to
use at the terminal. It is Python code that gets invoked by the **hlsBs** commands.
Python was chosen because

- Python is familiar to many and is a good match for the task.
- Python can implement the simple to the complex.
- Errors are nicely reported by the Python interpreter.
- Easy to interface with the Vitis Python APIs.

Locating the Project File
-------------------------
Obviously the location of *Project file* itself cannot be sourced from the
*Project file*. There are 2 ways to specify the *Project file* location:

- By setting its environment variable

  .. code-block:: bash

     # Commands will then use this environment variable as the project file
     $ export HLSBS_PROJECT=<project file location>

- Directly on the command line

  .. code-block:: bash

     # Only this command will use this project file location
     $ hlsWs --create --project=<project file location>

The latter is an example of a command line variable overriding the static setting
of the environment variable.

.. admonition:: Recommendation
   :class: tip

   Define the environment variable for normal usage.  Typically
   this would be defined in the project's setup script. The second form
   is useful to test variations of the project file.

While many values in the *Project file* can be overridden on the command line,
normal usage is to use the values in the *Project file*. Not only does this
decrease typing at the command line, indirectly it ensures consistency from
command to command and helps to eliminate errors caused by typos.  An example of
standard and non-standard usage might be

.. code-block:: bash

   $ hlsWs --create  # Create the workspace defined in the project file specified by HLSBS_PROJECT
                     # or, if defined, HLSBS_WORKSPACE.
   $ hlsWs --create --workspace=/tmp/tmp_workspace  # Create an ad-hoc workspace as a playpen

As is true in many cases, the advantage of the first form is that this definition
is hidden and need not be remembered and the disadvantage is that this definition
is hidden and not remembered. When in doubt about this hidden context, use
**hlsCtx** to display the implicit **hlsBs** context information.

.. _environment_variables-label:

Environment Variables
---------------------
The following environment variables are recognized. These override potential
equivalent values in the project file, but they themselves can be overridden
on the command line with explicit parameters, *e.g.*

.. code-block:: bash

   $ hlsWs --create --project=<my_project_file>

.. list-table::
   :header-rows: 1

   * - Variable
     - Meaning
   * - HLSBS_XILINX_SETUP
     - The search path(s) for the Xilinx/Vitis settings scripts
   * - HLSBS_PROJECT
     - The project file
   * - HLSBS_PRODUCTS
     - The products directory
   * - HLSBS_BUILD
     - The build directory
   * - HLSBS_WORKSPACE
     - The workspace
   * - HLSBS_CFG
     - The configuration files directory
   * - HLSBS_IP
     - The ip (modified .zip & .dcp files) directory
   * - HLSBS_INI
     - This is a colon separated list of @FILES

Usage
~~~~~
The **HLSBS_PRODUCTS**, **HLSBS_BUILD**, **HLSBS_WORKSPACE**, **HLSBS_CFG**
and **HLSBS_IP** environment variables are useful for one-off ad-hoc
experimentation. Products produced during such experimentation can be
redirected so as to not pollute the regular directories.

**HLSBS_INI** is an :ref:`advanced feature <indirect_files-label>`
allowing one to collect a number of indirect files used to modify
command line parameters in a colon separated list of such files.

   This is not ideal. It is unfortunate that *argparse* does not allow an
   include mechanism so that files with well-defined purposes can be mixed
   and matched.

All user-facing **hlsBs** environment variables begin with **HLSBS_**. These can
be listed using **hlsCtx**.


Structure
---------
The project file is a piece of user written Python. As a practical matter,
in many cases it will be cloned from a similar project with a few name
changes, *e.g.* the names of the source files, where the includes are, the
**csim.exe** command line parameters, *etc*. Since it is Python, more complex
projects, for example projects with multiple components like the SNL Test suite
(>25 components) can be accommodated.

   .. admonition:: Editorial Comment
      :class: tip

      The standard Vitis method in the GUI/IDE works fine when creating a
      single configuration/component, but creating many components is not
      only tedious, but, once created, implementing a change common to all
      is error prone. Python is much better suited in creating multiple
      configuration files and components.  It is familiar to many users and
      syntax errors are well handled by the Python interpreter.

With experience it is anticipated that a small collection of stock project
template files will be accumulated.  For example, one for a simple project with
a single test bench and hls file, reducing it to a *fill-in-the-form* exercise.

    There is already one for SNL. Here the structure is very static and basically
    all that is needed is the network definition file, the target FPGA and the test
    files. A universal file (SNL.py) provides the boilerplate contained in a single
    class initialized with the values from the project dependent project file.

Environment Variables & Logical Symbols
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Environment variables (both the
:ref:`hlsBs defined ones <environment_variables-label>` and user defined project
specific ones) and logical symbols (explained later, think of them as
variables in a programming language) are used extensively in the project file. This
is one of the primary advantages of **hlsBs** over the standard
Xilinx/Vitis/HLS methods.  It allows for abstraction; instead of hard-coding,
logical symbols, such as representing the configuration file name, can be used.

Conventions: What to Name the Project File & Where to Put It
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
While the project file can go anywhere simply by defining **HLSBS_PROJECT** as its location, using the recommended location in the directory tree is the
easiest and should be used unless there is good reason not to.

.. admonition:: Recommendation
   :class: tip

   Place the project file in the */project* subdirectory of the
   project's top level directory and name it after the project.
   Again, not necessary, but standard placement and usage helps others
   sharing the project.

Project File - Annotated Example
================================
To bring some concreteness to the discussion below, a hypothetical project
(called *example*) with the following directory structure will be assumed.

.. warning::

   This is not a working example. It is only meant to illustrate the basics
   of the overall structure of a **hlsBs** project.  See the
   `hlsBs-examples <https://github.com/slaclab/hlsBs-examples>`_ repository
   for complete working examples.

::

    example/
            project/ExampleProject.py
            src/example/ExampleTb.cc, ExampleHls.cc
            include/example/Example.hh
                           /opt
                               /Opt1.hh
                               /Opt2.hh

The **hlsBs** commands produce a variety of output products. The default layout is

::

   example/
           products/
                   build/  # A .gitignore excludes build/ and its contents from being committed.
                         ws/{vitis-version} # Workspace for a particular Vitis version
                        cfg/{vitis-version} # Configuration files directory
                   ip/{vitis-version}       # Directory for the modified .dcp and .zip file


The Project File is a handful of user provided python methods. These methods
break into 2 distinct categories:

- Those locating the directories where the output products go
- Those that define the configuration file and ip products contents

Those defining the directories of the output products are optional if their
defaults are acceptable. The default can be used by

- Omitting the method
- Return *None*

.. admonition:: Recommendation
   :class: tip

   If accepting the defaults, rather than omitting the method, it may be
   helpful to return *None*. This serves as a visual reminder that the method
   can be changed if the defaults are not acceptable. For experienced,
   in-the-know users, omitting the method is perfectly valid.

Only the :ref:`get_products <get_products-label>` method is mandatory.

.. warning::
   The :ref:`get_ip <get_ip-label>` method is also optional; however,
   accepting the defaults could be problematic. Accepting the default
   implies that the output products are valid for all known FPGA
   families.

Product Directory Methods
-------------------------

These methods locate the directories that receive the output products.

.. admonition:: Recommendation
   :class: tip

   These may all be omitted if the default directory layout is acceptable.


get_project_root (project)
~~~~~~~~~~~~~~~~~~~~~~~~~~
This returns the project's root directory.  Example

.. code-block:: python

   def get_project_root (project) : return '$MY_PROJECT_ROOT'

Better is to self locate the project root relative to the project file.  Using
the directory structure above

.. code-block:: python

   def get_project_root (project) : return os.path.dirname(os.path.dirname(__file__)

or the more modern and syntactically cleaner

.. code-block:: python

   def get_project_root (project) : return Path(__file__).resolve().parent.parent

The second form is the default and is used if the method is omitted or
returns *None*.

.. admonition:: Recommendation
   :class: tip

   If possible, self root the project root relative to the project file. This keeps
   environment variables (which may be forgotten to be set) and absolute
   file paths out of the project file resulting in a configuration file that is
   more self-contained and portable.

.. _get_products_root-label:

get_products_root (project)
~~~~~~~~~~~~~~~~~~~~~~~~~~~
This returns the umbrella directory where the various products (workspace,
configuration files, ip) are placed.  While **hlsBs** provides the
ability to individually place these anywhere, it is convenient to place
these within a common directory. Doing so allows one to remove all products
with a simple `rm -rf <products_dir>`.

Example

.. code-block:: python

   def get_products_root (project) : return '$MY_PRODUCTS_ROOT'

or locate it relative to the project root

.. code-block:: python

   def get_products_root (project) : return os.path.join (project.root, 'products')


Of course, it can be located anywhere and named anything. The latter specification
above is the default.

.. admonition:: Recommendation
   :class: tip

   Locate the products relative to the project root.

Note the use of *project.root*.  This is deliberate because the
project root can be overridden on the command line. If this is done,
this *project.root* will be set to this value.  This is a
recurring pattern.  Many of the values in the project file can be
sourced either from within the project file itself or overridden at
the command line.

   The products root can be overridden from the command line either with
   an explicit command line parameter or the **HLSBS_PRODUCTS**
   environment variable.  This is useful for creating ad hoc,
   experimental versions of the products. A possible usage is to temporarily
   relocate the products in a throw-away directory. *e.g.* */tmp/products*.


get_build (project)
~~~~~~~~~~~~~~~~~~~~~~~
This returns the build directory. It is customary to place output products
that will not be committed to *git* in this directory or subdirectories of it.
Typically, the *build* directory is excluded by an entry in *.gitignore*.

.. code-block:: python

   def get_build (project) : return '$MY_BUILD_ROOT'

or locate it relative to the products root

.. code-block:: python

   def get_build (project) : return os.path.join (project.products, 'build')

This is the default.

.. admonition:: Recommendation
   :class: tip

   Locate the build directory relative to the products directory.

Note the use of *project.products*.  This is deliberate because the
project root can be overridden on the command line. If this is done,
*project.products* will be set to this value.

   The build directory can be overridden from the command line either with
   an explicit command line parameter or the **HLSBS_BUILD**
   environment variable.  This is useful for creating ad hoc,
   experimental versions of the products. A possible usage is to temporarily
   relocate the build products in a throw-away directory. *e.g.* a
   subdirectory of */tmp/build*.


get_workspace (project)
~~~~~~~~~~~~~~~~~~~~~~~
This returns the location of the workspace directory. Example

.. code-block:: python

   def get_workspace (project) :	return '$MY_WORKSPACE'

or locate it relative to the build directory

.. code-block:: python

   def get_workspace (project) : return os.path.join (project.build, 'ws', '{vitis.version}')

This is the default.

Here *'{vitis.version}'* is the first encounter of a logical symbol.  This
allows the workspace to be distinguished by the Vitis version which will be
resolved to the current Vitis version, typically set by **hlsVersion**,
when the workspace is referenced.

.. admonition:: Recommendation
   :class: tip

   Locate the workspace relative to the build directory and include the Vitis version.

Note the use of *project.build*.  This is deliberate because the
build directory root can be overridden on the command line. If this is done,
the *project.build* will be set to this value.

   The workspace can be overridden from the command line either by setting the
   environment variable **HLSBS_WORKSPACE** or specifying the command line parameter.
   This is useful for creating ad hoc, experimental versions of the workspace.
   A reasonable tactic would be to relocate the workspace to a throw-away directory
   such as in */tmp/ws*.  (Since this is a throw-away, whether the Vitis version is
   included is at the discretion of the user.)


get_cfg_root (project)
~~~~~~~~~~~~~~~~~~~~~~
This returns the root directory where all configuration files will be stored.

Example:

.. code-block:: python

   def get_cfg_root (project) : return os.path.join (project.products.root, 'cfg', '{vitis.version}')

This is the default.

.. admonition:: Recommendation
   :class: tip

   Locate the configuration directory relative to the project.build directory
   and include the Vitis version.

..

   A reason not to locate it relative to the build directory is if you wish
   the configuration files to be committed to *git*.  This is not usual, but
   **hlsCfg** ensures that all file references that can be made relative to
   the project directory are. If resulting configuration contains no
   absolute file paths, it can be checked out of *git* and used as is. A
   reasonable alternative is to locate the configuration directory relative
   to the *projects.products* directory.


As in the *workspace*, the version allows the configuration file to be
distinguished by the Vitis version and will be resolved when the configuration
directory is referenced.

   The configuration directory can be overridden by the environment variable
   **HLSBS_CFG** or the command line parameter. As with the *workspace*, a
   possible usage is to create an ad hoc set of configuration files, although
   this is not nearly as useful as with the workspace. It is provided more
   for consistency.


get_ip_root (project)
~~~~~~~~~~~~~~~~~~~~~
This returns the root directory where *ip* products, the modified *.dcp*
and *.zip* files will be written.

.. code-block:: python

   def get_ip_root (project) : return os.path.join (project.products.root, 'ip', '{vitis.version}')

This is the default.

.. admonition:: Recommendation
   :class: tip

    Locate the ip directory relative to the products directory and include
    the Vitis version.

.. admonition:: warning

   The *.dcp* and *.zip* files can be large.  If committing to git, consider
   adding

   .. code-block:: text

     *.dcp filter=lfs diff=lfs merge=lfs -text
     *.zip filter=lfs diff=lfs merge=lfs -text

   to the *.gitattributes* file.


As in the *workspace* and *cfg*, the version allows the ip products file to
be distinguished by the Vitis version and will be resolved when the ip root
directory is referenced.

   The ip directory can be overridden from the command line with the
   **HLSBS_IP** environment variable or the command line parameter.
   As in the workspace and cfg, a possible use is to create an ad hoc set of
   ip files, although this is not nearly as useful as the workspace. It is
   provided more for consistency.

.. _get_products-label:

Product Definition Methods
--------------------------

This is the major weight lifter.  It specifies all the information
needed to define the configuration files and components. As such,
there is a lot more to it.

.. tip::
   Look over the contents of :ref:`get_products <get_products_code-label>`.
   This will give you the big picture and use the annotated version only to
   clarify.

   Try not to get lost in details. Keep the necessary ingredients in mind
   when building HLS code:

      - The testbench and synthesis/HLS files
      - Their include paths
      - Any -D macro definitions
      - The top level function name
      - The arguments to csim and cosim
      - Where to put the configuration files and the workspace

   In general, there is a Python class for each of these.

   Do not let the amount of text deter you. Documenting even simple concepts
   at the level needed to code against is lengthy.

..

In the following example, many Python local variables are used to make the
intent clearer.  Whether that has been achieved is up for debate.

In addition, the example specifies all the parameters by their keyword.
The parameters have been listed in the call order so that as one becomes more
familiar with the classes, the keywords can be omitted.

Both make the **Project File** more wordy than one in practice would be.

.. admonition:: Convention
   :class: tip

   The parameter names used in various **hlsBs** Python classes use the plural
   when said parameter can accept a single, list or tuple. This is sometimes
   ambiguous when the parameter naturally references a single set of things.

A line-by-line annotation follows this listing.

get-products - An example
~~~~~~~~~~~~~~~~~~~~~~~~~

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

       # --------=--------------------------------------------------
       # Includes an explicitly named file to the source code
       # #include IMPORT_FILE(OPT_FILE)
       # The actual path generated is relative to the <include_path>
       # ---------=-------------------------------------------------
       opt_file      = Product.IncludeFile  (name     = 'OPT_FILE',
                                             file     = 'opt/Opt1.hh'
                                             rel_path = include_path)

       # -----------------------------------------------------
       # Defines the testbench and hls/synthesis source files
       # Note: The testbench needs both 'verbose' and opt_file
       #       The synthesis needs only opt_file
       # -----------------------------------------------------
       tb_srcs       = Product.Sources (root     = code_root,
                                        files    = 'src/example/ExampleTb.cc'.
                                        includes = include_paths,
                                        defines  = (verbose, opt_file))

       syn_srcs      = Product.Sources (root      = code_root,
                                        files     = 'src/example/ExampleHls.cc',
                                        includes  = include_paths,
                                        defines   = opt_file)

       # ---------------
       # Creates a build
       # ---------------
       build         = Product.Build  (id         = 'example',
                                       top        = 'doit'
                                       tb         = tb_srcs,
                                       syn        = syn_srcs,
                                       csim_argv  = '--ntests=10',
                                       cosim_argv = '--ntests=100'} )

       # -------------------------------------------------------------------
       # Defines the FPGAs to use. Here 2 are defined as a tuple, but a list
       # or a single Product.Fpga could be used. There must be at least 1.
       # -------------------------------------------------------------------
       fpgas         = (Product.Fpga (id          = '6ns',
                                      part        = 'xcku115-flvb2104-2-i',
                                      clock       = '6',
                                      uncertainty = None),

                        Product.Fpga (id          = '5ns,
                                      part        = 'xcku115-flvb2104-2-i',
                                      clock       = '5',
                                      uncertainty = None))

       # ----------------------------------
       # Creates the component contributors
       # ----------------------------------
       ctb_builds    = Product.CtbBuilds  (prefix =  'build',
                                           builds =   build)

       ctb_fpgas     = Product.CtbFpgas   (prefix =  'fpga',
                                           fpgas  =   fpgas)

       # --------------------------------------------------------------------
       # Defines the list of contributors to be used in defining a component.
       # A component must include:
       #   - at least 1 build contributor
       #   - at least 1 fpga  contributor
       # There are other contributors, but these are the two mandatory ones.
       # --------------------------------------------------------------------
       contributors = Product.Contributors (ctb_builds = ctb_builds,
                                            ctb_fpgas  = ctb_fpgas)

       # --------------------------------------------------------------------
       # Defines the configuration template which uniquely names the
       # configuration file path.
       #
       # A directory and the file extension are provided if
       #   - the template is not an absolute file path (use product.cfg_root)
       #   - the extension is omitted (use '.cfg').
       # --------------------------------------------------------------------
       cfg_template = Product.CfgTemplate  (prefix     = 'cfg'
                                            template   = '{build.id}-{fpga.id}')

       # ----------------------------------------------------------------------
       # Names the components after the configuration file name.
       # It is equally valid to name the configuration file after the component.
       #
       # While the component name must be unique, only the configuration file
       # path, not its file name, must be unique.
       # ----------------------------------------------------------------------
       cmp_template = Product.CmpTemplate  (prefix     = 'cmp',
                                            template   = '{cfg.name}')

       # ------------------------------------------
       # A fully defined component consists of
       #    i) The list of contributors
       #   ii) The configuration file path template
       #  iii) The component's name template
       # ------------------------------------------
       components   = Product.Components (contributors = contributors,
                                          cfg_template = cfg_template,
                                          cmp_template = cmp_template)

       # ---------------------------------------------------------
       # The usual Vitis Package IP and Package Output
       #
       # Much of this, but unfortunately not all, is boilerplate.
       #
       # 1. The name is chosen to be the configuration file name
       #    but could also be cmp_name.  It does not have to be
       #    unique, so could be the build.id.
       #
       # 2. The version can be from the git logical symbols, i.e.
       #      '{git.tag}',
       #      '{git.branch}'
       #      '{git.hash_short}'
       #      '{git.hash_long}'
       #      '{git.hash_msg
       #    or any combination.
       # ---------------------------------------------------------
       package_ip     = Product.Package.Ip     (name     = '{cfg.name}',
                                                vendor   = 'SLAC',
                                                version  = '1.0.0',
                                                library  = 'hls')

       package_output = Product.Package.Output (format  = 'ip_catalog',
                                                syn     = 'false')

       package        = Product.Package        (ip      = package_ip,
                                                output  = package_output)

       vivado         = Product.Vivado         (flow    ='syn',
                                                syn_dcp = '1')

       # --------------------------------------------------------------------------
       # In keeping with the method name (get_products), a single, list or tuple
       # of products may be returned.
       # --------------------------------------------------------------------------
       return Product (project    = project,
                       components = components,
                       package    = package,
                       vivado     = vivado)
   # ------------------------------------------------------------------------------

A line-by-line annotation now follows.

Convenience Declarations
~~~~~~~~~~~~~~~~~~~~~~~~
Since this is Python, defining variables and symbols to both shorten
typing, capture common concepts or make the code more readable is
encouraged.

.. code-block:: python

      Product = project.Product

*Product* is merely a shorthand used to access the inner classes defined in
the Project class. It avoids having to do an explicit import which
would require either modifying the PYTHONPATH or some other way of
locating it. This keeps the project file free of unnecessary details.

.. code-block:: python

   code_root = project.root

*code_root* is a convenience variable used to locate the source code and
include file paths relative to it. If there were source code or include files
pulled from other directories, additional variables locating those could
be defined.

.. tip::
   There is nothing mandatory or magical about these two definitions. Use or
   omit them in your project file as you see fit.

IncludePaths
~~~~~~~~~~~~~

.. code-block:: python

   include_paths = Product.IncludePaths (root  = code_root,
                                         paths = 'include',
                                         type  = 'rel_path)

..

This defines one or more include paths to search when resolving *#include "file.hh"*.

.. list-table::
   :header-rows: 1

   * - Parameter
     - Meaning
   * - root
     - | The directory path for all *paths* that are not absolute file paths.
       | May be specified as *None* if all the paths are absolute.
   * - paths
     - A single path or a list or tuple of paths.
   * - type
     - | '*rel_path*': Makes the include path relative to the source file including it.
       | or
       | '*abs_path*': Uses the include path as is

.. admonition:: Recommendation
  :class: tip

   Use *rel_path* when the include path is in the same directory tree as the
   source files it will be used with. This keeps absolute file paths out of
   the generated configuration file.

   - Use for all *in package* includes.
   - Use it whenever possible.

   It is the default and can be omitted.

   Use *abs_path* when the source file is not in the same directory tree.

     - An example is including files from an external package.
     - Here using an environment variable to locate the external package
       is reasonable.

The *include_paths* may be a single path, list or tuple of paths.
This would be necessary if, for example, there are multiple include paths
for the project. In general, external include paths could not be added to
this common instance of *paths* if

- They are not absolute paths, they would likely incorrectly use *root*
  as the base directory.
- They may wish to use a different *type* (i.e. *abs_path*, not *rel_path*)

The solution in either of these cases is to define another instance of
*Product.IncludePaths* with appropriate *root* and *type* values.

.. admonition:: CAVEAT
   :class: warning

   While environment variables can be used in specifying the
   include file paths, please see :ref:`A Word of Caution on
   Environment Variables <caution_environment_variables-label>`.


DefineValue
~~~~~~~~~~~

.. code-block:: python

   verbose = Product.DefineValue (name  = 'VERBOSE',
                                  value = 'true')

This simply results in the macro definition, ``#define VERBOSE true``
in the source code. It is made available to the relevant source code
files via the `defines =` parameter in the
:ref:`Product.Sources <product_sources-label>`.

.. list-table::
   :header-rows: 1

   * - Parameter
     - Meaning
   * - name
     - The macro name to represent the value
   * - value
     - The value to be assigned to *name*

.. admonition:: Advanced Topic Lookahead
   :class: tip

    The advanced topic section, see
    :ref:`Product.CtbValues <product_ctb_values-label>`, shows how
    to use a per component logical symbol value, replacing the explicit
    macro name, to leverage *Product.DefineValue* to generate multiple
    components each with a different value of the macro name.

IncludeFile
~~~~~~~~~~~

.. code-block:: python

   opt_file = Product.IncludeFile (name     = 'OPT_FILE'
                                   file     = 'opt/Opt1.hh'
                                   rel_path = include_path)

This forces an include of the file *include_path/opt/Opt1.hh* into the source
file.

- The key point here is that the file name is not explicit in the source
  file, but instead is represented by a macro name in the source file set
  by *Product.IncludeFile*.

.. list-table::
   :header-rows: 1

   * - Parameter
     - Meaning
   * - name
     - The #define macro name used to represent the file
   * - file
     - The file to be included
   * - rel_path
     - The file is located relative to this path

This introduces a ``#define OPT_FILE opt/Opt.hh`` into the *Product.Sources*
by specifying the `defines = opt_file` parameter. It is a variation of
*Product.DefineValue* for including files which has special semantics when
explicitly including a file with a macro name.

   In the source file, the file must be included by

   .. code-block:: c++

      #include IMPORT_FILE(OPT_FILE)

   .. note::

      Unfortunately due to Vitis/HLS inconsistent handling of quoted strings in
      the make file and Vitis utility to drive the cosim, the IMPORT_FILE macro is
      necessary.

.. admonition:: Advanced Topic Lookahead
   :class: tip

   The advanced topic section, see
   :ref:`Product.CtbFiles <product_ctb_files-label>`, shows how to use a per
   component logical symbol file instead of an explicit
   file name to leverage *Product.IncludeFile* to generate multiple components
   with different files.

      A possible usage is to define coherent sets of different optimization
      parameters, data types and even complete methods in separate include
      files. By using wildcards to specify the include files, the configuration
      files/components would be created without modifying the source code nor
      the *Project File*, being driven entirely by the set of include files.

Sources
~~~~~~~

.. _product_sources-label:

.. code-block::  python

   tb_srcs  = Product.Sources (root     = code_root,
                               files    = 'src/example/ExampleTb.cc'.
                               includes = include_paths,
                               defines  = (verbose, opt_file))

   syn_srcs = Product.Sources (root      = code_root,
                               files     = 'src/example/ExampleHls.cc',
                               includes  = include_paths,
                               defines   = opt_file)


These define the test bench and **hls** synthesis files along with any necessary
include paths and macro definitions.

.. list-table::
   :header-rows: 1

   * - Parameter
     - Meaning
   * - root
     - Used as the directory path for all *files* that are not absolute file
       paths
   * - files
     - The single, list or tuple of files
   * - includes
     - The include paths to be used for all *files*
   * - defines
     - | Introduce ``#define`` macro names and/or files that will be
       | included at compile time. These values and/or included files
       | can be *hard-coded*, as in this example, but can come from a
       | list of values or a wild-carded file list, with each value or
       | file generating a new build/component. See
       |
       | :ref:`Product.CtbValues <product_ctb_values-label>` and
       | :ref:`Product.CtbFiles <product_ctb_files-label>`

Multiple instances of *Product.Sources* may be defined if the source files

- Have a different root directory.
- Have a different set of include paths and/or defines.

.. admonition:: Recommendation
   :class: tip

   If a source file has a different set of include paths and/or defines,
   instantiate another instance of *Product.Sources* using the values
   appropriate to those sources.

   The problem of *sponging* off existing definitions is that overly broad
   include paths and irrelevant defines can lead to

   - slowing the compilation down as many search paths are explored
   - finding an incorrect include file
   - unwittingly and incorrectly setting/using a #define macro name

   This is just clean coding. In 90% of the cases, a little time typing can be
   saved, but in 10%, if the wrong file is included or a #define macro name is
   incorrectly used, it can take hours or days to find the root cause. Don't be
   penny-wise, pound-foolish.

Build
~~~~~

.. code-block:: python

    build        = Product.Build (id         = 'example',
                                  top        = 'doit',
                                  tb         = tb_srcs,
                                  syn        = syn_srcs,
                                  csim_argv  = '--ntests=10',
                                  cosim_argv = '--ntests=100'} )

This defines all the ingredients necessary to build the *csim*, *synthesis*, *cosim*,
*etc.*

.. list-table::
   :header-rows: 1

   * - Key
     - Meaning
   * - id
     - Identifier of this build
   * - top
     - Name of the top level HLS method
   * - tb
     - The single, list or tuple of paired test bench file(s) and their include path(s).
   * - syn
     - The same structure as the *testbench* files, except for the HLS/synthesis files.
   * - csim_argv
     - The command line arguments to pass to *csim.exe*
   * - cosim_argv
     - The command line arguments to pass to *cosim.exe*

.. note::

   Even though *'tb'* and *'syn'* can accept a list or tuple,
   they are not specified as plurals on the (debatable) idea that the testbench
   and synthesis are singular entities that *may* be composed of more
   than one thing.  There are not multiple testbenches and hls syntheses.


Fpga
~~~~

.. code-block:: python

       fpgas = (Product.Fpga (id          = '6ns',
                              part        = 'xcku115-flvb2104-2-i',
                              clock       = '6',
                              uncertainty = None)


                Product.Fpga (id          = '5ns',
                              part        = 'xcku115-flvb2104-2-i',
                              clock       = '5',
                              uncertainty =  None))

Defines the target FPGA or FPGAs. Here the simplicity of defining just 1 FPGA
has been abandoned to illustrate how easy it is to generate code targeting
multiple FPGAs.

The following attributes, used when composing logical symbols, are defined.

.. list-table::
   :header-rows: 1

   * - Parameter
     - Meaning
   * - id
     - A string identifying this FPGA
   * - part
     - The Xilinx FPGA part designator
   * - clock
     - The FPGA clock, can include all the usual units like MHz, ns, etc
   * - uncertainty
     - The uncertainty in absolute time units or percentage, None = the
       default 15%)


The *id* needs further explanation. One of the key aspects of
creating a component is that, since all component definitions reside
in the workspace directory, the components must be uniquely named.  The intent
in this example is that the same code is built targeting 2 different
FPGA specifications, resulting in 2 components. The *id* is useful
in uniquely naming the components.

   The *id* can, as can the *part*, *clock* and *fpga_uncertainty*, be
   used as logical symbols to generate a unique component name.  Here the
   *clock* could serve the same purpose since it is different. The
   *id* serves as a convenient user chosen nickname for the FPGA specification.

.. admonition:: Recommendation
   :Class: tip

   Choose a meaningful name for the *id* so it is apparent from the component
   name what it means.  Ids such as 'f0' and 'f1' convey little.



CtbBuilds
~~~~~~~~~

.. code-block:: python

   ctb_builds = Product.CtbBuilds (prefix = 'build',
                                   builds =  build)

Defines a single named build, list or tuple of builds. A build includes
much of the  information needed to generate and identify the *csim.exe*,
*synthesis*, *cosim*, *etc.* products; essentially what goes into the
*MakeFile*.

.. list-table::
   :header-rows: 1

   * - Parameter
     - Meaning
   * - prefix
     - The prefix used when referencing build's identifier, *i.e. *{build.id}*
   * - builds
     - | A single, list or tuple of named builds where each named build
       | consists of an identifier and its *Product.Build* expressed as
       | a 2 element list or tuple.
       |
       | Here *build* is from the previously defined ``build = Product.Build (...)``

CtbFpgas
~~~~~~~~

.. code-block:: python

   ctb_fpgas  = Product.CtbFpgas  (prefix = 'fpga',
                                   fpgas  =  fpgas)

Defines a single FPGA, list or tuple of FPGAs to target.

.. list-table::
   :header-rows: 1

   * - Parameter
     - Meaning
   * - prefix
     - The prefix used when referencing the attributes of the FPGA
   * - fpgas
     - A single Product.Fpgas, list or tuple of *Product.Fpgas*


Contributors
~~~~~~~~~~~~

.. code-block:: python

   contributors = Product.Contributors (builds = ctb_builds,
                                        fpgas  = ctb_fpgas)

This collects all the contributors to eventually be used in defining a
*component*.

.. list-table::
   :header-rows: 1

   * - Parameter
     - Meaning
   * - builds
     - a single, list or tuple of *Product.CtbBuilds*
   * - fpgas
     - a single, list or tuple of *Product.CtbFpgas*

A component is composed of a number of contributors. The minimum component
must include at least one *Product.CtbBuilds* and one *Product.CtbFpgas* contributor.

   There are two other :ref:`contributors <additional_contributors-label>`,
   not included in this simple example.  See the examples labeled *ex3*, *ex4*
   and *ex5* in the
   `hlsBs-examples <https://github.com/slaclab/hlsBs-examples>`_  repository.


The first element must be an instance of *Product.CtbBuilds* and the second an
instance of *Product.CtbFpgas*.

   More contributors can be added as additional parameters after the 2 mandatory
   *Product.CtbBuilds* and *Product.CtbFpgas*. These may include
   :ref:`additional contributors <additional_contributors-label>`, as well as
   *Product.CtbBuilds* or *Product.CtbFpgas*.



To aid in composing unique names for the configuration file paths and
components, attributes of the build and FPGAs can be accessed using
*build* and *fpga* prefix strings that appear in the above specification.
Think of it as the *prefix* of an instantiated class in Python or C++ with
the attributes as its field members.

In this example logical symbols with the following attributes are constructed.

.. list-table:: Builds
   :header-rows: 1

   * - Prefix
     - Attribute
     - Logical Symbol
     - Value
   * - build
     - id
     - build.id
     - 'example'

.. list-table:: Fpgas
   :header-rows: 1

   * - Prefix
     - Attribute
     - Logical Symbol
     - Fpga 0 Value
     - Fpga 1 Value
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

   The prefixes *'build'* and *'fpga'*, while meaningful, are user chosen.
   In more complex builds, these prefixes may need to be different to avoid
   name clashes.

   To be safe, limit prefixes to characters used to form legitimate Python variables.

.. admonition:: Caveat
   :class: warning

   All prefixes must be unique. This may be relaxed if necessary.


CfgTemplate
~~~~~~~~~~~

.. code-block:: python

       cfg_template = Product.CfgTemplate (prefix   = 'cfg',
                                           template = '{build.id}-{fpga.id}')

This defines a template of how to name the full path of the configuration file.

.. list-table::
   :header-rows: 1

   * - Parameter
     - Meaning
   * - prefix
     - The prefix to be used when accessing the attributes
   * - template
     - The configuration template

Here the configuration file's name is composed of *build.id* and *fpga.id*.

- If the template is not an absolute file path, the *product.cfg_root* is used
  as the directory.
- If no file extension has been provided, *.cfg* is used.

.. admonition:: Recommendation

   Use logical symbols to generate the configuration file name, even in a simple
   HLS project consisting of a single component. This accommodates future changes.

   If needed:

   - Both the directory and the extension can be specified in the template
     definition.

   - Any arbitrary text may be added to the template, *i.e.*
     ``Bld_{build.id}-Fpga_{fpga.id}`` to add meaning or increase clarity.


Configuration file attributes and their logical symbols are as follows.
These are useful in naming other products such as the component and the ip products.
In this example ``<prefix> = cfg``

.. list-table::
   :header-rows: 1

   * - Prefix
     - Attribute
     - Logical Symbol
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

- A common usage of the configuration file name is to name the component,
  see :ref:`CmpTemplate <component_name-label>`.

..

- If the configuration file name is not unique, only a logical symbol for the
  first subdirectory is provided

  - If this is insufficient to make the component name unique, some other method must
    be used.

.. _component_name-label:

CmpTemplate
~~~~~~~~~~~

.. code-block:: python

       cmp_template = Product.CmpTemplate (prefix   = 'cmp',
                                           template = '{cfg.name}')

This defines a template of how to name the component.

.. list-table::
   :header-rows: 1

   * - Parameter
     - Meaning
   * - prefix
     - The prefix to be used when accessing the attributes
   * - template
     - The component template

In this example the component name is the configuration file's name, *i.e.* *cfg.name*

In general, naming the component after the configuration file name is
the most straightforward naming.  As always, there may be instances
where the freedom to name it otherwise is useful.

A few differences from the configuration file template are to be noted here:

- There is no directory or file extension

  - The component *is always* a subdirectory of the workspace.

..

- Since all components are first level subdirectories of the workspace, the
  component name must be unique.

  - Contrast this with the configuration file where only the configuration *path* name,
    not the configuration *file* name, needs to be unique.

.. note::

   The configuration file could just as easily have been named after the component.
   Naming the component after the configuration file was just a matter of
   choice in this example. Choose whichever works best.


Components
~~~~~~~~~~

.. code-block:: python

   components  = Product.Components (contributors = contributors,
                                     cfg_template = cfg_template,
                                     cmp_template = cmp_template)

This defines a fully specified component. A *component* is the identifying
unit of an HLS product.

.. list-table::
   :header-rows: 1

   * - Parameter
     - Meaning
   * - contributors
     - A single, list or tuple of *Product.Contributors*
   * - cfg_template
     - The template used to generate the configuration file name
   * - cmp_template
     - The template used to generate the component name

In this example, 2 configuration files along with their 2 components are
generated:

.. list-table::
   :header-rows: 1

   * - Configuration File
     - Component
   * - <project.cfg_root>/example-5ns.cfg
     - <project.workspace>/example-5ns
   * - <project.cfg_root>/example-6ns.cfg
     - <project.workspace>/example-6ns


Package.Ip
~~~~~~~~~~

.. code-block:: python

   package_ip = Product.Package.Ip (name     = '{cfg.name}',
                                    vendor   = 'SLAC',
                                    version  = '1.0.0',
                                    library  = 'hls')

This is packaging identification.

.. list-table::
   :header-rows: 1

   * - Parameter
     - Meaning
   * - name
     - The name to give the package. This need not be unique
   * - vendor
     - An arbitrary string identifying the producing entity.
   * - version
     - A version number
   * - library
     - Almost always 'hls'


Two noteworthy things:

- *name* has been chosen to be the configuration name.

   - It could have been the component name or any name composed of absolute
     text and logical symbols. *{git.repo}* from the
     :ref:`git <git_logical_symbols-label>` logical symbols would be another
     reasonable choice.

..

- Another reasonable choice for the *version* would have been to use one of
  the :ref:`git <git_logical_symbols-label>` logical symbols:

  - *git.tag*
  - *git.branch*
  - *git.hash_short*
  - *git.hash_long*
  - *git.hash_msg*

.. warning::

   Only the branch is guaranteed to be immediately available. The others,
   *git.tag*, *git.hash_short* and *git.hash_long* and *git.hash_msg* are
   only valid after a *git* commit. These will come up as *None* or *Dirty*
   if the current code has not been committed.

   For testing, since one can know the *git tag* prior to formally defining it
   to *git*, one option is to specify the version on the command line. Of
   course this *pre-commit* option is not possible for the *git* hashes.


Package.Output
~~~~~~~~~~~~~~
This is the standard output packaging.

.. code-block:: python

       package_output = Product.Package.Output (format = 'ip_catalog',
                                                syn    = 'false')

These are almost always the values shown, but are provided for completeness.

.. list-table::
   :header-rows: 1

   * - Parameter
     - Meaning
   * - format
     - Almost always 'ip_catalog'
   * - syn
     - Almost always 'false'

Package
~~~~~~~

.. code-block:: python

   package = Product.Package (ip      = package_ip,
                              output  = package_output)

Simply combines *Product.Package.Ip* and *Product.Package.Output* into a single
class.

 .. list-table::
    :header-rows: 1

    * - Parameter
      - Meaning
    * - ip
      - The instantiation of *Product.Package.Ip*
    * - output
      - The instantiation of *Product.Package.Output*


Vivado
~~~~~~

.. code-block:: python

       vivado  = Product.Vivado  (flow ='syn',  syn_dcp = '1')

These are almost always the values shown, but are provided for completeness.

.. list-table::
   :header-rows: 1

   * - Parameter
     - Meaning
   * - flow
     - Almost always 'syn'
   * - syn_dcp
     - Almost always '1'

.. admonition:: Recommendation
   :class: tip

   Even though **flow** has been deprecated as of 2026.1, specifying it
   keeps the configuration file compatible with previous versions.


Product
~~~~~~~
This returns the defined product.  This may also return a list or tuple of
products.

.. code-block:: python

       return Product (project    = project,
                       components = components,
                       package    = package,
                       vivado     = vivado)

.. list-table::
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
     - The Vivado information



IP Products
===========

These are optional modified Vitis products produced by **hlsBs**.  They
have proven to be useful in overcoming limitations of the Vitis products
they are derived from.


There are 2 such products:

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


.. _get_ip-label:

Annotated get_ip
----------------

.. code-block:: python

   # ------------------------------------------------------------------------------
   def get_ip (project) :
       ip = project.Ip (

           # -------------------------------------------------------
           # Placing the .dcp and .ip in the product_root/ directory
           # will generally mean these files are committed to git.
           # Given that these files are likely very dependent to the
           # Vitis version that produced them, including the Vitis
           # version is sensible.
           # -------------------------------------------------------
           dir      =  os.path.join (project.products_root,
                                     'ip', '{vitis.version}'),
           zip_file = '{cmp_name}',
           family   = ('artix7,kintex7,virtex7,zynq,kintexu,virtexu,kintexuplus,'
                       'virtexuplus,virtexuplusHBM,zynqplus,zynquplusRFSOC,versal'),

           # ----------------------------------------------------------------
           # These are the defaults and can be omitted or set to None
           # ----------------------------------------------------------------
           dcp_rename = '{cmp_name}',
           dcp_file   = '{dcp_rename}',

           # --------------------------------------------------------
           # Place the journal and log files, two files that have only
           # marginal interest, in the project.build/ip/dgn directory
           # The <project.build>/ip directory is the default stem.
           # By placing them in the build directory, they will
           # not (if the .build directory is set in '.gitignore')
           # be committed to git..
           # -----------------------------------------------------
           dgn_dir    = 'dgn/',
           jou_file   = '{dcp_name}',
           log_file   = '{dcp_name}'
       )

       return ip
   # ------------------------------------------------------------------------------

The values shown are all the defaults and can be specified by setting the
parameter value to *None*. To accept *all* the defaults, either

- Omit the definition of *get_ip* altogether
- Return *None*

.. admonition:: Recommendation
   :class: tip

   Unless there is a good reason, use the defaults, except for possibly the *family*.
   Here it might be wise to trim the *family* to only the required and permissible set.

.. note::
   The default ip directory is in the *products/* directory. Without
   a special entry in *.gitignore*. the *.dcp* and *.zip* file will be committed
   to *git*.  This is usually the desired behavior. Since these files can be
   large, add the following to the *.gitattributes* file.

   .. code-block:: text

     *.dcp filter=lfs diff=lfs merge=lfs -text
     *.zip filter=lfs diff=lfs merge=lfs -text

.. list-table::
   :header-rows: 1

   * - Attribute
     - Meaning
   * - dir
     - The common ip output directory for the *.dcp* and *.zip* files
   * - zip_file
     - The name of the new zip file with the modified FPGA families
   * - family
     - A comma separated list of the augmented FPGA families
   * - dcp_rename
     - The new embedded name
   * - dcp_file
     - The name of the modified dcp file
   * - dgn_dir
     - The common directory where the Vivado journal and log file are written
   * - jou_file
     - The name of the dcp journal file
   * - log_file
     - The name of the dcp log file

By default, these output files are collected in the *ip/* subdirectory
of the *products/* directory.  As usual, these may be placed anywhere
by suitably defining the appropriate file paths. Typically the various
file path specifications are defined as only the file name, but these
can be complete file paths or any subset of the directory path, the
file name and the file extension. Any missing pieces will be filled in.

All the values are sensibly defaulted, except for the *'family'*.
While it does have a default value, it may not be what is wanted.

.. admonition:: Recommendation
   :class: tip

   If the defaults are acceptable, rather than omitting them, set the values to
   *None*. This will serve as a reminder that they can be altered.


.. note::
   **hlsRun** was advertised to be able to execute needing only
   the workspace, no project file necessary. However the generation of
   the IP products may need additional information not present in
   components if the defaults are not acceptable.

   These parameters may be provided directly on the command line. A better
   approach is to include these in an indirect *@FILE*. This avoids typing an
   involved command line and the inevitable typos.

   While the specification of the renaming can be sensibly defaulted, defaulting
   the list of FPGA families is problematic. A viable solution is being explored.


Global Logical Symbols
======================
In addition to component specific logical symbols there are two global logical
symbols.

- :ref:`Vitis Version <vitis_version-label>`
- :ref:`Git <git_logical_symbols-label>`


.. _vitis_version-label:

Vitis Version
-------------
This logical symbol has already been encountered. It is referenced as

.. list-table::
   :header-rows: 1

   * - Prefix
     - Attribute
     - Logical Symbol
     - Meaning
   * - vitis
     - version
     - vitis.version
     - The active Vitis version


.. _git_logical_symbols-label:

Git
---
This set of logical symbols gives information about the *git* repository. It
can be used anywhere, but its most common usage will likely be in setting
project versions.

.. list-table::
   :header-rows: 1

   * - Prefix
     - Attribute
     - Logical Symbol
     - Meaning
   * - git
     - repo
     - git.repo
     - Name of Git repository
   * -
     - tag
     - git.tag
     - The Git tag
   * -
     - dirty
     - git.dirty
     - 'True'/'False'
   * -
     - branch
     - git.branch
     - The current Git branch
   * -
     - hash_long
     - git.hash_long
     - The long form of the hash code
   * -
     - hash_short
     - git.hash_short
     - The short form of the hash code
   * -
     - hash_msg
     - git.hash_msg
     - | If not dirty, the long hash code
       | If dirty, "Dirty"


Advanced Usage
==============
The above covers the basics, but with usage, common repeating patterns occur.
While the following could all be done with what has been given, formalizing these
makes usage easier and more robust.

The patterns are

- Additional Product contributors
- Deferring Environment Variables translation

  - This is relevant only for run-time values such as file specifications
    in *csim_argv* and *cosim_argv*.

In order to maintain full capability with the IDE/GUI, support within both the
configuration file generation and the C++ runtime is needed, so these require
more work on the user's part.  Hopefully the gains justify what amounts to
a one-time investment of fairly simple code.

.. _additional_contributors-label:

Additional Component Contributors
---------------------------------
There are 2 other contributor classes not illustrated in this simple
example. These leverage the C++ preprocessor to add information at
compile-time. Their big advantage is they can generate
additional components without modifying either the project file or the
source code. In an imperfect analogy, they act as traditional plug-ins,
extending the functionality with minimal impact.

These two contributors are:

- *Product.CtbValues*  - adds the value of a #define macro to the source code

  - See *ex4* in `hlsBs-examples <https://github.com/slaclab/hlsBs-examples>`_
- *Product.CtbFiles*   - forces a named include file into the source code

  - See *ex3* in `hlsBs-examples <https://github.com/slaclab/hlsBs-examples>`_

Also note that these can be used in the instantiation of *Product.Contributors*

- Multiple times with different definitions
- Together or separately

Just add them to the list of parameters after the *Product.CtbBuilds* and
*Product.CtbFpgas*.

Since the total number of components generated is the product of all the
contributions, the number of components can get very large, very quickly.
Consider a *Product.Components* definition with

- A *CtbBuilds* specifying 2 distinct builds
- A *CtbFpgas* containing 3 target FPGAs
- A *CtbValues* with a list of 4 values
- A *CtbFiles* with 5 files

The number of generated components will be 2 * 3 * 4 * 5 = 120. This may
take awhile to build all the output products. However, it is this ability
to easily generate many components that enables experimentation and testing
of a large number of variations of a package.


.. _product_ctb_values-label:

Product.CtbValues
~~~~~~~~~~~~~~~~~

Motivation
^^^^^^^^^^
The simple example produced a component with a ``#define VERBOSE true``.
An obvious extension is to produce two components, one with
*VERBOSE true*, the other with *VERBOSE false*.

*Product.CtbValues* instantiates a single or list or tuple of bound
*(id,value)* pairs as created by Product.Value*, each producing a
component.


How
^^^
This uses 2 Python classes

- *Product.Value*     - creates a value with an identifier

  .. code-block:: python

     values     = Product.Value (id    = '<ID>',
                                 value = '<VALUE>')

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

1.  Instantiate a single, list or tuple of *Product.Value*'s

    .. code-block:: python

         quiet   = Product.Value (id = 'Quiet',   value = 'false')
         verbose = Product.Value (id = 'Verbose', value =  'true')
         level   = (quiet, verbose)

    Where:

    .. list-table:
       :header-rows: 1

       * - Parameter
         - Meaning
       * - id
         - A string identifying this value,
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
    be used in very simple cases.


2.  Instantiate the value contributors using the previously
    created *Product.Value*'s

    .. code-block:: python
                   
       values  = Product.CtbValues (prefix = 'verbosity',
                                    values =       level)

    Where:

      .. list-table::
         :header-rows: 1

         * - Parameter
           - Meaning
         * - prefix
           - The prefix used in referencing the 2 attributes, ``id`` & ``value``
         * - values
           - A single, list or tuple of *Product.Value*'s

    For this example, the following are defined:

    .. list-table::
       :header-rows: 1

       * - Prefix
         - Attribute
         - Logical Symbol
         - Value0
         - Value1
       * - verbosity
         - id
         - verbosity.id
         - Quiet
         - Verbose
       * -
         - value
         - verbosity.value
         - false
         - true

..

3.  As in the original project file example

   - Instantiate a  *Product.DefineValue* to be used in *Product.SourceFiles*


   .. code-block:: python

      verbose       = Product.DefineValue  (name  = 'VERBOSE',
                                            value = '{verbosity.value}')
   
   - Modify the cfg_template
     
    .. code-block:: python                                  
       cfg_template = Product.CfgTemplate (prefix   = 'cfg'
                                           template = '{build.id}-{verbosity.id}-{fpga.id}')

   Note the only difference is the use of logical symbols

   - ``{verbosity.value}`` instead of the explicit 'true' in *Product.DefineValue*
   - ``{verbosity.id}`` in *Product.CfgTemplate* to uniquely name the
     configuration file

4. In the C++ code, make use of the *#define*

   .. code-block:: c++

      static constexpr auto Verbose = VERBOSE;

   Each value in the list of values generates a new component.  Here one
   component will be generated with ``Verbose = true`` and another with
   ``Verbose = false``.

      Here the list of *Product.Values* (ids, values) is  hard-coded into the
      project file.  A useful technique may be to read these from a file. This
      allows new values, and hence new components, to be added simply by
      editing a file containing the list of *(id, value)* pairs.

..

   .. admonition:: Recommendation
      :class: tip

      The use of *Product.CtbValues* should be limited to simple applications,
      *e.g.* specifying a different numeric value for the *REUSE* pragma
      parameter.  This is in keeping with *#defines* limitations

        - lack of name space protection, they are effectively globals
        - no type checking, completely against the concept of a statically
          typed language such as C++.
        - very fragile rules on using quotes and parentheses

      For more involved cases, such as

      - steering the code, this would involve littering the source code with
        many #ifdef's.
      - redefining many data types as a coherent set.
      - the extreme case of defining completely different implementations of
        a C++ function to explore which gives the best results.

      consider using :ref:`Product.CtbFiles <product_ctb_files-label>`.

   .. warning::

      Due to AMD/XILINX/HLS's inconsistent handling of quoted strings and other
      characters deemed *special*  by the shell, when defining a string as a
      macro value, the string must be *requoted* in the C++ code, *e.g.* as
      follows

      .. code-block:: C++

         static const char BuildName[] = HLSHELPER_QUOTE(BUILD_STRING)

      It is suggested to use :ref:`Product.CtbFiles <product_ctb_files-label>`
      capturing such strings in an include file.  It is cleaner and more
      extensible.

.. _product_ctb_files-label:

Product.CtbFiles
~~~~~~~~~~~~~~~~
This contributor allows one to include a file, named not in the source code,
but in the project file at compile-time.

   There is a lot of verbiage that follows, but except for defining the
   *Product.CtbFiles* contributor, it is just a novel use of previously
   introduced concepts, strongly paralleling
   :ref:`Product.CtbValues <product_ctb_values-label>` usage.

Example
^^^^^^^
While the file or files can be named explicitly, a useful technique is to
include them by wild-carding them from a specific directory or directories.

Suppose there is a directory, *opt/*, which includes a family of files with
different optimization strategies. For example, they may include different
pragma values or data types. A component for each of these files can be
generated by the following

1. Defining the files as a wild-card specification:

.. code-block:: python

   ctb_files = Product.CtbFiles (prefix = 'opt',
                                 files  = os.path.join (code_root, 'opt', '*.hh')


The following logical symbols are made available

.. list-table::
   :header-rows: 1

   * - Prefix
     - Attribute
     - Logical Symbol
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
  name, *i.e.* ``{<prefix>.path>}``. It is the value of the defined macro name.

2. Adding *ctb_files* to the *Product.Contributors* class after the
   *Product.CtbBuilds* and *CtbFpgas* contributors.

.. code-block:: python

   contributors = Product.Contributors (ctb_builds,
                                        ctb_fpgas,
                                        ctb_files)
..


3. Instantiating *Product.IncludeFile*

.. code-block:: python

   opt_file  = Product.IncludeFile (name     = "MY_OPT",     # Name of #define
                                    file     = '{opt.path}', # File to include
                                                             # (from attribute table below)
                                    rel_path = include_path) # Reference by a relative path

Note that the only difference in *Product.IncludeFile* from the example project
file is the logical symbol *{opt.path}* instead of an explicit file name.

4. Just as in the original *Product.Sources*, include this in the ``defines =``
   parameter list

.. code-block:: python

   syn_srcs = Product.Sources (root      = code_root,
                               files     = 'src/example/ExampleHls.cc',
                               includes  = include_paths,
                               defines   = opt_file)

..

5. In the C++ code

.. code-block:: c++

       #include IMPORT_FILE(MY_OPT)

Each file satisfying the wildcard generates a new component.


   SNL uses this to great advantage. All SNL networks use the same testbench
   and HLS synthesis code with only the network definition changing. SNL
   network definitions are entered into a user provided directory. The ``files``
   parameter of *Project.CtbFiles* is then specified as a wildcard, *e.g.*
   *<network>/\*.hh*.

   The project file then generates a component for each network specification.
   The code is thus customized without touching the actual text of the code.
   One can add a new network simply by adding it to the network directory.

.. _indirect_files-label:

Indirect Files
--------------

Python's *argparse* has a nice feature that any number of command line
arguments can be included in a named file which is referenced as *@FILE* on
the command line. The format of this file is very simple, one command line
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

.. admonition:: observation
   :class: tip

   Indirect files offer a number of advantages over adding parameters
   directly on the **hlsExe/hlsGdb** commands.

   - Coherency

     - a number of related options can be grouped in a file

   - Naming

     - a file can have a name reflecting its purpose

   - Lifetime

     - a file can exist over login sessions

   - Versatility

     - including an indirect file specified as an environment
       variable in *csim_argv* or *cosim_argv* allows parameters
       to be modified when the command is executed:

     .. code-block:: shell

        $ hlsRun --csim=r
        $ hlsRun --cosim

     or with the HLS GUI.

.. note::

   For *cosim*, this is the only flexible alternative. As opposed
   to *csim*, there is no equivalent of *hlsExe/hlsGdb* for *cosim* where
   command line parameters can be added.

Usage
~~~~~
Since C++ has no native support for this feature, hlsBs provides it. In the
test bench code, add the following:

.. code-block:: c++

   // Make the utility available
   #include "hlsHelpers::ExpandArgs.hh"

and

.. code-block:: c++

   // Create and use the expanded set of command line arguments
   hlsHelpers::ExpandArgs cl (argc, argv);
   getopt (cl.m_argc, cl.m_argv);

Suggestion
~~~~~~~~~~
As a workaround to having no include facility, a suggestion is to define
the multiple files as a colon separated list and, to make it easy to
reference, use an environment variable:

.. code-block:: bash

   $ export MyMods=File1.txt:File2.txt:File3.txt
   .
   .
   $ hlsExe <component> @$MyMods

.. warning::

   This is generally available only if **hlsCfg** was used to create the
   configuration file.  **hlsCfg** makes the include file as part of
   creating the configuration file.

   If the configuration file is not created by **hlsCfg**, either

   - Do not use this feature

     - This is the recommended action

   - Copy the *hlsHelpers::ExpandArgs.hh include file into your project and
     add any necessary *-I include_path* to it in the configuration file.

     - The file is in *<path_to>/ruckus/vitis/hlsBs/include*
     - This is not recommended, too fragile.

Deferred Environment Variable Translation
-----------------------------------------
A common desire is to defer translation of environment variables until
runtime. Practically speaking, this applies to the strings in the *csim_argv*
and *cosim_argv* values.

   For example, referring to various test data files either
   by an environment variable or using an environment variable to specify just
   the root directory.  Other usages may be to refer to the number of tests to
   run with an environment variable.

However, using environment variables in the utilities that compose and use
the configuration files is problematic at best. As a workaround **hlsBs**
provides 2 classes to encode the environment variables, one for
variables and one for files.

.. code-block:: python

   # Encode a bare string as an environment variable
   var  = Product.EnvString.convert ("NTESTS")

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
     The first 2 will translate any environment variables during the
     creation of the configuration file.  They are mentioned here because
     this set of 3 methods provides all the choices of how to present
     the file paths in the configuration file.

   - Absolute file paths should be avoided if possible. They make the
     configuration file less modular, but there are cases where this
     is appropriate.

   - Relative file paths are equally dicey.  In their simplest form,
     the executable would have to be run from a particular directory. A
     more modular approach would be to modify the directory when
     processing the file name in, say, getopts.

   - Preserving the environment variables offers the most flexibility.
     For example, all test files could be in various data directories
     which could be located at runtime with *${DATA}*.


Usage
~~~~~
Since the shell cannot translate these modified environment variables,
a C++ utility has been provided.

.. code-block:: c++

   #include "hlsHelpers/ExpandEnvs.hh"

   // This contains the method
   // std::string hlsHelpers::expand_envs (std::string string)

   // Example:
   // Translate an environment variable in my_string
   tvar = hlsHelpers::expand_envs (my_string)


.. warning:

   Presuming all the environment variables have been defined, the
   resulting csim.exe and cosim.exe both will execute using

   .. code-block:: shell
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
   flexibility was a motivating goal for **hlsBs**.

.. warning::

   This is generally available only if **hlsCfg** was used to create the
   configuration file.  **hlsCfg** makes the include file as part of
   creating the configuration file.

   If the configuration file is not created by **hlsCfg**, either

   - Do not use this feature

     - This is the recommended action

   - Copy the include file into your project and add the -I include path to it
     in the configuration file.

     - The file is in *ruckus/vitis/hlsBs/include*
     - This is not recommended, too fragile.


.. _caution_environment_variables-label:

A Word of Caution on Environment Variables
==========================================
Values in the project file, *e.g.* file paths, may include environment
variables, but because HLS configuration files do not allow environment
variables, except *almost* in *csim_argv* and *cosim_argv* strings,
environment variables must be translated when the configuration file is
created.

Since the testbench, hls/synthesis and include file paths are
generally reinterpreted as relative to the configuration file, this is
not a problem. However, for 'csim_argv' and 'cosim_argv', the choice
to defer the translation to runtime is desirable and that method has been
described.  But there are dangers.

    Consider the case when the configuration file is built and the
    environment variables were not defined.  For file and include paths,
    the build will fail and certainly be noticed.  **hlsBs** does try
    to verify the existence of files used in the build of the code and
    issue an appropriate message. So, annoying, but tolerable.

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
    might mysteriously fail or produce unexpected results.

       This is not a theoretical problem. It cost the author a couple of days
       to learn this. Because of this, **hlsBs** is very careful in its
       handling of environmental variables.

    Using the **hlsBs** commands does have the advantage that commands inherit
    the context of the shell they are launched from, so it is more immediate.
    There is not the lingering context of the IDE/GUI.



GIT: To Commit or Not To Commit, That is the Question
=====================================================
This is a personal preference, but do be sure to think about which
products should be committed to GIT, else some very large files and
other unintended files could be committed to your GIT repository.

- Preclude files not to be committed using *.gitignore*
- Set *lfs* attribute for large files that are intended to be committed.

**RECOMMENDATIONS**:

- Add the workspace directory to the .gitignore.

  - The ambitious may wish to explore saving all but the hls/ and logs/
    directories.
  - This would preserve the component definition, saving recreating it
    on checkout and the reports, which may be used for tracking purposes.

- Whether to commit the configuration directory and files to the git repository
  is a user choice.

  - The configuration files are constructed, whenever possible, to have
    all relative paths, so it may be convenient to commit them.

    - If your project references files not in the project root
      subdirectory, the configuration file may contain absolute paths
      making them potentially ineligible to be stored in git. If in doubt,
      look at the configuration files.

  - If they are committed, their corresponding components, which are
    stored in the workspace, are generally not free of the absolute paths
    where they were constructed. Here, the components must be recreated on
    checkout using **hlsComp**. This diminishes the usefulness of committing
    the configuration files if they can easily be recreated by **hlsCfg**.

    - Since only the basic options to compose a configuration file
      are supported by **hlsCfg**, it may be that they have been hand
      tailored to add unsupported options.
    - In this case, committing the configuration file is highly
      recommended to preserve these additions.

- Commit the *ip* directory and its contents to git, due to the time involved
  in creating the contents. These are large files, so use the *lfs* attribute.


Finally - Input/Feedback Wanted
-------------------------------
Improvements

- Expand the number of parameters available on the command line.

  - In developing HLS code, the ability to do ad hoc experimentation and
    then capture and catalog the useful ones is invaluable. Being able
    to experiment on the command line goes a long way in realizing this.
  - Doing all parameters was too large a job to do all at once. Getting
    the basics was hard enough.

  - If there is interest, a 'hook' routine could be invented to add
    necessary, but unsupported options.

    - The hard piece is defining a user API. Just what information is
      needed?
    - This gets complicated since many *unsupported* options are
      Vitis version dependent.

- There may be better ways to capture the common defaults

    - A common problem of defaulting is that the full functionality
      is hidden.
    - Want a solution that says 'here are the usual defaults, but if
      more is needed, it is here'.

While a lot of thought went into this, some things only come with actual
usage, *i.e.* this single author was limited by imagination and time.
