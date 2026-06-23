#!/usr/bin/env bash
# Smoke-test production API endpoints for scripting integration.
set -euo pipefail

BASE="${STOCKPULSE_API_BASE:-https://api.tryan.app}"
TODAY="$(TZ=America/New_York date +%Y-%m-%d)"

check() {
  local path="$1"
  local label="$2"
  local code
  code="$(curl -sS -o /tmp/stockpulse_verify.json -w "%{http_code}" "${BASE}${path}")"
  if [[ "$code" != "200" ]]; then
    echo "FAIL $label — HTTP $code (${BASE}${path})"
    head -c 200 /tmp/stockpulse_verify.json 2>/dev/null || true
    echo
    return 1
  fi
  echo "OK   $label — HTTP $code"
}

echo "Verifying ${BASE} (session date ${TODAY})"
check "/api/health" "health"
check "/api/catalog/sectors" "catalog sectors"
check "/api/catalog/catalysts" "catalog catalysts"
check "/api/health/providers" "provider health"
check "/api/intelligence/session/${TODAY}" "session intelligence today"
check "/api/intelligence/session/${TODAY}/open" "session intelligence open slot"
echo "All production smoke checks passed."
