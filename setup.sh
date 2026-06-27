#!/usr/bin/env bash
# setup.sh – Fully automatic environment setup + launcher
#
# Creates venv, installs dependencies, verifies structure, then launches.
# All arguments are forwarded to src/RunMe.sh.
#
# Usage:
#   ./setup.sh                        # default port 1337
#   ./setup.sh 8080                   # custom port
#   ./setup.sh 8080 4                 # custom port + verbose=4
#
# Environment variables (pass before or alongside):
#   MONITOR=true          Enable security monitoring proxy (port 1339)
#   HLS_PROXY=false       Disable HLS rewrite proxy (default: true)
#   GOMEMLIMIT=4G         Override Go memory limit (default: 2GiB)
#   MAX_STREAMS=8         Limit concurrent streams
#   ADMIN_USER=admin      Static admin username (default: admin)
#   ADMIN_PASS=secret     Static admin password (default: admin1337)

set -euo pipefail

SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$SETUP_DIR/src"

# Switch to src/ early — venv, scripts, and binary all live here
cd "$SRC_DIR"

# ─── Colors ────────────────────────────────────────────────────────────
BLD='\033[1m'
DIM='\033[2m'
RED='\033[0;31m'
GRN='\033[0;32m'
YLW='\033[0;33m'
BLU='\033[0;34m'
MAG='\033[0;35m'
CYN='\033[0;36m'
RST='\033[0m'
CHECK="${GRN}\xE2\x9C\x94${RST}"
CROSS="${RED}\xE2\x9C\x98${RST}"
ARROW="${CYN}\xE2\x96\xB6${RST}"

# ─── Helpers ───────────────────────────────────────────────────────────
ok()   { echo -e "  ${CHECK} ${BLD}$1${RST} $2"; }
info() { echo -e "  ${ARROW} ${DIM}$1${RST}"; }
warn() { echo -e "  ${YLW}\xE2\x9A\xA0${RST} ${BLD}$1${RST} $2"; }
fail() { echo -e "  ${CROSS} ${RED}$1${RST}"; }
sep()  { echo -e "  ${DIM}──────────────────────────────────────────────${RST}"; }
box()  {
  local s="$1" w=56
  echo -e "  ${DIM}\xE2\x95\x94$(printf '\xE2\x95\x90%.0s' $(seq 1 $w))\xE2\x95\x97${RST}"
  echo -e "  ${DIM}\xE2\x95\x91${RST}  ${BLD}$s${RST}"
  echo -e "  ${DIM}\xE2\x95\x9A$(printf '\xE2\x95\x90%.0s' $(seq 1 $w))\xE2\x95\x9D${RST}"
}

# ─── Header ────────────────────────────────────────────────────────────
clear 2>/dev/null || true
echo
box "o11pro  –  Setup & Launch"
echo

# ─── Phase 1: Python 3 ─────────────────────────────────────────────────
echo -e "  ${BLU}\xE2\x96\xBC${RST} ${BLD}Phase 1${RST}  \xE2\x80\x94 Python 3"
echo

if ! command -v python3 &>/dev/null; then
  warn "Python 3 not found" "attempting install..."
  if command -v apt-get &>/dev/null; then
    sudo apt-get update && sudo apt-get install -y python3 python3-venv python3-pip
  elif command -v yum &>/dev/null; then
    sudo yum install -y python3 python3-pip
  else
    fail "No supported package manager. Install Python 3 manually."; exit 1
  fi
fi
ok "Python" "$(python3 --version)"
echo

# ─── Phase 2: Virtual Environment ──────────────────────────────────────
echo -e "  ${BLU}\xE2\x96\xBC${RST} ${BLD}Phase 2${RST}  \xE2\x80\x94 Virtual Environment"
echo

VENV_DIR="$SRC_DIR/venv"
if [ ! -d "$VENV_DIR" ]; then
  info "Creating venv at ${DIM}$VENV_DIR${RST}..."
  python3 -m venv "$VENV_DIR"
  ok "venv" "created"
