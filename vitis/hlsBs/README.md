# hslBs -- A HLS Build System

Welcome to that indispenable thing called documentation. Demanded by many, written by one, destined to be read by few.  Being honest, the build system is not high on anyone's interest list. This is a reference manual, *i.e.*, where only the truly lost and hopelessly confused desparately seeking answers come, the land of last resort.

In the **hlsBs-examples** repository is a *How-To* user's manual. For many, this is all that is needed. If the project is beyond the basics, then this more complete manual may be of interest.  The test suite for the SNL framework, which has 20+ components each of whose performance, resource usage and integrity must be tracked across multiple Vitis releases  is an example of a such a project.  The SNL framework, where experimentation and trail and error are part and parcel of its development also demands a more capable buitd system.

The author is decidely not a UI expert. This design is the product of actually producing HLS code and the frustrations and limitations of building it. Whether **hlsBs**  actually achieves making this simpler and more flexible remains to be seen. All that can be said is the effort was there.

**RECOMMENDATION:** Skim this, look at the section titles, then first level of bullet its, take a look at hlsBs-Examples, test drive it, then come back and read more thoroughly.  Reference manuals are just a blizzard of words without hands-on experience to connect them. It is a feedback process, not a core-dump.

HLS development is not easy. Hopefully **hlsBs** helps in developing your own personal disciplined workflow.

### Limitation
Since **hlsBs** depends on the more recent unified development framework, only Vitis Versions 2023.2 or greater are supported. As a heads-up, 2023.2 being the first version to support the unified development environment, has some *pecularities*.  **hlsBs** has a number of workarounds, but as with all workarounds, there are pitfalls.

**RECOMMENDATION:** Use versions 2024.1 or greater unless for other reasons 2023.2 must be used.

# Goals
**hlsBs** is a command line driven system designed to simplify the HLS/Vitis build process, particularly for projects involving multiple components.  The utility of multiple components falls into 2 categories
- Projects composed of 2 or more distinct HLS components or variations.
	- Components may run on physically different FPGAs with one feeding the other in a daisy-chain fashion.
	- The same project needs to run on mutliple FPGA parts.
- The same component but with different algorithms or pragma parameters to explore the performance/resource tradeoffs.

It is the second category where, admittedly, there is some social engineering on the author's part. The goal was, by making it easy to create, build, compare and catalog mulitple components, to encourage experimentation and exploration.  The cruel school of experience in developing HLS code has shown this step is necessary to achieve the best results.  The correct algorithm and pragma settings are never immediately apparent.

A truly useful feature of the Vitis IDE/GUI is the ability to compare components. **hlsBs** tries to facilitate this by providing methods to capture and organize development evolution. A common theme is realizing some aspect of the resource/preformance tradeoffs has been overlooked during development and now is far from where it was 2 days ago. By capturing the steps along the way, there is a chance to isolate the offending random code/pragma change.


### Primary Goals
- Make simple projects simple and more complex projects possible.
- Be compatible with the HLS GUI/IDE build and development system.
	- One can mix and match, using whichever one is appropriate and comfortable with for the task at hand.
- Accommodate building the same project using multiple VITIS versions.
	- This encourages both moving forward with new versions and comparing their differences.
- Handling the drudery of creating the configuration files and components.
	- This is reduced to almost a 'fill-in-the-blanks' exercise.
	- Biggest advantages is when producing multiple, very similar components.
- Easily run all or any collection of the various build stages (csim, synthesis, cosim, etc)


### Secondary, less user-facing goals
Paraphasing the great Joni Mitchell, "*you don't what you need till its not there*".
- Design the commands to be intuitive and follow the principle of *least surprise*.
- Commands do not depend on the current working directory.
	- They can be executed from any directory.
	- Recalled commands work the same whether the current working directory has been changed or not.
	- Well, almost. See *A Word Of Caution* section for, well, a word of caution.
	- If one keeps cd'ing, you find your directories, like city streets with pigeons, littered with random and, at times, very large Vitis file droppings.
- Keep the utilities as policy free as possible.
	- For example, no particular directory structure or naming conventions are imposed.
	- Still provide sensible defaults which can be easily modified to suit the user's personal perferences and/or the specific projects's needs.
- Appropriately partition the needed information by where it is kept, when it is used and its lifetime.
	- Static information, such as the workspace and configuration file descriptions.
		- These are keep in the project file (described later)
	- Quasi-static information, such as experimenting with parameters that affect performance/resource trade-offs.
		- These are kept in named files which can contain 1 or more command line parameters
		- They are referenced on the command line as **@FILE**; a nice featur of Python's argparse methods.
		- A usage might be to define alternate test sets in a family of such files and selecting which one to use at run-time.
	- Run time parameters, such changing the input test data or the number of tests to run.
		- A useful technique is to experiment on the command line and if a particular set of parameters is interesting, saving them in them in an appropriately named quasi-static file which can be referenced when needed.
	- This is achieved by establishing a priority ordering with run time parameters overriding quasi-static parameters and quasi-static parameters overriding static parameters.
    - Currently not all parameters can be overriden. Experience will help guide expansion.
