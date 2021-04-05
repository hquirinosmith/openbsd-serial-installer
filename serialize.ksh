#!/bin/ksh

## Entrypoint
function main {
	invocation_name=$1
	image=$2
	if [ -z "${image}" ]; then
		print_usage "${invocation_name}"
		exit 1
	fi

	namespace="hqs_obsd_serial"
	mountpoint="/mnt/${namespace}"

	# Build
	vnode=`attach_image "${image}"`
	mount_image_device_at "/dev/${vnode}a" "${mountpoint}"

	amend_boot_settings "${mountpoint}/etc/boot.conf"

	# Clean
	unmount_directory "${mountpoint}"
	detach_image "${image}"
}

function print_usage {
	invocation_name=$1

	echo "USAGE:"
	echo "\t${invocation_name} <IMAGE_PATH>"
	echo ""
	echo "REFERENCES:"
	echo "\tYou can find the latest version of OpenBSD available"
	echo "\tat https://www.openbsd.org/faq/faq4.html#Download"
	echo ""
	echo "\tConsult FTP(1) for a curl/wget substitute. (It is part"
	echo "\tof the base install): https://man.openbsd.org/ftp"
	echo ""
	echo "CAVEATS:"
	echo "\tThis program is known to work on OpenBSD 6.8 for amd64"
	echo "\tbut has not been tested with other versions/platforms."
}

function detach_image {
	image=$1

	vnode=`find_vnode "covering ${image}"`
	if [ ! -z "${vnode}" ]; then
		log "Detaching image from vnode '${vnode}'"
		vnconfig -u "${vnode}"
	fi
}

function unmount_directory {
	path=$1

	mount | grep -q "${path}"
	if [ $? -eq 0 ]; then
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

	mount | grep -q "${path}"
	if [ $? -eq 1 ]; then
		log "Mounting image at '${path}'"
		mkdir -p "${path}"
		mount "${device}" "${path}"
	fi
}

function attach_image {
	image=$1

	vnode=`find_vnode "covering ${image}"`
	if [ -z "${vnode}" ]; then
		vnode=`find_vnode "not in use"`
		log "Attaching image '${image}' to vnode '${vnode}'"
		vnconfig "${vnode}" "${image}"
	fi
	echo "${vnode}"
}

function find_vnode {
	pattern=$1

	vnconfig -l | grep "${pattern}" | head -n1 | cut -d':' -f1
}

function log {
	print "\n\033[34m# $1\033[00m" >&2
}

main $0 $1
