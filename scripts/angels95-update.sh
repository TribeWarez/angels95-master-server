#!/bin/bash
# ANGELS95 Auto-Update Script
# Checks the canonical game repo for the latest RELEASE (not tag), verifies the
# Linux assets actually exist, rebuilds both images and recreates the master +
# dedicated servers. Safe to run from cron.
#
# Failure policy: a transient error (GitHub 404 while assets upload, network
# blip, missing GameData) must NOT advance the state file. The old script wrote
# the tag unconditionally, so one failed run permanently skipped that release.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
GH_REPO="TribeWarez/Angels-95"
COMPOSE_FILE="$REPO_ROOT/docker-compose.angels95.yml"
STATE_FILE="$REPO_ROOT/.angels95-latest-tag"
LOG_FILE="$REPO_ROOT/angels95-update.log"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

running_version() {
  docker inspect --format '{{ index .Config.Labels "org.opencontainers.image.version" }}' \
    "$1" 2>/dev/null || true
}

# --- Resolve latest release tag from GitHub ---------------------------------
LATEST_TAG="$(curl -fsSL --max-time 30 \
  "https://api.github.com/repos/${GH_REPO}/releases/latest" \
  | grep -oP '"tag_name":\s*"\K[^"]+' | head -n1 || true)"

if [ -z "$LATEST_TAG" ]; then
  log "ERROR: could not resolve latest release tag from GitHub"
  exit 1
fi

CURRENT_TAG=""
if [ -f "$STATE_FILE" ]; then
  CURRENT_TAG="$(cat "$STATE_FILE")"
fi

if [ "$CURRENT_TAG" = "$LATEST_TAG" ]; then
  # The state file is a claim; the running container label is the truth. A
  # manual rollback or a previously half-applied update must be repaired.
  RUNNING="$(running_version angels95-test-server)"
  if [ "$RUNNING" = "$LATEST_TAG" ]; then
    log "Up to date (tag=${LATEST_TAG}). No action."
    exit 0
  fi
  log "State says ${LATEST_TAG} but angels95-test-server runs '${RUNNING:-unknown}'; rebuilding"
fi

# --- A release is only usable if BOTH Linux assets exist ---------------------
# b95/b96 exist as tags but have no GitHub Release at all (CI fails at make
# test), and a release can exist briefly before its assets finish uploading.
for asset in \
  "AngelServ-${LATEST_TAG}-linux-x86_64" \
  "AngelMaster-${LATEST_TAG}-linux-x86_64"; do
  if ! curl -fsIL --max-time 30 \
      "https://github.com/${GH_REPO}/releases/download/${LATEST_TAG}/${asset}" \
      >/dev/null 2>&1; then
    log "ERROR: release ${LATEST_TAG} is missing ${asset}; not updating"
    exit 1
  fi
done

# --- GameData is gitignored and baked into the image at build time -----------
# Without this check a missing tree makes `COPY GameData` fail, the old image
# keeps running, and the tag used to be marked as done anyway.
if [ ! -d "$REPO_ROOT/angels95-test-server/GameData/Worlds" ]; then
  log "ERROR: $REPO_ROOT/angels95-test-server/GameData/Worlds is missing (gitignored)."
  log "       Populate it from the game repo (or release zip) before updating."
  exit 1
fi

log "Updating ANGELS95: ${CURRENT_TAG:-none} -> ${LATEST_TAG}"

cd "$REPO_ROOT"

# --- Rebuild both images pinned to the latest release tag --------------------
if ! docker compose -f "$COMPOSE_FILE" build \
      --build-arg ANGELS95_TAG="$LATEST_TAG" \
      angels95-master-api angels95-test-server; then
  log "ERROR: docker compose build failed; will retry next run"
  exit 1
fi

# --- Recreate the Master first, then the Dedicated servers (depends_on) ------
if ! docker compose -f "$COMPOSE_FILE" up -d --force-recreate --no-build \
      angels95-master-api; then
  log "ERROR: master recreate failed; will retry next run"
  exit 1
fi
if ! docker compose -f "$COMPOSE_FILE" up -d --force-recreate --no-build \
      angels95-test-server angels95-test-coop angels95-test-dm angels95-test-tdm; then
  log "ERROR: dedicated recreate failed; will retry next run"
  exit 1
fi

# `up --no-build` keeps the old image if the build did not replace it. Verify
# the RUNNING image label, not the build log.
sleep 2
for svc in angels95-master-api angels95-test-server angels95-test-coop \
           angels95-test-dm angels95-test-tdm; do
  RUNNING="$(running_version "$svc")"
  if [ "$RUNNING" != "$LATEST_TAG" ]; then
    log "ERROR: ${svc} runs '${RUNNING:-unknown}', wanted ${LATEST_TAG}; will retry next run"
    exit 1
  fi
done

echo "$LATEST_TAG" > "$STATE_FILE"
log "DONE: ANGELS95 master + dedicated now on ${LATEST_TAG}"