- Make the commands consistent, short and unique with the goals of minimizing remembering details, limiting typing and avoiding name clashes.
- Make the commands as efficient/fast as possible
	- Mainly this involves only using, deferring or avoiding the use of the underlying Vitis utilities until absolutely necessary.
	- An example is making and cleaning the csim.exe. After the initial build by Vitis to create the make file, **hlsBs** just uses that make file, bypassing the overhead of going through Vitis.
		- For the SNL test suite, cleaning and rebuilding the 28 components using **hlsBs** takes about a 1.5 minutes versus 11 minutes going through Vitis.
	- Even for steps where the overhead is small compared to the execution time such as synthesis, **hlsBs** sometimes can detect errors before invoking the Vitis utility, saving the Vitis startup time.
- Provide query commands, such as listing the components and configuration files.
	- Given the power of these commands, without fail unknown *stuff* (in **hlsBs** parlance, this is known as **cruft**) creeps in.
- Similar command structure
	- The most commonly used commands uniformily targetting component(s) by name and catagory.
	- Compoment names may be an explicit name, a wildcarded name, or a list of any combination.
	- Components are classified into the following categories
		- Existing
		- Missing
		- Cruft
	- Commands, by default, target the most logical component category and names. As a concrete example, the default targets for the configuration file and components management actions are

> | Action | Catagory | Target Name  |
> | :----- | :------- | :----------  |
> | clean  | existing | None, since this is destructive, demand an explicit target|
> | list   | all      | All          |
> | create | missing  | All          |
> | replace| existing | All          |

## The Basics
There are two distinct pieces to the build system
- A piece concerning the workspace and creation of the configuration files and the components that populate the workspace.
- The set of **hlsBs** commands.


Loosely speaking, the former defines the set of configuration files and components and their contents, while the latter, with some obvious exceptions, uses the generated components to produce the output products, *i.e.* **csim**, **synthesis**, **cosim** *etc*.

In keeping with the goal of being able to mix techniques, it is permissable for the configuration files, the workspace and components to be generated by some other means. The most common example of this would be legacy projects. However, not using **hlsBs** to generate these products will limit some of its most useful features.

The first piece is by far the most complicated and, as noted, may be ignored if the workspace, configuration files and components already exist. The second piece will be addressed first.


## Setup
There are number of setup steps. If  **hlsBs** defaults are acceptable or the workspace, configuration files and components are created by other means, not are all these steps may be necessary.  This will describe the most '**hlsBs**' like usage. The first two steps can be done in an order.

- Define the environment variable *HLS_PROJECT_XILINX_SETUP*
	- This is a colon separated list of places to look for the XILINX setup files for the various versions of Vitis.
	- This is site specific so cannot be set by **hlsBs**. Suggestions are
		- Place in your login script.
		- Define an alias that can be easily remembered and invoked, e.g. *hlsLocate*.


	- At SLAC, all XILINX installations are under one root directory, so this would be
	> $ export HLS_PROJECT_XILINX_SETUP='/sdf/group/faders/tools/xilinx/${version}'<br>
 where **version** will be filled in when a version (2024.1,2024.2,etc) is selected. (Note the single quotes to prevent the shell from translating **{version}**.)

	- **RECOMMENDATION:** Be as specific as possible.
		- Since this involves a file search, a broad search may be slow.
		- At some sites it may be better to have mutiple, more specific paths than a single broad one.
		- In the SLAC example, including a symbolic version number in the search greatly speeds up the search.

	- Defining this environment variable can be omitted if some other method of selecting the Vitis version is preferred.
		- This is the recommended method. Try it, you'll like it,

- Source **hlsBs** setup script in
	> $ source ..ruckus/vitis/hlsBs/scripts/setup_hls.sh
	- This merely makes the commands available to the bash shell, there is nothing project or Vitis version specific.
	- As such, it can be a one-time step at login time, perhaps combined with the first step.
		- Commonly, *ruckus* will be a submodule of the project and it may be more natural to include this in the project's setup script, since the **hlsBs** setup script can be located relative to the project.
	- Except for the time (it does not take long), it may be repeatedly executed.


