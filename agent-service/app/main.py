from __future__ import annotations

from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI, Request

from app.contracts import (
    CoachReply,
    CoachReplyRequest,
    ScanVerdictRequest,
    ScanVerdictResponse,
    StrategistReplyRequest,
    StrategistReplyResponse,
)
from app.coach_runtime import get_coach_assets
from app.service import StrategistService, get_settings


@asynccontextmanager
async def lifespan(app: FastAPI):
    settings = get_settings()
    get_coach_assets(settings.coach_assets_dir)
    app.state.strategist_service = StrategistService(settings=settings)
    yield


app = FastAPI(
    title="WellnessLens Agent Service",
    version="0.1.0",
    lifespan=lifespan,
)


def get_service(request: Request) -> StrategistService:
    if not hasattr(request.app.state, "strategist_service"):
        request.app.state.strategist_service = StrategistService(settings=get_settings())
    return request.app.state.strategist_service


@app.get("/healthz")
async def healthz() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/v1/strategist/reply", response_model=StrategistReplyResponse)
async def strategist_reply(
    request: StrategistReplyRequest,
    service: StrategistService = Depends(get_service),
) -> StrategistReplyResponse:
    return StrategistReplyResponse(reply=service.reply(request))


@app.post("/v1/scan/verdict", response_model=ScanVerdictResponse)
async def scan_verdict(
    request: ScanVerdictRequest,
    service: StrategistService = Depends(get_service),
) -> ScanVerdictResponse:
    return ScanVerdictResponse(verdict=service.verdict(request))


@app.post("/v1/coach/reply", response_model=CoachReply)
async def coach_reply(
    request: CoachReplyRequest,
    service: StrategistService = Depends(get_service),
) -> CoachReply:
    return service.coach_reply(request)
