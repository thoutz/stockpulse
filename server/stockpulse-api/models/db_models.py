from datetime import datetime

from sqlalchemy import DateTime, Float, Index, Integer, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from database import Base


class Ticker(Base):
    __tablename__ = "tickers"

    symbol: Mapped[str] = mapped_column(String(16), primary_key=True)
    name: Mapped[str | None] = mapped_column(String(128), nullable=True)
    exchange: Mapped[str | None] = mapped_column(String(16), nullable=True)
    index_tag: Mapped[str | None] = mapped_column(String(32), nullable=True)
    active: Mapped[bool] = mapped_column(default=True)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())


class Favorite(Base):
    __tablename__ = "favorites"

    symbol: Mapped[str] = mapped_column(String(16), primary_key=True)
    name: Mapped[str | None] = mapped_column(String(128), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class SessionFavorite(Base):
    __tablename__ = "session_favorites"
    __table_args__ = (Index("ix_session_favorites_session_symbol", "session_id", "symbol", unique=True),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    session_id: Mapped[str] = mapped_column(String(64), index=True)
    symbol: Mapped[str] = mapped_column(String(16))
    name: Mapped[str | None] = mapped_column(String(128), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class BarDaily(Base):
    __tablename__ = "bars_daily"
    __table_args__ = (Index("ix_bars_daily_symbol_date", "symbol", "bar_date", unique=True),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    symbol: Mapped[str] = mapped_column(String(16), index=True)
    bar_date: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    open: Mapped[float] = mapped_column(Float)
    high: Mapped[float] = mapped_column(Float)
    low: Mapped[float] = mapped_column(Float)
    close: Mapped[float] = mapped_column(Float)
    volume: Mapped[float] = mapped_column(Float)


class BarMinute(Base):
    __tablename__ = "bars_minute"
    __table_args__ = (Index("ix_bars_minute_symbol_ts", "symbol", "bar_ts", unique=True),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    symbol: Mapped[str] = mapped_column(String(16), index=True)
    bar_ts: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    open: Mapped[float] = mapped_column(Float)
    high: Mapped[float] = mapped_column(Float)
    low: Mapped[float] = mapped_column(Float)
    close: Mapped[float] = mapped_column(Float)
    volume: Mapped[float] = mapped_column(Float)


class Indicator(Base):
    __tablename__ = "indicators"
    __table_args__ = (Index("ix_indicators_symbol_type_ts", "symbol", "indicator_type", "bar_ts", unique=True),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    symbol: Mapped[str] = mapped_column(String(16), index=True)
    indicator_type: Mapped[str] = mapped_column(String(32))
    bar_ts: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    value: Mapped[float] = mapped_column(Float)


class MonitorSettings(Base):
    """Single-row monitor focus (id=1)."""

    __tablename__ = "monitor_settings"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    focus_sector_id: Mapped[str | None] = mapped_column(String(32), nullable=True)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())


class Snapshot(Base):
    __tablename__ = "snapshots"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    symbol: Mapped[str] = mapped_column(String(16), index=True)
    price: Mapped[float] = mapped_column(Float)
    change_1d_pct: Mapped[float] = mapped_column(Float, default=0.0)
    change_30d_pct: Mapped[float] = mapped_column(Float, default=0.0)
    change_5m_pct: Mapped[float | None] = mapped_column(Float, nullable=True)
    change_15m_pct: Mapped[float | None] = mapped_column(Float, nullable=True)
    rsi: Mapped[float | None] = mapped_column(Float, nullable=True)
    sma_20: Mapped[float | None] = mapped_column(Float, nullable=True)
    quote_source: Mapped[str | None] = mapped_column(String(16), nullable=True)
    captured_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class AIReport(Base):
    __tablename__ = "ai_reports"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    report_type: Mapped[str] = mapped_column(String(32), index=True)
    title: Mapped[str] = mapped_column(String(256))
    body: Mapped[str] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), index=True)


class AISuggestion(Base):
    __tablename__ = "ai_suggestions"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    symbol: Mapped[str] = mapped_column(String(16), index=True)
    bias: Mapped[str] = mapped_column(String(32))
    summary: Mapped[str] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), index=True)


class AIAlert(Base):
    __tablename__ = "ai_alerts"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    symbol: Mapped[str] = mapped_column(String(16), index=True)
    alert_type: Mapped[str] = mapped_column(String(32))
    message: Mapped[str] = mapped_column(Text)
    change_pct: Mapped[float] = mapped_column(Float)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), index=True)
    delivered_push: Mapped[bool] = mapped_column(default=False)