- Establish the Vitis version to use
	> $ hlsVersion \<vitis_version\>
	- If the Vitis version is specified, the Vitis setup script for that version is sourced.
		- This depends on the HLS_PROJECT_XILINX_SETUP environment variable being appropriately set.
		- This is very convenient for switching between Vitis versions.
	- If the version has been previously established in some other way, **hlsVersion** will use that version.
	- Once the Xilinx/Vitis version has been established, internal **hlsBs** version dependent context is initialized
	- Again, no project specific context is setup.
		- Selecting the target project is covered in the **Project File** section.


## The Commands
This is a listing of all the commands, presented roughly in logical usage order, along with a brief description. All commands have a corresponding
 **man** page which can be invoked by either
> $ hls\<*Cmd*\> [-h | --help] <br>
  $ man hls\<*Cmd*\>

See the *hlsBs-examples* repository for more of a *How-To*.


| Command   | Descriptions |
|:----------|:----------   |
| hlsBs     | Provides a quick summary of all the commands, basically the online version of this section. |
| hlsVersion| Establishes the Xilinx/Vitis version to be used. |
| hlsWs     | Creates and provides information on the workspace. |
| hlsCfg    | Creates, replaces, cleans, lists the configuration files and components. |
| hlsRun    | Runs all or any build stage (csim, synthesis, cosim, package, implementation, ip).|
| hlsExe    | Runs one particular component. This is useful when changing the arguments to csim.exe, *e.g.* changing the test files or the number of tests. |
| hlsGdb    | Invokes the debugger on a particular component |
| hlsGui    | Starts the IDE/GUI |
| hlsCtx    | Shows the values of the environment variables in current use by **hlsBs** |

Once the workspace has been established and the configuration files and compoonents created (essentially one-time activities) the vast majority of the use is **hlsRun**, with perhaps the occassional use of **hlsExe** and **hlsGdb** during development and debugging.

### A Word of Caution
There are few bash shell *gotchas*. These aren't pecular to **hlsBs**, but it seems particularly vulnerable to these.

1. As indicated before, target names may include wildcards, which the shell is eager to translate by finding matching patterns in the file names of the current working directory. Of cource, unless the current working directory is the target of the translation, this is will not yield the desired results.<br><br> Even more insidious, if there are no matching files, as per bash shell rules, the translation will fail and the wildcard will be passed as is, yielding the desired results. While this sounds like a good thing, this can lead to very mysterious behavior; a recalled command that previously worked, may now not work because the current working directory has changed or a new file was added that now satisfies the wildcard.  There are two methods to prevent this.
	- Always single quote any wildcarded name if specified as a positional argument, *e.g.* *'a\*'*
	- Use the alternative optional argument syntax to specify the components, *e.g.* --component="*a\**'. The  *--component* can be abbreviated to the minimum to be unique, currenlty *--com*.

2. Be very careful placing a positional argument immediately following an optional argument that accepts a value or list of values.  Since the bash shell enforces no formal binding or grouping, a positional argument juxtaposed to such a positional argument will be *eaten* by that positional argument. To avoid this
	- If using a positional argument to specify the component's name, make the positional argument the first argument
	- As in the first issue, use the alternative optional argument, *.e.g.* --component='a*'
	- Example of what not to do:
	> $hlsCfg --list '*'.<br>
	> Since --list takes a list of component categories, effectively this will be seen as *--list='\*'*. certainly not the intent.


**RECOMMENDATION**: Use positional arguments sparingly, favoring the optional argument form *--components='\*'*. While the *\'=\'* is optional, it does bind the argument list and, as a bonus, prevents the shell from expanding the wildcard even without the single quotes. It is the most fool-proof method.

Positional parameters are a trap waiting for a victim.



## The Project File
The project file is source of information that makes these commands easy to use at the terminal. Obviously the location of project file itself cannot be sourced from the project file. There are 2 ways to specify the project file location:
- By setting an environment variable<br>
> export HLS_PROJECT_PRJ=\<project file location\>   # *Commands will then use this environment variable as the project file*<br>
- Directly on the command line<br>
> hlsWs --create --project=\<project file location\> # *Only this command this use this project file location*

Defining the environment variable is the recommended way for normal usage.  Typically this would be defined in the project's setup script.

The second form is useful to test variations of the project file.  This is an example of a command line variable overriding the static setting of the environment variable.

While many values in the project file can be overriden on the command line, normal usage is to use the values in the project file. Not only does this decrease typing at the command line, indirectly it ensures consistency from command to command and helps to eliminate errors caused by typos.  An example of standard and non-standard usage might be

> $ hlsWs --create  # *Create the workspace in the project file specified by the HLS_PROJECT_PRJ*<br>
> $ hlsWs --create --workspace=/tmp/tmp_workpace  # *Create an ad-hoc temporary workspace as a playpen*


As is true in many cases, the advantage of the first form is that this definition is hidden and need not be remembered and the disadvantage is that this definition is hidden and not remembered.  When in doubt about this hidden context, use **hlsCtx** to display the implicit **hlsBs** context information.

