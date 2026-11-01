# PlutoSDR / PlutoSDR+ with FS2

Status: verified working on one station (Pluto Rev.C, Z7010-AD9363A, with the Pluto+ timestamping firmware).

## What is required (all three, otherwise radios say "no service")
1. **Timestamping firmware on the board.** The stock firmware cannot be used.
   - Adalm Pluto: https://github.com/pgreenland/plutosdr-fw/releases
   - Pluto+: https://github.com/wahlm/plutosdr-fw-timestamp/releases
   The installer downloads the Pluto+ firmware straight from the upstream release (`plutosdr-fw-v0.38_plutoplus_with_timestamping-3-g54f7-dirty.zip`, v0.38_plutoplus_timestamp_w1, sha256 `411c617f512a02e2b0e4b7866d993e5d5aafbaae0dbf2fee93868c790cdde9e1`) and checks that checksum; the file is not copied into this kit. Only the file `pluto.frm` inside that zip is used. For an original Adalm Pluto set `PLUTO_FW_URL` / `PLUTO_FW_SHA256` in `defaults.env` to the pgreenland release instead.
2. **Patched SoapyPlutoSDR driver** (hardware timestamping):
   `https://github.com/pgreenland/SoapyPlutoSDR`, branch `sdr_gadget_timestamping`.
   The FS2 installer (`sudo bash install.sh --sdr pluto`) builds it for you (3-5 minutes) and pins the tested commit `2bbf771`. The stock `soapysdr-module-plutosdr` package or `pothosware/SoapyPlutoSDR` is NOT enough: the carrier is visible on a receiver, but radios never register.
3. **USB access rule** for the board (vendor 0456, product b673): the installer writes `/etc/udev/rules.d/90-libiio_pluto.rules`.

## Firmware check in the installer
`install.sh --sdr pluto` reads the board's firmware version (`iio_attr -u ip:192.168.2.1 -C fw_version`). If it does not contain "timestamp" it warns that radios will not register. If `PLUTO_FW_URL` (and `PLUTO_FW_SHA256`) are set in `defaults.env`, it offers to flash the firmware: type `yes`, it copies `pluto.frm` to the board's mass-storage drive, the board flashes itself (about 4 minutes, do not unplug it), then run the installer again. Set `FS2_FLASH_FW=1` to skip the question. This flashing step has NOT been tested on hardware yet.

## How to check it worked
- `SoapySDRUtil --find` lists `driver = plutosdr`.
- In FS2's log (`log/tetra_full_error.log`) after start you should see:
  `RX timestamping enabled, every 1500 samples` and `TX timestamping enabled, every 1500 samples`.
  If these lines are missing, the stock driver or firmware is still in use.

## Settings that were verified
- Config `[phy_io.soapysdr]`: `device = "driver=plutosdr"`; all gain lines may stay commented out (board defaults: TX 0 dB attenuation = maximum power, RX 20 dB manual).
- Keep radios a few metres away from the board when testing: TX power is high.
- `ppm_err` (oscillator correction) was not needed on the tested board; try small values (for example 5.0 or -5.0) only if radios still do not lock.
- `freq_offset` in `[cell_info]` is a channel offset, not an oscillator correction.

## Dashboard (VPS) notes
- `rf_export_label` in `[brew_secondary]` must be at most 16 characters (letters, digits, - and _), and unique per cell, otherwise the RF panel does not appear.
- Two cells at one site need different `location_area` numbers (the VPS card name is built from it).
