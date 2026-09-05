# ==============================================================================
# AUTOMATED OEM CORE CODE INJECTION HOOK FOR PENGUINS-EGGS v26.9.4+
# ==============================================================================
echo "-> Integrating dynamic OEM chroot automation..."

# ⚠️ ADVICE: Replace 'MASTER_USER' below with your actual master system username!
MASTER_USER_NAME="MASTER_USER"

LIVEROOT="${1}/liveroot"
AUTOSTART_DIR="$LIVEROOT/etc/skel/.config/autostart"
mkdir -p "$AUTOSTART_DIR"

# 1. Create a hidden autostart shortcut within the Live system template
cat << 'EOF' > "$AUTOSTART_DIR/live_branding_patch.desktop"
[Desktop Entry]
Type=Application
Exec=bash /usr/local/bin/patch_branding_on_fly.sh
Hidden=false
NoDisplay=true
X-GNOME-Autostart-enabled=true
Name=Live Branding Patch
EOF

# 2. Create the runtime interceptor daemon script
cat << EOF > "$LIVEROOT/usr/local/bin/patch_branding_on_fly.sh"
#!/bin/bash

RUNNER_FILE="/etc/penguins-eggs.d/installer.d/krill-chroot-runner.sh"
RUNNER_CONF="/etc/penguins-eggs.d/installer.d/modules/shellprocess_krill-chroot-runner.conf"

# High-frequency polling loop waiting for the installer initialization
while true; do
    if [ -f "\$RUNNER_FILE" ] && [ -f "\$RUNNER_CONF" ]; then
        
        # A. PREVENT KRILL KILLS: Increase Calamares execution timeout for heavy profile migrations
        sudo sed -i 's|timeout: 600|timeout: 99999|' "\$RUNNER_CONF" 2>/dev/null

        # B. CORE INJECTION INTO CHROOT LIFECYCLE (Targeting update-grub closure within if-statement)
        sudo sed -i 's|update-grub\\\\nfi\\\\n|update-grub\\\\nfi\\\\nNEW_USER=\\\$(ls '\''/home'\'' \\| grep -v '\''lost+found'\'' \\| head -n 1)\\\\ntar -xzf /opt/my_settings.tar.gz -C /home/\\\$NEW_USER/\\\\nif [ -d /home/\\\$NEW_USER/root ]; then\\\\n        cp -a /home/\\\$NEW_USER/root/. /root/ 2\\\u003e/dev/null\\\\n        rm -rf /home/\\\$NEW_USER/root\\\\n        chown -R root:root /root/; fi\\\\nchown -R 1000:1000 /home/\\\$NEW_USER/\\\\nexport NEW_USER\\\\ngrep -r -l -Z -I --exclude-dir=dconf '\''$MASTER_USER_NAME'\'' /home/\\\$NEW_USER/ \\| xargs -r -0 perl -pi -e '\''s/$MASTER_USER_NAME/\\\$ENV{NEW_USER}/g'\''\\\\nrm -f /opt/my_settings.tar.gz\\\\nrm -f /usr/local/bin/patch_branding_on_fly.sh\\\\nrm -f /etc/skel/.config/autostart/live_branding_patch.desktop\\\\nrm -f /home/\\\$NEW_USER/.config/autostart/live_branding_patch.desktop|' "\$RUNNER_FILE"

        break
    fi
    
    sleep 0.2
done

# Purge the background daemon from the live environment RAM memory
rm -f ~/.config/autostart/live_branding_patch.desktop
sudo rm -f /usr/local/bin/patch_branding_on_fly.sh
EOF

chmod +x "$LIVEROOT/usr/local/bin/patch_branding_on_fly.sh"
# ==============================================================================
