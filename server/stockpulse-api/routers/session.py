from __future__ import annotations

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Response
from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from models.db_models import SessionFavorite, Ticker
from routers.data import FavoriteIn, FavoriteOut, _backfill_favorite
from services.session import get_or_create_session_id

router = APIRouter(prefix="/api/session", tags=["session"])

SESSION_COOKIE = "sp_session"
SESSION_MAX_AGE = 60 * 60 * 24 * 365  # 1 year


def _set_session_cookie(response: Response, session_id: str) -> None:
    response.set_cookie(
        key=SESSION_COOKIE,
        value=session_id,
        max_age=SESSION_MAX_AGE,
        httponly=True,
        secure=True,
        samesite="lax",
        path="/",
    )


@router.get("/favorites", response_model=list[FavoriteOut])
async def list_session_favorites(
    response: Response,
    db: AsyncSession = Depends(get_db),
    session_id: str = Depends(get_or_create_session_id),
) -> list[FavoriteOut]:
    _set_session_cookie(response, session_id)
    result = await db.execute(
        select(SessionFavorite)
        .where(SessionFavorite.session_id == session_id)
        .order_by(SessionFavorite.symbol)
    )
    return [FavoriteOut(symbol=f.symbol, name=f.name) for f in result.scalars().all()]


@router.post("/favorites", response_model=FavoriteOut)
async def add_session_favorite(
    body: FavoriteIn,
    response: Response,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db),
    session_id: str = Depends(get_or_create_session_id),
) -> FavoriteOut:
    symbol = body.symbol.strip().upper()
    if not symbol:
        raise HTTPException(400, "symbol is required")

    _set_session_cookie(response, session_id)

    await db.execute(
        pg_insert(SessionFavorite)
        .values(session_id=session_id, symbol=symbol, name=body.name)
        .on_conflict_do_update(
            index_elements=["session_id", "symbol"],
            set_={"name": body.name},
        )
    )
    ticker_stmt = pg_insert(Ticker).values(symbol=symbol, name=body.name, active=True)
    if body.name:
        ticker_stmt = ticker_stmt.on_conflict_do_update(
            index_elements=["symbol"], set_={"name": body.name, "active": True}
        )
    else:
        ticker_stmt = ticker_stmt.on_conflict_do_nothing(index_elements=["symbol"])
    await db.execute(ticker_stmt)
    await db.commit()

    background_tasks.add_task(_backfill_favorite, symbol)
    return FavoriteOut(symbol=symbol, name=body.name)


@router.delete("/favorites/{symbol}")
async def remove_session_favorite(
    symbol: str,
    response: Response,
    db: AsyncSession = Depends(get_db),
    session_id: str = Depends(get_or_create_session_id),
) -> dict:
    sym = symbol.strip().upper()
    _set_session_cookie(response, session_id)

    result = await db.execute(
        select(SessionFavorite).where(
            SessionFavorite.session_id == session_id,
            SessionFavorite.symbol == sym,
        )
    )
    fav = result.scalar_one_or_none()
    if fav is None:
        raise HTTPException(404, f"{sym} is not a favorite")
    await db.delete(fav)
    await db.commit()
    return {"removed": sym}
