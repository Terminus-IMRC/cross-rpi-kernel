#!/usr/bin/env bash

# Default targets
# 'all' implies 'zImage', 'modules' and 'dtbs'.
TARGETS='all perf modules_install headers_install dtbs_install'

# Default Docker image
IMAGE=ysugi/cross-rpi-kernel

usage() {
	echo "Usage: $0 [OPTION]..."
	echo
	echo "  -i IMAGE          Docker image to use"
	echo "                    Default: $IMAGE"
	echo
	echo "  -a ARCH           Set target arch"
	echo "  -s KBUILD_SRC     Set kernel source directory"
	echo "  -o KBUILD_OUTPUT  Set kernel build directory"
	echo "  -d DESTDIR        Set install destination"
	echo "  -c CROSS_COMPILE  Set cross compile prefix"
	echo "  -k SUFFIX         Set kernel suffix"
	echo "                    The output will be kernelSUFFIX.img"
	echo
	echo "  -v VERS           Build kernel for RPi version VERS"
	echo "                    1: ARCH=arm"
	echo "                       KBUILD_SRC=. KBUILD_OUTPUT=build-rpi1"
	echo "                       DESTDIR=dest-rpi1 SUFFIX=v6-idein"
	echo "                       CROSS_COMPILE=/home/idein/x-tools/armv6-rpi-linux-gnueabihf/bin/armv6-rpi-linux-gnueabihf-"
	echo "                    2: ARCH=arm"
	echo "                       KBUILD_SRC=. KBUILD_OUTPUT=build-rpi2"
	echo "                       DESTDIR=dest-rpi2 SUFFIX=v7-idein"
	echo "                       CROSS_COMPILE=/home/idein/x-tools/armv7-rpi2-linux-gnueabihf/bin/armv7-rpi2-linux-gnueabihf-"
	echo
	echo "  -t                Make specific target(s)"
	echo "                    Default: $TARGETS"
	echo "                    You can load the default configuration with"
	echo "                    'bcm2835_defconfig' (RPi1) or"
	echo "                    'bcm2709_defconfig' (RPi2), configure it with"
	echo "                    'nconfig', and build perf with 'perf'"
	echo
	echo "  -h                Show this help"
}

OPTS=$(getopt 'i:a:s:o:d:c:k:v:t:h' "$@")
if [ "$?" -ne 0 ]; then
	usage
	exit 1
fi
set -- $OPTS
while [ -n "$1" ]; do
	case "$1" in
		-i)
			IMAGE="$2"
			shift 2
			;;
		-a)
			ARCH="$2"
			shift 2
			;;
		-s)
			KBUILD_SRC="$2"
			shift 2
			;;
		-o)
			KBUILD_OUTPUT="$2"
			shift 2
			;;
		-d)
			DESTDIR="$2"
			shift 2
			;;
		-c)
			CROSS_COMPILE="$2"
			shift 2
			;;
		-k)
			SUFFIX="$2"
			shift 2
			;;
		-v)
			case "$2" in
				1)
					ARCH=arm
					KBUILD_SRC=.
					KBUILD_OUTPUT=build-rpi1
					DESTDIR=dest-rpi1
					SUFFIX=v6-idein
					CROSS_COMPILE=/home/idein/x-tools/armv6-rpi-linux-gnueabihf/bin/armv6-rpi-linux-gnueabihf-
					;;
				2)
					ARCH=arm
					KBUILD_SRC=.
					KBUILD_OUTPUT=build-rpi2
					DESTDIR=dest-rpi2
					SUFFIX=v7-idein
					CROSS_COMPILE=/home/idein/x-tools/armv7-rpi2-linux-gnueabihf/bin/armv7-rpi2-linux-gnueabihf-
					;;
				*)
					echo "error: Invalid VERS $2"
					usage
					exit 1
					;;
			esac
			shift 2
			;;
		-t)
			TARGETS="$2"
			shift 2
			;;
		-h)
			usage
			shift 1
			exit 0
			;;
		--)
			shift 1
			break
			;;
		*)
			echo "error: Invalid argument: $1"
			usage
			exit 1
			;;
	esac
done

if [ -n "$1" ]; then
	echo "error: Extra argument(s) specified"
	usage
	exit 1
fi


ifany() {
	v=$(eval echo "\$$1")
	[ -z "$v" ] || echo "$1=$v"
}


if [ "$ARCH" != arm ]; then
	echo "error: This script mainly targets ARCH=arm"
	usage
	exit 1
fi

set -e

mkdir -p "$KBUILD_OUTPUT/"
rm -rf "$DESTDIR/"
mkdir -p "$DESTDIR/boot/overlays/" "$DESTDIR/lib/firmware/" "$DESTDIR/usr/"

for i in KBUILD_SRC KBUILD_OUTPUT DESTDIR; do
	v=$(eval echo \$$i)
	if [ -z "$v" ]; then
		echo "error: Specify $i"
		usage
		exit 1
	elif [ ! -d "$v" ]; then
		echo "error: Directory $i ($v) not found"
		usage
		exit 1
	fi
	eval "$i=\$(realpath "$v")"
done

for i in IMAGE ARCH KBUILD_SRC KBUILD_OUTPUT DESTDIR CROSS_COMPILE SUFFIX TARGETS; do
	echo "$i=$(eval echo \$$i)"
done

NPROCS=$(which nproc >/dev/null 2>/dev/null && nproc || echo 1)
NPROCS=$((NPROCS * 2))
echo "Using $NPROCS threads"

[ -n "$UID" ] || UID=$(id -u)
GID=$(id -g)
DOCKER="time -p docker run --rm -it -u $UID:$GID \
		-v $KBUILD_SRC:/home/idein/src:ro \
		-v $KBUILD_OUTPUT:/home/idein/build:rw,delegated \
		-v $DESTDIR:/home/idein/dest:rw,delegated \
		$IMAGE"

for target in $TARGETS; do
	echo
	echo "** Making target $target **"
	if [ "$target" == perf ]; then
		mkdir -p "$KBUILD_OUTPUT/tools/perf/" "$DESTDIR/usr/local/"
		$DOCKER make install -j "$NPROCS" \
				$(ifany ARCH) $(ifany CROSS_COMPILE) \
				-C /home/idein/src/ \
				O=/home/idein/build/tools/perf/ \
				DESTDIR=/home/idein/dest/usr/local/
	else
		$DOCKER make "$target" -j "$NPROCS" \
				$(ifany ARCH) $(ifany CROSS_COMPILE) \
				-C /home/idein/src/ O=/home/idein/build/ \
				INSTALL_DTBS_PATH=/home/idein/dest/boot/ \
				INSTALL_MOD_PATH=/home/idein/dest/ \
				INSTALL_HDR_PATH=/home/idein/dest/usr/
	fi
done

if echo $TARGETS | tr -s ' ' '\n' | egrep -q '^(all)|(zImage)$'; then
	echo
	echo "** Generating kernel$SUFFIX.img **"
	$DOCKER /home/idein/src/scripts/mkknlimg \
			/home/idein/build/arch/arm/boot/zImage \
			"/home/idein/dest/boot/kernel$SUFFIX.img"
fi
