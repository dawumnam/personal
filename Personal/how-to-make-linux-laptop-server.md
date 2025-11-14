# How to Configure Ubuntu 24.04 Laptop as a Server

This guide documents the complete setup process to run an Ubuntu 24.04 laptop as a headless server with the lid closed.

**System:** ASUS TUF Gaming A14 FA401UM
**OS:** Ubuntu 24.04 (Noble)
**Kernel:** 6.14.0-35-generic
**Date:** November 14, 2025

---

## Table of Contents

1. [Shell Environment Setup](#1-shell-environment-setup)
2. [SSH Server Installation](#2-ssh-server-installation)
3. [Lid Close Configuration](#3-lid-close-configuration)
4. [Tailscale VPN Installation](#4-tailscale-vpn-installation)
5. [Automatic Suspend Prevention](#5-automatic-suspend-prevention)
6. [USB Power Management](#6-usb-power-management)
7. [Screen Backlight Management](#7-screen-backlight-management)
8. [Thermal Monitoring](#8-thermal-monitoring)
9. [Automatic Login Configuration](#9-automatic-login-configuration)
10. [Verification & Testing](#10-verification--testing)
11. [Troubleshooting](#11-troubleshooting)

---

## 1. Shell Environment Setup

### Install Zsh and Oh-My-Zsh

```bash
# Install zsh
sudo apt update
sudo apt install -y zsh

# Install git (required for oh-my-zsh)
sudo apt install -y git

# Configure git
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"

# Install oh-my-zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
```

### Install Essential Zsh Plugins

```bash
# zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions

# zsh-syntax-highlighting
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

# zsh-completions
git clone https://github.com/zsh-users/zsh-completions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-completions
```

### Configure Plugins

Edit `~/.zshrc` and update the plugins line:

```bash
plugins=(
  git
  zsh-autosuggestions
  zsh-syntax-highlighting
  zsh-completions
)
```

Enable the PATH in `~/.zshrc`:

```bash
export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH
```

### Set Zsh as Default Shell (Optional)

```bash
chsh -s $(which zsh)
# Log out and back in for this to take effect
```

---

## 2. SSH Server Installation

### Install OpenSSH Server

```bash
sudo apt update
sudo apt install -y openssh-server
```

### Enable and Start SSH Service

```bash
sudo systemctl enable ssh
sudo systemctl start ssh
```

### Verify SSH is Running

```bash
systemctl status ssh
```

Expected output: `Active: active (running)`

### Get Your IP Address

```bash
hostname -I
```

### Test SSH Connection

From another machine:

```bash
ssh your-username@your-ip-address
```

**Note:** SSH will automatically start on every boot.

---

## 3. Lid Close Configuration

### Problem
By default, Ubuntu suspends when you close the laptop lid. For a server, we need it to keep running.

### Solution

Edit `/etc/systemd/logind.conf`:

```bash
sudo nano /etc/systemd/logind.conf
```

Find and modify these lines (remove `#` to uncomment):

```conf
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
IdleAction=ignore
```

### Restart systemd-logind

```bash
sudo systemctl restart systemd-logind
```

**Important:** Restarting systemd-logind may log you out of GUI sessions.

### Verify Configuration

```bash
grep -E "(HandleLidSwitch|IdleAction)" /etc/systemd/logind.conf | grep -v "^#"
```

Expected output:
```
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
IdleAction=ignore
```

---

## 4. Tailscale VPN Installation

Tailscale provides secure remote access from anywhere without port forwarding.

### Add Tailscale Repository

```bash
# Add GPG key
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.noarmor.gpg | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null

# Add repository
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.tailscale-keyring.list | sudo tee /etc/apt/sources.list.d/tailscale.list
```

### Install Tailscale

```bash
sudo apt-get update
sudo apt-get install -y tailscale
```

### Connect to Tailscale Network

```bash
sudo tailscale up
```

Follow the URL provided to authenticate with your Tailscale account.

### Verify Tailscale Status

```bash
tailscale status
```

You should see your device with an assigned Tailscale IP (100.x.x.x).

**Note:** Tailscale will automatically start on every boot.

---

## 5. Automatic Suspend Prevention

### Problem
Even with lid close ignored, GNOME power management will still suspend the system after idle timeout.

### Check Current Settings

```bash
# Check AC power timeout (in seconds)
gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout

# Check battery timeout (in seconds)
gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout
```

Default values:
- AC power: 3600 (60 minutes)
- Battery: 900 (15 minutes)

### Disable Automatic Suspend

```bash
# Disable suspend on AC power
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout 0

# Disable suspend on battery
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout 0
```

**Note:** Setting to `0` means never suspend.

### Verify Changes

```bash
gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout
gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout
```

Both should return `0`.

---

## 6. USB Power Management

### Problem
If using USB-C hub for Ethernet, the hub may autosuspend and disconnect your network.

### Identify USB Devices

```bash
lsusb | grep -i "hub\|ethernet"
```

Example output:
```
Bus 006 Device 002: ID 05e3:0626 Genesys Logic, Inc. Hub
Bus 006 Device 003: ID 0bda:8153 Realtek Semiconductor Corp. RTL8153 Gigabit Ethernet Adapter
```

### Check Current Power Management

```bash
# Find your USB hub (adjust path based on your bus number)
cat /sys/bus/usb/devices/6-1/power/control
cat /sys/bus/usb/devices/6-1.2/power/control
```

- `auto` = autosuspend enabled
- `on` = autosuspend disabled

### Disable Autosuspend Immediately

```bash
# For USB hub
echo 'on' | sudo tee /sys/bus/usb/devices/6-1/power/control

# For Ethernet adapter
echo 'on' | sudo tee /sys/bus/usb/devices/6-1.2/power/control
```

### Make It Persistent with udev Rules

Create `/etc/udev/rules.d/50-usb-power.rules`:

```bash
sudo nano /etc/udev/rules.d/50-usb-power.rules
```

Add the following content (replace VendorID:ProductID with your devices):

```conf
# Disable USB autosuspend for USB-C hub and Ethernet adapter
# Genesys Logic USB3.1 Hub
ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="05e3", ATTR{idProduct}=="0626", ATTR{power/control}="on"

# Realtek RTL8153 Gigabit Ethernet Adapter
ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="0bda", ATTR{idProduct}=="8153", ATTR{power/control}="on"
```

### Reload udev Rules

```bash
sudo udevadm control --reload-rules
sudo udevadm trigger
```

### Verify Persistent Configuration

```bash
cat /sys/bus/usb/devices/6-1/power/control
cat /sys/bus/usb/devices/6-1.2/power/control
```

Both should show `on`.

---

## 7. Screen Backlight Management

### Problem
When lid is closed with `HandleLidSwitch=ignore`, the screen backlight stays on, wasting power (~2-5W) and generating heat.

### Solution: Console Blanking

Add kernel parameter to automatically turn off the screen after idle timeout.

### Backup GRUB Configuration

```bash
sudo cp /etc/default/grub /etc/default/grub.backup
```

### Edit GRUB Configuration

```bash
sudo nano /etc/default/grub
```

Find this line:
```
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"
```

Change it to:
```
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash consoleblank=60"
```

**Note:** `consoleblank=60` turns off screen after 60 seconds of inactivity.

### Update GRUB

```bash
sudo update-grub
```

### Verify Changes

```bash
sudo grep "consoleblank" /boot/grub/grub.cfg | head -2
```

You should see `consoleblank=60` in the kernel parameters.

**Important:** This change requires a reboot to take effect.

### Verify After Reboot

```bash
cat /proc/cmdline | grep consoleblank
```

---

## 8. Thermal Monitoring

### Problem
Laptops with closed lids can run 5-10°C hotter due to reduced airflow. Monitoring temperatures is crucial.

### Install lm-sensors

```bash
sudo apt install -y lm-sensors
```

### Detect Available Sensors

```bash
sudo sensors-detect --auto
```

**Note:** On many laptops, hardware sensors aren't detected because thermal management is handled by ACPI. This is normal.

### Check Temperature Sensors

```bash
sensors
```

Example output:
```
k10temp-pci-00c3
Adapter: PCI adapter
Tctl:         +37.4°C

amdgpu-pci-6500
Adapter: PCI adapter
edge:         +32.0°C
PPT:           6.12 W

nvme-pci-0400
Adapter: PCI adapter
Composite:    +27.9°C
```

### Create Temperature Check Script

```bash
cat > ~/check_temps.sh << 'EOF'
#!/bin/bash
# Quick temperature check script for dev server

echo "=== System Temperatures ==="
echo ""
sensors | grep -E "(°C|RPM|W)" | grep -v "^$"
echo ""
echo "Current time: $(date)"
EOF

chmod +x ~/check_temps.sh
```

### Usage

```bash
# Quick check
sensors

# Using the script
~/check_temps.sh

# Watch in real-time (updates every 2 seconds)
watch -n 2 sensors

# Check remotely via SSH
ssh user@server-ip 'sensors'
```

### Safe Operating Temperatures

- **CPU:** Under 85°C normal, under 70°C ideal
- **GPU:** Under 80°C normal, under 70°C ideal
- **NVMe SSD:** Under 70°C normal, under 60°C ideal

### Warning Signs

- CPU/GPU consistently over 85°C → Improve cooling
- Fans constantly at max speed → Check for dust/airflow
- System throttling → Too hot

---

## 9. Automatic Login Configuration

### Why Automatic Login is Needed

For a headless server that operates without manual intervention after reboot, automatic login is **essential**.

**What works WITHOUT login:**
- ✅ SSH server (system service)
- ✅ Tailscale (system service)
- ✅ Network/Ethernet connection
- ✅ Lid close handling (systemd logind.conf)
- ✅ USB autosuspend settings (udev rules)
- ✅ Console blanking (kernel parameter)

**What REQUIRES login:**
- ⚠️ GNOME power management settings (user-level)
- ⚠️ User-level applications and services
- ⚠️ Desktop environment features

### The Problem

The GNOME power settings we configured are user-level settings:

```bash
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout 0
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout 0
```

These only apply when the user is logged in. Without automatic login, the system might still suspend after reboot until you manually login.

### Security Consideration

**Important:** Enabling automatic login means anyone with physical access to your laptop can see your desktop without entering a password.

**Mitigations:**
- Keep laptop in a secure location
- Screen will turn off after 60 seconds (consoleblank)
- Lid will be closed anyway
- SSH still requires password/authentication
- Tailscale still requires authentication

### Enable Automatic Login

#### Backup GDM Configuration

```bash
sudo cp /etc/gdm3/custom.conf /etc/gdm3/custom.conf.backup
```

#### Edit GDM Configuration

```bash
sudo nano /etc/gdm3/custom.conf
```

Find the `[daemon]` section and add these lines:

```conf
[daemon]
AutomaticLoginEnable = true
AutomaticLogin = your-username
```

**Or use sed to do it automatically:**

```bash
sudo sed -i '/\[daemon\]/a AutomaticLoginEnable = true\nAutomaticLogin = your-username' /etc/gdm3/custom.conf
```

Replace `your-username` with your actual username (e.g., `dawum-nam`).

#### Verify Configuration

```bash
cat /etc/gdm3/custom.conf
```

Expected output should include:

```conf
[daemon]
AutomaticLoginEnable = true
AutomaticLogin = your-username
```

#### Reboot to Test

```bash
sudo reboot
```

After reboot:
- System should automatically login to your desktop
- All services and settings will be active
- SSH/Tailscale should be immediately accessible

### Verify Automatic Login is Working

From another device, SSH into your server:

```bash
ssh your-username@your-server-ip
```

Then check who is logged in:

```bash
who
# Should show your username logged in on tty or :0
```

### Automatic Recovery After Reboot

With automatic login enabled:

| Scenario | Automatic Recovery? |
|----------|---------------------|
| Software crash/reboot | ✅ YES - Fully automatic |
| Kernel panic | ✅ YES - Fully automatic |
| Manual reboot command | ✅ YES - Fully automatic |
| System hang (SSH reboot) | ✅ YES - Fully automatic |
| Scheduled reboots | ✅ YES - Fully automatic |
| **Power failure** | ❌ NO - Manual power button needed* |
| **Battery dies** | ❌ NO - Manual power button needed* |

**Note:** Most consumer laptops don't automatically power on after complete power loss. Only software-initiated reboots will auto-recover.

### Optional: Check for BIOS Auto-Power-On

Some laptops (mainly business models) support auto-power-on after AC power loss:

1. Reboot and enter BIOS (usually F2 or DEL during boot)
2. Look for settings:
   - "Restore on AC/Power Loss"
   - "Power On After Power Failure"
   - "AC Recovery"
3. If available, set to "Power On" or "Last State"

**Reality:** Most consumer/gaming laptops don't have this feature. If you need 100% uptime, consider:
- UPS (Uninterruptible Power Supply) - Recommended
- Remote monitoring to alert when server goes offline
- Physical access plan for power button press

---

## 10. Verification & Testing

### System Configuration Checklist

Run these commands to verify everything is configured correctly:

```bash
# 1. SSH Service
systemctl status ssh
systemctl is-enabled ssh

# 2. Tailscale Service
systemctl status tailscaled
tailscale status

# 3. Lid Close Configuration
grep -E "(HandleLidSwitch|IdleAction)" /etc/systemd/logind.conf | grep -v "^#"

# 4. Automatic Suspend Disabled
gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout
gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout

# 5. USB Power Management
cat /sys/bus/usb/devices/6-1/power/control
cat /sys/bus/usb/devices/6-1.2/power/control

# 6. Console Blanking (after reboot)
cat /proc/cmdline | grep consoleblank

# 7. Temperature Monitoring
sensors

# 8. Network Connectivity
hostname -I
nmcli device status

# 9. Automatic Login
cat /etc/gdm3/custom.conf | grep -A 1 "\[daemon\]"
who
```

### Expected Results

1. **SSH:** Active and enabled
2. **Tailscale:** Connected with 100.x.x.x IP
3. **Lid Close:** `HandleLidSwitch=ignore`, `HandleLidSwitchExternalPower=ignore`, `IdleAction=ignore`
4. **Suspend:** Both timeouts = `0`
5. **USB Power:** Both = `on`
6. **Console Blank:** `consoleblank=60` in kernel parameters
7. **Temps:** CPU/GPU under 70°C is ideal
8. **Network:** Ethernet connected, Tailscale active
9. **Auto-Login:** `AutomaticLoginEnable = true` and `AutomaticLogin = your-username` in GDM config, user shown in `who` output

### Test Lid Close Behavior

1. Close the laptop lid
2. Wait 30 seconds
3. From another device, SSH into the laptop:
   ```bash
   ssh user@laptop-ip
   ```
4. Check system is still running:
   ```bash
   uptime
   sensors
   ```

### Test Remote Access

```bash
# Via local network
ssh user@local-ip

# Via Tailscale (from anywhere)
ssh user@tailscale-ip
```

---

## 11. Troubleshooting

### SSH Connection Issues

**Problem:** Cannot connect via SSH

**Solutions:**
```bash
# Check SSH is running
sudo systemctl status ssh

# Check firewall (if enabled)
sudo ufw status
sudo ufw allow 22/tcp

# Check SSH is listening
ss -tlnp | grep :22
```

### System Still Suspends

**Problem:** Laptop suspends even with lid close ignored

**Check:**
```bash
# 1. Verify logind.conf
grep HandleLidSwitch /etc/systemd/logind.conf | grep -v "^#"

# 2. Verify GNOME power settings
gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout

# 3. Check for other power management services
systemctl list-units | grep -i power
```

### Network Disconnects When Lid Closes

**Problem:** Ethernet connection drops when lid is closed

**Check:**
```bash
# 1. Verify USB power management
cat /sys/bus/usb/devices/*/power/control

# 2. Check udev rules exist
cat /etc/udev/rules.d/50-usb-power.rules

# 3. Monitor USB events
sudo udevadm monitor
```

### Screen Won't Turn Off

**Problem:** Screen backlight stays on after lid close

**Check:**
```bash
# 1. Verify consoleblank parameter
cat /proc/cmdline | grep consoleblank

# 2. Check backlight status
cat /sys/class/backlight/*/brightness

# 3. Manually blank console (temporary)
setterm --blank 1 --powerdown 2
```

### Overheating Issues

**Problem:** Laptop running too hot with lid closed

**Solutions:**

1. **Check current temperatures:**
   ```bash
   sensors
   watch -n 2 sensors
   ```

2. **Improve airflow:**
   - Place laptop on hard, flat surface
   - Ensure vents aren't blocked
   - Leave space around the laptop
   - Consider laptop cooling pad

3. **Clean dust from vents:**
   ```bash
   # Shutdown first
   sudo shutdown -h now
   # Use compressed air to clean vents
   ```

4. **Check for processes consuming CPU:**
   ```bash
   top
   htop
   ```

5. **Consider limiting CPU frequency:**
   ```bash
   # Install cpufrequtils
   sudo apt install cpufrequtils

   # Set governor to powersave
   sudo cpufreq-set -g powersave
   ```

### Reboot After Updates

**Problem:** System reboots automatically after updates

**Check:**
```bash
# Verify auto-reboot is disabled
grep "Automatic-Reboot" /etc/apt/apt.conf.d/50unattended-upgrades
```

Should show:
```
//Unattended-Upgrade::Automatic-Reboot "false";
```

### Check System Logs

```bash
# View system logs
journalctl -b

# Check for suspend events
journalctl | grep -i "suspend\|sleep"

# Check lid events
journalctl -b | grep -i "lid"

# View last boot logs
journalctl -b -1
```

---

## Summary

Your laptop is now configured as a headless server with:

- ✅ **SSH Server** - Remote access on port 22
- ✅ **Tailscale VPN** - Secure access from anywhere
- ✅ **Lid Close Handling** - System stays running when lid closed
- ✅ **Suspend Prevention** - Never auto-suspends
- ✅ **USB Power Management** - Network stays connected
- ✅ **Screen Power Saving** - Backlight turns off automatically
- ✅ **Thermal Monitoring** - Track temperatures
- ✅ **Automatic Login** - User logs in automatically on boot
- ✅ **Auto-start Services** - SSH and Tailscale start on boot
- ✅ **Auto Updates** - System updates automatically (no auto-reboot)

## Access Information

**Local Network:**
```bash
ssh dawum-nam@210.223.39.152
```

**Tailscale (from anywhere):**
```bash
ssh dawum-nam@100.66.93.42
```

## Best Practices for Laptop Servers

1. **Keep it plugged in** - Running on battery defeats the purpose
2. **Position properly** - Hard, flat surface with good airflow
3. **Monitor temps weekly** - Run `sensors` to check temperatures
4. **Check logs monthly** - `journalctl -b` to review system health
5. **Update regularly** - `sudo apt update && sudo apt upgrade`
6. **Backup important data** - Laptops aren't enterprise hardware
7. **UPS recommended** - Protect against power outages
8. **Consider physical security** - Laptop can be easily moved/stolen

## Additional Resources

- [Ubuntu Server Guide](https://ubuntu.com/server/docs)
- [systemd logind.conf man page](https://www.freedesktop.org/software/systemd/man/logind.conf.html)
- [Tailscale Documentation](https://tailscale.com/kb/)
- [Oh My Zsh GitHub](https://github.com/ohmyzsh/ohmyzsh)

---

**Document Version:** 1.0
**Last Updated:** November 14, 2025
**Author:** Created during system configuration session
