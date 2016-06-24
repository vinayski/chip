#!/bin/bash

set -x

SCRIPTDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $SCRIPTDIR/common.sh

BUILDROOT_OUTPUT_DIR=".new/firmware"
FIRMWARE_DIR=".new/firmware"

DL_URL="http://opensource.nextthing.co/chip/images"

METHOD=fel
FLAVOR=buildroot
BRANCH=stable
DL_DIR=".dl"

while getopts "fsdpb:" opt; do
  case $opt in
    f)
      echo "fastboot enabled"
      METHOD=fb
      ;;
    s)
      echo "server selected"
      FLAVOR=serv
      ;;
    d)
      echo "desktop selected"
      METHOD=fb ##must fastboot
      FLAVOR=desk
      ;;
    p)
      echo "pocketchip selected"
      METHOD=fb ##must fastboot
      FLAVOR=pocket
      ;;
    b)
      echo "${BRANCH} branch selected"
      BRANCH="$OPTARG"
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
  esac
done

function require_directory {
  if [[ ! -d "${1}" ]]; then
      mkdir -p "${1}"
  fi
}

function dl_check {
	CACHENUM=$(curl $DL_URL/$BRANCH/$FLAVOR/latest)
	
	if [[ ! -f "$DL_DIR/$BRANCH-$FLAVOR-$METHOD-b${CACHENUM}.tar.gz" ]]; then
		echo "New image available"
		
		rm -rf $BRANCH-$FLAVOR-$METHOD*
		
		echo "Downloading.."
		pushd $DL_DIR
		if ! wget -O $BRANCH-$FLAVOR-$METHOD-b${CACHENUM}.tar.gz\
		 $DL_URL/$BRANCH/$FLAVOR/${CACHENUM}/img-$FLAVOR-$METHOD.tar.gz; then
			echo "download of $BRANCH-$FLAVOR-$METHOD-b${CACHENUM} failed!"
			exit $?
		fi
		
		echo "Extracting.."
		tar -xf $BRANCH-$FLAVOR-$METHOD-b${CACHENUM}.tar.gz
		mv img-* $BRANCH-$FLAVOR-$METHOD-b${CACHENUM}
		
		echo "Staging for flashing"
		cp -R $BRANCH-$FLAVOR-$METHOD-b${CACHENUM}/images ../$FIRMWARE_DIR/
		popd
	else
		pushd $DL_DIR
		echo "Cached files located"
		echo "Staging for flashing"
		cp -R $BRANCH-$FLAVOR-$METHOD-b${CACHENUM}/images ../$FIRMWARE_DIR/
		popd
	fi
}

FEL=fel

METHOD=${METHOD:-fel}
AFTER_FLASHING=${AFTER_FLASHING:-wait}


NAND_ERASE_BB=false
if [ "$1" == "erase-bb" ]; then
	NAND_ERASE_BB=true
fi

PATH=$PATH:$BUILDROOT_OUTPUT_DIR/host/usr/bin
PADDED_SPL="${BUILDROOT_OUTPUT_DIR}/images/sunxi-spl-with-ecc.bin"
PADDED_SPL_SIZE=0
UBOOT_SCRIPT="${BUILDROOT_OUTPUT_DIR}/images/uboot.scr"
UBOOT_SCRIPT_MEM_ADDR=0x43100000
SPL="$BUILDROOT_OUTPUT_DIR/images/sunxi-spl.bin"
SPL_MEM_ADDR=0x43000000
UBOOT="$BUILDROOT_OUTPUT_DIR/images/u-boot-dtb.bin"
PADDED_UBOOT="$BUILDROOT_OUTPUT_DIR/images/padded-u-boot"
UBOOT_MEM_ADDR=0x4a000000
UBI="$BUILDROOT_OUTPUT_DIR/images/rootfs.ubi"
UBI_MEM_ADDR=0x4b000000

assert_error() {
	ERR=$?
	ERRCODE=$1
	if [ "${ERR}" != "0" ]; then
		if [ -z "${ERR}" ]; then
			exit ${ERR}
		else
			exit ${ERRCODE}
		fi
	fi
}

echo == preparing images ==
require_directory "$FIRMWARE_DIR"
require_directory "$DL_DIR"
dl_check

echo == upload the SPL to SRAM and execute it ==
if ! wait_for_fel; then
  echo "ERROR: please make sure CHIP is connected and jumpered in FEL mode"
fi
${FEL} spl "${SPL}"
assert_error 128

sleep 1 # wait for DRAM initialization to complete

echo == upload spl ==
${FEL} write $SPL_MEM_ADDR "${PADDED_SPL}" || ( echo "ERROR: could not write ${PADDED_SPL}" && exit $? )
assert_error 129

echo == upload u-boot ==
${FEL} write $UBOOT_MEM_ADDR "${PADDED_UBOOT}" || ( echo "ERROR: could not write ${PADDED_UBOOT}" && exit $? )
assert_error 130

echo == upload u-boot script ==
${FEL} write $UBOOT_SCRIPT_MEM_ADDR "${UBOOT_SCRIPT}" || ( echo "ERROR: could not write ${UBOOT_SCRIPT}" && exit $? )
assert_error 131

if [[ "${METHOD}" == "fel" ]]; then
	echo == upload ubi ==
	${FEL} --progress write $UBI_MEM_ADDR "${UBI}"

	echo == execute the main u-boot binary ==
	${FEL} exe $UBOOT_MEM_ADDR

	echo == write ubi ==
else
	echo == execute the main u-boot binary ==
	${FEL} exe $UBOOT_MEM_ADDR
	assert_error 132

	echo == waiting for fastboot ==
	if wait_for_fastboot; then
		fastboot -i 0x1f3a -u flash UBI $UBI
		assert_error 134

		fastboot -i 0x1f3a continue
		assert_error 135
	else
		exit 1
	fi
fi

if [[ "${METHOD}" == "fel" ]]; then
	if ! wait_for_linuxboot; then
		echo "ERROR: could not flash":
		exit 1
	else
		${SCRIPTDIR}/verify.sh
	fi
fi

 
