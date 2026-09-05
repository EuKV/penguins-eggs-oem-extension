# Penguins' Eggs OEM Installer Extension (Linux Mint Edition)

An automated engineering solution for OEM deployment of customized Linux distributions (tested on Linux Mint 22.3 Cinnamon) leveraging the **[Penguins' Eggs](https://github.com) (`coa`)** engine and runtime chroot injections.

## ⚠️ Prerequisites & System Requirements

This project is tailored and fully verified for **Penguins' Eggs v26.9.4 or higher**. 

By default, the core package does not bundle a graphical installer interface as a hard dependency. Before generating your image, ensure that the graphical Calamares subsystem and its slideshow configuration modules are installed on your master host:

```bash
sudo apt update
sudo apt install calamares calamares-settings-debian
```

*(Note: Replace `calamares-settings-debian` with `calamares-settings-ubuntu` if building on an Ubuntu-specific package base).*

## 🔒 Security Notice & Data Privacy (Read Before Proceeding!)

When migrating hidden user configurations (`.config`, `.local`), you are inherently capturing application state data. Modern web browsers (Chrome, Chromium, Firefox), messengers (Telegram, Discord), and collaboration tools (Zoom, Teams) store active session tokens, cookies, browsing history, and saved passwords within these directories.

**To prevent accidental data leaks or transferring your personal credentials to third parties, strictly follow one of these mitigation strategies before compiling the archive:**

1. **The Staging Method (Highly Recommended):** Do not build the final image from your main production operating system. First, use `sudo coa remaster --clone` to create a full staging copy on a separate partition or machine. Boot into the staging clone, log out of all active accounts, clear browser histories, caches, and saved passwords, and then proceed with the OEM archive compilation.
2. **The Cleanup Method:** If operating on your local environment, ensure you sign out of all profiles, purge browser profiles (or leave only clean bookmarks), and clear session states across all communications software prior to running the `tar` command.

---

## 🚀 Problem Statement & Motivation

The native framework provides a cloning mode (`sudo coa remaster --clone`). While it excels at Official 1:1 backup replication, it enforces a significant limitation: **it does not allow altering user credentials (username, hostname, passwords) during the target deployment phase**. 

While modern upstream releases introduced an internal `skel` tool, it often handles environments poorly, causing broken panels, corrupted panel launchers, and missing configurations within administrative tools run via `sudo` (the `/root` tree). Furthermore, it completely lacks absolute path adaptation, causing critical execution failures on core tools (e.g., Wine, Flatpak, GoldenDict) due to dead references pointing to the old master username namespace.

**Project Goal:** Bypass installer environment isolation to achieve a seamless, hardware-independent OEM deployment workflow. This extension allows end-users to set up the system with unique credentials via the GUI, while instantly inheriting 100% of the customized desktop environment, administrative root themes, and applications configurations.

## 🛠️ System Architecture & Layout

This repository provides **two distinct methodologies** depending on the administrative workflow required:

*   `README.md` — This master documentation file.
*   `oem-post-install.sh` — The interactive Zenity-based script for **Method 1**.
*   `automated-patch-code.sh` — The background daemon source code to be appended for **Method 2**.

---

## 📌 Method 1: Manual Post-Installation Routine (Visual & Cold-Partitioning)

Designed for administrators who prefer absolute control over the post-installation environment. Custom payload extraction occurs right after the target installer writes the system files but before unmounting, ensuring no active background daemons can lock or corrupt the configuration state.

### Key Features:
* Immediate pulsating Zenity UI initialization to eliminate "frozen script" false alarms.
* High-precision disk space quota calculation via `gzip -l` and `df` bytes-to-KB translation prior to extraction to prevent partition overflows.
* Live file-by-file extraction progress tracking mapping 0% to 100%.
* Automatic house-keeping that deletes all temporary setup `.sh` scripts and source tarballs upon successful completion.

### How to use:
1. **⚠️ IMPORTANT:** Open the `oem-post-install.sh` script, locate the path adaptation line (approx. line 100-105), and replace the string `MASTER_USER` with your actual master system username.
2. On your master machine, compress your baseline user configurations along with the administrative root environment:
   ```bash
   sudo tar -czf /opt/my_settings.tar.gz -C ~ .config .local /root/.config /root/.local
   ```
   *(Note: You can easily include additional application directories by appending them to the end of the command if needed, e.g., `.wine .goldendict /root/.synaptic`)*
3. Place the modified `oem-post-install.sh` script onto the master system's skeleton Desktop directory: `/etc/skel/Desktop/`
4. Produce the standard distribution ISO: 
   ```bash
   sudo coa remaster
   ```
   *(The generated ISO file will be saved by default in the `/home/eggs/` directory).*
5. Boot the target machine via the generated Live ISO and launch the desktop installer icon.
6. Setup the new user account and proceed with the installation.
7. **CRITICAL:** Once the installation progress reaches 100%, **DO NOT** reboot and do not close the installer window yet.
8. Minimize the installer window, double-click `oem-post-install.sh` on the Live Desktop, and select **"Run in Terminal"**.
9. Wait for the graphic success dialog box, return to the installer, check the "Restart" box, and hit "Done".

---

## 📌 Method 2: Dynamic Live-Session Interception (100% Automated Deployment)

Designed for frictionless end-user distribution. The entire asset delivery and code injection are managed implicitly by the installer backend. No manual shell execution or interaction is required within the live environment.

### Key Features:
* Operates via a lightning-fast **on-the-fly resource interception workflow (hot-patching)**.
* Modifies the installer backend runtime configuration memory via a background daemon tracking filesystem writes.
* **Timeout Protection:** Automatically rewrites the Calamares execution limits configuration (`timeout: 600` to `99999`), preventing installer crashes during heavy profile migrations (e.g., massive `.wine`, `.playonlinux`, or Android virtual environments).
* Automatically evaluates and targets the unique username established by the end-user via the installation GUI.
* Safe stream filtering using `grep -Z` and `xargs -r -0` to adapt absolute developer paths to the new user namespace across all text configs, safely isolating binary `dconf` nodes to prevent environment crashes.

### How to use:
1. On your master machine, compress your baseline configurations along with the administrative root environment:
   ```bash
   sudo tar -czf /opt/my_settings.tar.gz -C ~ .config .local /root/.config /root/.local
   ```
   *(Note: You can easily include additional application directories by appending them to the end of the command if needed, e.g., `.wine .goldendict /root/.synaptic`)*
2. **⚠️ IMPORTANT:** Open the `automated-patch-code.sh` file from this repository and replace `MASTER_USER` (line 7) with your actual master system username. Then, copy its entire contents and append it to the very end of your master machine's core script located at `/etc/penguins-eggs.d/scripts/bootstrap-liveroot.sh`.
3. Run standard image production on the master host: 
   ```bash
   sudo coa remaster
   ```
   *(The generated ISO file will be saved by default in the `/home/eggs/` directory).*
4. Burn the generated ISO. Hand over the media to the end-user.
5. The end-user follows standard GUI installation routines. On the final lifecycle segment (`install-bootloader`), the backend silently injects the user and root configurations, resolves UNIX permissions (`1000:1000` for user, `root:root` for /root), processes high-speed Perl-stream rewrites, and purges all setup artifacts automatically.

## 💻 Technical Stack
* **OS:** Linux Mint 22.3 (Debian/Ubuntu package base)
* **Core Engine:** Penguins' Eggs / `coa` (Go/C Core Architecture v26+)
* **Automation:** Bash (Shell scripting), Chroot environments, JSON streaming
* **Stream I/O Processing:** Grep (Regex), Xargs, Perl (Stream rewriting via environment `$ENV`)
