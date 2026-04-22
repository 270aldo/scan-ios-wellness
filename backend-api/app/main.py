from __future__ import annotations

from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI, Header, HTTPException, Request, status

from app.config import Settings, get_settings
from app.contracts import (
    AnalyzeProductRequest,
    AnalyzeProductResponse,
    AnalyzeStructuredScanRequest,
    AnalyzeStructuredScanResponse,
    ClientConfigResponse,
    CompleteOnboardingRequest,
    DailyHomeRequest,
    DailyHomeResponse,
    EmptyResponse,
    HistorySyncRequest,
    HistorySyncResponse,
    SaveCheckInEventRequest,
    SaveCheckInRequest,
    SaveFavoriteItemRequest,
    SaveScanDecisionRequest,
    UpsertMemoryRequest,
    WeeklyInsightsRequest,
    WeeklyInsightsResponse,
)
from app.date_utils import apple_timestamp_now
from app.repository import StateRepository, build_repository
from app.product_resolver import ProductResolver
from app.security import (
    SecurityVerificationError,
    VerifiedRequestContext,
    verify_firebase_app_check_token,
    verify_firebase_id_token,
)
from app.services import BackendServices


def build_backend_services(settings: Settings | None = None) -> BackendServices:
    resolved_settings = settings or get_settings()
    repository = build_repository(resolved_settings)
    return BackendServices(
        repository=repository,
        settings=resolved_settings,
        resolver=ProductResolver(resolved_settings),
    )


@asynccontextmanager
async def lifespan(app: FastAPI):
    app.state.backend_services = build_backend_services()
    yield


app = FastAPI(
    title="WellnessLens Backend API",
    version="0.1.0",
    lifespan=lifespan,
)


def get_backend_services(request: Request) -> BackendServices:
    if not hasattr(request.app.state, "backend_services"):
        request.app.state.backend_services = build_backend_services()
    return request.app.state.backend_services


def get_settings_dependency() -> Settings:
    return get_settings()


async def validate_client_context(
    settings: Settings = Depends(get_settings_dependency),
    authorization: str | None = Header(default=None),
    x_firebase_appcheck: str | None = Header(default=None),
) -> VerifiedRequestContext:
    auth_claims = None
    app_check_claims = None

    if settings.firebase_auth_enabled and not authorization:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Missing Authorization header.")
    if settings.app_check_enforced and not x_firebase_appcheck:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Missing X-Firebase-AppCheck header.")
    try:
        if settings.firebase_auth_enabled and authorization:
            auth_claims = verify_firebase_id_token(authorization)
        if settings.app_check_enforced and x_firebase_appcheck:
            app_check_claims = verify_firebase_app_check_token(x_firebase_appcheck)
    except SecurityVerificationError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc

    return VerifiedRequestContext(auth_claims=auth_claims, app_check_claims=app_check_claims)


@app.get("/healthz")
async def healthz() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/v1/client-config", response_model=ClientConfigResponse)
async def client_config(services: BackendServices = Depends(get_backend_services)) -> ClientConfigResponse:
    return services.client_config()


@app.post("/analyzeProduct", response_model=AnalyzeProductResponse, dependencies=[Depends(validate_client_context)])
async def analyze_product(
    request: AnalyzeProductRequest,
    services: BackendServices = Depends(get_backend_services),
) -> AnalyzeProductResponse:
    return AnalyzeProductResponse(
        analysis=services.analyze_product(request.input, request.userContext, request.scanContext)
    )


@app.post("/v1/scan/analyze", response_model=AnalyzeStructuredScanResponse, dependencies=[Depends(validate_client_context)])
async def analyze_structured(
    request: AnalyzeStructuredScanRequest,
    services: BackendServices = Depends(get_backend_services),
) -> AnalyzeStructuredScanResponse:
    return AnalyzeStructuredScanResponse(
        analysis=services.analyze_structured(
            input=request.input,
            profile=request.profile,
            recent_scans=request.recentScans,
            recent_checkins=request.recentCheckIns,
            scan_context=request.scanContext,
        )
    )


@app.post("/saveCheckIn", response_model=EmptyResponse, dependencies=[Depends(validate_client_context)])
async def save_checkin(
    request: SaveCheckInRequest,
    services: BackendServices = Depends(get_backend_services),
) -> EmptyResponse:
    return services.save_checkin(request.installID, request.checkIn, request.userContext)


@app.post("/v1/scan/feedback", response_model=EmptyResponse, dependencies=[Depends(validate_client_context)])
async def save_checkin_event(
    request: SaveCheckInEventRequest,
    services: BackendServices = Depends(get_backend_services),
) -> EmptyResponse:
    return services.save_checkin_event(request.installID, request.event)


@app.post("/v1/profile/sync", response_model=EmptyResponse, dependencies=[Depends(validate_client_context)])
async def sync_profile(
    request: CompleteOnboardingRequest,
    services: BackendServices = Depends(get_backend_services),
) -> EmptyResponse:
    return services.save_profile(request)


@app.post("/v1/onboarding/complete", response_model=EmptyResponse, dependencies=[Depends(validate_client_context)])
async def complete_onboarding(
    request: CompleteOnboardingRequest,
    services: BackendServices = Depends(get_backend_services),
) -> EmptyResponse:
    return services.save_profile(request)


@app.post("/v1/home", response_model=DailyHomeResponse, dependencies=[Depends(validate_client_context)])
async def daily_home(
    request: DailyHomeRequest,
    services: BackendServices = Depends(get_backend_services),
) -> DailyHomeResponse:
    return services.home(request)


@app.post("/v1/home/weekly-insights", response_model=WeeklyInsightsResponse, dependencies=[Depends(validate_client_context)])
async def weekly_insights(
    request: WeeklyInsightsRequest,
    services: BackendServices = Depends(get_backend_services),
) -> WeeklyInsightsResponse:
    return services.weekly_insights(request.installID)


@app.post("/v1/scans/decision", response_model=EmptyResponse, dependencies=[Depends(validate_client_context)])
async def save_scan_decision(
    request: SaveScanDecisionRequest,
    services: BackendServices = Depends(get_backend_services),
) -> EmptyResponse:
    return services.save_scan_decision(request.installID, request.decision)


@app.post("/v1/favorites", response_model=EmptyResponse, dependencies=[Depends(validate_client_context)])
async def save_favorite(
    request: SaveFavoriteItemRequest,
    services: BackendServices = Depends(get_backend_services),
) -> EmptyResponse:
    return services.save_favorite(request.installID, request.favorite)


@app.post("/v1/memory/upsert", response_model=EmptyResponse, dependencies=[Depends(validate_client_context)])
async def upsert_memory(
    request: UpsertMemoryRequest,
    services: BackendServices = Depends(get_backend_services),
) -> EmptyResponse:
    return services.upsert_memory_items(request.installID, request.memoryItems)


@app.post("/v1/history/sync", response_model=HistorySyncResponse, dependencies=[Depends(validate_client_context)])
async def history_sync(
    request: HistorySyncRequest,
    services: BackendServices = Depends(get_backend_services),
) -> HistorySyncResponse:
    state = services.repository.sync_history(request)
    return HistorySyncResponse(
        installID=request.installID,
        scans=list(state.scan_events.values()),
        checkIns=list(state.checkin_events.values()),
        favorites=list(state.favorites.values()),
        memoryItems=list(state.memory_items.values()),
        scanDecisions=list(state.scan_decisions.values()),
        serverTimestamp=apple_timestamp_now(),
    )
