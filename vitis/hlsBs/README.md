# hslBs -- A HLS Build System

Welcome to that indispenable thing called documentation. Demanded by many, written by one, destined to be read by fewer.  Being honest, the build system is not high on anyone's interest list. This is a reference manual, *i.e.*, where only the truly lost and hopelessly confused desparately seek answers come, the land of last resort.

In the **hlsBs-examples** repository is a *How-To* user's manual. For many, this is all that is needed. If the project is beyond the basics, then this more complete manual may be of interest.  The test suite for the SNL framework, which has 20+ components each of whose performance, resource usage and integrity must be tracked across multiple Vitis releases  is an example of a such a project.  The SNL framework, where experimentation and trail and error are part and parcel of its development also demands a more capable buitd system.

### Limitation
Since **hlsBs** depends on the more recent unified development framework, only Vitis Versions 2023.2 or greater are supported. As a word of caution, 2023.2, being the first version to support the unified development environment, has some *pecularities*.  **hlsBs** has a number of workarounds, but as with all workarounds, there are pitfalls. So unless for other reasons 2023.2 must be used, it is recommended to use 2024.1 or greater.

# Goals
**hlsBs** is a command line driven system designed to simplify the HLS/Vitis build process, particularly for projects involving multiple components.  The utility of multiple components falls into 2 categories
- Projects composed of 2 or more distinct HLS components or variations
	- Components may run on physically different FPGAs with one feeding the other in a daisy-chain fashion.
	- The same project needs to run on mutliple FPGA parts.
- The same component but with different algorithms or pragma parameters to explore the performance/resource tradeoffs.

It is the second category where, admittedly, there is some social engineering on the author's part. The goal was, by making it easy to create, build, compare and catalog them, to encourage experimentation and exploration.  In developing HLS code, this step is necessary to achieve the best results.  The correct algorithm and pragma settings are never immediately apparent.

### The primary goals were:
- Make simple projects simple and more complex projects possible
- Be compatible with the HLS GUI/IDE build and development system. 
	- One can mix and match, using whichever one is appropriate and comfortable with for the task at hand
- Accommodate building the same project using multiple VITIS versions
	- This encourages both moving forward with new versions and comparing their differences
- Handling the drudery of creating the configuration files and components
	- This is reduced to almost a 'fill-in-the-blanks' exercise
- Easily run all or any collection of the various build stages (csim, synthesis, cosim, etc)

### Secondary, less user-facing goals
Paraphasing the great Joni Mitchell, "*you don't what you need till you need it*"
- Keep the utilities as policy free as possible
	- For example, no particular directory structure or naming conventions are imposed
	- Still provide sensible defaults which can be easily modified to suit the user's personal perferences and/or the specific projects's needs.
- Appropriately partition the needed information by where it is kept, when it is used and its lifetime.
	- Static information, such as the Vitis Version and workspace
		- These are keep in the project file (described later)
	- Quasi-static information, such as experimenting with parameters that affect performance/resource trade-offs.
		- These are kept in named files which can contain 1 or more command line parameters
		- They are referenced on the command line as **@FILE**.
		- This is a nice feature of the Python argparse methods.
		- A usage might be to define alternate test sets in a family of such files and selecting which one to use at run-time.
	- Run time parameters, such changing the input test data or the number of tests to run
	- This is achieved by establishing a priority ordering with run time parameters overriding quasi-static parameters and quasi-static parameters overriding static paramters.
    - Not all parameters can be overriden. Experience will help guide expansion.
- Make the commands consistent, short and unique with the goals of minimizing remembering details, limiting typing and avoiding name clashes. 
- Make the commands as efficient/fast as possible
	- Mainly this involves only using or deferring the use of the underlying Vitis utilities until absolutely necessary.
- Provide query commands, such as listing the components and configuration files
	- Given the power of these commands, without fail unknown *stuff* (in **hlsBs** parlance, this is known as **cruft**) creeps in.
- Similar command structure
	- Almost all commands target the component(s) by name and cataogory
	- Compoment names may be an explicit name, a wildcarded name, or a list of any combination.
	- Components are classified into the following catgories
		- Existing
		- Missing
		- Cruft
	- Commands, by default, target the most logical component catagory and names. As a concrete example, the default targets for the configuration file and components management actions are

