#!/usr/bin/env bash
# Push Alpaca + trading vars from local .env to VPS (does not overwrite whole .env).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${ROOT}/.env"
VPS="${VPS_HOST:-mspclientpro}"
REMOTE_ENV="/opt/stockpulse-api/.env"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing $ENV_FILE"
  exit 1
fi

get_var() {
  grep -E "^${1}=" "$ENV_FILE" | tail -1 | cut -d= -f2- || true
}

KEY=$(get_var ALPACA_API_KEY)
SECRET=$(get_var ALPACA_SECRET_KEY)

if [[ -z "$KEY" || -z "$SECRET" ]]; then
  echo "ERROR: Set ALPACA_API_KEY and ALPACA_SECRET_KEY in $ENV_FILE first."
  echo ""
  echo "Paste your PAPER keys on lines 20–21:"
  echo "  ALPACA_API_KEY=PK..."
  echo "  ALPACA_SECRET_KEY=..."
  exit 1
fi

PAPER=$(get_var ALPACA_PAPER); PAPER=${PAPER:-true}
TRADING=$(get_var TRADING_ENABLED); TRADING=${TRADING:-true}
TSECRET=$(get_var TRADING_API_SECRET)
NOTIONAL=$(get_var DEFAULT_TRADE_NOTIONAL); NOTIONAL=${NOTIONAL:-5}
AUTO=$(get_var AUTO_TRADE_ENABLED); AUTO=${AUTO:-true}
COOLDOWN=$(get_var PROPOSE_COOLDOWN_HOURS); COOLDOWN=${COOLDOWN:-4}
MICRO=$(get_var MICRO_TRADE_ENABLED); MICRO=${MICRO:-true}
MICRO_NOTIONAL=$(get_var MICRO_TRADE_NOTIONAL); MICRO_NOTIONAL=${MICRO_NOTIONAL:-50}
MICRO_TP=$(get_var MICRO_TAKE_PROFIT_PCT); MICRO_TP=${MICRO_TP:-0.75}
MICRO_SL=$(get_var MICRO_STOP_LOSS_PCT); MICRO_SL=${MICRO_SL:-0.50}
MICRO_CAP=$(get_var MICRO_DAILY_PROFIT_CAP_USD); MICRO_CAP=${MICRO_CAP:-50}

echo "Updating Alpaca vars on $VPS ..."

ssh "$VPS" "python3 - << 'PY'
from pathlib import Path
import re

path = Path('$REMOTE_ENV')
text = path.read_text() if path.exists() else ''

updates = {
    'ALPACA_API_KEY': '''$KEY''',
    'ALPACA_SECRET_KEY': '''$SECRET''',
    'ALPACA_PAPER': '''$PAPER''',
    'TRADING_ENABLED': '''$TRADING''',
    'TRADING_API_SECRET': '''$TSECRET''',
    'DEFAULT_TRADE_NOTIONAL': '''$NOTIONAL''',
    'AUTO_TRADE_ENABLED': '''$AUTO''',
    'PROPOSE_COOLDOWN_HOURS': '''$COOLDOWN''',
    'MIN_FRACTIONAL_NOTIONAL': '1',
    'MICRO_TRADE_ENABLED': '''$MICRO''',
    'MICRO_TRADE_NOTIONAL': '''$MICRO_NOTIONAL''',
    'MICRO_TAKE_PROFIT_PCT': '''$MICRO_TP''',
    'MICRO_STOP_LOSS_PCT': '''$MICRO_SL''',
    'MICRO_DAILY_PROFIT_CAP_USD': '''$MICRO_CAP''',
    'MICRO_SCAN_INTERVAL_MINUTES': '5',
}

for k, v in updates.items():
    line = f'{k}={v}'
    if re.search(rf'^{re.escape(k)}=', text, re.M):
        text = re.sub(rf'^{re.escape(k)}=.*$', line, text, flags=re.M)
    else:
        if text and not text.endswith('\\n'):
            text += '\\n'
        text += line + '\\n'

path.write_text(text)
print('Wrote', path)
PY
systemctl restart stockpulse-api
sleep 2
cd /opt/stockpulse-api && ./venv/bin/python scripts/verify_alpaca.py
"

echo "Done. Test: curl -s https://api.tryan.app/api/trading/status"