### Environment Variables
The following environment variables are recognized. These override values in the Project File.

| Variable | Meaning |
| :------- | :------ |
| HLS_PROJECT_XILINX_SETUP | The search paths for the Xilinx/Vitis setttings scripts |
| HLS_PROJECT_PRJ | The project file |
| HLS_PROJECT_WORKSPACE | The workspace |
| HLS_PROJECT_PRODUCTS  | The products directory |
| HLS_PROJECT_INI       | This is a colon separated list of @FILES |

#### Usage
The workspace and products environment variables are useful for one-of ad-hoc experimentation. Output can be directed there so as to not pollute the regular workspace.

The 'ini' allows one to collect a number indirect files used to modify command line parameters. This is not ideal. It is unfortunate that argparse does not allow an include mechanism so that files with well-defined purposes can be mixed and matched.

All user-facing **hlsBs** environment variables begin with **HLS_PROJECT_**. These can be listed using **hlsCtx**.

**QUESTION:** Is **HLSBS_** a more appropriate prefix?


### Structure
The project file is a piece of user written Python. In many, if not most cases, it will be cloned from a similar project and with a few names changes, *e.g.* the names of the source files, where the includes are, the **csim.exe** command line parameters, *etc*. Since it is Python, more complex projects, for example projects with multiple components like the Snl Test Suite (>25 components), can be accomodated.

The standard Vitis method in the GUI/IDE works fine with creating a single configuration/component, but creating many is not only tedious, but implementing a change common to all is error prone. Python is much better suited in creating multiple configuration files and components.  It is familar by many users and syntax errors are well handled by the Python interpreter.

With experience, it is anticipated that a small collection of *stock* project template files will be accumulated.  For example, one for a simple project with a single test bench and hls file, reducing it to a 'fill-in-the-form' exercise.  There is already one for SNL. Here the structure is very static and basically all that is needed is the network definition file, the target FPGA and the test files. There is a universal file (SNL.py) which provides the boilerplate and a single class which the user initializes with the values from his project dependent project file.

A common feature extensively used are environment variables and logical symbols (explained later, think of them as variables in a progrmming language) in the project file. This is one of the primary advantages of **hlsBs** over the standard Xilinx/Vitis/HLS methods.  It allows for abstraction; instead of hard-coding, logical symbols can be used.

It is recommended that the project file be placed in the */products* subdirectory of the project's top level directory. To bring some concreteness to the discussion below, a hypthothical project (called *example*) wtth the following directory structure will be assumed
<pre>
 example/
         project/ExampleProject.py
         src/example/ExampleTb.cc. ExampleHls.cc
         include/example/Example.hh
</pre>

The **hlsBs** commands produce a variety of output products. The default layout is

<pre>
example/
        products/
                 ws/{vitis_version}   # The workspace for a particular Vitis versionn
                cfg/{vitis_version}   # Directory for the confifiguration files for a particular Vitis version
                 ip/{vitis_version}   # Directory for the modified .dcp and .zip file
</pre>

**NEEDED USER OPINION:** There is the eternal debate of the ordering of the *ws, cfg* and *ip* directories and the *{vitis_version}*. Should they be reversed. There are pros and cons for each.

## What is in a Project File
There are 4 user provided python methods defined in the project file, which are optional if their defaults are acceptable.

### get_project_root (project)
This returns the project's root directory.  Example
> def get_project_root (project) :
	return '$MY_PROJECT_ROOT'

Better is to self locate the project root relative to the project file.  Using the directory structure above
> def get_project_root (project) : return os.path.split (os.path.split (\_\_FILE\_\_)[0])[0]

**RECOMMENDATION:**: Always self root the project root.<br>

**OPTIONAL**: If the standard layout is acceptable, this method can be omitted altogether or return *None*, with the project root effectively being defined as in the second form.

### get_products_root (project)
This returns the directory where the various products (workspace, configuration files, ip) are placed.  While **hlsBs** provides the ability to individually place these anywhere, it is common practice and convenient to place these within a common directory. Examples
> def get_product_root (project) : return 'MY_PRODUCTS_ROOT'

**RECOMMENDATION**: Locate the products relative to the project root
> def get_product_root (project) : return os.path.join (project.root, 'products')

Of course one can locate it anywhere relative to the project root and name it anything.  The above is the default.

Note also the use of *project.root*.  This is deliberate because the project root can be overriden on the command line. If this is done, the command line value of *project.root* takes precedent.  This is a reoccuring pattern.  Many of the values in the project file can be sourced either from within the project file itself or overridden at the command line.

