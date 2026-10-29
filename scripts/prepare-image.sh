#!/usr/bin/env bash
# Run on the REFERENCE Raspberry Pi right before you copy its SD card to an image file.
# Removes personal data and per-device identity. After it finishes, power off and copy the card.
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "Run as root: sudo $0" >&2; exit 1; }
echo "This will DELETE the FS2 config, logs, WiFi passwords, SSH keys and shell history on THIS Pi."
read -r -p 'Type WIPE to continue: ' a </dev/tty
[ "$a" = "WIPE" ] || { echo "Cancelled."; exit 1; }

systemctl stop fs2 2>/dev/null || true
systemctl disable fs2-firstboot.service >/dev/null 2>&1 || true

# FS2: keep only the program and the config template
if [ -d /opt/fs2 ]; then
  find /opt/fs2 -mindepth 1 -maxdepth 1 ! -name fs2 ! -name share -exec rm -rf {} +
  install -d /opt/fs2/log
fi

# Network secrets
rm -f /etc/NetworkManager/system-connections/* /etc/wpa_supplicant/wpa_supplicant*.conf 2>/dev/null || true

# Per-device identity (recreated on first boot)
rm -f /etc/ssh/ssh_host_*
: > /etc/machine-id
rm -f /var/lib/dbus/machine-id

# Shell history, keys, caches
for h in /root /home/*; do
  [ -d "$h" ] || continue
  rm -f "$h/.bash_history" "$h/.viminfo" "$h/.lesshst" "$h/.ssh/authorized_keys" "$h/.ssh/known_hosts" "$h"/.ssh/id_* 2>/dev/null || true
  rm -rf "$h/.cache" "$h/.gitconfig" "$h/.git-credentials" 2>/dev/null || true
done

# Logs and temporary files
journalctl --rotate >/dev/null 2>&1 || true
journalctl --vacuum-time=1s >/dev/null 2>&1 || true
find /var/log -type f -exec truncate -s 0 {} + 2>/dev/null || true
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* 2>/dev/null || true

# Temporary build user must change the password at first login
if id fs2 >/dev/null 2>&1; then chage -d 0 fs2; fi

# First boot: create new SSH host keys
install -m 644 "$(dirname "$0")/../systemd/fs2-firstboot.service" /etc/systemd/system/fs2-firstboot.service
systemctl enable fs2-firstboot.service >/dev/null 2>&1 || true

sync
echo
echo "Done. Now run:  sudo poweroff   then copy the SD card to an image (see docs/BUILD-IMAGE.md)."
echo "Do NOT boot this card again before you have made the image."
