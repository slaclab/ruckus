##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################
# Ubuntu Software Setup:
#  $ sudo apt update
#  $ sudo apt install gcc-msp430 gdb-msp430 srecord -y
##############################################################################
# Based this Makefile on this code on github:
# https://gist.github.com/cdwilson/1493045
##############################################################################

# Alias the commands
CC       := msp430-gcc
CXX      := msp430-g++
LD       := msp430-ld
AR       := msp430-ar
AS       := msp430-gcc
GASP     := msp430-gasp
NM       := msp430-nm
OBJCOPY  := msp430-objcopy
RANLIB   := msp430-ranlib
STRIP    := msp430-strip
SIZE     := msp430-size
READELF  := msp430-readelf
MAKETXT  := srec_cat
CP       := cp -p
RM       := rm -f
MV       := mv
MKDIR_P  := mkdir -p

##############################################################################

# Project name
ifndef PROJECT
export PROJECT = $(notdir $(PWD))
endif

# Project dir path
ifndef PROJ_DIR
export PROJ_DIR = $(abspath $(PWD))
endif

# "top" direct path
ifndef TOP_DIR
export TOP_DIR  = $(abspath $(PROJ_DIR)/../..)
endif

# Project Build Directory
ifndef OUT_DIR
export OUT_DIR  = $(abspath $(TOP_DIR)/build/$(PROJECT))
endif

# Pointer to ruckus directory
export RUCKUS_DIR = $(TOP_DIR)/submodules/ruckus

# List all the source directories
ifndef SRCS_DIR
export SRCS_DIR = $(PROJ_DIR)/src
endif

# List all the source directories
ifndef SRCS_LIST
export SRCS_LIST = $(wildcard $(PROJ_DIR)/src/*.c)
endif

# List all the header directories
ifndef INC_DIRS
export INC_DIRS = $(PROJ_DIR)/include
endif

# Specifies the options passed to the flags for C simulation
INC_FLAGS := $(addprefix -I,$(INC_DIRS))

# Specifies the options passed to the linker for C simulation
ifndef LDFLAGS
export LDFLAGS = -mmcu=$(MCU) -L/usr/lib -Wl,-Map=$(BUILD_DIR)/$(TARGET).map
endif

# Specifies the options passed to the compiler for C simulation
ifndef CFLAGS
export CFLAGS = -mmcu=$(MCU) -g -Os -Wall -Wunused $(INC_FLAGS)
endif

# Build and image output paths
BUILD_DIR := $(OUT_DIR)/.obj
IMAGE_DIR := $(PROJ_DIR)/images

# the file which will include dependencies
OBJS := $(SRCS_LIST:$(SRCS_DIR)/%.c=$(BUILD_DIR)/%.o)

# Source shared/common Makefile script
include $(TOP_DIR)/submodules/ruckus/system_shared.mk

##############################################################################
all: clean dir $(IMAGE_DIR)/$(IMAGENAME).elf
##############################################################################
$(BUILD_DIR)/%.o: $(SRCS_DIR)/%.c
	$(MKDIR_P) $(dir $@)
	@echo "Compiling $@ from $<"
	$(CC) -c $(CFLAGS) -o $@ $<
##############################################################################
$(IMAGE_DIR)/$(IMAGENAME).elf: $(OBJS)
	@echo "Linking $@"
	$(CC) $(OBJS) $(LDFLAGS) $(LIBS) -o $@
	@echo
	@echo ">>>> Size of Firmware <<<<"
	$(SIZE) $@
	@echo
##############################################################################
.PHONY : test
test:
	@echo PROJECT: $(PROJECT)
	@echo MCU: $(MCU)
	@echo PRJ_VERSION: $(PRJ_VERSION)
	@echo IMAGENAME: $(IMAGENAME)
	@echo GIT_HASH_LONG: $(GIT_HASH_LONG)
	@echo GIT_HASH_SHORT: $(GIT_HASH_SHORT)
	@echo CFLAGS: $(CFLAGS)
	@echo LDFLAGS: $(LDFLAGS)
	@echo TOP_DIR: $(TOP_DIR)
	@echo RUCKUS_DIR: $(RUCKUS_DIR)
	@echo OUT_DIR: $(OUT_DIR)
	@echo PROJ_DIR: $(PROJ_DIR)
	@echo BUILD_DIR: $(BUILD_DIR)
	@echo INC_DIRS: $(INC_DIRS)
	@echo SRCS_DIR: $(SRCS_DIR)
	@echo OBJS: $(OBJS)
##############################################################################
.PHONY : dir
dir :
	@test -d $(TOP_DIR)/build/ || { \
			 echo ""; \
			 echo "Build directory missing!"; \
			 echo "You must create a build directory at the top level."; \
			 echo ""; \
			 echo "This directory can either be a normal directory:"; \
			 echo "   mkdir $(TOP_DIR)/build"; \
			 echo ""; \
			 echo "Or by creating a symbolic link to a directory on another disk:"; \
			 echo "   ln -s /tmp/build $(TOP_DIR)/build"; \
			 echo ""; false; }
	@test -d $(OUT_DIR) || mkdir $(OUT_DIR)
	$(MKDIR_P) $(BUILD_DIR)
	$(MKDIR_P) $(IMAGE_DIR)
##############################################################################
.PHONY : clean
clean:
	$(RM) -rf $(BUILD_DIR)
##############################################################################