The products root can be overidden from the command line either with an explicit command line parameter or the **HLS_PROJECT_PRODUCTS** environment variable.  This is useful for creating ad hoc, experimental versions of the products.  A common tactic is to relocate the products to a throw-away directory in /tmp/.

**OPTIONAL:** If the standard layout is acceptable, this method can be omitted or return *None*


### get_workspace (project)
This returns the workspace. Example
>def get_workspace (project) :	return 'MY_WORKSPACE'

**RECOMMENDATION**: Locate this relative to the products_root and include the Vitis Version. This is the default
> def get_workspace (project) : return os.path.join (project.products_root, 'ws', '{vitis_version}')

Here '{vitis_version}' is the first use of logical symbols.  This allows workspace to be distinguished by the Vitis version and wil be resolved when the workspace is refernced.<br>

The workspace can be overidden from the command line either with an explicit command line parameter or the **HLS_PROJECT_WORKSPACE** environment variable.  This is useful for creating ad hoc, experimental versions of the workspace.  A common tactic is to relocate the workspace to a throw-away directory in /tmp/.


**OPTIONAL:** If the standard layout is acceptable, this method can be omitted or return *None*


### def get_products
This is the major weight lifter.  It specifies all the information needed to define the configuration files and components. As such, there is a lot more to it.  In the following example, the fact that this is Python is used to define many local variables to make the intent clearer.  Whether that has been achieved is up for debate.

<pre>
# ------------------------------------------------------------------------------
def get_products (project) :

    Product       = project.Product

    testbench    = os.path.join (project.root, '../src/example/ExampleTb.cc')
    syn          = os.path.join (project.root, '../src/example/ExampleHls.cc')
    includes     = ( {'paths': os.path.join (project.root, '../', 'include'),
                      'type' : 'rel_file'} )

    # -------------------------------
    # Create a build called 'example'
    # -------------------------------
    build        = ('example',  { 'top'       : 'doit',
                                  'tb'        : [ { 'file'     : testbench,
                                                    'includes' :  includes} ],
                                  'syn'       : [ { 'file'     :       syn,
                                                    'includes' :  includes} ],
                                  'csim_argv'  : '--ntests=10',
                                  'cosim_argv' : '--ntests=100'} )

    # ----------------------------------------------------------------------
    # Define the FPGAs to use. Here 2 are defined, but it can be any number
    # except 0.
    # --------------------------------------------------------------
    fpgas        = ( Product.Fpga ('xcku115-flvb2104-2-i', '6',  None, '6ns'),
                     Product.Fpga ('xcku115-flvb2104-2-i', '5',  None, '5ns') )

    # ---------------------------------------------------------------------
    # Create the component by pairing the build with the Fpgas.
    # ---------------------------------------------------------------------
    components   = (Product.Builds (('build', build)),
                    Product.Fpgas  (  'fpga', fpgas))

    # -------------------------------------------------------------------
    # The configuration template uniquely names the configuration file path.
    # ------------------------------------------------------------------
    cfg_template = (os.path.join (project.products_root,
                                  'cfg',
                                  '{vitis_version}',
                                  '{build_id}-{fpga_id}.cfg'))

    # -------------------------------------------------
    # Name the components after the configuration files
    # -------------------------------------------------
    cmp_template = '{cfg_name}'

    # --------------------------------------------------------
    # The targets are the
    #    i) Fully specified component(s), can be a list/tuple
    #   ii) The configuration file path template
    #  iii) The configuration name template
    # --------------------------------------------------------
    targets      = [ { 'Components'        : components,
                       'ConfigurationName' : cfg_template,
                       'ComponentName'     : cmp_template } ]

    # --------------------------------------------------------
    # The usual Vitis Package IP
    # 1. The name is chosen to be the configuration file name
    #    but could also be cmp_name.  It does not have to be
    #    unique, so could be the build id.
    # 2. The version can be the git tag if any.
    #    It can overridden on the command line
    # -------------------------------------------------------
    package_ip   = Product.Package.Ip (name    = '{cfg_name}',
                                       vendor  = 'SLAC',
                                       version = '1.0.0',
                                       library = 'hls')

    #
    package_output = Product.Package.Output (format    = 'ip_catalog',
                                             syn       = 'false')

    vivado         = Product.Vivado  (flow ='syn',     syn_dcp = '1')


    return Product (project = project,
                    targets = targets,
                    package = Product.Package (ip     = package_ip,
                                               output = package_output),
                    vivado  = vivado)


# ------------------------------------------------------------------------------
</pre>


Going line-by-line

#### Convenience Declarations
Since this is Python, defining variables and symbols to both shorten typing, capture common concepts or make the code more readable is encouraged. Use all the techniques normally used when coding.
<pre>
   Product = project.Product
</pre>

