from __future__ import annotations

import asyncio
import logging
from datetime import datetime, timedelta, timezone

from sqlalchemy import func, select, delete
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession

from config import get_settings
from database import SessionLocal
from models.db_models import BarDaily, BarMinute, Favorite, Indicator, Snapshot, Ticker
from services.finnhub_client import FinnhubClient
from services.indicators import indicators_from_bars
from services.massive_client import MassiveClient
from services.monitor_tiers import MonitorTier, build_tier_map
from services.tracked import get_tracked_symbols

logger = logging.getLogger(__name__)

INGEST_TASKS_SECONDARY = ("minute",)


class IngestScheduler:
    def __init__(self) -> None:
        self.settings = get_settings()
        self.client = MassiveClient()
        self.finnhub = FinnhubClient()
        self._ticker_index = 0
        self._minute_round: list[str] = []
        self._lock = asyncio.Lock()
        self.warm_complete = False
        self._name_resync_queue: list[str] = []
        self._name_skip: set[str] = set()

    async def run_cycle(self) -> None:
        symbol: str | None = None
        task: str | None = None
        name_symbol: str | None = None

        async with self._lock:
            async with SessionLocal() as session:
                tickers = await get_tracked_symbols(session)
                if not tickers:
                    return

                if self.warm_complete:
                    symbol = await self._pick_stale_daily_symbol(session, tickers)
                    if symbol is not None:
                        task = "daily"
                    else:
                        name_symbol = await self._pick_name_to_resolve(session, tickers)

                if task is None and name_symbol is None:
                    if not self.warm_complete:
                        symbol = tickers[self._ticker_index % len(tickers)]
                        task = "daily"
                        self._ticker_index += 1
                    else:
                        symbol = await self._pick_minute_symbol(session, tickers)
                        if symbol:
                            task = "minute"

        if name_symbol is not None:
            try:
                async with SessionLocal() as session:
                    await self._ingest_name(session, name_symbol)
                    await session.commit()
            except Exception:
                logger.exception("Name resolve failed %s", name_symbol)
            return

        if symbol is None or task is None:
            return

        try:
            async with SessionLocal() as session:
                if task == "daily":
                    await self._ingest_daily(session, symbol)
                elif task == "minute":
                    await self._ingest_minute(session, symbol)
                if task == "daily":
                    await self._update_snapshot(session, symbol)
                await session.commit()
            logger.info("Ingested %s %s", task, symbol)
        except Exception:
            logger.exception("Ingest failed %s %s", task, symbol)

    async def _pick_minute_symbol(self, session: AsyncSession, tickers: list[str]) -> str | None:
        tier_map = await build_tier_map(session)
        hot = [t for t in tickers if tier_map.get(t) == MonitorTier.HOT]
        warm = [t for t in tickers if tier_map.get(t) == MonitorTier.WARM]
        pool = hot * 3 + warm
        if not pool:
            return None
        if not self._minute_round or set(self._minute_round) != set(pool):
            self._minute_round = pool
            self._ticker_index = 0
        sym = self._minute_round[self._ticker_index % len(self._minute_round)]
        self._ticker_index += 1
        return sym

    async def _pick_stale_daily_symbol(
        self, session: AsyncSession, tickers: list[str]
    ) -> str | None:
        hot_cutoff = datetime.now(timezone.utc) - timedelta(days=self.settings.hot_days)
        for sym in tickers:
            count_result = await session.execute(
                select(func.count())
                .select_from(BarDaily)
                .where(BarDaily.symbol == sym, BarDaily.bar_date >= hot_cutoff)
            )
            if (count_result.scalar() or 0) == 0:
                return sym
        return None

    async def _pick_name_to_resolve(
        self, session: AsyncSession, tickers: list[str]
    ) -> str | None:
        tracked = set(tickers)
        while self._name_resync_queue:
            sym = self._name_resync_queue.pop(0)
            if sym in tracked:
                return sym

        rows = (
            await session.execute(select(Ticker.symbol, Ticker.name).where(Ticker.symbol.in_(tickers)))
        ).all()
        names = {sym: name for sym, name in rows}
        for sym in tickers:
            if sym in self._name_skip:
                continue
            if not names.get(sym):
                return sym
        return None

    async def _ingest_name(self, session: AsyncSession, symbol: str) -> None:
        details = None
        if self.finnhub.configured:
            details = await self.finnhub.fetch_profile(symbol)
        if not details:
            details = await self.client.fetch_ticker_details(symbol)
        if not details or not details.get("name"):
            self._name_skip.add(symbol)
            return
        stmt = insert(Ticker).values(
            symbol=symbol,
            name=details["name"],
            exchange=details.get("exchange") or None,
            active=True,
        )
        stmt = stmt.on_conflict_do_update(
            index_elements=["symbol"],
            set_={"name": details["name"], "exchange": details.get("exchange") or None},
        )
        await session.execute(stmt)
        fav = await session.get(Favorite, symbol)
        if fav and not fav.name:
            fav.name = details["name"]
        logger.info("Resolved name for %s: %s", symbol, details["name"])

    async def request_full_name_resync(self) -> None:
        async with SessionLocal() as session:
            tickers = await get_tracked_symbols(session)
        self._name_skip.clear()
        self._name_resync_queue = list(tickers)
        logger.info("Queued full ticker-name resync for %d symbols", len(tickers))

    async def _bar_stats(self, session: AsyncSession, symbol: str) -> tuple[int, datetime | None]:
        count_result = await session.execute(
            select(func.count()).select_from(BarDaily).where(BarDaily.symbol == symbol)
        )
        count = count_result.scalar() or 0
        max_result = await session.execute(
            select(func.max(BarDaily.bar_date)).where(BarDaily.symbol == symbol)
        )
        last_date = max_result.scalar()
        return count, last_date

    async def _ingest_daily(self, session: AsyncSession, symbol: str) -> None:
        settings = self.settings
        count, last_date = await self._bar_stats(session, symbol)
        now = datetime.now(timezone.utc)
        today_str = now.strftime("%Y-%m-%d")
        bars: list = []

        if count < settings.hot_days:
            bars = await self.client.fetch_daily_bars(symbol, days=settings.full_days)
            logger.info("Backfill %s (%d bars in DB)", symbol, count)
        elif last_date is None:
            bars = await self.client.fetch_daily_bars(symbol, days=settings.full_days)
        else:
            last_day = last_date.replace(hour=0, minute=0, second=0, microsecond=0)
            yesterday = (now - timedelta(days=1)).replace(hour=0, minute=0, second=0, microsecond=0)
            if last_day >= yesterday:
                await self._compute_local_indicators(session, symbol)
                return
            from_str = last_day.strftime("%Y-%m-%d")
            bars = await self.client.fetch_daily_bars_range(
                symbol, from_str, today_str, limit=10
            )
            logger.info("Incremental %s from %s", symbol, from_str)

        await self._upsert_ticker(session, symbol)
        if bars:
            await self._upsert_bars(session, symbol, bars)
            await self._prune_old_bars(session, symbol)
        await self._compute_local_indicators(session, symbol)

    async def _compute_local_indicators(self, session: AsyncSession, symbol: str) -> None:
        result = await session.execute(
            select(BarDaily).where(BarDaily.symbol == symbol).order_by(BarDaily.bar_date)
        )
        rows = result.scalars().all()
        if len(rows) < 20:
            return
        bar_pairs = [(r.bar_date, r.close) for r in rows]
        rsi_rows, sma_rows = indicators_from_bars(bar_pairs)
        for ts, val in rsi_rows:
            stmt = insert(Indicator).values(
                symbol=symbol, indicator_type="RSI", bar_ts=ts, value=val
            )
            stmt = stmt.on_conflict_do_update(
                index_elements=["symbol", "indicator_type", "bar_ts"],
                set_={"value": val},
            )
            await session.execute(stmt)
        for ts, val in sma_rows:
            stmt = insert(Indicator).values(
                symbol=symbol, indicator_type="SMA20", bar_ts=ts, value=val
            )
            stmt = stmt.on_conflict_do_update(
                index_elements=["symbol", "indicator_type", "bar_ts"],
                set_={"value": val},
            )
            await session.execute(stmt)

    async def _upsert_bars(self, session: AsyncSession, symbol: str, bars: list) -> None:
        for bar in bars:
            stmt = insert(BarDaily).values(
                symbol=symbol,
                bar_date=bar["ts"],
                open=bar["open"],
                high=bar["high"],
                low=bar["low"],
                close=bar["close"],
                volume=bar["volume"],
            )
            stmt = stmt.on_conflict_do_update(
                index_elements=["symbol", "bar_date"],
                set_={
                    "open": bar["open"],
                    "high": bar["high"],
                    "low": bar["low"],
                    "close": bar["close"],
                    "volume": bar["volume"],
                },
            )
            await session.execute(stmt)

    async def _prune_old_bars(self, session: AsyncSession, symbol: str) -> None:
        cutoff = datetime.now(timezone.utc) - timedelta(days=self.settings.full_days + 5)
        await session.execute(
            delete(BarDaily).where(BarDaily.symbol == symbol, BarDaily.bar_date < cutoff)
        )

    async def _ingest_minute(self, session: AsyncSession, symbol: str) -> None:
        bars = await self.client.fetch_minute_bars(symbol, days=5)
        for bar in bars[-500:]:
            stmt = insert(BarMinute).values(
                symbol=symbol,
                bar_ts=bar["ts"],
                open=bar["open"],
                high=bar["high"],
                low=bar["low"],
                close=bar["close"],
                volume=bar["volume"],
            )
            stmt = stmt.on_conflict_do_update(
                index_elements=["symbol", "bar_ts"],
                set_={
                    "open": bar["open"],
                    "high": bar["high"],
                    "low": bar["low"],
                    "close": bar["close"],
                    "volume": bar["volume"],
                },
            )
            await session.execute(stmt)

    async def _upsert_ticker(self, session: AsyncSession, symbol: str) -> None:
        stmt = insert(Ticker).values(symbol=symbol, active=True)
        stmt = stmt.on_conflict_do_nothing(index_elements=["symbol"])
        await session.execute(stmt)

    async def _update_snapshot(self, session: AsyncSession, symbol: str) -> None:
        hot_cutoff = datetime.now(timezone.utc) - timedelta(days=self.settings.hot_days)
        result = await session.execute(
            select(BarDaily)
            .where(BarDaily.symbol == symbol, BarDaily.bar_date >= hot_cutoff)
            .order_by(BarDaily.bar_date)
        )
        bars = result.scalars().all()
        if not bars:
            result = await session.execute(
                select(BarDaily).where(BarDaily.symbol == symbol).order_by(BarDaily.bar_date)
            )
            bars = result.scalars().all()
        if not bars:
            return
        last = bars[-1]
        prev = bars[-2] if len(bars) >= 2 else last
        first_30 = bars[0]
        change_1d = ((last.close - prev.close) / prev.close * 100) if prev.close > 0 else 0
        change_30d = ((last.close - first_30.close) / first_30.close * 100) if first_30.close > 0 else 0

        rsi_result = await session.execute(
            select(Indicator)
            .where(Indicator.symbol == symbol, Indicator.indicator_type == "RSI")
            .order_by(Indicator.bar_ts.desc())
            .limit(1)
        )
        rsi_row = rsi_result.scalar_one_or_none()
        sma_result = await session.execute(
            select(Indicator)
            .where(Indicator.symbol == symbol, Indicator.indicator_type == "SMA20")
            .order_by(Indicator.bar_ts.desc())
            .limit(1)
        )
        sma_row = sma_result.scalar_one_or_none()

        session.add(
            Snapshot(
                symbol=symbol,
                price=last.close,
                change_1d_pct=change_1d,
                change_30d_pct=change_30d,
                rsi=rsi_row.value if rsi_row else None,
                sma_20=sma_row.value if sma_row else None,
                quote_source="daily_bar",
                captured_at=datetime.now(timezone.utc),
            )
        )

    async def full_refresh(self) -> None:
        self.warm_complete = False
        async with SessionLocal() as session:
            tickers = await get_tracked_symbols(session)
        batch = self.settings.calls_per_minute
        for i in range(0, len(tickers), batch):
            chunk = tickers[i : i + batch]
            await asyncio.gather(*[self._ingest_daily_only(t) for t in chunk])
            if i + batch < len(tickers):
                await asyncio.sleep(60)
        self.warm_complete = True
        logger.info("Warm-up complete — enabling tier-weighted minute ingest")

    async def _ingest_daily_only(self, symbol: str) -> None:
        async with SessionLocal() as session:
            await self._ingest_daily(session, symbol)
            await self._update_snapshot(session, symbol)
            await session.commit()


ingest_scheduler = IngestScheduler()