> | Action | Catagory | Target Name  |
> | :----- | :------- | :----------  |
> | clean  | existing | None         |
> | list   | all      | All          |
> | create | missing  | All          |
> | replace| existing | All          |

## The Basics
There are two distinct pieces to the build system
- A piece to facilitate the creation and contents of the workspace, configuration files and and the components that populate the workspace.
- The set of **hlsBs** commands.


Loosely speaking, the former defines the contents of the configuration files and components, while the latter, with some obvious exceptions, uses the generated components to produce the output products, *i.e.* **csim**, **synthesis**, **cosim** *etc*.

In keeping with the goal of being able to mix techniques, it is permissable for the configuration files, the workspace and components to be generated by some other means. The most common example of this would be legacy projects. However, not using **hlsBs** to generate these products will limit some of its most useful features. 

The first piece is by far the most complicated and, as noted, may be ignored if the workspace, configuration files and components already exist. The second piece will be addressed first.  


## Setup
There are number of setup steps. In keeping with the goal of allowing the choice between using the standard Vitis IDE build tools or the **hlsBs** ones as dictated by personal perference and whether **hlsBs** defaults are acceptable, not are all steps are strictly necessary.  This will describe the most '**hlsBs**' like usage. The first two steps can be done in an order.

- Define the environment variable *HLS_PROJECT_XILINX_SETUP*
	- This is a colon separated list of places to look for the XILINX setup files for the various versions of Vitis
	- This is site specific so cannot be set by **hlsBs**. Suggestions are
		- Place in your login script
		- Define an alias that can be easily remembered and invoked, e.g. *hlsLocate*


	- At SLAC, all XILINX installations are under one root directory, so this would be
	> $ export HLS_PROJECT_XILINX_SETUP='/sdf/group/faders/tools/xilinx/${version}'<br>
 where **version** will be filled in when a version (2024.1,2024.2,etc) is selected. (Note the single quotes to prevent the shell from translating **{version}**.)

	- Suggestion, be as specific as possible.
		- Since this involves a file search, a broad search may be slow
		- Practically speaking, at some sites it may be better to have mutiple, more specific paths than a single broad one
		- In the SLAC example, including a symbolic version number in the search greatly speeds up the search

	- Defining this environment variable can be omitted if some other method of selecting the Vitis version is preferred
		- This is the recommeneded method. Try it, you'll like it,

- Setup **hlsBs** by sourcing the setup script in
	> $ source ..ruckus/vitis/hlsBs/scripts/setup_hls.sh
	- This merely makes the commands available to the bash shell, there is nothing project or Vitis version specific
	- As such, it can be a one-time step at login time, perhaps combined with the first step
		- Many times *ruckus* will be a submodule of the project, so it may be more natural to include this in the project's setup script, since the **hlsBs** setup script can be located relative to the project.
	- Except for the time (it does not take long), it may be repeatedly executed.


- Establish the Vitis version to use
	> $ hlsVersion \<vitis_version\>
	- If the Vitis version is specified, the appropirate Vitis setup script for that version is sourced
		- This depends on the HLS_PROJECT_XILINX_SETUP environment variable being appropriately set.
		- This is very convenient for switching between Vitis versions
	- if the version has been previously established in some other way, **hlsVersion** will use that version.
	- Once the Xilinx/Vitis version has been established, internal **hlsBs** version dependent context is initialized
	- Again, no project specific context is setup
		- Selecting the target project is covered in the **Project File** section


## The Commands
This is a listing of all the commands, presented roughly in logical usage order, along with a brief description. All commands have a corresponding
 **man** page which can be invoked either by
> $ hls*Cmd* [-h | --help] <br>
  $ man hls*Cmd* 

See the *hlsBs-examples* repository for more of a *How-To*.