This is merely shorthand used to access the inner classes defined in the Project class and
avoids having to do an explicit import which would require either modifying the PYTHONPATH
or some other way of locating it keeping this module free of unnecessary details.

#### Source File and Include Definitons
<pre>
  testbench = os.path.join (project.root, '../src/example/ExampleTb.cc')
  syn       = os.path.join (project.root, '../src/example/ExampleHls.cc')

  includes  = ( {'paths' : os.path.join (project.root, '../', 'include'),
                 'type'  : 'rel_file'} )
</pre>
These locates the testbench, hls/synthesis files and, optionally, the include paths relative to the configuration file's directory.
- 'type' specifies how the include file path is treated
	-	'rel_file is relative to the configuration file
    -   'abs_file is absolute<br><br>

**RECOMMENDATION**: Specify includes as 'rel_file' where possible. It keeps absolute paths out of the configuration file so they only depend on relative paths. This is keeping with a goal of **hlsBs**  to allow configuration files to be saved in a repository by one user and checked and used by another as is.<br><br> The alternative is '*abs*' which allows absolute paths.<br> This would be used if the include path is not within the project's directory tree.|

Also noteworthy are
- The use of Python dictionaries, these are used extensively in the project file.
- While in this example, all file specifications are single paths, they may be anu Python iterable class, *.e.g.* list, tuple or array.
- More than one set if includes are allowed. The only practical reason would be if the additional include paths had a different *'type'*, otherwise it would be simpler to just add more paths after the *'file'*.

#### Build Defintion
<pre>
    build  = ( 'build', { 'top'       : 'doit',
                          'tb'        : [ { 'file'     : testbench,
                                            'includes' :  includes} ],
                          'syn'       : [ { 'file'     :       syn,
                                           'includes' :  includes} ],
                          'csim_argv'  : '--ntests=10',
                          'cosim_argv' : '--ntests=100'} )
</pre>
This is a list or tuple giving the name of the build product and a dictionary defining its makeup. The name is often used when composing the configuration file path and component name.

The build itself is specified as

| Key            | Meaning   |
|:---------------|:----------|
| top            | Name of the top level HLS method |
| tb             | The test bench file(s) and its include path(s) as one of more dictionaries.<br><br> Either or both the *'testbench'* and *'includes'* can be lists or tuples. The dictionary bind the *testbench* file(s) with a set of *include* paths.
| syn           | The same structure as the *testbench* files, except for the HLS/synthesis files. |
| csim_argv     | The command line arguments to pass to *csim.exe* |
| cosim_argv    | The command line arguments to pass to *cosim.exe*|

**CAVEAT**: While environment variables can be used in specifying the file paths, please see the section titled *A word of caution on environment variables*.


##### FPGA Definition
<pre>
    fpgas        = ( Product.Fpga ('xcku115-flvb2104-2-i', '6',  None, '6ns'),
                     Product.Fpga ('xcku115-flvb2104-2-i', '5',  None, '5ns'))
</pre>
This defines a list of two FPGAs giving their
- Part
- Clocking
- Uncertainity -- *None* means use the default
- An idenitfier

The identifier needs further explaination. One of the key aspects of creating a component is that, since all component definitions reside in the workspace directory, they must be uniquely named.  The intent in this example is the same code is built using 2 different FPGAs, resulting in 2 components.

The *fpga id*, as can the *fpga_part* abd *fpga_clock*, can be used as logical symbols to generate a unique component name.  Here the *fpga_clock* could serve the same purpose since it is only difference. However, if the part, clock and uncertainity were all different, the *fpga_id* serves as convenient nickname for the combination.

**RECOMMENDATION:** Choose a meannful name, so it is apparent from the component name what it means.  Do not use things like 'f0' and 'f1' which convey nothing.

#### Component Composition
<pre>
    components   = (Product.Builds ('build', [ ['example', build] ]),
                    Product.Fpgas  ('fpga',  fpgas))
</pre>
A component is composed of its build combined with its FPGAs. To aid in composing unique names for the configuration file paths and components, attributes of the build and FPGAs can be accessed using 'build'/'fpga' strings as a prefix.
| Prefix  | Attribute |
| :-----  | :-------- |
| build   | build_id  |
| fpga    | fpga_part <br>fpga_clock<br>fpga_uncertainity | fpga_id> |

**RECOMMENDATION**:  The names 'build' and 'fpga', while meaningful, are arbitrary. They can be anything.  To be safe, would limit to the characters used to form legitimate Python variables.


#### Configuration File Path Generation
This defines a template of how to name the configuration file path.
<pre>
    cfg_template = (os.path.join (project.products_root,
                                  'cfg',
                                  '{vitis_version}',
                                  '{build_id}-{fpga_id}.cfg'))
</pre>

