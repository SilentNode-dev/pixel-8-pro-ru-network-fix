#!/system/bin/sh
MODDIR=${0%/*}

# Set SELinux contexts and bind-mount modem configurations
if [ -f "$MODDIR/confpack/cfg.db" ]; then
    chcon u:object_r:modem_img_file:s0 "$MODDIR/confpack/cfg.db"
    mount --bind "$MODDIR/confpack/cfg.db" /mnt/vendor/modem_img/images/default/confpack/cfg.db
fi

if [ -f "$MODDIR/uecap/WILDCARD.binarypb" ]; then
    chcon u:object_r:modem_img_file:s0 "$MODDIR/uecap/WILDCARD.binarypb"
    mount --bind "$MODDIR/uecap/WILDCARD.binarypb" /mnt/vendor/modem_img/images/default/uecap/WILDCARD.binarypb
fi
