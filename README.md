# FS2 install kit

FS2 is a TETRA base station for Raspberry Pi with a software-defined radio board.
This repository contains only the **installation kit**: scripts, a clean configuration template
and step-by-step instructions. The program itself is a ready-made file on the
[Releases](../../releases) page. There is no source code here.

## What you need

- Raspberry Pi 5 (or CM5), 64-bit **Raspberry Pi OS (Debian 13 "trixie")**, internet access
- One radio board: **SX1255 board** (tested), PlutoSDR or LimeSDR (not tested yet)
- The legal right to transmit on your chosen frequencies. You are responsible for this.

## Choose your way

| You have | Do this |
|---|---|
| A Raspberry Pi that already runs Raspberry Pi OS | [Install on an existing system](docs/INSTALL-existing-os.md) |
| The ready-made FS2 Raspberry Pi image | [Use the image](docs/INSTALL-image.md) |

### Quick start (existing system)

```
sudo apt-get update && sudo apt-get install -y git
git clone https://github.com/yo9ion/fs2-kit.git
cd fs2-kit
sudo bash install.sh
```

The installer asks which board you have, installs what is needed, downloads the program,
checks it, and then asks a few questions (frequency, network codes). At the end it prints the
dashboard address and your password.

## After installing

- Open the dashboard: `http://<pi-address>:8080` and log in with the printed password.
- Check everything: `fs2-doctor`
- Logs: `/opt/fs2/log/tetra_full.log` and `journalctl -u fs2 -n 50`
- Do not put the dashboard directly on the public internet.

## Updating

Press **Update** in the FS2 dashboard when it shows a newer version. The program downloads the new
version, checks it, keeps the old one as `/opt/fs2/fs2.prev`, and restarts by itself.
Manual way: `cd fs2-kit && git pull && sudo bash install.sh --binary-only`.

## More

- [Radio boards and driver notes](docs/SDR-BOARDS.md)
- [Building the image yourself](docs/BUILD-IMAGE.md) (maintainers)
- [Publishing a new version](docs/MAINTAINER.md) (maintainers)

Licensing: see [LICENSE](LICENSE) and [NOTICE](NOTICE).
