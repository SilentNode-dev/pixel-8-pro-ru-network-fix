SKIPUNZIP=0

ui_print "- Installing Pixel Russian Networks & 5G/VoLTE Fix..."
ui_print "- Device: Google Pixel 8 Pro (Tensor G3)"
ui_print "- Target: VoLTE, VoWiFi, 5G (n78/n79), VoNR, LTE-A CA"

set_perm_recursive "$MODPATH" 0 0 0755 0644
set_perm "$MODPATH/post-fs-data.sh" 0 0 0755
set_perm "$MODPATH/service.sh" 0 0 0755
set_perm "$MODPATH/system/bin/Applier.dex" 0 0 0644

ui_print "- Installation complete! Reboot device to activate."