Here, in addition to using the *build_id* and the *fpga_id*, the vitis version is included in the directory path specification. When the component file path is constructed, these will be substituted with the appropriate values.

**RECOMMENDATION:** Use the logical symbols to generate the configuration file name, even in a simple HLS project consisting of a single component.


#### Configuration Name Generation
This defines a template of how to name the component.
<pre>
    cmp_template = '{cfg_name}'
</pre>
In general, naming the component after the configuration file name is the most straight-forward naming.  As always, there may be instances where the freedom to name it otherwise is useful.

A nuance should be noted here. While the component name must be unique, the configuration file name need not be since, while not recommended, the configuration file can be placed in its own distinguishing directory.  If this is done, *hlsBs* supplies the logical *cfg_dir* for the first directory to help in generating a unique component name. Note that only the first subdirectory is provided. There is currently no prescribed method if this is sitll not sufficient to generate a unique component name.

**NOTE**: Naming the coniguration file could just have easily been named after the component. Naming the component after the configuration file was just a matter of choice in this example.


#### Complete Configuration and Component Generation
This definition includes the components themselves and how to name the generated configuration file path(s) and component(s)
<pre>
    targets      = [ { 'Components'        : components,
                       'ConfigurationName' : cfg_template,
                       'ComponentName'     : cmp_template } ]
</pre>
**NOTE:**

-The name *targets*, like all the identifiers appearing on the left hand side of the *'='* is just the name of Python variable and has no signficance.  Frankly, better names are needed to convey what they stand for.<br>

-It is only for clarity that temporary names like *components*, *cfg_template* and *cmp_template* exist. One could dispence with them and directly add their definitions.   Again, treat this as any other piece of Python code and strive to make it as clear as possible.

- Even thought there is only one target, this has been specified as a list to emphasis it can be any Python iterable class. It can also be just the single element,

### Additional Information
What follows is bookkeeping and information needed by the build chain.

#### Package IP
This is packaging identification. The only noteworthy thing is the *name* is chosen to be the configuration name. It could have been the component name or any name composed of absolute text and logical symbols. See the section on *Configuration File Paths and Components Names* to help make the right decision for a given project.

<pre>
    package_ip   = Product.Package.Ip (name    = '{cfg_name}',
                                       vendor  = 'SLAC',
                                       version = '1.0.0',
                                       library = 'hls')
</pre>

Currently the *'version'* can be taken from the logical symbol  {git_tag} if it exists.  An improvement whould be to be able to specify this on the command line.

#### Package Output
This is the standard output packaging.
<pre>
    package_output = Product.Package.Output (format    = 'ip_catalog',
                                             syn       = 'false')
</pre>


#### Vivado Instructions
<pre>
    vivado         = Product.Vivado  (flow ='syn',     syn_dcp = '1')
</pre>


### Putting it all together
This returns the defined product.  This may also return a list of products
<pre>
    return Product (project = project,
                    targets = targets,
                    package = Product.Package (ip     = package_ip,
                                               output = package_output),
                    vivado  = vivado)
</pre>

| Key     | Meaning  |
|:------- | :--------|
| project | The controlling project |
| targets | The target components   |
| package | The IP and output packaging information |
| vivado  | The Vivado information



## IP Products
def get_ip (project)

These are products modified Vitis products but produced by **hlsBs**.  They have proven to be useful in overcoming some of the limitations of the Vitis products they are derived from. There are 2 such products, DCP renaming and expanding the permissible FPGA target families.

#### DCP Renaming
All standard Vitis/Vivado produced .dcp file have a the same embedded name. This makes it impossible to combine multiple .dcp files when producing a single FPGA image.  This allows unique names to be assigned to the .dcp files.

#### FPGA Family Augmentation
Using a Vivado utility, the .zip file is repackaged to include a specified list of FPGAs families.

<pre>
# ------------------------------------------------------------------------------
def get_ip (project) :
    ip = project.Ip \
    (
        dir      =  os.path.join (project.products_root,
                                  'ip', '{vitis_version}'),
        zip_file = '{cmp_name}',
        family   = ('artix7,kintex7,virtex7,zynq,kintexu,virtexu,kintexuplus,'
                    'virtexuplus,virtexuplusHBM,zynqplus,zynquplusRFSOC,veral'),

        # ----------------------------------------------------------------
        # These are the defaults and can be omitted or set to None
        # ----------------------------------------------------------------
        dcp_rename = '{cmp_name}',
        dcp_file   = '{dcp_rename}',

        dgn_dir    = 'dgn/',
        jou_file   = '{dcp_name}',
        log_file   = '{dcp_name}'
    )

    return ip
# ------------------------------------------------------------------------------
</pre>

