from __future__ import annotations

from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI, Header, HTTPException, Request, status
from fastapi.middleware.cors import CORSMiddleware
from slowapi import Limiter
from slowapi.errors import RateLimitExceeded
from slowapi.util import get_remote_address

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
    SubscriptionGrant,
    SubscriptionLifecycleNotificationRequest,
    SubscriptionReportRequest,
    SubscriptionStatusResponse,
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


def _client_key(request: Request) -> str:
    """Rate-limit key: prefer the install id header (scoped per account) and
    fall back to the remote IP. Using install id keeps shared-NAT households
    from tripping each other's limits while still capping a single misbehaving
    account."""
    install_id = request.headers.get("x-wellness-install-id")
    if install_id:
        return f"install:{install_id}"
    return get_remote_address(request)


limiter = Limiter(
    key_func=_client_key,
    default_limits=["120/minute"],
    # Header injection requires the Response object to be threaded through
    # every decorated handler. We rely on the 429 status code and JSON body
    # instead, which is what the iOS client decodes.
    headers_enabled=False,
)


async def _rate_limit_exceeded_handler(request: Request, exc: RateLimitExceeded):
    # Preserve slowapi's default 429 response but keep it JSON-shaped for the
    # iOS client's standard error decoder.
    raise HTTPException(
        status_code=status.HTTP_429_TOO_MANY_REQUESTS,
        detail=f"Rate limit exceeded: {exc.detail}",
    )


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
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# CORS: by default the backend refuses every browser origin. The iOS app does
# not rely on the browser same-origin model, so locking this down is a pure
# hardening step. When a web console actually ships, populate the
# `WELLNESSLENS_CORS_ALLOW_ORIGINS` env var with an explicit whitelist.
_cors_origins = get_settings().cors_origin_list
if _cors_origins:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=_cors_origins,
        allow_credentials=True,
        allow_methods=["GET", "POST", "DELETE"],
        allow_headers=[
            "Authorization",
            "Content-Type",
            "X-Firebase-AppCheck",
            "X-Wellness-Install-ID",
        ],
        max_age=600,
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
@limiter.exempt
async def healthz(request: Request) -> dict[str, str]:
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
@limiter.limit("30/minute")
async def analyze_structured(
    request: Request,
    body: AnalyzeStructuredScanRequest,
    services: BackendServices = Depends(get_backend_services),
) -> AnalyzeStructuredScanResponse:
    return AnalyzeStructuredScanResponse(
        analysis=services.analyze_structured(
            input=body.input,
            profile=body.profile,
            recent_scans=body.recentScans,
            recent_checkins=body.recentCheckIns,
            scan_context=body.scanContext,
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


@app.delete(
    "/v1/profile",
    response_model=EmptyResponse,
    status_code=status.HTTP_200_OK,
    dependencies=[Depends(validate_client_context)],
)
async def delete_profile(
    x_wellness_install_id: str | None = Header(default=None),
    services: BackendServices = Depends(get_backend_services),
) -> EmptyResponse:
    """Delete all stored data for the caller's install id.

    Implements App Store Review Guideline 5.1.1(v) account-deletion requirement.
    The install id is taken from the `X-Wellness-Install-ID` header that every
    iOS client already sends; the endpoint is a no-op if nothing is stored.
    """
    install_id = (x_wellness_install_id or "").strip()
    if not install_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Missing X-Wellness-Install-ID header.",
        )
    services.repository.delete_state(install_id)
    return EmptyResponse()


@app.post(
    "/v1/subscriptions/report",
    response_model=SubscriptionGrant,
    dependencies=[Depends(validate_client_context)],
)
@limiter.limit("20/minute")
async def subscriptions_report(
    request: Request,
    body: SubscriptionReportRequest,
    services: BackendServices = Depends(get_backend_services),
) -> SubscriptionGrant:
    """Persist a server-side audit record of a StoreKit 2 purchase.

    iOS still owns the authoritative entitlement check (StoreKit JWS verified
    locally). This endpoint gives ops + support a durable record keyed by
    install id, and primes a future slice that will turn the stored grant
    into the authoritative source of truth after App Store Server API
    signature verification lands.
    """
    return services.process_subscription_report(body)


@app.get(
    "/v1/subscriptions/status",
    response_model=SubscriptionStatusResponse,
    dependencies=[Depends(validate_client_context)],
)
@limiter.limit("60/minute")
async def subscriptions_status(
    request: Request,
    x_wellness_install_id: str | None = Header(default=None),
    services: BackendServices = Depends(get_backend_services),
) -> SubscriptionStatusResponse:
    install_id = (x_wellness_install_id or "").strip()
    if not install_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Missing X-Wellness-Install-ID header.",
        )
    return services.get_subscription_status(install_id)


@app.post(
    "/v1/subscriptions/notification",
    response_model=EmptyResponse,
    status_code=status.HTTP_200_OK,
)
@limiter.limit("240/minute")
async def subscriptions_notification(
    request: Request,
    body: SubscriptionLifecycleNotificationRequest,
    services: BackendServices = Depends(get_backend_services),
) -> EmptyResponse:
    """Webhook for Apple's App Store Server Notifications v2.

    Intentionally unauthenticated at the Firebase layer: Apple's servers
    cannot present Firebase auth or App Check tokens. Signature verification
    against Apple's certificate chain (the outer JWS) is the security layer
    and lives in a follow-up slice. Until then, the handler stores nothing
    and only logs payload length so ops can confirm reachability.
    """
    return services.process_subscription_lifecycle_notification(body)
