#!/bin/ksh -e

# Entrypoint. Invoked at the bottom of the script with all cli arguments
# forwarded from the shell. This allows us to read the program from top
# to bottom.
function main {
	image=$1
	mountpoint=$2

	if [ -z "${image}" ]; then
		print_usage
		exit 1
	fi

	if [ -z "${mountpoint}" ]; then
		mountpoint="/mnt"
	fi

	mount_image_at "${image}" "${mountpoint}"
	amend_boot_config "${mountpoint}"
	unmount_image_from "${image}" "${mountpoint}"
}

# Display a formatted manual page showing how this application can be
# invoked. We do this because this is just a single file executable, not
# really worth the trouble of bundling and installing.
function print_usage {
	(cat | mandoc) <<-HEREDOC
	.Dd April 05, 2021
	.Dt SERIAL_ADAPTER hqs
	.Os
	.Sh NAME
	.Nm serial_adapter.ksh
	.Nd Modify an OpenBSD install image to use com0 by default
	.Sh SYNOPSIS
	.Nm
	.Ar image_path
	.Op mount_point
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

# Mounts the provided image at /mnt in read-write mode.
function mount_image_at {
	image=$1
	mountpoint=$2

	# Attach the image to the first available vnode
	vnode=`find_vnode "not in use"`
	vnconfig "${vnode}" "${image}"

	# Mount that vnode at /mnt, using appropriate options depending
	# on the type of image we have.
	img_type=`extension "${image}"`
	if [ "${img_type}" == "iso" ]; then
		# mount sub-device 'c' as a CD-ROM
		mount -t cd9660 "/dev/${vnode}c" "${mountpoint}"
	else
		# mount sub-device 'a' as a disk
		mount "/dev/${vnode}a" "${mountpoint}"
	fi
}

function amend_boot_config {
	mountpoint=$1

	cat >> "${mountpoint}/etc/boot.conf" <<-HEREDOC
	stty com0 115200
	set tty com0
	HEREDOC
}

function unmount_image_from {
	image=$1
	mountpoint=$2

	umount "${mountpoint}"
	vnode=`find_vnode "covering ${image}"`
	vnconfig -u "${vnode}"
}

# Return the first vnode that matches our pattern.
function find_vnode {
	pattern=$1

	vnconfig -l | grep "${pattern}" | head -n1 | cut -d':' -f1
}

# Forward all arguments to main. This allows us to read the program from
# top-to-bottom, even though we really begin execution from down here.
main $*