By default these output files are collected in the *ip/* subdirectory of the *products/* directory.  As usual, these may be place anywhere by suitably defining the appropriate file paths. Typically the various file path specifications are defined as only the file name, but these can all be complete file paths or and subset of the directory path, the file name and the file extension. Any missing pieces will be parsed on.

All the values have sensible defaulted, except for the *'family'*.  While it does have a default value, it may not be what is wanted. The values above are the default values. They can all be omitted if the defaults are acceptable.

**RECOMMENDATION:** If the defaults are acceptable, rather than omitting them, set the values to *None*'. This will serve as a reminder that they can be altered.

| Member     | Meaning |
| :--------- | :------ |
| dir        | The common output directory |
| zip_file   | The name of the new zip file with the modified FPGA families |
| dcp_rename | The new embedded name |
| dcp_file   | The name of the modified dcp file |
| dgn_dir    | The common directory where the Vivado journal and log file are written |
| jou_file   | The name of the dcp journal file |
| log_file   | The name of the dcp log file |




## Into the Weeds
This part is certainly getting into the weeds, but an example pointing up these nuances may actually help understand the common case and clarify what are just conventions.


### Configuration File Paths and Components
In most cases the configuration file name and component name are the same, but this is not strictly necessary.

The following illustrates an example of an unusual case.  As in such examples, it is somewhat contrived.

Suppose the same underlying code is used to generate components that differ only by the targetted FPGA.  Here one could use {fpga_id}, not as part of the configuration name, but as part of the directory path.  This would allow all the configuration names to be the same since they reside in different directories.  The configuration file path template might look something like

<pre>
     cfg_template = os.path.join (project.products_root, '{vitis_version}', '{fpga_id}', '{build_id}') + 'cfg'
</pre>

The component name could not be the configuration file name, since it is not unique.  In this case it might be

<pre>
   cmp_template = {vitis_version}-{fpga_id}-{build_id}
</pre>

In this example, using the {cfg_name} could be used to make the Project.Ip's name the same independent of the FPGA it is deployed on. Of course there are other ways to achieve this, like simply naming the Project.Ip's name {build_id}.

As a side-note the logical symbol *{cmp_dir}* is the first sub-directory where the configuration file resides.


### A word of caution on enviroment variables:
The values, *e.g.* file paths, may include environment variables, but because HLS configuration files do not allow environment variables, these must be translated when the configuration file is created. Since the testbench, hls/synthesis and include file paths are generally reinterpreted as relative to the configuration file, this is not a problem. However for *csim_argv* and *cosim_argv*, the choice to defer the translation to runtime would be desireable. Ideas to defer translatation until run time are being explored.

> To illustrate how insidious this is consider the caae when the configuration file is built and the environment variables are not defined.  For file and include paths, the build will fail and certainly be noticed.  However, unless the resulting configuration file is carefully examined, any environment variables in the two *argv* will not have been translated and the paths will be incorrect and not noticed till running.

> Even worse, if the configuration is built not using *hlsBs*, but in the IDE/GUI, the value of the environment variables are whatever they were when launched.  If one assumes they are the values you see when the configuration file is made, a sad ending may await.  This is not a theortical problem. It cost the author a couple of days to learn this.  It is one reason why **hlsBs** is very careful in its handling of environmental variables. **hlsBs** does have the advantage that all its commands inherit the context of the shell they are launched in, so any enviroment variables have the values of that shell.

> Even more worse, if the execution is by prechance in a directory containing the test files where the fact that the environment variable translates nothing and they are *accidently* found, it might succeed, but tomorrow, when in a different directory, it might mysteriously fail.  Even worse, suppose there were 2 test sets and on day 1 the current directory was set 1 and on day 2 it was set 2.  Years of life could be lost trying to understand why the 2 days results are different.

> Just to illustrate the bizarrites of HLS, there were 2 promising methods to defer the translation, unfortunately one only works in running csim.exe straight, but not under gdb and visa-versa. Considered writing 2 confifuration files, one for each environment, but that creates a whole other host of problems.


#### Finally - User Input/Feedback Wanted
Improvements
- Expand the number of parameters available on the command line.
	- In developing HLS code, the ability to do ad hoc experimentation and then capture and catelog the useful ones is invaluable. Being able to experiment on the command line goes a long ways in realizing this.
	- Doing all parameters was too large a job. Getting the basics was hard enough.
- Not happy with Project file, in particular the get_products method
	- It is an uneven combination of Python class initialization and use of dictionaries.
	- There may be better ways to capture the common defaults
		- A common problem of defaulting, is that the full functionality is hidden
		- Want a solution that says 'here are usual defaults, but if more is needed, it is here'

While a lot thought went into this, somethings only come with actual usage, *i.e.*  this single author was limited by imagination and time.
