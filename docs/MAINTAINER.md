# Maintainer notes

## Create the repository (once)

1. On GitHub create a **public** repository named `fs2-kit` (no README, no .gitignore).
2. Edit `defaults.env` and replace `yo9ion/fs2-kit` with your own `username/fs2-kit`. Replace `OWNER` in
   `README.md` and the `docs/` files too (`sed -i 's#yo9ion/fs2-kit#USERNAME/fs2-kit#g' README.md docs/*.md defaults.env`).
3. Run the privacy scan on the folder: `bash scripts/privacy-scan.sh .` and fix every hit.
4. Upload: on your own computer with git logged in to your own account:

```
git init -b main && git add . && git commit -m "FS2 install kit"
git remote add origin https://github.com/USERNAME/fs2-kit.git
git push -u origin main
```

   (Or use the GitHub web page: **Add file**, **Upload files**, drag the folder content in.)
5. Create the license file on GitHub: **Add file**, **Create new file**, name it `LICENSE`; GitHub offers
   a template button, choose **Apache License 2.0**, commit.

## Publish a new program version

The installer expects two files on the **latest release**:

- `fs2-linux-aarch64` : the program (the `bluestation-bs` file from `target/release`)
- `fs2-linux-aarch64.sha256` : `sha256sum fs2-linux-aarch64 > fs2-linux-aarch64.sha256`

Steps on the build machine:

```
cp target/release/bluestation-bs fs2-linux-aarch64
sha256sum fs2-linux-aarch64 > fs2-linux-aarch64.sha256
```

Then GitHub, **Releases**, **Draft a new release**, new tag (e.g. `v0.3.1`), attach both files, **Publish**.
Only publish a build you have tested on a cell.

## Rules for this repository

- No source code, no config files with real values, no logs, no images in git.
- Never write names, callsigns, coordinates, addresses, domains, passwords or tokens in any file.
- Run `bash scripts/privacy-scan.sh .` before every push.

## Publishing an update (for the maintainer)

Updates reach the FS2 **Update** button through the update server (`FS2_UPDATE_URL` in `defaults.env`).
Nobody is updated automatically: each station only reads a tiny `latest.json` file to decide whether
the button should pulse, and downloads the program only when someone presses it.

1. Build on the build host (`cargo build --release`).
2. Run `/root/fs2-publish.sh`. It signs the program with the private key in `/root/fs2-signing/`
   (**never copy that key anywhere, never put it on GitHub**; keep a private backup) and uploads the
   program and `latest.json` to the update server.
3. Stations check every 30 minutes; the Update button turns green and pulses. Pressing it downloads the
   program, verifies the signature and checksum, keeps the old one as `fs2.prev` and restarts.

Rollback by hand: `sudo cp /opt/fs2/fs2.prev /opt/fs2/fs2 && sudo systemctl restart fs2`.

The public half of the signing key is compiled into the program. If the private key is lost, you must
publish a new program (by GitHub release) built with a new key; stations on the old key cannot be
updated by the button.

A station that was installed before this feature, or from an image made earlier, needs the program once
from the GitHub release (`sudo bash install.sh --binary-only`) and the address file:
`echo "<FS2_UPDATE_URL>" | sudo tee /opt/fs2/fs2-update.url`.

## Config: first install and later changes (maintainer)

- The full `config.toml` template is **not** in this repository. It lives on the update server and is signed.
  Publish it by copying the file to `/root/fs2-signing/config.template.toml` on the build host and running
  `/root/fs2-config-publish.sh`. `fs2-setup` downloads it, checks the signature, fills in the user's own values
  (frequencies, location, dashboard login, ...) and writes `fs2-config.level`.
- To change the config of every station later, add a change and publish it:

      /root/fs2-config-op.py default cell_info some_new_key 42      # add the line only if missing
      /root/fs2-config-op.py set     cell_info hangtime_secs 2       # add or change the line
      /root/fs2-config-op.py remove  cell_info old_key                # delete the line
      /root/fs2-config-publish.sh

  When a user presses Update, the signed list is downloaded and applied once at the next start. Only the listed
  lines are touched; the user's own values, comments and everything else stay. The result is checked with the
  real config parser first; if anything is wrong the old config is kept (`config.toml.pre-patch` is the backup,
  `fs2-config-patch.rejected` the refused list).
- Keep the template file in step with the changes (new installs get the template, existing stations get the changes).

## Announcements (hours + forecast with the user's city)

- The installer asks for the city and runs `fs2-announce setup` by itself (retry later: `sudo fs2-announce setup --city "YourCity"`). It installs ffmpeg and edge-tts, downloads the signed
  speech converter (`convert_one-aarch64`) from the update server, makes the 48 `hour_*` files
  ("TETRA România, nod <city>, este ora ...") and the daily forecast, and enables `fs2-forecast.timer` (05:30).
- Each user who wants their own isolated TG 1-9 gets a private relay port on the VPS (their own brew-server instance); they enter it in fs2-setup, which enables [brew_private] with the VPS address.
- Maintainer, once on the build host (after every change of the converter): `/root/fs2-tools-publish.sh`.
