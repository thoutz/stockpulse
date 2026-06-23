#!/bin/bash
# Run on server after api.tryan.app DNS A record points to 45.63.64.79
set -euo pipefail
dig +short api.tryan.app | grep -q '45.63.64.79' || {
  echo "DNS not ready: api.tryan.app must resolve to 45.63.64.79"
  exit 1
}
certbot --nginx -d api.tryan.app --non-interactive --agree-tos --register-unsafely-without-email
curl -s "https://api.tryan.app/api/health"
echo
