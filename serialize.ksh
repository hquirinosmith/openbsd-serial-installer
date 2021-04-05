#!/bin/ksh -e

## Entrypoint
function main {
	# Build
	image=`download_install_media`
	vnode=`find_vnode "not in use"`
	attach_image_to_vnode "${image}" "${vnode}"
	mount_image_device_at "/dev/${vnode}a" "/mnt/hqs_obsd_serial"
	amend_boot_settings "/mnt/hqs_obsd_serial/etc/boot.conf"

	# Cleanup
	unmount_directory "/mnt/hqs_obsd_serial"
	detach_image_from_vnode "${image}" "${vnode}"
}

function detach_image_from_vnode {
	image=$1
	vnode=$2

	active_vnode=`find_vnode "covering ${image}"`
	if [ ! -z "${active_vnode}" ]; then
		log "Detaching image from vnode '${vnode}'"
		vnconfig -u "${active_vnode}"
	fi
}

function unmount_directory {
	path=$1

	mount | grep -q "${path}"
	if [ $? -eq 1 ]; then
		log "Unmounting ${path}"
		umount "${path}"
		rmdir "${path}"
	fi
}

function amend_boot_settings {
	path=$1

	grep -q "com0" "${path}"
	if [ $? -eq 1 ]; then
		log "Modifying '${path}' to prefer com0"
		echo "stty com0 115200" >> "${path}"
		echo "set tty com0" >> "${path}"
	fi
}

function mount_image_device_at {
	device=$1
	path=$2

	if [ ! -d "${path}" ]; then
		log "Mounting image at '${path}'"
		mkdir -p "${path}"
		mount "${device}" "${path}"
	fi
}

function attach_image_to_vnode {
	image=$1
	vnode=$2

	log "Attaching image '${image}' to vnode '${vnode}'"
	vnconfig -c "${vnode}" "${image}"
}

function find_vnode {
	pattern=$1

	vnconfig -l | grep "${pattern}" | head -n1 | cut -d':' -f1
}

function download_install_media {
	HQS_OBSD_URL="https://cdn.openbsd.org/pub/OpenBSD/6.8/amd64/install68.img"
	path="hqs_obsd_serial.img"
	if [ ! -e "${path}" ]; then
		log "Downloading install media"
		ftp -o "${path}" "${HQS_OBSD_URL}"
	fi
	echo "${path}"
}

function log {
	print "\n\033[34m# $1\033[00m"
}

main
