# ruckus

[![DOE Code](https://www.osti.gov/assets/img/doe_code_logo.png)](https://www.osti.gov/doecode/biblio/8165)

A Makefile/TCL hybrid firmware build system for SLAC FPGA and ASIC projects.

ruckus provides a standard library of TCL procedures and Makefile targets that
abstract Vivado, Vitis HLS, GHDL, Cadence Genus, and Synopsys DC build flows into
a consistent `make bit` / `make syn` interface. It handles source loading, IP core
management, hook script injection, and firmware release packaging.

## Documentation

**Full documentation:** https://slaclab.github.io/ruckus/

- [Getting Started Tutorial](https://slaclab.github.io/ruckus/tutorial/first_vivado_build.html)
- [TCL API Reference](https://slaclab.github.io/ruckus/reference/tcl_api.html)
- [Makefile Reference](https://slaclab.github.io/ruckus/reference/makefile_reference.html)
- [How-To Guides](https://slaclab.github.io/ruckus/how-to/index.html)

## Prerequisites

- Linux operating system
- Licensed EDA tool installation (Vivado, Vitis, Cadence Genus, or Synopsys DC)
- Python 3 with pip packages: `gitpython pygithub pyyaml`

## Basic Usage

```bash
# Clone your firmware repository (ruckus is typically a submodule)
git clone --recursive https://github.com/slaclab/MyFirmware
cd MyFirmware/firmware/targets/MyTarget

# Create build directory (one-time setup)
mkdir ../../../../build

# Run the build
make bit
```

In your project `Makefile`:

```makefile
ifndef PRJ_PART
export PRJ_PART = xcku15p-ffva1760-2-e
endif

include $(TOP_DIR)/submodules/ruckus/system_vivado.mk
```

See the [full documentation](https://slaclab.github.io/ruckus/) for complete setup
instructions, all supported tool backends, and the firmware release workflow.