| Command   | Descriptions |
|:----------|:----------   |
| hlsBs     | Provides a quick summary of all the commands, basically the online version of this section. |
| hlsVersion| Establishes the Xilinx/Vitis version to be used. |
| hlsWs     | Creates and provides information on the workspace. |
| hlsCfg    | Creates, replaces, cleans, lists the configuration files and components |
| hlsRun    | Runs all or any build stage (csim, synthesis, cosim, package, implementation, ip) |
| hlsExe    | Runs one particular component. This is useful when changing the arguments to csim.exe, *e.g.* changing the test files or the number of tests |
| hlsGdb    | Invokes the debugger on a particular component |
| hlsGui    | Starts the IDE/GUI |
| hlsCtx    | Shows the values of the environment variables in current use by **hlsBs** |

Once the workspace has been established and the configuration files and compoonents created (essentially one-time activities) the vast majority of the use is **hlsRun**, with perhaps an occassional use of **hlsExe** and **hlsGdb** during development and debugging.

### A Word of Caution
There are few bash shell *gotchas*. These aren't pecular to **hlsBs**, but it seems particularly vulnerable to these.

1. As indicated before, target names may include wildcards, which the shell is eager to translate by finding matching patterns in the file names of the current working directory. Of cource, unless the current working directory is the target of the translation, this is will not yield the desired results. Even more insidious, if there are no matching files, as per bash shell rules, the translation will fail and the wildcard will be passed as is, yielding the desired results. This can lead to very mysterious behavior; a recalled command that previously worked, may not work because the current working directory has changed or a file was added that now satisfies the wildcard.  There are two methods to prevent this.
	- Always single quote any wildcarded name if specified as a positional argument, *e.g.* *'a\*'*
	- Use the alternative optional argument syntax to specify the components, *e.g.* --component="*a\**'. The name *component* can be abbreviated to the minimum to be unique, currenlty *--com*.  As standard advice, use the complete name in scripts.

2. By very careful placing a positional argument immediately following an optional argument that accepts a value or list of values.  Since the bash shell defines enforces no formal binding or grouping, a positional argument juxtaposed to such a positional argument will be *eaten* by that positional argument. To avoid this
	- If using a positional argument to specify the component's name, make the positional argument the first argument
	- As in the first issue, use the alternative optional argument, *.e.g.* --component='a*'
	- Example:  
	> $hlsCfg --list '*'.<br>
	> Since --list takes a list of component categories, this will be seen as *--list='\*'*. certainly not the intent.


**Recommentation**: Use positional arguments sparingly, favoring the optional argument form *--components='\*'*. While the *=* is optional, it does bind the argument list and, as a bonus, prevents the shell from expanding the wildcard even without the single quotes.



## The Project File
The project file is source of information that makes these commands easy to use at the terminal. Obviously the location of project file itself cannot be sourced from the project file. There are 2 ways to specify the project file location:
> export HLS_PROJECT_PRJ=\<project file location\>   # *Commands will then use this environment variable as the project file*<br>
> hlsWs --create --project=\<project file location\> # *Only this command this use this project file location*

Defining the environment variable is the recommended way for normal usage.  Typically this would be defined in the project's setup script. 

The second form is useful to test variations of the project file.  This is an example of a command line variable overriding the static setting of the environment variable.

While many values in the project file can be overriden on the command line, normal usage is to use the values in the project file. Not only does this decrease typing at the command line, indirectly it ensures consistency from command to command and helps to eliminate errors caused by typos.  An example of standard and non-standard usage might be

> $ hlsWs --create # *Create the workspace as specified in the project file*<br>
> $ hlsWs --create --workspace=/tmp/tmp_workpace  # *Create an ad-hoc temporary workspace as a playpen*


As is true in many cases, the advantage of the first form is that this definition is hidden and need not be remembered and the disadvantage is that this definition is hidden and not remembered.  When in doubt about this hidden context, use **hlsCtx** to display the implicit **hlsBs** context information.
 

### Structure  
The project file is a piece of user written Python. In many, if not most cases, it will be cloned from a similar project and with a few names changes, like the names of the source files, where the includes are, the **csim.exe** command line parameters, *etc*.  can be adapteed for the new project. Since it is Python, more complex projects, for example projects with multiple components like the Snl Test Suite (>25 components), can be accomodated.  Python, as opposed to the very rigid Vitis method, is much better suited in creating the configuration files and components.  It is familar by many users and syntax errors are well handled by the Python interpreter.

