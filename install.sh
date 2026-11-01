#!/usr/bin/env bash
# FS2 installer for an existing, working Raspberry Pi OS (Debian 13 "trixie", 64-bit).
# Usage:  sudo bash install.sh [--sdr sx|pluto|lime] [--binary-only] [--binary FILE] [--no-setup] [--yes]
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=defaults.env
. "$HERE/defaults.env"
PREFIX=/opt/fs2
SDR=""; BINARY_ONLY=0; LOCAL_BINARY=""; RUN_SETUP=1; ASSUME_YES=0

say()  { printf '\n\033[1;32m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33mWARNING: %s\033[0m\n' "$*"; }
die()  { printf '\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }
ask()  { local a; read -r -p "$1 " a </dev/tty || a=""; printf '%s' "$a"; }

while [ $# -gt 0 ]; do
  case "$1" in
    --sdr) SDR="${2:-}"; shift 2 ;;
    --binary-only) BINARY_ONLY=1; shift ;;
    --binary) LOCAL_BINARY="${2:-}"; shift 2 ;;
    --no-setup) RUN_SETUP=0; shift ;;
    --yes|-y) ASSUME_YES=1; shift ;;
    -h|--help) sed -n '2,3p' "$0"; exit 0 ;;
    *) die "Unknown option: $1" ;;
  esac
done

