SKIPUNZIP=0

DEVICE="$(getprop ro.product.device)"
MODEL="$(getprop ro.product.model)"
ANDROID_VER="$(getprop ro.build.version.release)"
SECURITY_PATCH="$(getprop ro.build.version.security_patch)"

ui_print "********************************************************"
ui_print "*   Pixel Russian Networks & 5G/VoLTE Fix (v1.2)       *"
ui_print "*   Author: SilentNode-dev                             *"
ui_print "********************************************************"
ui_print "- Device: $MODEL ($DEVICE)"
ui_print "- Android Version: $ANDROID_VER (Patch: $SECURITY_PATCH)"

# Check Tensor / Shannon modem presence
if [ -d "/mnt/vendor/modem_img" ] || [ -f "/vendor/firmware/modem.bin" ]; then
    ui_print "- Detected Samsung Shannon modem hardware"
else
    ui_print "[!] Warning: /mnt/vendor/modem_img not found."
    ui_print "    This module is designed for Google Pixel Tensor devices."
fi

ui_print "- Features: VoLTE, VoWiFi, 5G (n78/n79), VoNR, 4CA/5CA"
ui_print "- Certified baseband profiles: Samsung Shannon SER (A556E)"
ui_print "- Installing CLI utility: 'netfix'"
ui_print "- Installing KernelSU / KernelSU Next WebUI..."

# Set proper permissions
set_perm_recursive "$MODPATH" 0 0 0755 0644
set_perm "$MODPATH/post-fs-data.sh" 0 0 0755
set_perm "$MODPATH/service.sh" 0 0 0755
set_perm "$MODPATH/system/bin/Applier.dex" 0 0 0644
set_perm "$MODPATH/system/bin/netfix" 0 0 0755

ui_print "********************************************************"
ui_print "* Installation complete!                               *"
ui_print "* Reboot device to activate module.                    *"
ui_print "* Check status anytime via terminal: 'netfix status'   *"
ui_print "********************************************************"
