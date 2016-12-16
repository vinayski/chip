#!/bin/bash

IMAGES_DIR=$1
BUILDROOT_DIR=${IMAGES_DIR%/}
BUILDROOT_DIR=${BUILDROOT_DIR%/*/*}

echo "IMAGES_DIR=${IMAGES_DIR}"
echo "BUILDROOT_DIR=${BUILDROOT_DIR}"

mk_buildroot_images -N nand_configs/Toshiba-SLC-4G-TC58NVG2S0H.config -d "${IMAGES_DIR}" "${BUILDROOT_DIR}"

ln -sf "${IMAGES_DIR}/spl-40000-1000-100.bin"    "${IMAGES_DIR}/flash-spl.bin"      
ln -sf "${IMAGES_DIR}/uboot-40000.bin"           "${IMAGES_DIR}/flash-uboot.bin"    
ln -sf "${IMAGES_DIR}/uboot-env-400000.bin"      "${IMAGES_DIR}/flash-uboot-env.bin"
ln -sf "${IMAGES_DIR}/chip-40000-1000.ubi.sparse""${IMAGES_DIR}/flash-rootfs.bin"   
