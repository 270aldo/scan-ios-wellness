from __future__ import annotations

from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI, Header, HTTPException, Request, status

from app.contracts import (
    CoachReply,
    CoachReplyRequest,
    ScanVerdictRequest,
    ScanVerdictResponse,
    StrategistReplyRequest,
    StrategistReplyResponse,
)
from app.coach_runtime import get_coach_assets
from app.scan_verdict_runtime import get_scan_verdict_assets
from app.security import (
    SecurityVerificationError,
    VerifiedRequestContext,
    verify_firebase_app_check_token,
    verify_firebase_id_token,
)
from app.service import Settings, StrategistService, get_settings


@asynccontextmanager
async def lifespan(app: FastAPI):
    settings = get_settings()
    coach_assets = get_coach_assets(settings.coach_assets_dir)
    scan_assets = get_scan_verdict_assets(settings.scan_assets_dir)
    app.state.strategist_service = StrategistService(
        settings=settings,
        scan_assets=scan_assets,
        coach_assets=coach_assets,
    )
    yield


app = FastAPI(
    title="WellnessLens Agent Service",
    version="0.1.0",
    lifespan=lifespan,
)


def get_service(request: Request) -> StrategistService:
    if not hasattr(request.app.state, "strategist_service"):
        settings = get_settings()
        request.app.state.strategist_service = StrategistService(
            settings=settings,
            scan_assets=get_scan_verdict_assets(settings.scan_assets_dir),
            coach_assets=get_coach_assets(settings.coach_assets_dir),
        )
    return request.app.state.strategist_service


def get_settings_dependency() -> Settings:
    return get_settings()


async def validate_client_context(
    settings: Settings = Depends(get_settings_dependency),
    authorization: str | None = Header(default=None),
    x_firebase_appcheck: str | None = Header(default=None),
) -> VerifiedRequestContext:
    auth_claims = None
    app_check_claims = None

    if settings.auth_enforced and not authorization:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Missing Authorization header.")
    if settings.app_check_required and not x_firebase_appcheck:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Missing X-Firebase-AppCheck header.")
    try:
        if settings.auth_enforced and authorization:
            auth_claims = verify_firebase_id_token(authorization)
        if settings.app_check_required and x_firebase_appcheck:
            app_check_claims = verify_firebase_app_check_token(x_firebase_appcheck)
    except SecurityVerificationError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc

    return VerifiedRequestContext(auth_claims=auth_claims, app_check_claims=app_check_claims)


@app.get("/healthz")
async def healthz() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/v1/strategist/reply", response_model=StrategistReplyResponse, dependencies=[Depends(validate_client_context)])
async def strategist_reply(
    request: StrategistReplyRequest,
    service: StrategistService = Depends(get_service),
) -> StrategistReplyResponse:
    return StrategistReplyResponse(reply=service.reply(request))


@app.post("/v1/scan/verdict", response_model=ScanVerdictResponse, dependencies=[Depends(validate_client_context)])
async def scan_verdict(
    request: ScanVerdictRequest,
    service: StrategistService = Depends(get_service),
) -> ScanVerdictResponse:
    return ScanVerdictResponse(verdict=service.verdict(request))


@app.post("/v1/coach/reply", response_model=CoachReply, dependencies=[Depends(validate_client_context)])
async def coach_reply(
    request: CoachReplyRequest,
    service: StrategistService = Depends(get_service),
) -> CoachReply:
    return service.coach_reply(request)
