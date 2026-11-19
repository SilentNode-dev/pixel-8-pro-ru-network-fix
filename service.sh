#!/system/bin/sh
MODDIR=${0%/*}

# Wait until boot completed
until [ "$(getprop sys.boot_completed)" = "1" ]; do
    sleep 1
done

sleep 3

# Apply persistent telephony properties
setprop persist.dbg.ims_volte_enable 1
setprop persist.dbg.volte_avail_ovr 1
setprop persist.dbg.vt_avail_ovr 1
setprop persist.dbg.wfc_avail_ovr 1
setprop persist.radio.is_vonr_enabled_0 true
setprop persist.radio.is_vonr_enabled_1 true

# Ensure carrier_ims directory and config exist
mkdir -p /data/adb/carrier_ims
if [ -f "$MODDIR/config.json" ]; then
    cp "$MODDIR/config.json" /data/adb/carrier_ims/config.json
fi

# Enable VoLTE/VoWiFi in siminfo table
content update --uri content://telephony/siminfo --bind volte_vt_enabled:i:1 --bind video_calling_enabled:i:1 --bind wfc_ims_enabled:i:1 --bind wfc_ims_mode:i:2 --bind wfc_ims_roaming_mode:i:2 --bind wfc_ims_roaming_enabled:i:1 --bind nr_advanced_calling_enabled:i:1 --bind cross_sim_calling_enabled:i:1 2>/dev/null

# Execute Applier to inject CarrierConfig overrides directly via binder
if [ -f "$MODDIR/system/bin/Applier.dex" ]; then
    CLASSPATH="$MODDIR/system/bin/Applier.dex" app_process / Applier apply >/dev/null 2>&1
fi
