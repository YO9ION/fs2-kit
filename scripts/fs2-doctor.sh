#!/usr/bin/env bash
# Quick health check: board, service, dashboard, recent errors. Shows no secrets.
ok()  { printf '  [ ok ] %s\n' "$*"; }
bad() { printf '  [FAIL] %s\n' "$*"; }
echo "FS2 check"
[ "$(uname -m)" = "aarch64" ] && ok "64-bit system" || bad "needs 64-bit Raspberry Pi OS"
if aplay -l 2>/dev/null | grep -qi SX1255; then ok "SX1255 sound card present"; else echo "  [ -- ] no SX1255 sound card (fine if you use another board)"; fi
if command -v SoapySDRUtil >/dev/null; then
  if SoapySDRUtil --find 2>&1 | grep -q 'driver ='; then ok "radio found by SoapySDR: $(SoapySDRUtil --find 2>&1 | grep -m1 'driver =' | sed 's/^ *//')"; else bad "SoapySDR finds no radio (see docs/SDR-BOARDS.md)"; fi
else bad "SoapySDR tools not installed"; fi
[ -x /opt/fs2/fs2 ] && ok "program installed" || bad "/opt/fs2/fs2 missing"
[ -f /opt/fs2/config.toml ] && ok "config present" || bad "no config: run  sudo fs2-setup"
systemctl is-active --quiet fs2 && ok "service running" || bad "service not running (journalctl -u fs2 -n 30)"
(ss -ltn 2>/dev/null | grep -q ':8080 ') && ok "dashboard listening on port 8080" || bad "dashboard port 8080 not listening"
if [ -f /opt/fs2/log/tetra_full.log ]; then
  n=$(tail -n 2000 /opt/fs2/log/tetra_full.log | grep -c 'Too late to produce TX block')
  [ "$n" -eq 0 ] && ok "no TX timing warnings in the last 2000 log lines" || bad "$n TX timing warnings (restart: sudo systemctl restart fs2; reboot if it persists)"
fi
