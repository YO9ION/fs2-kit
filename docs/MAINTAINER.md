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
