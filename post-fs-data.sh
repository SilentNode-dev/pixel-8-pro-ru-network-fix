#!/system/bin/sh
MODDIR=${0%/*}

# Set SELinux context for source files
[ -f "$MODDIR/confpack/cfg.db" ] && chcon u:object_r:modem_img_file:s0 "$MODDIR/confpack/cfg.db"
[ -f "$MODDIR/uecap/WILDCARD.binarypb" ] && chcon u:object_r:modem_img_file:s0 "$MODDIR/uecap/WILDCARD.binarypb"

# Universal Shannon modem bind-mount for Pixel 6, 7, 8, 9 series (Tensor G1-G4)
# Scans all active images and symlinks under /mnt/vendor/modem_img/images/
if [ -d "/mnt/vendor/modem_img/images" ]; then
    for img_dir in /mnt/vendor/modem_img/images/*; do
        if [ -d "$img_dir/confpack" ] && [ -f "$MODDIR/confpack/cfg.db" ]; then
            mount --bind "$MODDIR/confpack/cfg.db" "$img_dir/confpack/cfg.db" 2>/dev/null
        fi
        if [ -d "$img_dir/uecap" ] && [ -f "$MODDIR/uecap/WILDCARD.binarypb" ]; then
            mount --bind "$MODDIR/uecap/WILDCARD.binarypb" "$img_dir/uecap/WILDCARD.binarypb" 2>/dev/null
        fi
    done
fi

# Fallback explicit bind for default symlink if not mounted
if [ -f "/mnt/vendor/modem_img/images/default/confpack/cfg.db" ]; then
    mount --bind "$MODDIR/confpack/cfg.db" /mnt/vendor/modem_img/images/default/confpack/cfg.db 2>/dev/null
fi
if [ -f "/mnt/vendor/modem_img/images/default/uecap/WILDCARD.binarypb" ]; then
    mount --bind "$MODDIR/uecap/WILDCARD.binarypb" /mnt/vendor/modem_img/images/default/uecap/WILDCARD.binarypb 2>/dev/null
fi
