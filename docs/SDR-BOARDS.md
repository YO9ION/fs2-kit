# Radio boards

| Board | Status | Driver |
|---|---|---|
| SX1255 board (SXceiver) | tested | SoapySX, built from https://github.com/tejeez/sxxcvr by `install.sh` |
| PlutoSDR | not tested | Debian package `soapysdr-module-plutosdr` |
| LimeSDR | not tested | Debian package `soapysdr-module-lms7` |

For PlutoSDR and LimeSDR the installer only installs the driver and sets `device = "driver=..."`.
List the gain names of your device with `SoapySDRUtil --probe` and add `rx_gain_<name>` /
`tx_gain_<name>` lines to the `[phy_io.soapysdr]` section.

## SX1255 board: how it works

- The board sends samples over **I2S** (it shows up as a sound card named `SX1255`: `aplay -l`)
  and is controlled over SPI/I2C. The Pi loads the matching device-tree overlay from the **HAT
  EEPROM** on the board, so nothing is added to `config.txt`.
- If your board has no HAT EEPROM written (some prototypes), write it first by following
  `dts/README.md` in https://github.com/tejeez/sxxcvr .
- `install.sh` also installs a small sound-server rule that keeps PipeWire away from the I2S port
  and loads the `i2c-dev` module at boot.

## Checks

```
aplay -l | grep SX1255
SoapySDRUtil --find
fs2-doctor
```

If the board is not found: power-cycle the Pi (not just a reboot), check the board is seated and
powered, then run `fs2-doctor` again.

## Transmit power

The default gains in the generated config are the values used on the reference station. They
depend on your hardware (amplifier, filter, antenna). Measure the output and set the gains so
you stay within the legal limit.
