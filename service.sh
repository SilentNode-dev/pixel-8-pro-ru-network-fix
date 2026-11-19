#!/system/bin/sh
MODDIR=${0%/*}

# Wait until boot completed
until [ "$(getprop sys.boot_completed)" = "1" ]; do
    sleep 1
done

sleep 2

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
content update --uri content://telephony/siminfo \
    --bind volte_vt_enabled:i:1 \
    --bind video_calling_enabled:i:1 \
    --bind wfc_ims_enabled:i:1 \
    --bind wfc_ims_mode:i:2 \
    --bind wfc_ims_roaming_mode:i:2 \
    --bind wfc_ims_roaming_enabled:i:1 \
    --bind nr_advanced_calling_enabled:i:1 \
    --bind cross_sim_calling_enabled:i:1 2>/dev/null

# Provision missing certified Russian MVNO APNs
if [ -x "$MODDIR/system/bin/netfix" ]; then
    "$MODDIR/system/bin/netfix" apn >/dev/null 2>&1
fi

# Execute Applier to inject CarrierConfig overrides directly via binder
if [ -f "$MODDIR/system/bin/Applier.dex" ]; then
    CLASSPATH="$MODDIR/system/bin/Applier.dex" app_process / Applier apply >/dev/null 2>&1
fi

# Zero-CPU SIM hot-swap and airplane mode change listener
(
    LAST_STATE="$(getprop gsm.sim.state)"
    while true; do
        resetprop -w gsm.sim.state
        CURR_STATE="$(getprop gsm.sim.state)"
        if [ "$CURR_STATE" != "$LAST_STATE" ]; then
            LAST_STATE="$CURR_STATE"
            sleep 3
            if echo "$CURR_STATE" | grep -q "LOADED\|READY"; then
                [ -f "$MODDIR/system/bin/Applier.dex" ] && CLASSPATH="$MODDIR/system/bin/Applier.dex" app_process / Applier apply >/dev/null 2>&1
            fi
        fi
    done
) &
