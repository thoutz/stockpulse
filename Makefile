.PHONY: test check-env seed-catalysts backfill-quotes provider-health backtest discover run-intelligence verify-prod

API_DIR := server/stockpulse-api
PY := $(API_DIR)/.venv/bin/python
SLOT ?= open
DATE ?=
DATE_ARG := $(if $(DATE),--date $(DATE),)

test:
	cd $(API_DIR) && .venv/bin/pytest tests/ -q

check-env:
	cd $(API_DIR) && $(PY) scripts/check_env.py

seed-catalysts:
	cd $(API_DIR) && $(PY) scripts/seed_catalysts.py

backfill-quotes:
	cd $(API_DIR) && $(PY) scripts/backfill_quote_windows.py

provider-health:
	cd $(API_DIR) && $(PY) scripts/provider_health.py

backtest:
	cd $(API_DIR) && $(PY) scripts/backtest_ripple.py

discover:
	cd $(API_DIR) && $(PY) scripts/discover_catalysts.py

discover-apply:
	cd $(API_DIR) && $(PY) scripts/discover_catalysts.py --apply

run-intelligence:
	cd $(API_DIR) && $(PY) scripts/run_session_intelligence.py --slot $(SLOT) $(DATE_ARG)

verify-prod:
	@bash scripts/verify_production.sh
