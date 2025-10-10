# ruckus
[DOE Code](https://www.osti.gov/doecode/biblio/8165)

A Makefile/TCL `hybrid` Firmware build system

# Documentation

[An Introduction to Ruckus Presentation](https://docs.google.com/presentation/d/1kvzXiByE8WISo40Xd573DdR7dQU4BpDQGwEgNyeJjTI/edit?usp=sharing)

[Doxygen Homepage](https://slaclab.github.io/ruckus/index.html)

[Support Homepage](https://confluence.slac.stanford.edu/display/ppareg/Build+System%3A+Vivado+Support)

# List of user defined TCL scripts

User defined TCL scripts are located in the target's vivado directory.
These user defined TCL scripts are not required.

Here's a full list of user defined TCL scripts:

| User Filename                     | source .TCL location                     |
|-----------------------------------|------------------------------------------|
| project_setup.tcl                 | vivado/project.tcl                       |
| properties.tcl                    | vivado/properties.tcl                    |
| messages.tcl                      | vivado/messages.tcl                      |
| sources.tcl                       | vivado/sources.tcl                       |
| pre_synthesis.tcl                 | vivado/pre_synthesis.tcl                 |
| post_synthesis.tcl                | vivado/post_synthesis.tcl                |
| post_route.tcl                    | vivado/post_route.tcl                    |
| gui.tcl                           | vivado/gui.tcl                           |
| dcp.tcl                           | vivado/dcp.tcl                           |
| post_build.tcl                    | vivado/build.tcl                         |
| batch.tcl                         | vivado/batch.tcl                         |
| pre_msim.tcl                      | vivado/msim.tcl                          |
| post_msim.tcl                     | vivado/msim.tcl                          |
| pre_vcs.tcl                       | vivado/vcs.tcl                           |
| post_vcs.tcl                      | vivado/vcs.tcl                           |
| xsim.tcl                          | vivado/xsim.tcl                          |
| sdk.tcl                           | vivado/post_route.tcl                    |
| promgen.tcl                       | vivado/promgen.tcl                       |
| pre_route_run.tcl                 | vivado/run/pre/route.tcl                 |
| post_route_run.tcl                | vivado/run/post/route.tcl                |
| pre_synth_run.tcl                 | vivado/run/pre/synth.tcl                 |
| post_synth_run.tcl                | vivado/run/post/synth.tcl                |
| pre_opt_run.tcl                   | vivado/run/pre/opt.tcl                   |
| post_opt_run.tcl                  | vivado/run/post/opt.tcl                  |
| pre_phys_opt_run.tcl              | vivado/run/pre/phys_opt.tcl              |
| post_phys_opt_run.tcl             | vivado/run/post/phys_opt.tcl             |
| pre_place_run.tcl                 | vivado/run/pre/place.tcl                 |
| post_place_run.tcl                | vivado/run/post/place.tcl                |
| pre_post_place_power_opt_run.tcl  | vivado/run/pre/post_place_power_opt.tcl  |
| post_post_place_power_opt_run.tcl | vivado/run/post/post_place_power_opt.tcl |
| pre_post_route_phys_opt_run.tcl   | vivado/run/pre/post_route_phys_opt.tcl   |
| post_post_route_phys_opt_run.tcl  | vivado/run/post/post_route_phys_opt.tcl  |
| pre_power_opt_run.tcl             | vivado/run/pre/power_opt.tcl             |
| post_power_opt_run.tcl            | vivado/run/post/power_opt.tcl            |