With experience, it is anticipated that a small collection of *stock* project template files will be accumulated.  For example, one for a simple project with a single test bench and hls file, reducing it to a 'fill-in-the-form' exercise.  There is already one for SNL. Here the structure is very static and basically all that is needed is the network definition file, the target FPGA and the test files. There is a universal file (SNL.py) which provides the boilerplate and a single class which the user initializes with the values.

A common feature used extensively is the ability to use environment variables and logical symbols (explained later, think of them as variables in a progrmming language) in the project file. This is one of the primary advantages of **hlsBs** over the standard Xilinx/Vitis/HLS methods.  It allows for abstraction; instead of hard-coding, logical symbols can be used.  This is the very essence of a programming language.

It is recommended that the project file be placed in the project's the */products* subdirectory of its top level directory. To bring some concreteness to the discussion below, a hypthothical project (called *example*) wtth the following directory structure will be assumed
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
There are 4 user provided python methods defined in the project file, some which are optional depending on whether defaults  are acceptable.

### get_project_root (project)
This returns the project's root directory.  Example
> def get_project_root (project) :
	return '$MY_PROJECT_ROOT'

Better is to self locate the project root relative to the project file.  Using the directory structure above
> def get_project_root (project) : return os.path.split (os.path.split (\_\_FILE\_\_)[0])[0]

**RECOMMENDATION:**: Always self root the project root.<br>
**OPTIONAL**: If the standard layout is acceptable, this method can be omitted altogether or return *None*, with the project root effectively being defined as in the last example.

### get_products_root (project)
This returns the directory where the various products (worksapce, configuration files, ip) are placed.  While **hlsBs** provides the ability to individually place these anywhere, it is common practice and convenient to place these within a common directory. Examples
> def get_product_root (project) : eturn 'MY_PRODUCTS_ROOT'

**RECOMMENDATION**: Locate the products relative to the project root
> def get_product_root (project) : return os.path.join (project.root, 'products')

Of course one can locate it anywhere relative to the project root and name it anything.  The above is the default.

Note also the use of *project.root*.  This is deliberate because the project root can be overriden on the command line. If this is done, the command line value of *project.root* takes precedent.  This is a reoccuring pattern.  Many of the values in the project file can be sourced either from within the project file itself or overridden at the command line.

The products root itself can be overidden from the command line.  This is useful for creating ad hoc, experimental versions of the products.  A common tactic is to relocate the products to some directory in /tmp/.

**OPTIONAL:**: If the standard layout is acceptable, this method can be omitted or return *None*


### get_workspace (project)
This returns the workspace. Example
>def get_workspace (project) :	return 'MY_WORKSPACE'

**RECOMMENDATION**: Locate this relative to the products_root and include the Vitis Version. This is the default
> def get_workspace (project) ; return os.path.join (project.products_root, 'ws', '{vitis_version}')

Here '{vitis_version}' is the first use of logical symbols.  This allows workspace to be distinguished by the Vitis version and wil be resolved when the workspace is refernced.
**OPTIONAL:** If the standard layout is acceptable, this method can be omitted or return *None*


### def get_products
This is the major weight lifter.  It specifies all the information needed to define the configuration files and components. As such, there is a lot more to it.  In the following example, the fact that this is Python is used to define many local variables in order to make the intent clearer.  Whether that has been achieved is up for debate.

