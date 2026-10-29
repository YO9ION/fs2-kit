#!/usr/bin/env bash
# Look for personal data in a folder (this repository, or a mounted image) before you publish it.
# Usage: bash scripts/privacy-scan.sh DIRECTORY [DIRECTORY...]
# Put your own words (callsign, domain, names, addresses, ISSIs, coordinates) one per line in
#   ~/.fs2-private-terms     (this file stays on your computer and is never committed).
set -uo pipefail
[ $# -ge 1 ] || { echo "Usage: $0 DIRECTORY..." >&2; exit 2; }
dirs=("$@")
found=0
scan() { # label, regex
  local out; out="$(grep -rInE --exclude-dir=.git --exclude=privacy-scan.sh -e "$2" "${dirs[@]}" 2>/dev/null | grep -vE '@@|0\.0\.0\.0|127\.0\.0\.1' | cut -c1-160 | head -20)"
  if [ -n "$out" ]; then printf '\n[%s]\n%s\n' "$1" "$out"; found=1; fi
}
terms="$HOME/.fs2-private-terms"
if [ -f "$terms" ]; then
  while IFS= read -r t; do [ -n "$t" ] && scan "your term: $t" "$(printf '%s' "$t" | sed 's/[][\.*^$+?(){}|/]/\\&/g')"; done < "$terms"
else
  echo "Tip: create $terms with your callsign, domain, names and ISSIs (one per line) for a better scan."
fi
scan "secret keys" '(bot_token|authkey|password|token)[[:space:]]*=[[:space:]]*"[^"]{4,}"'
scan "private key" 'BEGIN [A-Z ]*PRIVATE KEY'
scan "IP address" '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b'
scan "e-mail" '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[a-z]{2,}'
scan "coordinates" '(lat|lon)[a-z_]*[[:space:]]*=[[:space:]]*-?[1-9][0-9]*\.[0-9]+'
[ "$found" -eq 0 ] && echo "Nothing found." || echo $'\nReview every line above before publishing.'
exit "$found"
