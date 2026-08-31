#!/bin/bash

# 1. Automatically find Calamares mount point in /tmp
TARGET=$(mount | grep -o '/tmp/calamares-root-[^ ]*' | head -n 1)

if [ -z "$TARGET" ]; then
    TARGET=$(mount | grep 'calamares' | awk '{print $3}' | head -n 1)
fi

# Check if target partition is found.
if [ -z "$TARGET" ]; then
    zenity --error --title="Error" --text="Target installation partition not found!\n\nPlease ensure that the Calamares installation process is active and has reached 100%." --width=400
    exit 1
fi

# 2. Find the username created during Calamares setup
NEW_USER=$(ls "$TARGET/home" | grep -v 'lost+found' | head -n 1)

if [ -z "$NEW_USER" ]; then
    zenity --error --title="Error" --text="Home directory for the new user was not found in the installed system!" --width=400
    exit 1
fi

ARCHIVE="$TARGET/opt/my_settings.tar.gz"

# Check if the configuration archive exists
if [ ! -f "$ARCHIVE" ]; then
    zenity --error --title="Error" --text="Critical configuration archive not found at:\n$ARCHIVE" --width=400
    exit 1
fi

# ==============================================================================
# INTERFACE INITIALIZATION & DISK SPACE QUOTA CHECK
# ==============================================================================

# Background file count & space check with an immediate pulsating Zenity window
(
    TOTAL_FILES=$(sudo tar -tzf "$ARCHIVE" | wc -l)
    echo "$TOTAL_FILES" > /tmp/eggs_total_files.txt
    
    AVAILABLE_KB=$(df "$TARGET" | awk 'NR==2 {print $4}')
    
    REQUIRED_BYTES=$(sudo gzip -l "$ARCHIVE" | awk 'NR==2 {print $2}')
    REQUIRED_KB=$((REQUIRED_BYTES / 1024))
    
    # Safety margin: add 50 MB (51200 KB) for filesystem overhead
    REQUIRED_KB=$((REQUIRED_KB + 51200))
    
    echo "$AVAILABLE_KB" > /tmp/eggs_avail.txt
    echo "$REQUIRED_KB" > /tmp/eggs_req.txt

) | zenity --progress --title="Initialization" --text="Analyzing disk space and configuration archive..." --pulsate --auto-close --no-cancel --width=450

TOTAL_FILES=$(cat /tmp/eggs_total_files.txt 2>/dev/null || echo "1000")
AVAILABLE_KB=$(cat /tmp/eggs_avail.txt 2>/dev/null || echo "0")
REQUIRED_KB=$(cat /tmp/eggs_req.txt 2>/dev/null || echo "0")

rm -f /tmp/eggs_total_files.txt /tmp/eggs_avail.txt /tmp/eggs_req.txt

if [ "$AVAILABLE_KB" -lt "$REQUIRED_KB" ]; then
    FREE_MB=$((AVAILABLE_KB / 1024))
    NEED_MB=$((REQUIRED_KB / 1024))
    
    zenity --error --title="Insufficient Disk Space!" --text="Failed to deploy personal settings.\n\nAvailable on partition: ${FREE_MB} MB\nRequired for settings: ${NEED_MB} MB\n\nPlease reinstall the system using a larger partition." --width=450
    exit 1
fi

# ==============================================================================
# STEP 1: ARCHIVE EXTRACTION WITH SMOOTH PROGRESS BAR
# ==============================================================================
(
    CURRENT_FILE=0
    sudo tar -xzf "$ARCHIVE" -C "$TARGET/home/$NEW_USER/" -v | while read -r line; do
        CURRENT_FILE=$((CURRENT_FILE + 1))
        PERCENT=$((CURRENT_FILE * 100 / TOTAL_FILES))
        
        echo "$PERCENT"
        echo "# Extracting configurations and core applications settings... ($PERCENT%)"
    done
    echo "100"
) | zenity --progress --title="System Setup" --text="Preparing for extraction..." --percentage=0 --auto-close --no-cancel --width=450

# ==============================================================================
# STEP 2: FINALIZATION (PERMISSIONS, PATHS & WORKSPACE CLEANUP)
# ==============================================================================
(
    # А. Перенос папки root (Ваш универсальный метод)
    # Если внутри папки нового пользователя распаковался каталог 'root', переносим его в настоящий /root системы
    if [ -d "$TARGET/home/$NEW_USER/root" ]; then
        echo "# Restoring administrative root configuration..."
        sudo cp -a "$TARGET/home/$NEW_USER/root/." "$TARGET/root/" 2>/dev/null
        sudo rm -rf "$TARGET/home/$NEW_USER/root"
        sudo chown -R root:root "$TARGET/root/"
    fi
    sleep 1

    echo "# Applying file ownership and permissions for user [$NEW_USER]..."
    sudo chown -R 1000:1000 "$TARGET/home/$NEW_USER/"
    
    echo "# Adapting paths and application configs (this may take some time)..."
    # ⚠️ ATTENTION: Replace 'MASTER_USER' with your actual master system username before building!
    sudo find "$TARGET/home/$NEW_USER/" -type f -not -path "*/dconf/*" -exec grep -Iq . {} \; -exec sed -i "s|/home/MASTER_USER|/home/$NEW_USER|g" {} + 2>/dev/null
    
    echo "# Cleaning up temporary installation artifacts..."
    sudo rm -f "$TARGET/home/$NEW_USER/Рабочий стол"/*.sh 2>/dev/null
    sudo rm -f "$TARGET/home/$NEW_USER/Desktop"/*.sh 2>/dev/null
    sudo rm -f "$ARCHIVE" 2>/dev/null
) | zenity --progress --title="Finalization" --text="Wrapping up the system setup..." --pulsate --auto-close --no-cancel --width=450

# ==============================================================================
# REAL FILE CHECK & SUCCESS DIALOG
# ==============================================================================
if [ -d "$TARGET/home/$NEW_USER/.config" ]; then
    zenity --info --title="Success!" --text="All personal settings, UI themes, and application profiles have been successfully migrated to user [$NEW_USER].\n\nYou may now check the 'Restart' box in Calamares installer!" --width=450
else
    zenity --error --title="Attention" --text="An error occurred: the configuration directory was not created or file permissions are broken." --width=400
fi

