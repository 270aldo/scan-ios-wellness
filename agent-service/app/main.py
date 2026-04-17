from __future__ import annotations

from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI, Request

from app.contracts import StrategistReplyRequest, StrategistReplyResponse
from app.service import StrategistService, get_settings


@asynccontextmanager
async def lifespan(app: FastAPI):
    app.state.strategist_service = StrategistService(settings=get_settings())
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
