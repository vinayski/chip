#!/bin/bash

SCRIPTDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $SCRIPTDIR/common.sh

FEL=fel

METHOD=${METHOD:-fel}

echo "BUILDROOT_OUTPUT_DIR = $BUILDROOT_OUTPUT_DIR"

NAND_ERASE_BB=false
if [ "$1" == "erase-bb" ]; then
	NAND_ERASE_BB=true
fi

PATH=$PATH:$BUILDROOT_OUTPUT_DIR/host/usr/bin
TMPDIR=`mktemp -d -t chipflashXXXXXX`
PADDED_SPL="$TMPDIR/sunxi-padded-spl"
PADDED_SPL_SIZE=0
UBOOT_SCRIPT="$TMPDIR/uboot.scr"
UBOOT_SCRIPT_MEM_ADDR=0x43100000
UBOOT_SCRIPT_SRC="$TMPDIR/uboot.cmds"
SPL="$BUILDROOT_OUTPUT_DIR/images/sunxi-spl.bin"
SPL_MEM_ADDR=0x43000000
UBOOT="$BUILDROOT_OUTPUT_DIR/images/u-boot-dtb.bin"
PADDED_UBOOT="$TMPDIR/padded-uboot"
PADDED_UBOOT_SIZE=0xc0000
UBOOT_MEM_ADDR=0x4a000000
UBI="$BUILDROOT_OUTPUT_DIR/images/rootfs.ubi"
UBI_MEM_ADDR=0x4b000000

UBI_SIZE=`filesize $UBI | xargs printf "0x%08x"`
PAGE_SIZE=16384
OOB_SIZE=1664

prepare_images() {
	local in=$SPL
	local out=$PADDED_SPL

	if [ -e $out ]; then
		rm $out
	fi

  if [[ ! -e "${SCRIPTDIR}/spl-image-builder" ]]; then
    pushd "${SCRIPTDIR}"
    make
    popd
  fi

  "${SCRIPTDIR}/spl-image-builder" -d -r 3 -u 4096 -o 1664 -p 16384 -c 1024 -s 64 "$in" "$out"

  #PADDED_SPL_SIZE in pages
	PADDED_SPL_SIZE=$(filesize "$out")
  PADDED_SPL_SIZE=$(($PADDED_SPL_SIZE / ($PAGE_SIZE + $OOB_SIZE)))
  PADDED_SPL_SIZE=$(echo $PADDED_SPL_SIZE | xargs printf "0x%08x")
  echo "filesize= $(filesize "$out")"
  echo "PADDED_SPL_SIZE=$PADDED_SPL_SIZE"

	# Align the u-boot image on a page boundary
	dd if="$UBOOT" of="$PADDED_UBOOT" bs=16k conv=sync
	UBOOT_SIZE=`filesize "$PADDED_UBOOT" | xargs printf "0x%08x"`
	dd if=/dev/urandom of="$PADDED_UBOOT" seek=$((UBOOT_SIZE / 0x4000)) bs=16k count=$(((PADDED_UBOOT_SIZE - UBOOT_SIZE) / 0x4000))
}

