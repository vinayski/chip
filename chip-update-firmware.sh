#!/bin/bash

SCRIPTDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $SCRIPTDIR/common.sh

DL_DIR=".dl"
IMAGESDIR=".new/firmware/images"

DL_URL="http://opensource.nextthing.co/chip/images"

FLAVOR=server
BRANCH=stable

PROBES=(spl-40000-1000-100.bin
 spl-400000-4000-500.bin
 spl-400000-4000-680.bin
 sunxi-spl.bin
 u-boot-dtb.bin
 uboot-40000.bin
 uboot-400000.bin)

UBI_PREFIX="chip"
UBI_SUFFIX="ubi.sparse"
UBI_TYPE="400000-4000"

while getopts "sgpbhB:" opt; do
  case $opt in
    s)
      echo "server selected"
      FLAVOR=server
      ;;
    g)
      echo "gui selected"
      FLAVOR=gui
      ;;
    p)
      echo "pocketchip selected"
      FLAVOR=pocketchip
      ;;
    b)
      echo "buildroot selected"
      FLAVOR=buildroot
      ;;
    B)
      BRANCH="$OPTARG"
      echo "${BRANCH} branch selected"
      ;;
    h)
      echo ""
      echo "Help"
      echo ""
      echo "  -s  --  Server             [Debian + Headless]"
      echo "  -g  --  GUI                [Debian + XFCE]"
      echo "  -p  --  PocketCHIP"
      echo "  -b  --  Buildroot"
      echo "  -B  --  Branch(optional)   [eg. -B testing]"
      echo ""
      echo ""
      exit 0
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

function dl_probe {
	
	CACHENUM=$(curl $DL_URL/$BRANCH/$FLAVOR/latest)
	
	if [[ ! -d "$DL_DIR/$BRANCH-$FLAVOR-b${CACHENUM}" ]]; then
		echo "New image available"
		
		rm -rf $DL_DIR/$BRANCH-$FLAVOR*
		
		mkdir -p $DL_DIR/${BRANCH}-${FLAVOR}-b${CACHENUM}
		pushd $DL_DIR/${BRANCH}-${FLAVOR}-b${CACHENUM}
		
		echo "Downloading.."
		for FILE in ${PROBES[@]}; do
			if ! wget $DL_URL/$BRANCH/$FLAVOR/${CACHENUM}/$FILE; then
				echo "download of $BRANCH-$FLAVOR-$METHOD-b${CACHENUM} failed!"
				exit $?
			fi
		done
		popd
	else
		echo "Cached probe files located"
	fi
	
	echo "Staging for NAND probe"
	ln -s ../../$DL_DIR/${BRANCH}-${FLAVOR}-b${CACHENUM}/ $IMAGESDIR
	rm ${IMAGESDIR}/ubi_type
	detect_nand
	
	if [[ ! -f "$DL_DIR/$BRANCH-$FLAVOR-b${CACHENUM}/$UBI_PREFIX-$UBI_TYPE.$UBI_SUFFIX" ]]; then
		echo "Downloading new UBI, this will be cached for future flashes."
		pushd $DL_DIR/${BRANCH}-${FLAVOR}-b${CACHENUM}
		if ! wget $DL_URL/$BRANCH/$FLAVOR/${CACHENUM}/$UBI_PREFIX-$UBI_TYPE.$UBI_SUFFIX; then
			echo "download of $BRANCH-$FLAVOR-$METHOD-b${CACHENUM} failed!"
			exit $?
		fi
		popd
	else
		echo "Cached UBI located"
	fi
}

echo == preparing images ==
require_directory "$IMAGESDIR"
rm -rf ${IMAGESDIR}
require_directory "$DL_DIR"
dl_probe

flash_images
rm ${IMAGESDIR}/ubi_type

ready_to_roll
