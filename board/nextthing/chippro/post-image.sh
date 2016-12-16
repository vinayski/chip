#!/bin/bash

IMAGES_DIR=$1
BUILDROOT_DIR=${IMAGES_DIR%/}
BUILDROOT_DIR=${BUILDROOT_DIR%/*/*}

echo "IMAGES_DIR=${IMAGES_DIR}"
echo "BUILDROOT_DIR=${BUILDROOT_DIR}"

mk_buildroot_images -N nand_configs/Toshiba-SLC-4G-TC58NVG2S0H.config -d "${IMAGES_DIR}" "${BUILDROOT_DIR}"
