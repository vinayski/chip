#!/bin/bash

set -x

SCRIPTDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $SCRIPTDIR/common.sh
source $SCRIPTDIR/env.sh
export AWS_DEFAULT_REGION=us-west-2

BUILDROOT_OUTPUT_DIR=".new/firmware"
FIRMWARE_DIR=".new/firmware"

DL_METHOD=fel
METHOD=fel
DL_FLAVOR=serv
DL_DIST=rootfs
DL_DIR=".dl"

while getopts "fdphnu:" opt; do
  case $opt in
    f)
      echo "fastboot enabled"
      DL_METHOD=fb
      METHOD=fastboot
      ;;
    d)
      echo "desktop selected"
      DL_FLAVOR=desk
      ;;
    p)
      echo "desktop selected"
      DL_FLAVOR=pocket
      ;;
    h)
      echo "desktop selected"
      DL_FLAVOR=hdmi-fixture-rootfs
      ;;
    n)
      echo "next enabled"
      DL_DIST=testing-rootfs
      ;;
    u)
      BUILDROOT_OUTPUT_DIR="${OPTARG}"
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
  esac
done

if [[ "${DL_FLAVOR}" == "pocket" ]] && [[ "${DL_DIST}" == "testing-rootfs" ]]; then
  DL_FLAVOR="pocket-next"
fi

echo "BUILDROOT_OUTPUT_DIR = $BUILDROOT_OUTPUT_DIR"

function require_directory {
  if [[ ! -d "${1}" ]]; then
      mkdir -p "${1}"
  fi
}

function dl_check {
	wget -O $DL_DIR/latest.md5\
		opensource.nextthing.co/chippian/$DL_DIST/latest.md5

	pushd $DL_DIR
	if [[ $(cat latest.md5 | grep "`md5sum img-$DL_FLAVOR-$DL_METHOD.tar.gz`")\
	 && -d "img-$DL_FLAVOR-$DL_METHOD/images" ]]; then
		echo "Cached files located"
		echo "Staging for flashing"
		cp -R img-$DL_FLAVOR-$DL_METHOD/images ../$FIRMWARE_DIR/
	else
		echo "New image available"
		rm -rf img-$DL_FLAVOR-$DL_METHOD*
	
    if [[ "${DL_FLAVOR}"=="pocket" || "${DL_FLAVOR}"=="pocket-next" ]]; then	
		  aws s3 cp s3://opensource.nextthing.co/chippian/$DL_DIST/img-$DL_FLAVOR-$DL_METHOD.tar.gz . || exit 1
    else
		  wget opensource.nextthing.co/chippian/$DL_DIST/img-$DL_FLAVOR-$DL_METHOD.tar.gz|| exit 1
    fi

		echo "Extracting.."
		tar -xf img-$DL_FLAVOR-$DL_METHOD.tar.gz
		echo "Staging for flashing"
		cp -R img-$DL_FLAVOR-$DL_METHOD/images ../$FIRMWARE_DIR/
	fi
	popd
}


require_directory "$FIRMWARE_DIR"
require_directory "$DL_DIR"

dl_check

FEL=fel

METHOD=${METHOD:-fel}
AFTER_FLASHING=${AFTER_FLASHING:-wait}


NAND_ERASE_BB=false
if [ "$1" == "erase-bb" ]; then
	NAND_ERASE_BB=true
fi

PATH=$PATH:$BUILDROOT_OUTPUT_DIR/host/usr/bin
TMPDIR=`mktemp -d -t chipflashXXXXXX`
PADDED_SPL="${BUILDROOT_OUTPUT_DIR}/images/sunxi-spl-with-ecc.bin"
PADDED_SPL_SIZE=0
UBOOT_SCRIPT="${BUILDROOT_OUTPUT_DIR}/images/uboot.scr"
UBOOT_SCRIPT_MEM_ADDR=0x43100000
UBOOT_SCRIPT_SRC="$TMPDIR/uboot.cmds"
SPL="$BUILDROOT_OUTPUT_DIR/images/sunxi-spl.bin"
SPL_MEM_ADDR=0x43000000
UBOOT="$BUILDROOT_OUTPUT_DIR/images/u-boot-dtb.bin"
PADDED_UBOOT="$BUILDROOT_OUTPUT_DIR/images/padded-u-boot"
PADDED_UBOOT_SIZE=0x400000
UBOOT_MEM_ADDR=0x4a000000
UBI="$BUILDROOT_OUTPUT_DIR/images/rootfs.ubi"
SPARSE_UBI="${TMPDIR}/rootfs.ubi.sparse"
UBI_MEM_ADDR=0x4b000000

UBI_SIZE=`filesize $UBI | xargs printf "0x%08x"`
PAGE_SIZE=16384
OOB_SIZE=1280

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
#prepare_images
#prepare_uboot_script

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

	echo == creating sparse image ==
#	img2simg ${UBI} ${SPARSE_UBI} $((2*1024*1024))
	assert_error 133

	echo == waiting for fastboot ==
	if wait_for_fastboot; then
		fastboot -i 0x1f3a -u flash UBI $UBI
		assert_error 134

		fastboot -i 0x1f3a continue
		assert_error 135
	else
		rm -rf "${TMPDIR}"
		exit 1
	fi
fi

if [[ "${METHOD}" == "fel" ]]; then
	if ! wait_for_linuxboot; then
		echo "ERROR: could not flash":
		rm -rf ${TMPDIR}
		exit 1
	else
		${SCRIPTDIR}/verify.sh
	fi
fi
rm -rf "${TMPDIR}"
