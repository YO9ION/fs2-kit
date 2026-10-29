# Use the ready-made FS2 image

The image is Raspberry Pi OS with everything already installed: FS2, the radio driver and the service.
You only add your own settings. Later updates come from the **Update** button in the dashboard.

## 1. Write the image

1. Download the image file from the [Releases](../../releases) page (`fs2-image-....img.xz`) and its `.sha256` file.
2. Check it: `sha256sum -c fs2-image-....img.xz.sha256`
3. Write it to a microSD card or SSD with Raspberry Pi Imager: **Use custom** and pick the file.
   Do not use the Imager's "OS customisation" for WiFi or users unless you know what you are doing.

## 2. First start

1. Connect the radio board and the network cable, then power on. The first boot takes a few minutes.
2. Log in over SSH: user `fs2`, temporary password written on the Releases page.
   You are forced to choose a new password at the first login.
3. Run the setup (frequency, network codes, dashboard password):

```
sudo fs2-setup
sudo systemctl restart fs2
fs2-doctor
```

4. Open `http://<pi-address>:8080` and log in with the password printed by `fs2-setup`.

## 3. Updates

- Dashboard: press **Update** when a newer version is offered. It downloads, checks, swaps the program and restarts by itself.
- Your config, logs and settings are not touched by an update.
- If something goes wrong, the previous program is kept as `/opt/fs2/fs2.prev`:
  `sudo mv /opt/fs2/fs2.prev /opt/fs2/fs2 && sudo systemctl restart fs2`

## 4. Good to know

- The operating system itself is not updated by the FS2 button. Run `sudo apt update && sudo apt full-upgrade` now and then.
- Do not put the dashboard directly on the public internet.
