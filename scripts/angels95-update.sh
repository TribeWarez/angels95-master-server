#!/bin/bash
# ANGELS95 Auto-Update Script
# Checks github.com/odelyzid/angels-95-omega-tech for the latest release,
# rebuilds + restarts the ANGELS95 Master Server and Official Dedicated
# servers (plain co-op, COOP campaign, DM, TDM) when a new tag is published.
# Safe to run from cron.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
GH_REPO="odelyzid/angels-95-omega-tech"
COMPOSE_FILE="$REPO_ROOT/docker-compose.angels95.yml"
STATE_FILE="$REPO_ROOT/.angels95-latest-tag"
LOG_FILE="$REPO_ROOT/angels95-update.log"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# --- Resolve latest release tag from GitHub ---
LATEST_TAG="$(curl -fsSL --max-time 30 "https://api.github.com/repos/${GH_REPO}/releases/latest" | grep -oP '"tag_name":\s*"\K[^"]+' | head -n1)"

if [ -z "$LATEST_TAG" ]; then
  log "ERROR: could not resolve latest release tag from GitHub"
  exit 1
fi

if [ -f "$STATE_FILE" ]; then
  CURRENT_TAG="$(cat "$STATE_FILE")"
else
  CURRENT_TAG=""
fi

if [ "$CURRENT_TAG" = "$LATEST_TAG" ]; then
  log "Up to date (tag=${LATEST_TAG}). No action."
  exit 0
fi

log "Updating ANGELS95: ${CURRENT_TAG:-none} -> ${LATEST_TAG}"

cd "$REPO_ROOT"

# --- Rebuild both images pinned to the latest release tag ---
docker compose -f "$COMPOSE_FILE" build \
  --build-arg ANGELS95_TAG="$LATEST_TAG" \
  angels95-master-api angels95-test-server \
  || log "ERROR: docker compose build failed"

# --- Recreate the Master first, then the Dedicated servers (depend_on master) ---
docker compose -f "$COMPOSE_FILE" up -d --force-recreate --no-build \
  angels95-master-api \
  || log "ERROR: master recreate failed"
docker compose -f "$COMPOSE_FILE" up -d --force-recreate --no-build \
  angels95-test-server angels95-test-coop angels95-test-dm angels95-test-tdm \
  || log "ERROR: dedicated recreate failed"

echo "$LATEST_TAG" > "$STATE_FILE"
log "DONE: ANGELS95 master + dedicated now on ${LATEST_TAG}"
