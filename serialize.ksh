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

	(cat | mandoc) <<-HEREDOC
	.Dd April 05, 2021
	.Dt SERIALIZE hqs
	.Os
	.Sh NAME
	.Nm ${invocation_name}
	.Nd Modify an OpenBSD install image to use com0 by default
	.Sh SYNOPSIS
	.Nm
	.Ar image_path
	.Sh DESCRIPTION
	The
	.Nm
	utility will modify an amd64-based OpenBSD install image to use the
	first available serial console (com0 on most systems) as the default
	interactive console. It assumes a connected terminal operating at
	115200 baud.
	.Pp
	You can find the latest version of OpenBSD available for download at
	https://www.openbsd.org/faq/faq4.html#Download. Be sure to select a
	disk image (*.img) rather than an ISO-9660 (*.iso) file, as this utility
	does not support cd/dvd images.
	.Pp
	Consult
	.Xr ftp 1
	for a curl/wget substitute that is available in the
	OpenBSD base install.
	.Sh EXIT STATUS
	.Ex -std echo
	.Sh SEE ALSO
	.Xr ksh 1 ,
	.Xr ftp 1 ,
	.Xr vnconfig 8 ,
	.Xr mount 8 ,
	.Xr boot.conf 8
	HEREDOC
}

function detach_image {
	image=$1

	vnode=`find_vnode "covering ${image}"`
	if [ ! -z "${vnode}" ]; then
		vnconfig -u "${vnode}"
	fi
}

function unmount_directory {
	path=$1

	mount | grep -q "${path}"
	if [ $? -eq 0 ]; then
		umount "${path}"
		rmdir "${path}"
	fi
}

function amend_boot_settings {
	path=$1

	grep -q "com0" "${path}"
	if [ $? -eq 1 ]; then
		echo "stty com0 115200" >> "${path}"
		echo "set tty com0" >> "${path}"
	fi
}

function mount_image_device_at {
	device=$1
	path=$2

	mount | grep -q "${path}"
	if [ $? -eq 1 ]; then
		mkdir -p "${path}"
		mount "${device}" "${path}"
	fi
}

function attach_image {
	image=$1

	vnode=`find_vnode "covering ${image}"`
	if [ -z "${vnode}" ]; then
		vnode=`find_vnode "not in use"`
		vnconfig "${vnode}" "${image}"
	fi
	echo "${vnode}"
}

function find_vnode {
	pattern=$1

	vnconfig -l | grep "${pattern}" | head -n1 | cut -d':' -f1
}

main $0 $1