prepare_uboot_script() {
	if [ "$NAND_ERASE_BB" = true ] ; then
		echo "nand scrub -y 0x0 0x200000000" > "${UBOOT_SCRIPT_SRC}"
	else
		echo "nand erase 0x0 0x200000000" > "${UBOOT_SCRIPT_SRC}"
	fi
	echo "echo sunxi_nand config spl" >> "${UBOOT_SCRIPT_SRC}"
  echo "sunxi_nand config spl" >> "${UBOOT_SCRIPT_SRC}"
	echo "echo nand write.raw $SPL_MEM_ADDR 0x0 $PADDED_SPL_SIZE" >> "${UBOOT_SCRIPT_SRC}"
	echo "nand write.raw $SPL_MEM_ADDR 0x0 $PADDED_SPL_SIZE" >> "${UBOOT_SCRIPT_SRC}"
	echo "echo nand write.raw $SPL_MEM_ADDR 0x400000 $PADDED_SPL_SIZE" >> "${UBOOT_SCRIPT_SRC}"
	echo "nand write.raw $SPL_MEM_ADDR 0x400000 $PADDED_SPL_SIZE" >> "${UBOOT_SCRIPT_SRC}"
	echo "sunxi_nand config default" >> "${UBOOT_SCRIPT_SRC}"
	echo "nand write $UBOOT_MEM_ADDR 0x800000 $PADDED_UBOOT_SIZE" >> "${UBOOT_SCRIPT_SRC}"
	echo "setenv bootargs root=ubi0:rootfs rootfstype=ubifs rw earlyprintk ubi.mtd=4" >> "${UBOOT_SCRIPT_SRC}"
	echo "setenv bootcmd 'source \${scriptaddr}; nand slc-mode on; mtdparts; ubi part UBI; ubifsmount ubi0:rootfs; ubifsload \$fdt_addr_r /boot/sun5i-r8-chip.dtb; ubifsload \$kernel_addr_r /boot/zImage; bootz \$kernel_addr_r - \$fdt_addr_r'" >> "${UBOOT_SCRIPT_SRC}"
	echo "saveenv" >> "${UBOOT_SCRIPT_SRC}"

  if [[ "${METHOD}" == "fel" ]]; then
	  echo "nand slc-mode on" >> "${UBOOT_SCRIPT_SRC}"
	  echo "nand write.trimffs $UBI_MEM_ADDR 0x1000000 $UBI_SIZE" >> "${UBOOT_SCRIPT_SRC}"
	  echo "mw \${scriptaddr} 0x0" >> "${UBOOT_SCRIPT_SRC}"
	  echo "boot" >> "${UBOOT_SCRIPT_SRC}"
  else
    echo "echo going to fastboot mode" >>"${UBOOT_SCRIPT_SRC}"
    echo "fastboot" >>"${UBOOT_SCRIPT_SRC}"
    echo "echo " >>"${UBOOT_SCRIPT_SRC}"
    echo "echo *****************[ BOOT ]*****************" >>"${UBOOT_SCRIPT_SRC}"
    echo "echo " >>"${UBOOT_SCRIPT_SRC}"
    echo "echo " >>"${UBOOT_SCRIPT_SRC}"
    echo "boot" >>"${UBOOT_SCRIPT_SRC}"
  fi

	mkimage -A arm -T script -C none -n "flash CHIP" -d "${UBOOT_SCRIPT_SRC}" "${UBOOT_SCRIPT}"
}


##############################################################
#  main
##############################################################
while getopts "f" opt; do
  case $opt in
    f)
      echo "fastboot enabled"
      METHOD=fastboot
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
  esac
done


echo == preparing images ==
prepare_images
prepare_uboot_script

echo == upload the SPL to SRAM and execute it ==
if ! wait_for_fel; then
  echo "ERROR: please make sure CHIP is connected and jumpered in FEL mode"
fi
${FEL} spl "${SPL}"

sleep 1 # wait for DRAM initialization to complete

echo == upload spl ==
${FEL} write $SPL_MEM_ADDR "${PADDED_SPL}"

echo == upload u-boot ==
${FEL} write $UBOOT_MEM_ADDR "${PADDED_UBOOT}"

echo == upload u-boot script ==
${FEL} write $UBOOT_SCRIPT_MEM_ADDR "${UBOOT_SCRIPT}"

if [[ "${METHOD}" == "fel" ]]; then
  echo == upload ubi ==
  ${FEL} --progress write $UBI_MEM_ADDR "${UBI}"

  echo == execute the main u-boot binary ==
  ${FEL} exe $UBOOT_MEM_ADDR

  echo == write ubi ==
else
  echo == execute the main u-boot binary ==
  ${FEL} exe $UBOOT_MEM_ADDR
  
  echo == waiting for fastboot ==
  if wait_for_fastboot; then
    fastboot -S 0 -u flash UBI ${BUILDROOT_OUTPUT_DIR}/images/rootfs.ubi
    fastboot continue
  else
    rm -rf "${TMPDIR}"
    exit 1
  fi
fi

rm -rf "${TMPDIR}"
