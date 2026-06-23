from functools import lru_cache
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    massive_api_key: str = ""
    groq_api_key: str = ""
    database_url: str = "postgresql+asyncpg://stockpulse:stockpulse@127.0.0.1:5432/stockpulse"
    tickers: str = "RKLB,TSLA,NVDA,ASTS,LUNR,HWM,RDW,AMD,AVGO"
    calls_per_minute: int = 5
    alert_threshold_pct: float = 5.0
    alert_velocity_pct: float = 2.0
    alert_cooldown_hours: float = 4.0
    alerts_retain_count: int = 50
    finnhub_api_key: str = ""
    favorite_limit: int = 20
    quote_scheduler_seconds: int = 30
    alphavantage_api_key: str = ""
    groq_daily_token_budget: int = 85000
    groq_chat_daily_limit: int = 10
    groq_model: str = "llama-3.3-70b-versatile"
    massive_base_url: str = "https://api.massive.com"
    hot_days: int = 30
    full_days: int = 180  # ~6 months daily bar retention for AI context

    # Alpaca Trading API (paper or live)
    alpaca_api_key: str = ""
    alpaca_secret_key: str = ""
    alpaca_paper: bool = False
    trading_enabled: bool = False
    trading_api_secret: str = ""
    auto_trade_enabled: bool = False
    propose_cooldown_hours: float = 4.0
    max_position_pct: float = 10.0
    max_positions: int = 3
    min_confidence: float = 0.75
    daily_loss_limit_pct: float = 5.0
    default_trade_notional: float = 5.0
    min_fractional_notional: float = 1.0
    admin_password: str = ""

    # Micro day-trading (intraday momentum + auto TP/SL)
    micro_trade_enabled: bool = True
    micro_scan_interval_minutes: int = 5
    micro_trade_notional: float = 50.0
    micro_take_profit_pct: float = 0.75
    micro_stop_loss_pct: float = 0.50
    micro_min_momentum_5m_pct: float = 0.25
    micro_max_momentum_5m_pct: float = 2.5
    micro_min_momentum_15m_pct: float = 0.35
    micro_slow_grind_5m_pct: float = 0.10
    micro_momentum_flip_5m_pct: float = -0.15
    micro_propose_cooldown_minutes: float = 30.0
    micro_daily_profit_cap_usd: float = 50.0
    micro_entry_cutoff_hour: int = 15
    micro_entry_cutoff_minute: int = 45
    micro_eod_flat_enabled: bool = True
    micro_eod_flat_hour: int = 15
    micro_eod_flat_minute: int = 55

    @property
    def ticker_list(self) -> list[str]:
        return [t.strip().upper() for t in self.tickers.split(",") if t.strip()]


@lru_cache
def get_settings() -> Settings:
    return Settings()