<pre>
# ------------------------------------------------------------------------------
def get_products (project) :

    Product       = project.Product
    
    testbench    = os.path.join (project.root, '../src/example/ExampleTb.cc')
    syn          = os.path.join (project.root, '../src/example/ExampleHls.cc')
    includes     = [ {'file' : os.path.join (project.root, '../', 'include'),
                      'type' : 'rel_file'} ]

    builds       = { 'top'       : 'doit',
                     'tb'        : [ { 'file'     : testbench,
                                       'includes' :  includes} ],
                     'syn'       : [ { 'file'     :       syn,
                                       'includes' :  includes} ],
                    'csim_argv'  : '--ntests=10',
                    'cosim_argv' : '--ntests=100'}

    # --------------------------------------------------
    # The following symbolics are exported to be used in
    # configuration and component name generation
    #     fpga_part fpga_clock and fpga_id
    # --------------------------------------------------
    fpgas        = [ Product.Fpga ('xcku115-flvb2104-2-i', '6',  None, '6ns'),
                     Product.Fpga ('xcku115-flvb2104-2-i', '5',  None, '5ns')]

    # ----------------------------------------------------------------
    # Create 4 components, 2 different builds, paired with the 2 Fpgas
    #    streamA-6ns streamA-5ns
    #    streamB-6ns streamB-5ns
    # ----------------------------------------------------------------
    components   = (Product.Builds ('build', [ ['example', builds] ]),
                    Product.Fpgas  ('fpga',  fpgas))

    # --------------------------------------------------
    # Configuration file name template
    # Makes  products/cfg/{vitis_version}/{build_id}.cfg
    #  e.g.  products/cfg/2024.2/streams.cfg
    # --------------------------------------------------
    cfg_template = (os.path.join (project.products_root,
                                  'cfg',
                                  '{vitis_version}',
                                  '{build_id}-{fpga_id}.cfg'))

    # -----------------------------------------------
    # Name the component after the configuration file
    # -----------------------------------------------
    cmp_template = '{cfg_name}'
    

    targets      = [ { 'Components'        : components,
                       'ConfigurationName' : cfg_template,
                       'ComponentName'     : cmp_template } ]

    package_ip   = Product.Package.Ip (name    = '{cfg_name}',
                                       vendor  = 'SLAC',
                                       version = '1.0.0',
                                       library = 'hls')

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

#### Convenience Declaration
Since this is Python, defining variables and symbols to both shorten typing, capture common concepts or make the code more readable is common and encourage. There is no reason not to use all the techniques available to do this.
<pre>
   Product = project.Product
</pre>

This is merely shorthand used to access the inner classes defined in the Project class.  

#### Source File and Include Definitons
<pre>
  testbench = os.path.join (project.root, '../src/example/ExampleTb.cc')
  syn       = os.path.join (project.root, '../src/example/ExampleHls.cc')

  includes  = [ {'file' : os.path.join (project.root, '../', 'include'),
                 'type' : 'rel_file'} ]
</pre>
The first 2 lines locates the testbench and hls files relative to the project's root.<br>
The third line locates the the include file relative to the project's root.  (It assumed that include files in the .cc files are referenced in the usual "example/Example.hh" fashion).  
- Locating the include files is less straightforward than locating the source files, To accomodate this, two attributes are attached to the definition.

| Key           | Meaning |
| :-------------|:--------|
| file          | Specifies files to be include are normal files.<br> In more complicated projects, there may be other ways to specify this.<br>Essentially, this is an attempt to allow future flexibility |
| type          | '*rel_file*' specifies to make the include path relative to configuration file.<br> This is the recommended method keeping explicit references to absolute paths out of the configuration directory so they only depend on relative paths.<br> One of goals if *hlsBs* was to allow configuration files to be saved in a repository by one user and checked and used by another.<br><br> The alternative is '*abs*' which allows absolute paths.<br> This would be used if the include path is not within the project's directory tree.|

Also noteworthy are
- The use of Python dictionaries, these are used extensively in the project file
- The fact that the *includes* are specfied as list. A project may have more than one include path.

#### Build Defintion 
<pre>
    builds  = { 'top'       : 'doit',
                'tb'        : [ { 'file'     : testbench,
                                 'includes' :  includes} ],
                'syn'       : [ { 'file'     :       syn,
                                  'includes' :  includes} ],
                'csim_argv'  : '--ntests=10',
                'cosim_argv' : '--ntests=100'}
</pre>
This specifies

