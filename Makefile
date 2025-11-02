# ==============================================================================
#
# Project: 		CoreaLoader
# Name: 		Three-Stage Bootloader Build System
# File: 		Makefile
# Author: 		@lorick_la_brique
# Date: 		02 November 2025 - Revision 1
# Description: 	This Makefile manages the assembly of the 16-bit and 64-bit 
#              	bootloader stages and creates a single 1.44MB bootable floppy 
#              	disk image (boot.img).
#
# ==============================================================================

# Configuration Variables
BUILD_DIR = build
BOOTLOADER_SRC = src/bootloader.asm
SECOND_STAGE_SRC = src/second_stage.asm
BOOTLOADER_BIN = $(BUILD_DIR)/bootloader.bin
SECOND_STAGE_BIN = $(BUILD_DIR)/second_stage.bin
BOOT_PAYLOAD = $(BUILD_DIR)/boot.bin
IMAGE_NAME = $(BUILD_DIR)/boot.img
IMAGE_SIZE_KB = 1440 # Standard 1.44MB floppy disk size in KB

# Default target: build the image
.PHONY: all
all: $(IMAGE_NAME)

# ------------------------------------------------------------------------------
# Dependencies and Compilation
# ------------------------------------------------------------------------------

# Create the build directory if it doesn't exist
$(BUILD_DIR):
	@mkdir -p $(BUILD_DIR)
	@echo "Creating build directory $(BUILD_DIR)/"

# Compile the first stage (MBR/VBR)
$(BOOTLOADER_BIN): $(BOOTLOADER_SRC) | $(BUILD_DIR)
	@echo "Assembling $< to $(BOOTLOADER_BIN)..."
	nasm -f bin $< -o $@

# Compile the second stage (Transition to Long Mode)
$(SECOND_STAGE_BIN): $(SECOND_STAGE_SRC) | $(BUILD_DIR)
	@echo "Assembling $< to $(SECOND_STAGE_BIN)..."
	nasm -f bin $< -o $@

# Concatenate both stages into a single payload file
$(BOOT_PAYLOAD): $(BOOTLOADER_BIN) $(SECOND_STAGE_BIN)
	@echo "Concatenating boot stages..."
	cat $(BOOTLOADER_BIN) $(SECOND_STAGE_BIN) > $@

# ------------------------------------------------------------------------------
# Disk Image Creation
# ------------------------------------------------------------------------------

# Target to create the disk image
$(IMAGE_NAME): $(BOOT_PAYLOAD)
	@echo "Creating disk image $(IMAGE_NAME) of $(IMAGE_SIZE_KB)KB..."
	# 1. Create a blank 1.44MB image file
	dd if=/dev/zero of=$(IMAGE_NAME) bs=1024 count=$(IMAGE_SIZE_KB) 2>/dev/null
	# 2. Copy the payload content to the start of the image (without truncation)
	dd if=$(BOOT_PAYLOAD) of=$(IMAGE_NAME) conv=notrunc 2>/dev/null
	@echo "Bootable image successfully created."

# ------------------------------------------------------------------------------
# Utility Commands
# ------------------------------------------------------------------------------

# Target to clean up all generated files
.PHONY: clean
clean:
	@echo "Cleaning up build files..."
	rm -f $(BOOTLOADER_BIN) $(SECOND_STAGE_BIN) $(BOOT_PAYLOAD) $(IMAGE_NAME)
	rm -rf $(BUILD_DIR)