[ "$(id -u)" -eq 0 ] || die "Run as root:  sudo ./install.sh"
[ "$(uname -m)" = "aarch64" ] || die "FS2 needs 64-bit Raspberry Pi OS (aarch64). This system is $(uname -m)."
. /etc/os-release
[ "${VERSION_ID:-}" = "13" ] || warn "Tested on Debian 13 (trixie). This is ${PRETTY_NAME:-unknown}; continuing."
case "$FS2_REPO" in OWNER/*) [ -n "$LOCAL_BINARY" ] || die "defaults.env still contains the placeholder FS2_REPO. Edit it first." ;; esac

detect_sdr() {
  if command -v aplay >/dev/null 2>&1 && aplay -l 2>/dev/null | grep -qi 'SX1255'; then echo sx; return; fi
  if command -v lsusb >/dev/null 2>&1; then
    if lsusb 2>/dev/null | grep -qiE '1d50:6108|0403:601f'; then echo lime; return; fi
    if lsusb 2>/dev/null | grep -qi '0456:b673'; then echo pluto; return; fi
  fi
  echo ""
}


pluto_firmware_check() {
  # The PlutoSDR must run a TIMESTAMPING firmware. Check what the board reports and, if the file is
  # published (PLUTO_FW_URL), offer to flash it. NOT tested on hardware: flashing is always asked first.
  apt-get install -y --no-install-recommends libiio-utils >/dev/null 2>&1 || true
  local fw=""
  for u in ip:192.168.2.1 ip:pluto.local; do
    fw="$(iio_attr -u "$u" -C fw_version 2>/dev/null | head -n1 || true)"; [ -n "$fw" ] && break
  done
  if [ -z "$fw" ]; then
    warn "Could not read the PlutoSDR firmware version (board not reachable at 192.168.2.1). Check docs/PLUTO.md."
    return 0
  fi
  if printf '%s' "$fw" | grep -qi timestamp; then say "PlutoSDR firmware supports timestamping: $fw"; return 0; fi
  warn "PlutoSDR firmware has NO timestamping ($fw): radios will not register."
  if [ -z "${PLUTO_FW_URL:-}" ]; then
    warn "Flash a timestamping firmware first (links in docs/PLUTO.md), then run this installer again."; return 0
  fi
  local go="no"
  if [ "${FS2_FLASH_FW:-0}" = "1" ]; then go="yes"
  else go="$(ask "Flash the timestamping firmware now? Do NOT unplug the board for 5 minutes afterwards. Type yes:")"; fi
  [ "$go" = "yes" ] || { warn "Skipping the firmware flash."; return 0; }
  local z=/tmp/pluto-fw.zip f=/tmp/pluto.frm
  apt-get install -y --no-install-recommends unzip >/dev/null 2>&1 || true
  curl -fL --retry 3 -o "$z" "$PLUTO_FW_URL" || { warn "Firmware download failed."; return 0; }
  [ -z "${PLUTO_FW_SHA256:-}" ] || [ "$(sha256sum "$z" | awk '{print $1}')" = "$PLUTO_FW_SHA256" ] || { warn "Firmware checksum mismatch. Not flashing."; return 0; }
  rm -f "$f"; unzip -o -j "$z" pluto.frm -d /tmp >/dev/null 2>&1 && [ -s "$f" ] || { warn "pluto.frm not found in the firmware zip."; return 0; }
  local dev mnt=/mnt/plutofw
  dev="$(lsblk -rno PATH,LABEL 2>/dev/null | awk 'tolower($2) ~ /^pluto/ {print $1; exit}')"
  [ -n "$dev" ] || { warn "PlutoSDR mass-storage drive not found. Copy $f to it by hand (docs/PLUTO.md)."; return 0; }
  mkdir -p "$mnt"; mount "$dev" "$mnt" || { warn "Could not mount $dev"; return 0; }
  cp "$f" "$mnt/pluto.frm" && sync
  umount "$mnt" 2>/dev/null || true
  say "Firmware copied. The board now flashes itself and restarts (about 4 minutes). Do not unplug it. Run this installer again afterwards."
  exit 0
}

install_binary() {
  say "Installing the FS2 program"
  install -d -m 755 "$PREFIX" "$PREFIX/log" "$PREFIX/share"
  install -d -m 755 "$PREFIX/announcements" "$PREFIX/wap"
  # The program keeps some files (history, coverage points, announcements, WAP page, Proximity
  # minimum distance) under the fixed path /root/flowstation. Point that at the install folder.
  if [ ! -e /root/flowstation ] && [ ! -L /root/flowstation ]; then ln -s "$PREFIX" /root/flowstation; fi
  local tmp; tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' RETURN
  if [ -n "$LOCAL_BINARY" ]; then
    cp "$LOCAL_BINARY" "$tmp/fs2.bin"
  else
    local base="https://github.com/${FS2_REPO}/releases/latest/download"
    curl -fL --retry 3 -o "$tmp/fs2.bin" "$base/fs2-linux-aarch64" || die "Download failed. Check FS2_REPO in defaults.env and that a release exists."
    curl -fL --retry 3 -o "$tmp/fs2.sha256" "$base/fs2-linux-aarch64.sha256" || die "Checksum download failed."
    local want got
    want="$(awk '{print $1}' "$tmp/fs2.sha256")"; got="$(sha256sum "$tmp/fs2.bin" | awk '{print $1}')"
    [ -n "$want" ] && [ "$want" = "$got" ] || die "Checksum mismatch. Not installing."
    echo "Checksum OK ($got)"
  fi
  chmod 755 "$tmp/fs2.bin"
  file "$tmp/fs2.bin" 2>/dev/null | grep -qi 'aarch64' || warn "Could not confirm this is an aarch64 program."
  install -m 755 "$tmp/fs2.bin" "$PREFIX/fs2.new"
  [ -f "$PREFIX/fs2" ] && cp -f "$PREFIX/fs2" "$PREFIX/fs2.prev"
  mv -f "$PREFIX/fs2.new" "$PREFIX/fs2"
  # Address the dashboard Update button checks (never overwrite an address the user changed).
  if [ -n "${FS2_UPDATE_URL:-}" ] && [ ! -s "$PREFIX/fs2-update.url" ]; then
    printf '%s\n' "$FS2_UPDATE_URL" > "$PREFIX/fs2-update.url"
  fi
  [ -n "${FS2_UPDATE_PUBKEY:-}" ] && printf '%s\n' "$FS2_UPDATE_PUBKEY" > "$PREFIX/fs2-update.pubkey"
}

if [ "$BINARY_ONLY" -eq 1 ]; then
  install_binary
  systemctl restart fs2 && say "FS2 updated and restarted." || warn "Installed, but the service did not restart."
  exit 0
fi

[ -n "$SDR" ] || SDR="$(detect_sdr)"
if [ -z "$SDR" ]; then
  echo "Which radio board do you have?"
  echo "  1) SX1255 board (SXceiver)   2) PlutoSDR   3) LimeSDR"
  case "$(ask 'Number:')" in 1) SDR=sx ;; 2) SDR=pluto ;; 3) SDR=lime ;; *) die "No board chosen." ;; esac
fi
case "$SDR" in sx|pluto|lime) ;; *) die "Unknown board: $SDR (use sx, pluto or lime)" ;; esac
say "Radio board: $SDR"
[ "$SDR" = "sx" ] || warn "Only the SX board path is tested on real hardware. PlutoSDR/LimeSDR are untested."
if [ "$ASSUME_YES" -ne 1 ]; then
  [ "$(ask 'Continue installing? [y/N]')" = "y" ] || die "Cancelled."
fi

say "Installing packages"
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends ca-certificates curl file python3 python3-venv openssl ffmpeg usbutils libsoapysdr0.8 soapysdr-tools
case "$SDR" in
  sx) apt-get install -y --no-install-recommends git make g++ cmake libsoapysdr-dev libasound2-dev alsa-utils i2c-tools ;;
  pluto)
    # Pluto needs the PATCHED SoapyPlutoSDR (hardware timestamping). The stock Debian/pothosware
    # driver does not work: the carrier is on air but radios cannot synchronise. Firmware must also
    # be a timestamping build (Pluto: pgreenland/plutosdr-fw, Pluto+: wahlm/plutosdr-fw-timestamp).
    say "building the timestamping SoapyPlutoSDR driver (pgreenland, branch sdr_gadget_timestamping), 3-5 minutes"
    apt-get install -y --no-install-recommends git make g++ cmake libsoapysdr-dev libiio-dev libad9361-dev
    SRC=/usr/local/src/SoapyPlutoSDR
    rm -rf "$SRC"; git clone -b sdr_gadget_timestamping https://github.com/pgreenland/SoapyPlutoSDR.git "$SRC"
    # 2bbf771 = the build that was verified working (module version 0.2.1-2bbf771); fall back to branch head if it is gone
    git -C "$SRC" checkout 2bbf771 2>/dev/null || warn "pinned driver commit 2bbf771 not found, using the branch head"
    mkdir -p "$SRC/build"
    ( cd "$SRC/build" && cmake .. && make -j2 && make install && ldconfig )
    echo 'SUBSYSTEM=="usb", ATTR{idVendor}=="0456", ATTR{idProduct}=="b673", MODE="666"' > /etc/udev/rules.d/90-libiio_pluto.rules
    udevadm control --reload-rules 2>/dev/null || true; udevadm trigger 2>/dev/null || true
    pluto_firmware_check ;;
  lime) apt-get install -y --no-install-recommends soapysdr-module-lms7 ;;
esac

if [ "$SDR" = "sx" ]; then
  MOD=/usr/local/lib/SoapySDR/modules0.8/libSXSupport.so
  if [ -f "$MOD" ] && [ "${FS2_REBUILD_SX:-0}" != "1" ]; then
    say "SoapySX driver already installed (set FS2_REBUILD_SX=1 to rebuild)"
  else
    say "Building the SoapySX driver (about 1-2 minutes)"
    SRC=/usr/local/src/sxxcvr
    rm -rf "$SRC"; git clone "$SXXCVR_REPO" "$SRC"; git -C "$SRC" checkout "$SXXCVR_COMMIT"
    mkdir -p "$SRC/SoapySX/build"
    ( cd "$SRC/SoapySX/build" && cmake .. && make -j2 && make install && ldconfig )
    if [ -f "$SRC/SoapySX/60-pipewire-do-not-use-i2s.lua" ]; then
      install -D -m 644 "$SRC/SoapySX/60-pipewire-do-not-use-i2s.lua" /usr/share/wireplumber/main.lua.d/60-pipewire-do-not-use-i2s.lua
    fi
  fi
  printf 'i2c-dev\n' > /etc/modules-load.d/fs2.conf
  modprobe i2c-dev 2>/dev/null || true
fi

install_binary
install -m 755 "$HERE/scripts/fs2-setup" /usr/local/bin/fs2-setup
install -m 755 "$HERE/scripts/fs2-announce" /usr/local/bin/fs2-announce
install -m 644 "$HERE/systemd/fs2-forecast.service" /etc/systemd/system/fs2-forecast.service
install -m 644 "$HERE/systemd/fs2-forecast.timer" /etc/systemd/system/fs2-forecast.timer
install -m 755 "$HERE/scripts/fs2-doctor.sh" /usr/local/bin/fs2-doctor
install -m 644 "$HERE/systemd/fs2.service" /etc/systemd/system/fs2.service
systemctl daemon-reload
systemctl enable fs2 >/dev/null 2>&1

if [ ! -f "$PREFIX/config.toml" ] && [ "$RUN_SETUP" -eq 1 ]; then
  say "Configuration"
  fs2-setup --sdr "$SDR"
elif [ -f "$PREFIX/config.toml" ]; then
  say "Keeping your existing $PREFIX/config.toml"
fi

if [ -f "$PREFIX/config.toml" ]; then
  systemctl restart fs2 && say "FS2 is running." || warn "FS2 did not start. Run: fs2-doctor"
else
  say "Installed. Create the configuration with:  sudo fs2-setup   then:  sudo systemctl start fs2"
fi
[ "$SDR" = "sx" ] && echo && echo "If the SX board is not detected, reboot once and run: fs2-doctor  (see docs/SDR-BOARDS.md)"
exit 0