| Key            | Meaning   |
|:---------------|:----------|
| top            | Name of the top level HLS method |
| tb             | The test bench file and its include paths.<br>Note this can be a list with each file having its own include path.<br> If either of both the *testbench' and 'includes' where themselves lists, each *testbench* file in the list would have all the *include* paths. |
| syn           | The same structure as the *testbench* files, excepth for the HLS/synthesis files. |
| csim_argv     | The command line arguments to pass to *csim.exe* |
| cosim_argv    | The command line arguments to pass to *cosim.exe*|

Please ee the section titled *A word of caution on environment variables*


##### Fpga Definition
<pre>
    # --------------------------------------------------
    # The following symbolics are exported to be used in
    # configuration and component name generation
    #     fpga_part fpga_clock and fpga_id
    # --------------------------------------------------
    fpgas        = [ Product.Fpga ('xcku115-flvb2104-2-i', '6',  None, '6ns'),
                     Product.Fpga ('xcku115-flvb2104-2-i', '5',  None, '5ns')]
</pre>
This defines a list of two FPGAs giving their
- Part
- Clocking
- Uncertainity -- *None* means use the default
- An idenitfier

The identifier needs further explaination. One of the key aspects of creating a component is that, since all component definitions reside in the workspace directory, they must be uniquely named.  The intent is in this example is the same code is built using 2 different FPGAs, resulting in 2 components.  The *fpga id*, as can the *fpga_part* abd *fpga_clock*, can be used a logical symbols to generate a unique component name.  Here the *fpga_clock* could serve the same purpose since it is only difference. However, if the part, clock and uncertainity were all different, the *fpga_id* serves as convenient nickname for the combination.  Choosw a meannful name, so that it apparent from the component name what it means.  Do not use things like 'f0' and 'f1' which convey nothing.

#### Component Composition
<pre>
    # ----------------------------------------------------------------
    # Create 2 components, one for each of the Fpgas
    # ----------------------------------------------------------------
    components   = (Product.Builds ('build', [ ['example', build] ]),
                    Product.Fpgas  ('fpga',  fpgas))
</pre>
A component is composed of its build combined with its FPGAs. Note that each build has a name, again to be used to name the component, as does the fpga.  Also note that 'build' is a list.  This would be useful the project contains two distinct products, say a separate HLS to read the data and another to write the data.

#### Configuration File  Name Generation
This defines a template of how to name the configuration file and component files. 
<pre>
    # --------------------------------------------------
    # Configuration file name template
    # Makes  products/cfg/{vitis_version}/{build_id}.cfg
    #  e.g.  products/cfg/2024.2/example.cfg
    # --------------------------------------------------
    cfg_template = (os.path.join (project.products_root,
                                  'cfg',
                                  '{vitis_version}',
                                  '{build_id}-{fpga_id}.cfg'))
</pre>
It is recommended that even in the simplest HLS project consisting of a single component, one uses the logical symbols to generate the configuration file name. Here, in addition to using the *build_id* and the *fpga_id*, the vitis version is included in the directory path specification. 

#### Configuration Name Generation
This defines a template of how to name the configuration
<pre>
    # -----------------------------------------------
    # Name the component after the configuration file
    # -----------------------------------------------
    cmp_template = '{cfg_name}'
</pre>
In general, naming the component after the configuration file name is the most straight-forward.  As always, there may be instances where the freedom to name it otherwise is useful. 

A nuance should be noted here. While the component name must be unique, the configuration file name need not be since, while not recommended, the configuration file can be placed in its own distinguishing directory.  If this is done, *hlsBs* supplies the logical *cfg_dir* for the first directory to help in generating a unique component name. Note that only the first subdirectory is provided. There is currently no prescribed method if this is sitll not sufficient to generate a unique component name.


#### Complete Configuration and Component Generation
This definition includes the components themselves and how to name generated configuration file(s) and component(s)
<pre>
    targets      = [ { 'Components'        : components,
                       'ConfigurationName' : cfg_template,
                       'ComponentName'     : cmp_template } ]
</pre>
NOTE: The name *target*, like all the identifiers appearing on the left hand side of the *=* is just the name of python variable and has no signficance.  Frankly, better names are needed to convey what they stand for.<br>
Also note: It is only for clarity that temporary names like *components*, *cfg_template* and *cmp_template* exist. One could dispence with them and directly add their definitions.   Again, treat this as any other piece of Python code and strive to make it as clear as possible. 