class MarketObservation(Base):
    __tablename__ = "market_observations"
    __table_args__ = (Index("ix_market_obs_symbol_created", "symbol", "created_at"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    symbol: Mapped[str] = mapped_column(String(16), index=True)
    observation_type: Mapped[str] = mapped_column(String(32), index=True)
    change_pct: Mapped[float] = mapped_column(Float, default=0.0)
    window_minutes: Mapped[int] = mapped_column(Integer, default=0)
    message: Mapped[str] = mapped_column(Text)
    session_date: Mapped[str] = mapped_column(String(10), index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), index=True)


class NewsItem(Base):
    __tablename__ = "news_items"
    __table_args__ = (Index("ix_news_items_url", "url", unique=True),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    symbol: Mapped[str] = mapped_column(String(16), index=True)
    headline: Mapped[str] = mapped_column(String(512))
    summary: Mapped[str | None] = mapped_column(Text, nullable=True)
    source: Mapped[str | None] = mapped_column(String(128), nullable=True)
    url: Mapped[str] = mapped_column(String(1024))
    published_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    sentiment_score: Mapped[float | None] = mapped_column(Float, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class AVDailyBundle(Base):
    """Once-per-day Alpha Vantage snapshot for the close pulse report."""
    __tablename__ = "av_daily_bundles"
    __table_args__ = (Index("ix_av_daily_bundles_session", "session_date", unique=True),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    session_date: Mapped[str] = mapped_column(String(10), index=True)
    earnings_summary: Mapped[str] = mapped_column(Text, default="")
    market_breadth: Mapped[str] = mapped_column(Text, default="")
    fundamentals_summary: Mapped[str] = mapped_column(Text, default="")
    news_sentiment_summary: Mapped[str] = mapped_column(Text, default="")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class QuoteTick(Base):
    """Finnhub quote ticks for 5m/15m window recovery after restarts."""

    __tablename__ = "quote_ticks"
    __table_args__ = (Index("ix_quote_ticks_symbol_captured", "symbol", "captured_at"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    symbol: Mapped[str] = mapped_column(String(16), index=True)
    price: Mapped[float] = mapped_column(Float)
    captured_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)


class SessionIntelligence(Base):
    """Pre-computed analytics fed to pulse reports and future reporting APIs."""

    __tablename__ = "session_intelligence"
    __table_args__ = (Index("ix_session_intel_date_slot", "session_date", "slot"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    session_date: Mapped[str] = mapped_column(String(10), index=True)
    slot: Mapped[str] = mapped_column(String(16), index=True)
    category: Mapped[str] = mapped_column(String(32), index=True)
    symbol: Mapped[str | None] = mapped_column(String(16), nullable=True, index=True)
    tier: Mapped[str | None] = mapped_column(String(16), nullable=True)
    metric_key: Mapped[str | None] = mapped_column(String(32), nullable=True)
    metric_value: Mapped[float | None] = mapped_column(Float, nullable=True)
    summary_text: Mapped[str] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), index=True)


class CatalystEvent(Base):
    __tablename__ = "catalyst_events"
    __table_args__ = (Index("ix_catalyst_events_ticker_date", "ticker", "event_date"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    ticker: Mapped[str] = mapped_column(String(16), index=True)
    name: Mapped[str] = mapped_column(String(128))
    event_name: Mapped[str] = mapped_column(String(256))
    event_date: Mapped[str] = mapped_column(String(10))
    active: Mapped[bool] = mapped_column(default=True)
    confidence_score: Mapped[float | None] = mapped_column(Float, nullable=True)
    source: Mapped[str] = mapped_column(String(32), default="manual")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())


class CatalystRipple(Base):
    __tablename__ = "catalyst_ripples"
    __table_args__ = (Index("ix_catalyst_ripples_event_ticker", "catalyst_event_id", "ripple_ticker", unique=True),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    catalyst_event_id: Mapped[int] = mapped_column(Integer, index=True)
    ripple_ticker: Mapped[str] = mapped_column(String(16), index=True)
    description: Mapped[str] = mapped_column(String(256), default="")
    hit_rate: Mapped[float | None] = mapped_column(Float, nullable=True)
    avg_post_pct: Mapped[float | None] = mapped_column(Float, nullable=True)


class TradeDecisionLog(Base):
    """Audit trail for AI/rule-based trade proposals and executions."""

    __tablename__ = "trade_decision_logs"
    __table_args__ = (Index("ix_trade_decisions_symbol_created", "symbol", "created_at"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    symbol: Mapped[str] = mapped_column(String(16), index=True)
    action: Mapped[str] = mapped_column(String(16))
    confidence: Mapped[float] = mapped_column(Float, default=0.0)
    notional_usd: Mapped[float] = mapped_column(Float, default=0.0)
    rationale: Mapped[str] = mapped_column(Text, default="")
    signal_source: Mapped[str | None] = mapped_column(String(64), nullable=True)
    buying_signal_score: Mapped[float | None] = mapped_column(Float, nullable=True)
    alpaca_order_id: Mapped[str | None] = mapped_column(String(64), nullable=True)
    status: Mapped[str] = mapped_column(String(32), default="proposed", index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), index=True)

