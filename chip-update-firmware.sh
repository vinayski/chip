#!/bin/bash
FW_DIR="$(pwd)/.firmware"
FW_IMAGE_DIR="${FW_DIR}/images"
S3_URL="https://s3-ap-northeast-1.amazonaws.com/stak-images/firmware/chip/stable/5/images"

function require_directory {
	if [[ ! -d "${1}" ]]; then
		mkdir -p "${1}"
	fi
}

function cache_download {
	if [[ ! -f "${1}/${2}" ]]; then
		wget -P "${FW_IMAGE_DIR}" "${S3_URL}/${2}" ||
			exit 1
	fi
}

require_directory "${FW_IMAGE_DIR}"
cache_download "${FW_IMAGE_DIR}" rootfs.ubi
cache_download "${FW_IMAGE_DIR}" sun5i-r8-chip.dtb
cache_download "${FW_IMAGE_DIR}" sunxi-spl.bin
cache_download "${FW_IMAGE_DIR}" uboot-env.bin
cache_download "${FW_IMAGE_DIR}" zImage
cache_download "${FW_IMAGE_DIR}" u-boot-dtb.bin

BUILDROOT_OUTPUT_DIR="${FW_DIR}" ./chip-fel-flash.sh