This completes the definition of the target components. What follows is bookkeeping and information needed by the build chain.


#### Package IP
This is packaging identification. The only noteworthy thing is the *name* is chosen to be the configuration name. It could have been the component name or any name composed of absolute text and logical symbols. See the section on *Configuration File Paths and Components Names* to help make the right decision for a given project.

<pre>
    package_ip   = Product.Package.Ip (name    = '{cfg_name}',
                                       vendor  = 'SLAC',
                                       version = '1.0.0',
                                       library = 'hls')
</pre>

Currently the Version can be taken from the logical symbol  {git_tag} if it exists.  An improvement should be to be able to specify this on the command line. 

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

|---------|----------|
| Key.    | Meaning  |
|:------- | :--------|
| project | The controlling project |
| targets | The target components   |
| package | The IP and output packaging information |
| vivado  | The vivado information



## Into the Weeds
This part is certainly getting into the weeds, but an example pointing up these nuances may actually help understand the common case and clarify what are truly the same and what are *usually* the same.


###Configuration File Paths and Components
In most cases configuration file name and component name are the same, but this is not strictly necessary. As in illustrating unusual cases, this example is somewhat contrived.  Suppose the same underlying code is used to generate components that differ only by the targetted FPGA.  Here one could use {fpga_id}, not a part of the configuration name, but as part of the directory path.  This would allow all the configuration names to be the same since they reside in different directories.  The configuration file path template might look something like

<pre>
     cfg_template = os.path.join (project.products_root, '{vitis_version}', '{fpga_id}', '{build_id}') + 'cfg'
</pre>

The component name could not be the configuration file name, since it is not unique.  In this case it might be

<pre>
   cmp_template = {vitis_version}-{fpga_id}-{build_id}
</pre>

In this example, using the {cfg_name} could be used to make the Project.Ip's name the same independent of the FPGA it is deployed on. Of course there are other ways to achieve this, like simply naming the Project.Ip's name {build_id}.

As a side-note the logical symbold {cmp_dir} is the first sub-directory where the configuration file resides.


### A word of caution of enviroment variables: 
The values, *e.g.* file paths, may include environment variables, but because HLS configuration files do not allow environment variables, these must be translated when the configuration file is created. Since the testbench, hls/synthesis and include file paths are generally reinterpreted as relative to the configuration file, this is not a problem. However for *csim_argv* and *cosim_argv*, the choice to defer the translation to runtime would be desireable. Ideas to defer translatation until run time are being explored.  

> To illustrate how insidious this is consider the caae when the configuration file is built and the environment variables are not defined.  For file and include paths, the building will fail and certainly be noticed.  However, unless the resulting configuration file is carefully examined, an environment variables in the two *argv* will not have been translated and the paths will be incorrect and not noticed till running. 

> Even worse, if the configuration is built not using *hlsBs*, but in the IDE/GUI, the value of the environment variables are whateever they were when launched.  If one assumes they are the values you see when the configuration file is made, a sad ending may awwait you.  This is not a theortical problem. It cost the author a couple of days to learn this.  It is one reason why hlsBs is very careful in its handling of environmental variables.

> Even more worse, if the execution is by prechance in a directory containing the test files, it might succeed, but tomorrow, when in a different directory, it might mysteriously fail.  Even worse, suppose there were 2 test sets and on day 1 the current directory was set 1 and on day 2 it was set 2.  Years of life could be lost trying to understand why the 2 days results are different.

> Just to illustrate the bizarrites of HLS, there were 2 promising methods to defer the translation, unfortunately one only works in running csim.exe straight, but not under gdb and visa-versa. Considered writing 2 confifuration files, one for each environment, but that creates a whole other host of problems.
 
 
#### Finally - User Input/Feedback Wanted
Improvements, such as being able to specify the Package version on the command line, will come with using *hlsBs* and  discovering what features would be useful. While a lot thought went into this, somethings only come with actual usage, *i.e.* the author didn't think of everything.
