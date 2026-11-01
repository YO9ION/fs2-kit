#!/bin/bash
# Publish the speech converter AND its library (signed) for the kit's fs2-announce. Run on cell 1.
#   /root/fs2-tools-publish.sh
set -euo pipefail
KEYDIR=/root/fs2-signing
[ -f "$KEYDIR/publish.env" ] && . "$KEYDIR/publish.env"
DEST="${FS2_PUBLISH_DEST:?set FS2_PUBLISH_DEST in $KEYDIR/publish.env}"
BIN="${1:-/root/flowstation/target/release/examples/convert_one}"
[ -f "$BIN" ] || { echo "not found: $BIN"; exit 1; }
[ -f "$KEYDIR/ed25519.pem" ] || { echo "no signing key in $KEYDIR"; exit 1; }
ARCH="$(uname -m)"
# find the codec library the converter needs
export LD_LIBRARY_PATH="$(dirname "$BIN"):$(dirname "$BIN")/..:${LD_LIBRARY_PATH:-}"
LIB="$( { ldd "$BIN" 2>/dev/null || true; } | awk '/libtetra-codec/ {print $3}' | head -n1)"
if [ -z "$LIB" ] || [ ! -f "$LIB" ]; then LIB="$(find /root/flowstation -name 'libtetra-codec.so*' -type f 2>/dev/null | head -n1)"; fi
[ -n "$LIB" ] && [ -f "$LIB" ] || { echo "libtetra-codec.so not found (ldd and find both failed)"; exit 1; }
echo "converter: $BIN"; echo "library:   $LIB"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
publish() {  # file name
  cp "$1" "$W/$2"
  SHA="$(sha256sum "$W/$2" | cut -d' ' -f1)"
  printf 'FS2-TOOL-1\n%s\n%s\n' "$2" "$SHA" > "$W/msg"
  openssl pkeyutl -sign -inkey "$KEYDIR/ed25519.pem" -rawin -in "$W/msg" -out "$W/sig"
  SIG="$(od -An -v -tx1 "$W/sig" | tr -d ' \n')"
  printf '{"sha256":"%s","sig":"%s"}\n' "$SHA" "$SIG" > "$W/$2.json"
  if [[ "$DEST" == *:* ]]; then
    scp -q "$W/$2" "$DEST/$2.tmp" && ssh "${DEST%%:*}" "mv '${DEST#*:}/$2.tmp' '${DEST#*:}/$2'"
    scp -q "$W/$2.json" "$DEST/$2.json"
  else
    mkdir -p "$DEST"; cp "$W/$2" "$W/$2.json" "$DEST/"
  fi
  echo "Published $2 (sha256 ${SHA:0:12}...) -> $DEST"
}
publish "$BIN" "convert_one-$ARCH"
publish "$(readlink -f "$LIB")" "libtetra-codec.so-$ARCH"
