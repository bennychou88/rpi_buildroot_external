#!/bin/sh
set +e

for arg in "$@"
do
	case "${arg}" in
		--enable_uart)
		if ! grep -qE '^enable_uart=1' "${BINARIES_DIR}/rpi-firmware/config.txt"; then
			echo "Enabling UART in config.txt"
			cat << __EOF__ >> "${BINARIES_DIR}/rpi-firmware/config.txt"

# enable rpi3 ttyS0 serial console
enable_uart=1
__EOF__
		fi

		if ! grep -qE 'UART=1' "${BINARIES_DIR}/rpi-firmware/bootcode.bin"; then
			echo "UART patching bootcode.bin"
			sed -i -e "s/BOOT_UART=0/BOOT_UART=1/" ${BINARIES_DIR}/rpi-firmware/bootcode.bin
		fi
		;;

		--enable_simple_audio)
		if ! grep -qE '^dtparam=audio' "${BINARIES_DIR}/rpi-firmware/config.txt"; then
			echo "Adding 'dtparam=audio=on' to config.txt (enables simple audio)"
			cat << __EOF__ >> "${BINARIES_DIR}/rpi-firmware/config.txt"

# Enable audio jack on Raspberry Pi
dtparam=audio=on
__EOF__
		fi
		;;

		--hifiberry_dac)
		if ! grep -qE '^dtoverlay=hifiberry-dac' "${BINARIES_DIR}/rpi-firmware/config.txt"; then
			echo "Adding 'dtoverlay=hifiberry-dac' to config.txt"
			cat << __EOF__ >> "${BINARIES_DIR}/rpi-firmware/config.txt"

#Enable hifiberry
dtoverlay=hifiberry-dac
__EOF__
		fi
		;;

		--nobootdelay)
		if ! grep -qE '^boot_delay=' "${BINARIES_DIR}/rpi-firmware/config.txt"; then
			echo "Adding 'boot_delay=0' to config.txt"
			cat << __EOF__ >> "${BINARIES_DIR}/rpi-firmware/config.txt"

boot_delay=0
__EOF__
		fi
		;;

		#TODO: Move this to buildroot's post-image.sh
		--add-pi3-miniuart-bt-overlay)
		if ! grep -qE '^dtoverlay=pi3-miniuart-bt' "${BINARIES_DIR}/rpi-firmware/config.txt"; then
			echo "Adding 'dtoverlay=pi3-miniuart-bt' to config.txt (fixes ttyAMA0 serial console)."
			cat << __EOF__ >> "${BINARIES_DIR}/rpi-firmware/config.txt"

# fixes rpi3 ttyAMA0 serial console
dtoverlay=pi3-miniuart-bt
__EOF__
		fi
		;;

	esac
done
