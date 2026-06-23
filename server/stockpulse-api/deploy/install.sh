#!/bin/bash
set -euo pipefail

# Run on server as root after rsync to /opt/stockpulse-api

APP_DIR="/opt/stockpulse-api"
cd "$APP_DIR"

python3 -m venv venv
./venv/bin/pip install --upgrade pip
./venv/bin/pip install -r requirements.txt

# PostgreSQL (idempotent)
sudo -u postgres psql -tc "SELECT 1 FROM pg_roles WHERE rolname='stockpulse'" | grep -q 1 || \
  sudo -u postgres createuser stockpulse
sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname='stockpulse'" | grep -q 1 || \
  sudo -u postgres createdb -O stockpulse stockpulse
sudo -u postgres psql -c "ALTER USER stockpulse WITH PASSWORD 'stockpulse_local';" 2>/dev/null || true

cp deploy/stockpulse-api.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable stockpulse-api
systemctl restart stockpulse-api

echo "StockPulse API installed. Check: curl http://127.0.0.1:8002/api/health"
