# ruckus
A Makefile/TCL Vivado build system

# Documentation

[An Introduction to Ruckus Presentation](https://docs.google.com/presentation/d/1kvzXiByE8WISo40Xd573DdR7dQU4BpDQGwEgNyeJjTI/edit?usp=sharing)

[Doxygen Homepage](https://slaclab.github.io/ruckus/html/index.html)

[Support Homepage](https://confluence.slac.stanford.edu/display/ppareg/Build+System%3A+Vivado+Support)

# List of user defined TCL scripts

User defined TCL scripts are located in the target's vivado directory.
These user defined TCL scripts are not required expect for when the make target is "prom". 
Then the promgen.tcl must be defined and exist. 

Here's a full list of user defined TCL scripts:

| User Filename      | source .TCL location           | 
| ------------------ | ------------------------------ | 
| project_setup.tcl  | vivado_project.tcl             | 
| properties.tcl     | vivado_properties.tcl          | 
| messages.tcl       | vivado_messages.tcl            | 
| sources.tcl        | vivado_sources.tcl             | 
| pre_synthesis.tcl  | vivado_pre_synthesis.tcl       | 
| pre_synth_run.tcl  | vivado_pre_synth_run.tcl       | 
| post_synth_run.tcl | vivado_post_synth_run.tcl      | 
| post_synthesis.tcl | vivado_post_synthesis.tcl      | 
| post_route.tcl     | vivado_post_route.tcl          | 
| promgen.tcl        | system_vivado.mk               | 
