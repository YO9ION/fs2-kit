# Building the FS2 image (maintainers)

Goal: one image file that anyone can write to a card, with no personal data inside.

**Do not copy your own working station's card.** It contains your config, logs, WiFi passwords,
SSH keys and history. Build from a clean official system instead; it is reproducible and safe.

## A. Build from a clean system (recommended)

1. Write the official **Raspberry Pi OS Lite (64-bit, Debian 13)** to a card with Raspberry Pi Imager.
   In the Imager settings create a **temporary** user `fs2` with the password `fs2-change-me`,
   and enable SSH. Do not enter your real WiFi or your own SSH key.
2. Boot, connect with the radio board, and update: `sudo apt update && sudo apt full-upgrade -y`.
3. Install the kit: clone this repository and run `sudo bash install.sh --no-setup --yes --sdr sx`.
   (No config is created: every user runs `fs2-setup` on their own.)
4. Do not boot with a real config. Check there is none: `ls /opt/fs2` shows only `fs2`, `log`, `share`.
5. Clean the system: `sudo bash scripts/prepare-image.sh` (type WIPE). It removes WiFi passwords, SSH keys,
   history, logs and the machine id, forces a password change for `fs2`, and enables new SSH host keys on first boot.
6. `sudo poweroff`. Do **not** boot this card again before imaging, or it creates new personal traces.

## B. Image from the card (on another computer)

Linux (replace `/dev/sdX` with the card, check with `lsblk`):

```
sudo dd if=/dev/sdX of=fs2-image.img bs=4M status=progress
sudo pishrink.sh -z fs2-image.img          # optional: shrinks and compresses
```

Without PiShrink: `xz -T0 -9 fs2-image.img`. Name the result `fs2-image-YYYY-MM-DD.img.xz` and create
its checksum: `sha256sum fs2-image-*.img.xz > fs2-image-YYYY-MM-DD.img.xz.sha256`.

## C. Check the image for personal data

Put your own words (callsign, domain, names, ISSIs, coordinates, addresses) one per line in
`~/.fs2-private-terms`. Then write the image to a spare card or loop-mount its partitions and scan:

```
sudo mkdir -p /mnt/img && sudo losetup -Pf --show fs2-image.img     # prints e.g. /dev/loop0
sudo mount /dev/loop0p2 /mnt/img
bash scripts/privacy-scan.sh /mnt/img/opt /mnt/img/etc /mnt/img/root /mnt/img/home
sudo umount /mnt/img && sudo losetup -d /dev/loop0
```

Every hit must be understood or removed. Rebuild if in doubt.

## D. Publish

1. GitHub, **Releases**, **Draft a new release**. Tag e.g. `image-2026-10`.
2. Attach the `.img.xz` and the `.sha256`. GitHub accepts files up to 2 GiB each. A larger image must be
   hosted elsewhere (for example your server) with the link in the release notes.
3. In the release notes write the temporary password (`fs2-change-me`) and the SHA-256.

## If you want to reuse your existing image

Only if you are sure about its contents: boot it on a spare Pi, run `sudo bash scripts/prepare-image.sh`,
power off, then continue with B and C. If the scan in C finds anything you cannot explain, build from
scratch with A instead.
