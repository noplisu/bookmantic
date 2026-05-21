#!/usr/bin/env bash
# Copy deployment config to a VPS (no git clone required on the server).
#
# Copies:
#   - compose.yaml
#   - Caddyfile
#   - .env (unless --config-only; only if deployment/.env exists locally)
#
# Usage:
#   VPS_USER=deploy VPS_HOST=203.0.113.10 ./sync-to-vps.sh
#   ./sync-to-vps.sh deploy@203.0.113.10
#   ./sync-to-vps.sh --config-only deploy@203.0.113.10   # CI: compose + Caddyfile only
#
# Environment:
#   VPS_USER, VPS_HOST     Target (if user@host not passed)
#   REMOTE_DEPLOY_DIR      Remote directory (default: /opt/semantic-search-rails/deployment)
set -euo pipefail

DEPLOY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_ONLY=false
TARGET=""

usage() {
  sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config-only) CONFIG_ONLY=true; shift ;;
    -h | --help) usage; exit 0 ;;
    -*)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      TARGET="$1"
      shift
      ;;
  esac
done

if [[ -z "$TARGET" ]]; then
  VPS_USER="${VPS_USER:-}"
  VPS_HOST="${VPS_HOST:-}"
  if [[ -z "$VPS_USER" || -z "$VPS_HOST" ]]; then
    echo "sync-to-vps: set VPS_USER and VPS_HOST, or pass user@host" >&2
    usage >&2
    exit 1
  fi
  TARGET="${VPS_USER}@${VPS_HOST}"
fi

REMOTE_DIR="${REMOTE_DEPLOY_DIR:-/opt/semantic-search-rails/deployment}"

FILES=(compose.yaml Caddyfile)
if [[ "$CONFIG_ONLY" == false ]]; then
  if [[ -f "${DEPLOY_DIR}/.env" ]]; then
    FILES+=(.env)
  else
    echo "sync-to-vps: no local ${DEPLOY_DIR}/.env — skipping (create .env on the VPS or copy it once from this machine)." >&2
  fi
fi

PATHS=()
for f in "${FILES[@]}"; do
  src="${DEPLOY_DIR}/${f}"
  if [[ ! -f "$src" ]]; then
    echo "sync-to-vps: missing file: ${src}" >&2
    exit 1
  fi
  PATHS+=("$src")
done

echo "Syncing ${FILES[*]} → ${TARGET}:${REMOTE_DIR}/"
ssh "$TARGET" "mkdir -p '${REMOTE_DIR}'"

if command -v rsync >/dev/null 2>&1; then
  rsync -avz "${PATHS[@]}" "${TARGET}:${REMOTE_DIR}/"
else
  scp "${PATHS[@]}" "${TARGET}:${REMOTE_DIR}/"
fi

echo "Done."
