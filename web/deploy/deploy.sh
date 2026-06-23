#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOST="${DEPLOY_HOST:-mspclientpro}"
REMOTE_DIR="/var/www/tryan.app"

echo "Building web app..."
cd "$ROOT"
npm ci
npm run build

echo "Deploying to ${HOST}:${REMOTE_DIR}..."
rsync -avz --delete dist/ "${HOST}:${REMOTE_DIR}/"

echo "Done. Site: https://tryan.app"
