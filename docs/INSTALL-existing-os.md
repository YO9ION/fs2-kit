# Install on an existing Raspberry Pi OS

For a Pi that already boots and works (Raspberry Pi OS 64-bit, Debian 13 "trixie").

## 1. Prepare

1. Connect the radio board and power the Pi with a good power supply.
2. Make sure the Pi is online: `ping -c 2 github.com`
3. Check it is 64-bit: `uname -m` must print `aarch64`.

## 2. Install

```
sudo apt-get update && sudo apt-get install -y git
git clone https://github.com/yo9ion/fs2-kit.git
cd fs2-kit
sudo bash install.sh
```

What the installer does, in order:

1. Detects your radio board (or asks you). Use `--sdr sx`, `--sdr pluto` or `--sdr lime` to choose it yourself.
2. Installs the packages (SoapySDR; for the SX board also the build tools).
3. SX board only: builds the **SoapySX** driver from its author's public repository (pinned to a tested version), installs the sound-server rule for the I2S port, and loads `i2c-dev` at boot.
4. Downloads the FS2 program from the latest release, **checks its checksum**, and installs it in `/opt/fs2`.
5. Installs the system service `fs2` (realtime priority, starts at boot).
6. Runs `fs2-setup`, which asks for your frequencies and network codes and writes `/opt/fs2/config.toml`.

## 3. First start

```
fs2-doctor
```

All lines should say `[ ok ]`. If the SX board is not found, reboot once (`sudo reboot`) and run it again.
Then open `http://<pi-address>:8080`.

## 4. Change settings later

- Dashboard, Config page (recommended), or edit `/opt/fs2/config.toml`, then `sudo systemctl restart fs2`.
- Start over with the questions: `sudo fs2-setup` (your old config is saved next to it).
- A known-good copy is kept as `/opt/fs2/config.toml.fallback`. If you break the config, FS2 starts with the fallback and shows a red warning in the dashboard.

## 5. Remove

```
sudo systemctl disable --now fs2
sudo rm -rf /opt/fs2 /etc/systemd/system/fs2.service /usr/local/bin/fs2-setup /usr/local/bin/fs2-doctor
```
