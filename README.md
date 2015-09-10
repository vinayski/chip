# CHIP-tools
A collection of scripts for working with CHIP

## Requirements
1) [sunxi-tools](https://github.com/linux-sunxi/sunxi-tools.git)
2) **uboot-tools** from your package manager

## Included Tools
### chip-update-firmware
This tool is used to download the latest firmware release for CHIP and run **chip-fel-flash** with the newest firmware.

### chip-fel-flash
This tool is used to flash a local firmware image to a connected CHIP over FEL

### chip-fel-upload
This tool is used to upload uboot, a linux kernel and an initramfs and launch into it 

