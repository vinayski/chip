#!/bin/bash
FW_DIR="$(pwd)/.firmware"
FW_IMAGE_DIR="${FW_DIR}/images"
S3_URL="https://s3-ap-northeast-1.amazonaws.com/stak-images/firmware/chip/stable/latest"

FLASH_SCRIPT=./chip-fel-flash.sh

function require_directory {
	if [[ ! -d "${1}" ]]; then
		mkdir -p "${1}"
	fi
}

function cache_download {
	if [[ ! -f "${1}/${2}" ]]; then
    
    LATEST_URL="$(wget -q -O- ${S3_URL})"
		wget -P "${FW_IMAGE_DIR}" "${LATEST_URL}images/${2}" ||
			exit 1
	fi
}


while getopts "uf" opt; do
  case $opt in
    u)
      echo "updating cache"
      if [[ -d "$FW_IMAGE_DIR" ]]; then
        rm -rf $FW_IMAGE_DIR
      fi
      ;;
    f)
      echo "fastboot enabled"
      FLASH_SCRIPT=./chip-fel-fastboot.sh
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
  esac
done

require_directory "${FW_IMAGE_DIR}"
cache_download "${FW_IMAGE_DIR}" rootfs.ubi
cache_download "${FW_IMAGE_DIR}" sun5i-r8-chip.dtb
cache_download "${FW_IMAGE_DIR}" sunxi-spl.bin
cache_download "${FW_IMAGE_DIR}" uboot-env.bin
cache_download "${FW_IMAGE_DIR}" zImage
cache_download "${FW_IMAGE_DIR}" u-boot-dtb.bin

RETURNVAL=$(BUILDROOT_OUTPUT_DIR="${FW_DIR}" ${FLASH_SCRIPT})
exit $(( ${RETURNVAL} ))
