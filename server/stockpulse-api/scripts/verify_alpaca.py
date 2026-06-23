#!/usr/bin/env python3
"""Verify Alpaca Trading API keys and print account summary + X-Request-ID."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import httpx

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from config import get_settings  # noqa: E402


def _base_url(paper: bool) -> str:
    return "https://paper-api.alpaca.markets" if paper else "https://api.alpaca.markets"


def _headers(key: str, secret: str) -> dict[str, str]:
    return {
        "APCA-API-KEY-ID": key,
        "APCA-API-SECRET-KEY": secret,
        "Accept": "application/json",
    }


def _request(method: str, path: str, *, paper: bool, key: str, secret: str) -> tuple[int, dict, str | None]:
    url = f"{_base_url(paper)}{path}"
    with httpx.Client(timeout=30.0) as client:
        resp = client.request(method, url, headers=_headers(key, secret))
        request_id = resp.headers.get("X-Request-ID")
        try:
            body = resp.json()
        except Exception:
            body = {"raw": resp.text[:500]}
        return resp.status_code, body, request_id


def main() -> int:
    parser = argparse.ArgumentParser(description="Verify Alpaca Trading API connection")
    parser.add_argument("--live", action="store_true", help="Use live API (default: paper)")
    parser.add_argument("--key", help="Override ALPACA_API_KEY")
    parser.add_argument("--secret", help="Override ALPACA_SECRET_KEY")
    args = parser.parse_args()

    settings = get_settings()
    key = (args.key or settings.alpaca_api_key).strip()
    secret = (args.secret or settings.alpaca_secret_key).strip()
    paper = not args.live
    mode = "live" if args.live else "paper"

    if not key or not secret:
        print("ERROR: Set ALPACA_API_KEY and ALPACA_SECRET_KEY in .env")
        print("  Get keys: https://app.alpaca.markets → API Keys")
        print("  Paper keys for testing; live keys for real money.")
        return 1

    print(f"Mode: {mode}")
    print(f"Base: {_base_url(paper)}")
    print()

    for label, path in [("Account", "/v2/account"), ("Clock", "/v2/clock")]:
        status, body, req_id = _request("GET", path, paper=paper, key=key, secret=secret)
        print(f"=== {label} (HTTP {status}) ===")
        if req_id:
            print(f"X-Request-ID: {req_id}")
        if status != 200:
            print(f"FAILED: {body}")
            return 1
        if label == "Account":
            print(f"  Status:     {body.get('status')}")
            print(f"  Account #:  {body.get('account_number', 'n/a')}")
            if body.get("created_at"):
                print(f"  Created:    {body.get('created_at')}")
            print(f"  Equity:     ${float(body.get('equity', 0)):,.2f}")
            print(f"  Cash:       ${float(body.get('cash', 0)):,.2f}")
            print(f"  Buying pwr: ${float(body.get('buying_power', 0)):,.2f}")
            if float(body.get("equity", 0) or 0) == 0 and float(body.get("cash", 0) or 0) == 0 and paper:
                print()
                print("  NOTE: Paper account has $0. Check Alpaca dashboard account switcher")
                print("        (top left) — you may have multiple paper accounts. Open a new")
                print("        paper account with $100,000 starting balance + new Paper API keys.")
        else:
            print(f"  Market open: {body.get('is_open')}")
            print(f"  Next open:   {body.get('next_open')}")
        print()

    print("Alpaca connection OK.")
    print("Add keys to server/stockpulse-api/.env and deploy to api.tryan.app")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
