#!/system/bin/sh
MODDIR=${0%/*}

# Stealth Ramfs Donor directory to avoid /proc/self/mountinfo leaking /data/adb/modules
DONOR_DIR="/dev/.modem_donor"
mkdir -p "$DONOR_DIR"
chmod 755 "$DONOR_DIR"

if [ -f "$MODDIR/confpack/cfg.db" ]; then
    cp -f "$MODDIR/confpack/cfg.db" "$DONOR_DIR/cfg.db"
    chcon u:object_r:modem_img_file:s0 "$DONOR_DIR/cfg.db" 2>/dev/null
    chmod 644 "$DONOR_DIR/cfg.db"
fi

if [ -f "$MODDIR/uecap/WILDCARD.binarypb" ]; then
    cp -f "$MODDIR/uecap/WILDCARD.binarypb" "$DONOR_DIR/WILDCARD.binarypb"
    chcon u:object_r:modem_img_file:s0 "$DONOR_DIR/WILDCARD.binarypb" 2>/dev/null
    chmod 644 "$DONOR_DIR/WILDCARD.binarypb"
fi

# Universal Shannon modem bind-mount for Pixel 6, 7, 8, 9 series (Tensor G1-G4)
# Mounts from /dev/.modem_donor instead of /data/adb to prevent root detection by Mir Pay / banking apps
if [ -d "/mnt/vendor/modem_img/images" ]; then
    for img_dir in /mnt/vendor/modem_img/images/*; do
        if [ -d "$img_dir/confpack" ] && [ -f "$DONOR_DIR/cfg.db" ]; then
            mount --bind "$DONOR_DIR/cfg.db" "$img_dir/confpack/cfg.db" 2>/dev/null
        fi
        if [ -d "$img_dir/uecap" ] && [ -f "$DONOR_DIR/WILDCARD.binarypb" ]; then
            mount --bind "$DONOR_DIR/WILDCARD.binarypb" "$img_dir/uecap/WILDCARD.binarypb" 2>/dev/null
        fi
    done
fi

# Fallback explicit bind for default symlink if not mounted
if [ -f "/mnt/vendor/modem_img/images/default/confpack/cfg.db" ] && [ -f "$DONOR_DIR/cfg.db" ]; then
    mount --bind "$DONOR_DIR/cfg.db" /mnt/vendor/modem_img/images/default/confpack/cfg.db 2>/dev/null
fi
if [ -f "/mnt/vendor/modem_img/images/default/uecap/WILDCARD.binarypb" ] && [ -f "$DONOR_DIR/WILDCARD.binarypb" ]; then
    mount --bind "$DONOR_DIR/WILDCARD.binarypb" /mnt/vendor/modem_img/images/default/uecap/WILDCARD.binarypb 2>/dev/null
fi
