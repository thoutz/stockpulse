from collections.abc import AsyncGenerator

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.orm import DeclarativeBase

from config import get_settings


class Base(DeclarativeBase):
    pass


engine = create_async_engine(get_settings().database_url, echo=False, pool_pre_ping=True)
SessionLocal = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    async with SessionLocal() as session:
        yield session


async def init_db() -> None:
    from models import db_models  # noqa: F401

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
        await conn.execute(text("ALTER TABLE tickers ADD COLUMN IF NOT EXISTS exchange VARCHAR(16)"))
        await conn.execute(text("ALTER TABLE tickers ADD COLUMN IF NOT EXISTS index_tag VARCHAR(32)"))
        await conn.execute(text("ALTER TABLE news_items ADD COLUMN IF NOT EXISTS sentiment_score DOUBLE PRECISION"))
        await conn.execute(text("ALTER TABLE snapshots ADD COLUMN IF NOT EXISTS change_5m_pct DOUBLE PRECISION"))
        await conn.execute(text("ALTER TABLE snapshots ADD COLUMN IF NOT EXISTS change_15m_pct DOUBLE PRECISION"))
        await conn.execute(text("ALTER TABLE snapshots ADD COLUMN IF NOT EXISTS quote_source VARCHAR(16)"))