else
  ok "venv" "exists at ${DIM}$VENV_DIR${RST}"
fi
echo

# ─── Phase 3: Dependencies ─────────────────────────────────────────────
echo -e "  ${BLU}\xE2\x96\xBC${RST} ${BLD}Phase 3${RST}  \xE2\x80\x94 Python Dependencies"
echo

"$VENV_DIR/bin/pip" install --upgrade pip -q 2>/dev/null
if [ -f "$SETUP_DIR/requirements.txt" ]; then
  REQ_COUNT=$(grep -cEv '^\s*(#|$)' "$SETUP_DIR/requirements.txt" || echo 0)
  info "Installing ${REQ_COUNT} packages from ${DIM}requirements.txt${RST}..."
  "$VENV_DIR/bin/pip" install -r "$SETUP_DIR/requirements.txt" -q 2>&1 | tail -1
  ok "dependencies" "ready"
else
  warn "requirements.txt not found" "\xE2\x80\x94 skipping packages"
fi
echo

# ─── Phase 4: Project Structure ────────────────────────────────────────
echo -e "  ${BLU}\xE2\x96\xBC${RST} ${BLD}Phase 4${RST}  \xE2\x80\x94 Project Structure"
echo

ok "root" "${DIM}$SETUP_DIR${RST}"

# Launcher scripts
LAUNCHER_COUNT=$(ls -1 *.sh 2>/dev/null | wc -l)
ok "src/" "${LAUNCHER_COUNT} launcher(s)"

# Binary
BINARY=""
for b in o11pro o11; do
  [ -f "$b" ] && BINARY="$b" && break
done
if [ -n "$BINARY" ]; then
  BIN_SIZE=$(stat -c%s "$BINARY" 2>/dev/null | numfmt --to=iec 2>/dev/null || echo "?")
  ok "binary" "${DIM}$BINARY${RST}  (${BIN_SIZE})"
  [ -x "$BINARY" ] || chmod +x "$BINARY" && ok "binary" "made executable"
else
  fail "No o11pro binary found in ${DIM}$SRC_DIR${RST}"; exit 1
fi

# RunMe.sh
if [ -f "RunMe.sh" ]; then
  chmod +x "RunMe.sh"
  ok "launcher" "${DIM}RunMe.sh${RST}"
else
  fail "RunMe.sh not found in ${DIM}$SRC_DIR${RST}"; exit 1
fi

# Provider configs
PROV_DIR="$SETUP_DIR/providers"
PROV_COUNT=0
if [ -d "$PROV_DIR" ]; then
  PROV_COUNT=$(find "$PROV_DIR" -maxdepth 1 -name '*.cfg' 2>/dev/null | wc -l)
fi
if [ "$PROV_COUNT" -gt 0 ]; then
  ok "providers/" "${PROV_COUNT} config(s)"
else
  info "No provider configs yet — place .cfg files in ${DIM}providers/${RST}"
fi

# HLS proxy maps
CACHE_DIR="$SETUP_DIR/cache"
ORIG_MAP="$CACHE_DIR/orig_urls.json"
if [ -f "$ORIG_MAP" ]; then
  MAP_COUNT=$(python3 -c "import json; print(len(json.load(open('$ORIG_MAP'))))" 2>/dev/null || echo "?")
  ok "HLS map" "${MAP_COUNT} channel(s) in ${DIM}cache/orig_urls.json${RST}"
else
  info "HLS map will be auto-generated on launch"
fi
echo

# ─── Phase 5: Launch ───────────────────────────────────────────────────
echo -e "  ${GRN}\xE2\x96\xB6${RST}  ${BLD}Starting o11pro${RST} — delegating to src/RunMe.sh"
echo

export PATH="$VENV_DIR/bin:$PATH"
exec ./RunMe.sh "$@"