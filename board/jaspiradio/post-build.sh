#!/bin/sh
set +e

if [ -f ${BINARIES_DIR}/rpi-firmware/config.txt.orig ]; then
	cp ${BINARIES_DIR}/rpi-firmware/config.txt.orig ${BINARIES_DIR}/rpi-firmware/config.txt
fi

patch -b -N ${BINARIES_DIR}/rpi-firmware/config.txt <<__EOF__
@@ -18,3 +18,17 @@
 gpu_mem_256=100
 gpu_mem_512=100
 gpu_mem_1024=100
+
+# Enable built-in audio
+#dtparam=audio=on
+dtparam=act_led_gpio=25
+dtparam=act_led_trigger=heartbeat
+
+boot_delay=0
+
+#Requires bootcode.bin patch (UART=1)
+enable_uart=1
+
+#Enable hifiberry
+dtoverlay=hifiberry-dac
+
__EOF__