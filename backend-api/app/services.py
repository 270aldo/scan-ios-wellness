from __future__ import annotations

from dataclasses import dataclass
from uuid import NAMESPACE_URL, uuid5

from app.config import Settings
from app.contracts import (
    ActiveGoal,
    AppleTimestamp,
    AlternativeSuggestion,
    AnalysisEntityType,
    AnalysisEnvelope,
    AnalysisInputType,
    AnalysisVerdict,
    CheckInEntry,
    CheckInEvent,
    CheckInSignal,
    ClientConfigResponse,
    ClientKillSwitches,
    CompleteOnboardingRequest,
    ConfidenceLevel,
    DailyHomeHeroEmphasis,
    DailyHomeHeroV2,
    DailyHomePayload,
    DailyHomePayloadV2,
    DailyHomeRequest,
    DailyHomeResponse,
    DailyNutritionPriority,
    EmptyResponse,
    FavoriteItem,
    FirstWeekPlan,
    GoalMilestone,
    GoalStatus,
    HistorySyncRequest,
    IngredientTag,
    Ingredient,
    LensScore,
    MedicalSafety,
    MemoryItem,
    MemoryItemKind,
    MexicoWarningLabel,
    OpenLoop,
    PatternContext,
    ProductCandidate,
    ProductResolutionSemantic,
    ProductResolutionSource,
    ProductType,
    ReasonImpact,
    ReasonItem,
    Recommendation,
    RecommendationKind,
    RecentWin,
    RestaurantFrequency,
    SafetyRiskLevel,
    ScanAnalysis,
    ScanDecision,
    ScanDecisionKind,
    ScanEvent,
    ScanContext,
    ScanInput,
    ScanSource,
    StrategistNote,
    StructuredLensScores,
    SubscriptionGrant,
    SubscriptionGrantState,
    SubscriptionLifecycleNotificationRequest,
    SubscriptionReportRequest,
    SubscriptionStatusResponse,
    SubscriptionTier,
    SwapPriority,
    SwapSuggestion,
    TodayFocus,
    UserContext,
    UserGoal,
    UserLifecycleState,
    UserProfile,
    WeeklyInsight,
    WeeklyInsightsResponse,
    WellnessLensKind,
    WellnessFeatureFlags,
    fixture_payload,
)
from app.date_utils import apple_timestamp_now
from app.mexico_nutrition import mexico_signal_titles
from app.product_resolver import ProductResolver, ResolverResult
from app.product_resolution_semantics import (
    ensure_product_resolution_semantics,
    product_has_resolution_semantic,
)
from app.repository import StateRepository, UserState


DISCLAIMER = (
    "WellnessLens offers consumer wellness guidance only. "
    "It does not diagnose, treat, or replace medical advice."
)

FIXTURE_BASE_TIMESTAMP: AppleTimestamp = 777_777_777.0


def _stable_id(prefix: str, *parts: str) -> str:
    material = "|".join([prefix, *[part for part in parts if part]])
    return str(uuid5(NAMESPACE_URL, material))


def _timestamp(value: AppleTimestamp | None = None) -> AppleTimestamp:
    return value if value is not None else apple_timestamp_now()


@dataclass
class BackendServices:
    repository: StateRepository
    settings: Settings
    resolver: ProductResolver

    def client_config(self) -> ClientConfigResponse:
        return ClientConfigResponse(
            environment=self.settings.env,
            minimumSupportedVersion=self.settings.minimum_supported_version,
            minimumSupportedBuild=self.settings.minimum_supported_build,
            copyVersion=self.settings.copy_version,
            persistenceMode=self.settings.persistence_mode,
            firebaseAuthEnforced=self.settings.firebase_auth_enabled,
            appCheckEnforced=self.settings.app_check_enforced,
            agentProviderMode=self.settings.agent_provider_mode,
            flags=WellnessFeatureFlags(),
            killSwitches=ClientKillSwitches(),
            updatedAt=apple_timestamp_now(),
        )

    def analyze_product(self, input: ScanInput, user_context: UserContext, scan_context: ScanContext | None = None) -> ScanAnalysis:
        resolution = self.resolver.resolve(input)
        return build_scan_analysis(input=input, user_context=user_context, resolution=resolution, scan_context=scan_context)

    def analyze_structured(
        self,
        input: ScanInput,
        profile: UserProfile,
        recent_scans: list[ScanEvent],
        recent_checkins: list[CheckInEvent],
        scan_context: ScanContext | None = None,
    ) -> AnalysisEnvelope:
        resolution = self.resolver.resolve(input)
        return build_analysis_envelope(
            input=input,
            user_context=profile.userContext,
            recent_scans=recent_scans,
            recent_checkins=recent_checkins,
            resolution=resolution,
            scan_context=scan_context,
        )

    def save_profile(self, request: CompleteOnboardingRequest) -> EmptyResponse:
        self.repository.save_profile(
            install_id=request.installID,
            profile=request.profile,
            active_goals=request.activeGoals,
            first_week_plan=request.firstWeekPlan,
        )
        return EmptyResponse()

    def save_checkin(self, install_id: str, checkin: CheckInEntry, user_context: UserContext) -> EmptyResponse:
        self.repository.save_checkin(install_id, checkin, user_context)
        return EmptyResponse()

    def save_checkin_event(self, install_id: str, event: CheckInEvent) -> EmptyResponse:
        self.repository.save_checkin_event(install_id, event)
        return EmptyResponse()

    def save_scan_decision(self, install_id: str, decision: ScanDecision) -> EmptyResponse:
        self.repository.save_scan_decision(install_id, decision)
        return EmptyResponse()

    def save_favorite(self, install_id: str, favorite: FavoriteItem) -> EmptyResponse:
        self.repository.save_favorite(install_id, favorite)
        return EmptyResponse()

    def upsert_memory_items(self, install_id: str, memory_items: list[MemoryItem]) -> EmptyResponse:
        self.repository.upsert_memory_items(install_id, memory_items)
        return EmptyResponse()

    def home(self, request: DailyHomeRequest) -> DailyHomeResponse:
        state = self.repository.get_state(request.installID)
        profile = state.profile or request.profile
        active_goals = state.active_goals or request.activeGoals
        payload = build_daily_home_payload(
            state=state,
            profile=profile,
            active_goals=active_goals,
        )
        payload_v2 = build_daily_home_payload_v2(payload)
        return DailyHomeResponse(payload=payload, payloadV2=payload_v2)

    def weekly_insights(self, install_id: str) -> WeeklyInsightsResponse:
        state = self.repository.get_state(install_id)
        insights = build_weekly_insights(state)
        return WeeklyInsightsResponse(insights=insights)

    # --- Subscription receipt audit trail -----------------------------
    #
    # The iOS client is still the authoritative source of entitlements
    # (StoreKit 2 JWS is cryptographically verified on-device). What the
    # backend stores here is an audit/receipts trail so ops, support, and
    # a future server-authoritative grant flow can reason about purchases
    # without parsing the device state. Full signature verification and
    # App Store Server API cross-reference live in a follow-up slice.

    def process_subscription_report(self, request: SubscriptionReportRequest) -> SubscriptionGrant:
        now = apple_timestamp_now()
        state = _derive_grant_state(request.expiresAt, request.revokedAt, now)
        grant = SubscriptionGrant(
            installID=request.installID,
            tier=request.tier,
            productID=request.productID,
            originalTransactionID=request.originalTransactionID,
            transactionID=request.transactionID,
            purchasedAt=request.purchasedAt,
            expiresAt=request.expiresAt,
            revokedAt=request.revokedAt,
            state=state,
            rawTransactionJWS=request.rawTransactionJWS,
            updatedAt=now,
        )
        self.repository.save_subscription_grant(request.installID, grant)
        return grant

    def get_subscription_status(self, install_id: str) -> SubscriptionStatusResponse:
        grant = self.repository.get_subscription_grant(install_id)
        return SubscriptionStatusResponse(installID=install_id, grant=grant)

    def process_subscription_lifecycle_notification(
        self, request: SubscriptionLifecycleNotificationRequest
    ) -> EmptyResponse:
        # App Store Server Notifications v2 always wrap the real payload in a
        # JWS. Until the full verification layer lands (separate slice), we
        # store nothing — we only log enough metadata to confirm Apple can
        # reach the endpoint. Re-entering this function with the same payload
        # must be idempotent by construction.
        import logging

        logging.getLogger(__name__).info(
            "appstore_notification_received length=%d",
            len(request.signedPayload),
        )
        return EmptyResponse()


def _derive_grant_state(
    expires_at: AppleTimestamp | None,
    revoked_at: AppleTimestamp | None,
    now: AppleTimestamp,
) -> SubscriptionGrantState:
    if revoked_at is not None:
        return SubscriptionGrantState.revoked
    if expires_at is None:
        # StoreKit non-subscription purchases (e.g. lifetime unlocks) arrive
        # without an expiration. Treat them as active until a future lifecycle
        # notification says otherwise.
        return SubscriptionGrantState.active
    if expires_at > now:
        return SubscriptionGrantState.active
    return SubscriptionGrantState.expired


def _product_type_for_input(input: ScanInput) -> ProductType:
    if input.productTypeHint is not None:
        return input.productTypeHint
    if input.sourceType == ScanSource.labelPhoto:
        return ProductType.food
    if input.sourceType == ScanSource.menuPhoto or input.sourceType == ScanSource.mealPhoto:
        return ProductType.food
    return ProductType.food


def _entity_name(input: ScanInput) -> str:
    if input.barcode:
        return f"Scanned Product {input.barcode[-4:]}"
    if input.sourceType == ScanSource.mealPhoto:
        return "Meal Snapshot"
    if input.sourceType == ScanSource.menuPhoto:
        return "Menu Choice"
    return "Custom Label Scan"


def _tokens(input: ScanInput) -> list[str]:
    return [token.strip().lower() for token in (input.rawText or "").split(",") if token.strip()]


def build_scan_analysis(
    input: ScanInput,
    user_context: UserContext,
    resolution: ResolverResult | None = None,
    scan_context: ScanContext | None = None,
    created_at: AppleTimestamp | None = None,
) -> ScanAnalysis:
    resolved = resolution.product if resolution is not None else None
    tokens = analysis_tokens(input, resolved)
    product_type = resolved.productType if resolved is not None else _product_type_for_input(input)
    resolved_timestamp = _timestamp(created_at)
    product = resolved or ProductCandidate(
        id=f"product-{(input.barcode or 'manual').lower()}",
        name=_entity_name(input),
        brand="WellnessLens Cloud",
        productType=product_type,
        barcode=input.barcode,
        headline="Cloud-resolved compatibility scan aligned with the structured contract.",
        ingredients=[Ingredient(name=token.title()) for token in tokens[:5]],
        claims=["Cloud analyzed", "Consumer wellness guidance"],
        tags=[],
        alternativeIDs=[],
        notes=["Generated by the production API compatibility layer."],
        lookupTokens=tokens,
    )
    confidence = confidence_for_product(product, resolution)
    product = ensure_product_resolution_semantics(
        product,
        confidence=confidence,
        identity_source=resolution.identity_source if resolution is not None else None,
        fact_sources=resolution.fact_sources if resolution is not None else (),
    )
    lens_scores = build_lens_scores(tokens, user_context, product, input.sourceType, scan_context)
    overall_score = int(sum(score.score for score in lens_scores) / max(len(lens_scores), 1))
    reasons = build_reasons(product, overall_score, input.sourceType, scan_context)
    warnings = build_warnings(product, overall_score, input.sourceType, scan_context)
    alternatives: list[AlternativeSuggestion] = []
    if overall_score < 62 and product.productType == ProductType.food:
        alternatives.append(
            AlternativeSuggestion(
                id=f"{product.id}-swap-anchor",
                productName="Steadier Swap Anchor",
                productID="swap-anchor",
                whyBetter="A cleaner swap for energy and digestion support.",
                improvedLenses=["energyMood", "gutComfort"],
            )
        )
    return ScanAnalysis(
        id=_stable_id("scan-analysis", input.sourceType.value, input.barcode or input.rawText or "manual"),
        createdAt=resolved_timestamp,
        resolvedProduct=product,
        source=input.sourceType,
        productType=product_type,
        lensScores=lens_scores,
        overallSummary=summary_for_score(overall_score, product),
        topReasons=reasons,
        warnings=warnings,
        alternatives=alternatives,
        confidence=confidence,
        disclaimer=DISCLAIMER,
    )


def build_analysis_envelope(
    input: ScanInput,
    user_context: UserContext,
    recent_scans: list[ScanEvent],
    recent_checkins: list[CheckInEvent],
    resolution: ResolverResult | None = None,
    scan_context: ScanContext | None = None,
    created_at: AppleTimestamp | None = None,
) -> AnalysisEnvelope:
    analysis = build_scan_analysis(
        input,
        user_context,
        resolution=resolution,
        scan_context=scan_context,
        created_at=created_at,
    )
    lens_map = {score.lens: score.score for score in analysis.lensScores}
    overall = int(sum(lens_map.values()) / max(len(lens_map), 1))
    verdict = AnalysisVerdict.good if overall >= 75 else AnalysisVerdict.adjust if overall >= 55 else AnalysisVerdict.avoid
    entity_type = (
        AnalysisEntityType.meal if input.sourceType == ScanSource.mealPhoto
        else AnalysisEntityType.menuItem if input.sourceType == ScanSource.menuPhoto
        else AnalysisEntityType.supplement if analysis.productType == ProductType.supplement
        else AnalysisEntityType.product
    )
    return AnalysisEnvelope(
        analysis_id=contract_analysis_id(input),
        timestamp=analysis.createdAt,
        input_type=analysis_input_type(input.sourceType),
        entity_type=entity_type,
        resolved_product=analysis.resolvedProduct,
        verdict=verdict,
        overall_score=overall,
        lens_scores=StructuredLensScores(
            skin=lens_map.get("glowSkin", 0),
            hormones=lens_map.get("hormoneBalance", 0),
            gut=lens_map.get("gutComfort", 0),
            energy=lens_map.get("energyMood", 0),
            body_comp=lens_map.get("bodyCompositionStrength", 0),
        ),
        why_today=build_why_today(analysis, recent_checkins, input.sourceType),
        green_flags=[reason.title for reason in analysis.topReasons if reason.impact == ReasonImpact.positive][:4],
        red_flags=analysis.warnings[:4],
        recommended_actions=build_recommended_actions(overall, analysis.resolvedProduct),
        swap_suggestions=[
            SwapSuggestion(
                title=item.productName,
                reason=item.whyBetter,
                priority=SwapPriority.high if overall < 50 else SwapPriority.medium,
            )
            for item in analysis.alternatives
        ],
        follow_up_prompt=follow_up_prompt_for_source(input.sourceType),
        confidence=confidence_numeric(analysis.confidence),
        medical_safety=MedicalSafety(
            is_medical_advice=False,
            disclaimer_needed=True,
            risk_level=SafetyRiskLevel.low if overall >= 70 else SafetyRiskLevel.medium,
        ),
        pattern_context=PatternContext(
            used_history=bool(recent_scans or recent_checkins),
            relevant_pattern="Recent lower-fit choices are clustering." if overall < 60 and recent_scans else None,
        ),
    )


def build_daily_home_payload(state: UserState, profile: UserProfile, active_goals: list[ActiveGoal]) -> DailyHomePayload:
    has_activity = bool(state.scan_events or state.checkin_events or state.scan_decisions)
    lifecycle = UserLifecycleState.active if has_activity else UserLifecycleState.calibrating
    primary_goal = active_goals[0] if active_goals else default_active_goal(profile.userContext.goals[0] if profile.userContext.goals else UserGoal.steadyEnergy)
    open_loops = [
        OpenLoop(
            id=_stable_id("open-loop", decision.productName),
            title=decision.productName,
            summary=decision.note,
        )
        for decision in state.scan_decisions.values()
        if decision.resolvedAt is None
    ][:2]
    recent_wins = [
        RecentWin(
            id=_stable_id("recent-win", favorite.title),
            title=favorite.title,
            summary=favorite.summary,
        )
        for favorite in list(state.favorites.values())[:2]
    ]
    body_signal = CheckInSignal(
        id=_stable_id("body-signal", "recent" if state.checkin_events else "empty"),
        title="No fresh body signal yet" if not state.checkin_events else "Recent body signal captured",
        summary="Add one signal to tighten the next recommendation." if not state.checkin_events else "Recent check-ins are feeding your next decision.",
        tone="neutral" if not state.checkin_events else "supportive",
    )
    next_action_kind = RecommendationKind.scanStaple if not state.scan_events else RecommendationKind.checkInNow
    next_action = Recommendation(
        id=f"next-action-{next_action_kind}",
        kind=next_action_kind,
        title="Scan your first real choice" if not state.scan_events else "Close the last loop",
        summary="Start with a real product, meal, or menu choice." if not state.scan_events else "Log how the last scan held up in real use.",
        cta="Open scan" if not state.scan_events else "Open check-in",
        relatedGoal=primary_goal.goal,
    )
    strategist_note = StrategistNote(
        title="Production home is active",
        summary="The backend is returning a deterministic home contract while scan, sync, and premium signals accumulate.",
    )
    return DailyHomePayload(
        state=lifecycle,
        todayFocus=TodayFocus(
            title=primary_goal.title,
            summary=primary_goal.summary,
        ),
        bodySignal=body_signal,
        nextAction=next_action,
        recommendedSwap=None,
        openLoops=open_loops,
        strategistNote=strategist_note,
        recentWins=recent_wins,
    )


def build_daily_home_payload_v2(payload: DailyHomePayload) -> DailyHomePayloadV2:
    if payload.state == UserLifecycleState.calibrating:
        emphasis = DailyHomeHeroEmphasis.onboarding
        primary_module = "firstWeekPlan"
    else:
        emphasis = DailyHomeHeroEmphasis.protectMomentum
        primary_module = "dailyBrief"
    return DailyHomePayloadV2(
        hero=DailyHomeHeroV2(
            emphasis=emphasis,
            whyNow="The backend is prioritizing the shortest path to the next meaningful signal.",
        ),
        primaryModule=primary_module,
        secondaryModules=["activeGoals", "openLoops", "recentWins"],
        deferredModules=["strategistNote"],
        suppressedModules=[],
        ctaPriority=payload.nextAction.kind,
    )


def build_weekly_insights(state: UserState) -> list[WeeklyInsight]:
    if not state.scan_events:
        return [
            WeeklyInsight(
                id=_stable_id("weekly-insight", "start-with-scans"),
                title="Start with a few scans",
                summary="Your weekly story sharpens once Home, scans, and check-ins have signal to work with.",
                callToAction="Scan three real choices this week.",
            )
        ]
    loop_count = len([decision for decision in state.scan_decisions.values() if decision.resolvedAt is None])
    return [
        WeeklyInsight(
            id=_stable_id("weekly-insight", "backend-sync-live"),
            title="Your backend sync is live",
            summary=f"{len(state.scan_events)} structured scans, {len(state.checkin_events)} check-in events, and {loop_count} open loops are now available for weekly synthesis.",
            callToAction="Use one more check-in to tighten the next recommendation.",
        )
    ]


def analysis_tokens(input: ScanInput, product: ProductCandidate | None) -> list[str]:
    parts = [*(input.rawText or "").split(","), *(product.lookupTokens if product else [])]
    return [token.strip().lower() for token in parts if token and token.strip()]

CORE_FOOD_TAGS: set[IngredientTag] = {
    IngredientTag.proteinDense,
    IngredientTag.fiberSupport,
    IngredientTag.sugarSpike,
    IngredientTag.stimulant,
    IngredientTag.ultraProcessed,
}
PROBIOTIC_TOKENS = ("probiotic", "cultures", "lactobacillus", "bifidobacterium", "fermented")
PROTEIN_TOKENS = ("protein", "whey", "greek yogurt", "milk protein", "egg white")
FIBER_TOKENS = ("fiber", "chia", "flax", "oats", "beans", "greens")
SUGAR_TOKENS = ("sugar", "syrup", "candy", "sweetened", "cane sugar", "fructose")
STIMULANT_TOKENS = ("caffeine", "coffee", "energy drink", "pre workout", "pre-workout", "guarana", "matcha")
ULTRA_PROCESSED_TOKENS = ("natural flavors", "flavorings", "energy drink", "soda", "emulsifier", "maltodextrin")


@dataclass(frozen=True)
class DerivedFeatures:
    effective_tags: set[IngredientTag]
    protein_g_per_100g: float | None
    fiber_g_per_100g: float | None
    sugars_g_per_100g: float | None
    caffeine_mg_per_100g: float | None
    nova_group: int | None
    mexico_warning_labels: set[MexicoWarningLabel]
    mexico_contains_caffeine_warning: bool
    mexico_contains_sweetener_warning: bool
    conservative_inferred_mode: bool

    def contains(self, tag: IngredientTag) -> bool:
        return tag in self.effective_tags

    @property
    def has_mexico_signal(self) -> bool:
        return bool(
            self.mexico_warning_labels
            or self.mexico_contains_caffeine_warning
            or self.mexico_contains_sweetener_warning
        )


def build_lens_scores(
    tokens: list[str],
    user_context: UserContext,
    product: ProductCandidate,
    source: ScanSource,
    scan_context: ScanContext | None,
) -> list[LensScore]:
    features = derive_features(product, source)
    scores: list[LensScore] = []

    for lens in WellnessLensKind:
        score = 60
        positive_hits = 0
        caution_hits = 0

        for tag in features.effective_tags:
            delta = adjustment_for(tag, lens)
            score += delta
            if delta > 0:
                positive_hits += 1
            if delta < 0:
                caution_hits += 1

        score += user_context_adjustment(lens, features, user_context)
        score += scan_context_adjustment(lens, features, scan_context)
        score = max(15, min(95, score))

        if score >= 80:
            summary = "Strong fit"
        elif score >= 65:
            summary = "Solid fit"
        elif score >= 50:
            summary = "Mixed fit"
        else:
            summary = "Friction likely" if caution_hits > positive_hits else "Needs context"

        scores.append(LensScore(lens=lens, score=score, summary=summary))

    return scores


def derive_features(product: ProductCandidate, source: ScanSource) -> DerivedFeatures:
    conservative_inferred_mode = should_use_conservative_inference(product, source)
    snapshot = None if conservative_inferred_mode else (product.resolution.nutritionSnapshot if product.resolution else None)
    joined_text = searchable_text(product)
    mexico_signals = product.mexicoNutritionSignals
    mexico_warning_labels = set(mexico_signals.warningLabels if mexico_signals else [])
    effective_tags = {
        tag for tag in product.tags
        if product.productType != ProductType.food or tag not in CORE_FOOD_TAGS
    }

    if product.productType != ProductType.food:
        return DerivedFeatures(
            effective_tags=effective_tags.union(set(product.tags)),
            protein_g_per_100g=snapshot.proteinGPer100g if snapshot else None,
            fiber_g_per_100g=snapshot.fiberGPer100g if snapshot else None,
            sugars_g_per_100g=snapshot.sugarsGPer100g if snapshot else None,
            caffeine_mg_per_100g=snapshot.caffeineMgPer100g if snapshot else None,
            nova_group=snapshot.novaGroup if snapshot else None,
            mexico_warning_labels=mexico_warning_labels,
            mexico_contains_caffeine_warning=bool(mexico_signals and mexico_signals.containsCaffeineWarning),
            mexico_contains_sweetener_warning=bool(mexico_signals and mexico_signals.containsSweetenerWarning),
            conservative_inferred_mode=conservative_inferred_mode,
        )

    if MexicoWarningLabel.excessSugars in mexico_warning_labels:
        effective_tags.add(IngredientTag.sugarSpike)
    if MexicoWarningLabel.excessCalories in mexico_warning_labels:
        effective_tags.add(IngredientTag.ultraProcessed)
    if mexico_signals and mexico_signals.containsCaffeineWarning:
        effective_tags.add(IngredientTag.stimulant)
    if mexico_signals and mexico_signals.containsSweetenerWarning:
        effective_tags.add(IngredientTag.sugarAlcohol)

    if has_protein_support(snapshot, product, joined_text):
        effective_tags.add(IngredientTag.proteinDense)
    if has_fiber_support(snapshot, product, joined_text):
        effective_tags.add(IngredientTag.fiberSupport)
    if has_sugar_spike(snapshot, product, joined_text):
        effective_tags.add(IngredientTag.sugarSpike)
    if has_stimulant_load(snapshot, product, joined_text):
        effective_tags.add(IngredientTag.stimulant)
    if has_ultra_processed_signal(snapshot, product, joined_text):
        effective_tags.add(IngredientTag.ultraProcessed)
    if product.tags and IngredientTag.probiotic in product.tags or contains_any(PROBIOTIC_TOKENS, joined_text):
        effective_tags.add(IngredientTag.probiotic)
    if product.tags and IngredientTag.sugarAlcohol in product.tags or contains_any(("xylitol", "erythritol", "sorbitol"), joined_text):
        effective_tags.add(IngredientTag.sugarAlcohol)

    return DerivedFeatures(
        effective_tags=effective_tags,
        protein_g_per_100g=snapshot.proteinGPer100g if snapshot else None,
        fiber_g_per_100g=snapshot.fiberGPer100g if snapshot else None,
        sugars_g_per_100g=snapshot.sugarsGPer100g if snapshot else None,
        caffeine_mg_per_100g=snapshot.caffeineMgPer100g if snapshot else None,
        nova_group=snapshot.novaGroup if snapshot else None,
        mexico_warning_labels=mexico_warning_labels,
        mexico_contains_caffeine_warning=bool(mexico_signals and mexico_signals.containsCaffeineWarning),
        mexico_contains_sweetener_warning=bool(mexico_signals and mexico_signals.containsSweetenerWarning),
        conservative_inferred_mode=conservative_inferred_mode,
    )


def adjustment_for(tag: IngredientTag, lens: WellnessLensKind) -> int:
    match (tag, lens):
        case (IngredientTag.proteinDense, WellnessLensKind.energyMood):
            return 8
        case (IngredientTag.proteinDense, WellnessLensKind.bodyCompositionStrength):
            return 12
        case (IngredientTag.proteinDense, WellnessLensKind.hormoneBalance):
            return 6
        case (IngredientTag.probiotic, WellnessLensKind.gutComfort):
            return 12
        case (IngredientTag.probiotic, WellnessLensKind.energyMood):
            return 3
        case (IngredientTag.fiberSupport, WellnessLensKind.gutComfort):
            return 10
        case (IngredientTag.fiberSupport, WellnessLensKind.energyMood):
            return 6
        case (IngredientTag.fiberSupport, WellnessLensKind.hormoneBalance):
            return 8
        case (IngredientTag.fiberSupport, WellnessLensKind.bodyCompositionStrength):
            return 5
        case (IngredientTag.sugarSpike, WellnessLensKind.energyMood):
            return -10
        case (IngredientTag.sugarSpike, WellnessLensKind.hormoneBalance):
            return -10
        case (IngredientTag.sugarSpike, WellnessLensKind.glowSkin):
            return -8
        case (IngredientTag.sugarSpike, WellnessLensKind.bodyCompositionStrength):
            return -6
        case (IngredientTag.sugarAlcohol, WellnessLensKind.gutComfort):
            return -10
        case (IngredientTag.stimulant, WellnessLensKind.energyMood):
            return -7
        case (IngredientTag.stimulant, WellnessLensKind.hormoneBalance):
            return -6
        case (IngredientTag.ultraProcessed, WellnessLensKind.hormoneBalance):
            return -8
        case (IngredientTag.ultraProcessed, WellnessLensKind.gutComfort):
            return -6
        case (IngredientTag.ultraProcessed, WellnessLensKind.energyMood):
            return -6
        case (IngredientTag.ultraProcessed, WellnessLensKind.glowSkin):
            return -6
        case (IngredientTag.collagen, WellnessLensKind.glowSkin):
            return 6
        case (IngredientTag.collagen, WellnessLensKind.bodyCompositionStrength):
            return 5
        case (IngredientTag.omegaSupport, WellnessLensKind.hormoneBalance):
            return 8
        case (IngredientTag.omegaSupport, WellnessLensKind.glowSkin):
            return 4
        case (IngredientTag.niacinamide, WellnessLensKind.glowSkin):
            return 12
        case (IngredientTag.peptide, WellnessLensKind.glowSkin):
            return 8
        case (IngredientTag.hyaluronicAcid, WellnessLensKind.glowSkin):
            return 10
        case (IngredientTag.retinoid, WellnessLensKind.glowSkin):
            return 12
        case (IngredientTag.fragrance, WellnessLensKind.glowSkin):
            return -12
        case (IngredientTag.alcoholDrying, WellnessLensKind.glowSkin):
            return -7
        case (IngredientTag.harshSurfactants, WellnessLensKind.glowSkin):
            return -8
        case (IngredientTag.mineralSPF, WellnessLensKind.glowSkin):
            return 10
        case (IngredientTag.antioxidantBlend, WellnessLensKind.glowSkin):
            return 10
        case (IngredientTag.antioxidantBlend, WellnessLensKind.energyMood):
            return 4
        case (IngredientTag.emulsifierHeavy, WellnessLensKind.gutComfort):
            return -7
        case _:
            return 0


def user_context_adjustment(lens: WellnessLensKind, features: DerivedFeatures, user_context: UserContext) -> int:
    adjustment = 0

    for goal in user_context.goals:
        match (goal, lens):
            case (UserGoal.clearSkin, WellnessLensKind.glowSkin) if features.contains(IngredientTag.niacinamide) or features.contains(IngredientTag.retinoid):
                adjustment += 6
            case (UserGoal.steadyEnergy, WellnessLensKind.energyMood) if features.contains(IngredientTag.proteinDense) or features.contains(IngredientTag.fiberSupport):
                adjustment += 5
            case (UserGoal.steadyEnergy, WellnessLensKind.energyMood) if features.contains(IngredientTag.sugarSpike):
                adjustment -= 4
            case (UserGoal.gutCalm, WellnessLensKind.gutComfort) if features.contains(IngredientTag.probiotic) or features.contains(IngredientTag.fiberSupport):
                adjustment += 6
            case (UserGoal.deBloat, WellnessLensKind.gutComfort) if features.contains(IngredientTag.sugarAlcohol):
                adjustment -= 5
            case (UserGoal.hormoneSupport, WellnessLensKind.hormoneBalance) if features.contains(IngredientTag.fiberSupport) or features.contains(IngredientTag.omegaSupport):
                adjustment += 5
            case (UserGoal.leanStrength, WellnessLensKind.bodyCompositionStrength) if features.contains(IngredientTag.proteinDense):
                adjustment += 6
            case _:
                pass

    for sensitivity in user_context.sensitivities:
        match sensitivity:
            case "fragranceSensitive" if lens == WellnessLensKind.glowSkin and features.contains(IngredientTag.fragrance):
                adjustment -= 8
            case "caffeineSensitive" if lens == WellnessLensKind.energyMood and features.contains(IngredientTag.stimulant):
                adjustment -= 6
            case "sugarSensitive" if lens in {WellnessLensKind.energyMood, WellnessLensKind.hormoneBalance} and features.contains(IngredientTag.sugarSpike):
                adjustment -= 6
            case "acneProne" if lens == WellnessLensKind.glowSkin and (features.contains(IngredientTag.sugarSpike) or features.contains(IngredientTag.fragrance)):
                adjustment -= 5
            case "drySkin" if lens == WellnessLensKind.glowSkin and features.contains(IngredientTag.alcoholDrying):
                adjustment -= 5
            case "reactiveDigestion" if lens == WellnessLensKind.gutComfort and (features.contains(IngredientTag.sugarAlcohol) or features.contains(IngredientTag.emulsifierHeavy)):
                adjustment -= 6
            case _:
                pass

    if user_context.lifeStage == "highStress" and lens == WellnessLensKind.energyMood and features.contains(IngredientTag.stimulant):
        adjustment -= 4

    return adjustment


def scan_context_adjustment(
    lens: WellnessLensKind,
    features: DerivedFeatures,
    scan_context: ScanContext | None,
) -> int:
    if scan_context is None:
        return 0

    adjustment = 0

    if scan_context.isInAnabolicWindow and features.contains(IngredientTag.proteinDense):
        if lens == WellnessLensKind.bodyCompositionStrength:
            adjustment += 6
        elif lens == WellnessLensKind.energyMood:
            adjustment += 4

    if has_short_sleep(scan_context):
        if features.contains(IngredientTag.stimulant):
            if lens == WellnessLensKind.energyMood:
                adjustment -= 6
            elif lens == WellnessLensKind.hormoneBalance:
                adjustment -= 3
        if features.contains(IngredientTag.sugarSpike):
            if lens == WellnessLensKind.energyMood:
                adjustment -= 4
            elif lens == WellnessLensKind.hormoneBalance:
                adjustment -= 3
        if (features.contains(IngredientTag.proteinDense) or features.contains(IngredientTag.fiberSupport)) and lens == WellnessLensKind.energyMood:
            adjustment += 2

    if has_recovery_strain(scan_context):
        if features.contains(IngredientTag.proteinDense) and lens == WellnessLensKind.bodyCompositionStrength:
            adjustment += 4
        if features.contains(IngredientTag.ultraProcessed) and lens in {WellnessLensKind.energyMood, WellnessLensKind.bodyCompositionStrength}:
            adjustment -= 5
        if features.contains(IngredientTag.stimulant) and lens == WellnessLensKind.energyMood:
            adjustment -= 4

    if scan_context.cyclePhase == "luteal":
        if features.contains(IngredientTag.sugarSpike):
            if lens == WellnessLensKind.energyMood:
                adjustment -= 4
            elif lens == WellnessLensKind.hormoneBalance:
                adjustment -= 5
        if features.contains(IngredientTag.stimulant):
            if lens == WellnessLensKind.energyMood:
                adjustment -= 4
            elif lens == WellnessLensKind.hormoneBalance:
                adjustment -= 3
        if features.contains(IngredientTag.fiberSupport) and lens == WellnessLensKind.hormoneBalance:
            adjustment += 2
    elif scan_context.cyclePhase == "menstrual" and features.contains(IngredientTag.proteinDense):
        if lens == WellnessLensKind.bodyCompositionStrength:
            adjustment += 3
        elif lens == WellnessLensKind.energyMood:
            adjustment += 2

    return adjustment


def build_reasons(
    product: ProductCandidate,
    overall_score: int,
    source: ScanSource,
    scan_context: ScanContext | None,
) -> list[ReasonItem]:
    features = derive_features(product, source)
    reasons: list[ReasonItem] = []

    if product.resolution is not None:
        directional = product_has_resolution_semantic(product, ProductResolutionSemantic.directional)
        reasons.append(
            ReasonItem(
                id=_stable_id("reason", "resolution-signal"),
                title="Resolution signal",
                detail=resolution_signal_detail(product),
                impact=ReasonImpact.positive if not directional else ReasonImpact.caution,
            )
        )

    if features.contains(IngredientTag.proteinDense):
        reasons.append(
            ReasonItem(
                id=_stable_id("reason", "steadier-anchor"),
                title="Protein support",
                detail=f"The strongest food signal here is {rounded_metric(features.protein_g_per_100g, 'protein')} which usually supports steadier energy and stronger satiety.",
                impact=ReasonImpact.positive,
            )
        )
    if features.contains(IngredientTag.fiberSupport):
        reasons.append(
            ReasonItem(
                id=_stable_id("reason", "fiber-support"),
                title="Fiber support",
                detail=f"{rounded_metric(features.fiber_g_per_100g, 'fiber').capitalize()} helps this read look calmer for digestion and steadier for energy.",
                impact=ReasonImpact.positive,
            )
        )
    if features.has_mexico_signal:
        signal_titles = mexico_signal_titles(product.mexicoNutritionSignals)
        reasons.append(
            ReasonItem(
                id=_stable_id("reason", "mexico-label-signal"),
                title="Mexico label signal",
                detail=(
                    "Etiqueta mexicana detectada: "
                    + ", ".join(signal_titles[:3])
                    + ". La lectura lo usa como contexto de wellness, no como diagnostico."
                ),
                impact=ReasonImpact.caution,
            )
        )
    if scan_context and scan_context.isInAnabolicWindow and features.contains(IngredientTag.proteinDense):
        reasons.append(
            ReasonItem(
                id=_stable_id("reason", "recovery-window"),
                title="Recovery window support",
                detail="You trained recently, so protein support matters more for recovery and body-composition reads right now.",
                impact=ReasonImpact.positive,
            )
        )
    if features.contains(IngredientTag.sugarSpike) or features.contains(IngredientTag.stimulant) or features.contains(IngredientTag.ultraProcessed):
        load_parts = [
            "higher sugar load" if features.contains(IngredientTag.sugarSpike) else None,
            "meaningful caffeine" if features.contains(IngredientTag.stimulant) else None,
            "heavier processing" if features.contains(IngredientTag.ultraProcessed) else None,
        ]
        reasons.append(
            ReasonItem(
                id=_stable_id("reason", "load-to-watch"),
                title="Load to watch",
                detail=f"The softer part of this read is the {' + '.join(part for part in load_parts if part)}, which can work against calmer energy or hormone-friendly routines.",
                impact=ReasonImpact.caution,
            )
        )
    if scan_context and has_short_sleep(scan_context) and (features.contains(IngredientTag.stimulant) or features.contains(IngredientTag.sugarSpike)):
        reasons.append(
            ReasonItem(
                id=_stable_id("reason", "short-sleep-context"),
                title="Short sleep context",
                detail="With shorter sleep, high sugar or caffeine tends to feel less steady than the product alone suggests.",
                impact=ReasonImpact.caution,
            )
        )
    if overall_score < 60:
        reasons.append(
            ReasonItem(
                id=_stable_id("reason", "softer-fit-today"),
                title="Softer fit today",
                detail="This input looks directionally noisier for your current goals.",
                impact=ReasonImpact.caution,
            )
        )
    return reasons[:3]


def build_warnings(
    product: ProductCandidate,
    overall_score: int,
    source: ScanSource,
    scan_context: ScanContext | None,
) -> list[str]:
    features = derive_features(product, source)
    warnings: list[str] = []
    if product_has_resolution_semantic(product, ProductResolutionSemantic.directional):
        warnings.append("No exact packaged-food match yet. Treat this as directional guidance until you rescan a clearer barcode or label.")
    if features.contains(IngredientTag.sugarSpike):
        warnings.append("Higher sugar or heavier-processing cues may soften the fit.")
    if features.has_mexico_signal:
        titles = mexico_signal_titles(product.mexicoNutritionSignals)
        warnings.append(f"Senales de etiqueta Mexico detectadas: {', '.join(titles[:3])}. Conviene leer porcion y frecuencia.")
    if scan_context and has_short_sleep(scan_context) and features.contains(IngredientTag.stimulant):
        warnings.append("Short sleep raises the bar for caffeine-forward products to feel steady.")
    if scan_context and scan_context.cyclePhase == "luteal" and features.contains(IngredientTag.sugarSpike):
        warnings.append("In a luteal-phase context, higher sugar can feel less stable than the label alone suggests.")
    if scan_context and has_recovery_strain(scan_context) and features.contains(IngredientTag.ultraProcessed):
        warnings.append("Recovery looks more taxed today, so heavier processing may soften the fit further.")
    if overall_score < 55:
        warnings.append("Use this as directional guidance and verify with a follow-up check-in.")
    if not warnings:
        warnings.append("Consumer wellness guidance only.")
    return warnings[:3]


def summary_for_score(score: int, product: ProductCandidate) -> str:
    if product_has_resolution_semantic(product, ProductResolutionSemantic.directional):
        return "Directional read only. Use the result as a slower second look, not a final product-level truth."
    if score >= 80:
        return "Strong fit for today with calmer energy and digestion support."
    if score >= 65:
        return "Solid fit with a few tradeoffs worth watching."
    if score >= 50:
        return "Mixed fit. Worth a slower second look before repeating."
    return "Softer fit right now. Consider a cleaner anchor or swap."


def score_summary(score: int) -> str:
    if score >= 80:
        return "Strong fit"
    if score >= 65:
        return "Solid fit"
    if score >= 50:
        return "Mixed fit"
    return "Friction likely"


def should_use_conservative_inference(product: ProductCandidate, source: ScanSource) -> bool:
    if product_has_resolution_semantic(product, ProductResolutionSemantic.directional) or product_has_resolution_semantic(product, ProductResolutionSemantic.provisional):
        return True
    if source in {ScanSource.mealPhoto, ScanSource.menuPhoto}:
        return not product_has_resolution_semantic(product, ProductResolutionSemantic.canonical)
    return False


def searchable_text(product: ProductCandidate) -> str:
    return " ".join(
        [*product.claims, *product.lookupTokens, *[ingredient.name for ingredient in product.ingredients], product.headline, product.name, product.brand]
    ).lower()


def contains_any(needles: tuple[str, ...] | list[str], haystack: str) -> bool:
    return any(needle in haystack for needle in needles)


def has_protein_support(snapshot: Any, product: ProductCandidate, joined_text: str) -> bool:
    if snapshot and snapshot.proteinGPer100g is not None and snapshot.proteinGPer100g >= 10:
        return True
    return IngredientTag.proteinDense in product.tags or contains_any(PROTEIN_TOKENS, joined_text)


def has_fiber_support(snapshot: Any, product: ProductCandidate, joined_text: str) -> bool:
    if snapshot and snapshot.fiberGPer100g is not None and snapshot.fiberGPer100g >= 5:
        return True
    return IngredientTag.fiberSupport in product.tags or contains_any(FIBER_TOKENS, joined_text)


def has_sugar_spike(snapshot: Any, product: ProductCandidate, joined_text: str) -> bool:
    if snapshot and snapshot.sugarsGPer100g is not None and snapshot.sugarsGPer100g >= 12:
        return True
    return IngredientTag.sugarSpike in product.tags or contains_any(SUGAR_TOKENS, joined_text)


def has_stimulant_load(snapshot: Any, product: ProductCandidate, joined_text: str) -> bool:
    if snapshot and snapshot.caffeineMgPer100g is not None and snapshot.caffeineMgPer100g >= 45:
        return True
    return IngredientTag.stimulant in product.tags or contains_any(STIMULANT_TOKENS, joined_text)


def has_ultra_processed_signal(snapshot: Any, product: ProductCandidate, joined_text: str) -> bool:
    if snapshot and snapshot.novaGroup is not None and snapshot.novaGroup >= 4:
        return True
    return IngredientTag.ultraProcessed in product.tags or contains_any(ULTRA_PROCESSED_TOKENS, joined_text)


def has_short_sleep(scan_context: ScanContext) -> bool:
    return scan_context.sleepHours is not None and scan_context.sleepHours < 6


def has_recovery_strain(scan_context: ScanContext) -> bool:
    hrv_strained = scan_context.hrvMilliseconds is not None and scan_context.hrvMilliseconds < 32
    heart_rate_elevated = scan_context.restingHeartRate is not None and scan_context.restingHeartRate > 68
    temperature_elevated = scan_context.wristTemperatureDeltaCelsius is not None and scan_context.wristTemperatureDeltaCelsius >= 0.3
    return hrv_strained or heart_rate_elevated or temperature_elevated


def rounded_metric(value: float | None, fallback: str) -> str:
    if value is None:
        return fallback
    return f"{round(value)}g {fallback}/100g"


def confidence_for_product(product: ProductCandidate, resolution: ResolverResult | None) -> ConfidenceLevel:
    if resolution is not None:
        return resolution.confidence
    if product.resolution is None:
        return ConfidenceLevel.low
    if product.resolution.confidence >= 0.84:
        return ConfidenceLevel.high
    if product.resolution.confidence >= 0.58:
        return ConfidenceLevel.medium
    return ConfidenceLevel.low


def confidence_numeric(confidence: ConfidenceLevel) -> float:
    return {
        ConfidenceLevel.high: 0.88,
        ConfidenceLevel.medium: 0.72,
        ConfidenceLevel.low: 0.46,
    }[confidence]


def analysis_input_type(source: ScanSource) -> AnalysisInputType:
    mapping = {
        ScanSource.liveBarcode: AnalysisInputType.barcode,
        ScanSource.manualBarcode: AnalysisInputType.barcode,
        ScanSource.labelPhoto: AnalysisInputType.labelPhoto,
        ScanSource.mealPhoto: AnalysisInputType.mealPhoto,
        ScanSource.menuPhoto: AnalysisInputType.menuPhoto,
        ScanSource.manualLabel: AnalysisInputType.manual,
    }
    return mapping[source]


def build_why_today(analysis: ScanAnalysis, recent_checkins: list[CheckInEvent], source: ScanSource) -> list[str]:
    overall = int(sum(score.score for score in analysis.lensScores) / max(len(analysis.lensScores), 1))
    reasons = [
        "This read is being structured server-side to match the app contract without removing the local fallback."
    ]
    if analysis.resolvedProduct.resolution is not None:
        reasons.append(why_today_resolution_detail(analysis.resolvedProduct))
    if recent_checkins:
        reasons.append("Recent body-signal context is available and can shape the next decision.")
    if source == ScanSource.menuPhoto:
        reasons.append("Restaurant choices benefit from slower, cleaner anchors.")
    elif source == ScanSource.mealPhoto:
        reasons.append("Meal snapshots work best as directional guidance, not exact nutrition diagnosis.")
    elif overall < 60:
        reasons.append("This choice looks softer than your current momentum needs.")
    else:
        reasons.append("This choice looks supportive enough to keep momentum intact.")
    return reasons[:3]


def build_recommended_actions(overall: int, product: ProductCandidate) -> list[str]:
    if product_has_resolution_semantic(product, ProductResolutionSemantic.directional):
        return [
            "Rescan a clearer barcode or tighter label before turning this into a repeatable default.",
            "If you try it anyway, add a follow-up check-in so the next read uses real signal.",
        ]
    if overall >= 75:
        return [
            "Keep this as a repeatable default if real-life feedback agrees.",
            "Log a check-in later so the next recommendation stays grounded.",
        ]
    if overall >= 55:
        return [
            "Use this as a directional read and compare it with one cleaner option.",
            "Avoid turning this into a routine default until you close the feedback loop.",
        ]
    return [
        "Look for a calmer, simpler swap before repeating this choice.",
        "Use a follow-up check-in if you try it anyway.",
        "Ask the strategist for the single safest next move.",
    ]


def resolution_signal_detail(product: ProductCandidate) -> str:
    resolution = product.resolution
    if resolution is None:
        return "The resolver did not contribute a stable product record."
    if product_has_resolution_semantic(product, ProductResolutionSemantic.directional):
        return "No exact packaged-food match yet. The scan is staying directional instead of inventing certainty."

    return {
        ProductResolutionSource.openFoodFacts: "Exact packaged-food match from Open Food Facts.",
        ProductResolutionSource.usdaFoodDataCentral: "Matched against USDA FoodData Central for nutrient-backed food facts.",
        ProductResolutionSource.nihDSLD: "Matched against NIH DSLD for provider-backed supplement facts.",
        ProductResolutionSource.cosing: "Matched against CosIng for ingredient-backed cosmetic facts.",
        ProductResolutionSource.localCatalog: "Matched against the local WellnessLens catalog for a stable product record.",
        ProductResolutionSource.userProvided: "Matched against user-provided product details.",
        ProductResolutionSource.userEdited: "Matched against a user-corrected product record.",
        ProductResolutionSource.agentInferred: "Matched against a deterministic inferred product record.",
    }.get(resolution.source, "Matched against a stable resolved product record.")


def why_today_resolution_detail(product: ProductCandidate) -> str:
    resolution = product.resolution
    if resolution is None:
        return "Product identity is not backed by a stable resolver record yet."
    if product_has_resolution_semantic(product, ProductResolutionSemantic.directional):
        return "Product identity is still directional because the resolver did not find a confident packaged-food match."

    return {
        ProductResolutionSource.openFoodFacts: "Product identity came from Open Food Facts.",
        ProductResolutionSource.usdaFoodDataCentral: "Product facts came from USDA FoodData Central.",
        ProductResolutionSource.nihDSLD: "Product identity came from NIH DSLD.",
        ProductResolutionSource.cosing: "Product facts came from CosIng.",
        ProductResolutionSource.localCatalog: "Product identity came from the local WellnessLens catalog.",
        ProductResolutionSource.userProvided: "Product identity came from user-provided details.",
        ProductResolutionSource.userEdited: "Product identity came from a manual correction.",
        ProductResolutionSource.agentInferred: "Product identity came from a deterministic inferred record.",
    }.get(resolution.source, "Product identity came from a stable resolver record.")


def follow_up_prompt_for_source(source: ScanSource) -> str:
    if source == ScanSource.menuPhoto:
        return "Did the menu choice actually feel as supportive as the read suggested?"
    if source == ScanSource.mealPhoto:
        return "Did this meal hold energy and digestion where you wanted them?"
    return "Did this match how the choice felt in real use?"


def contract_analysis_id(input: ScanInput) -> str:
    source = input.sourceType.value
    suffix = (input.barcode or input.rawText or "manual")[:24].replace(" ", "-")
    return f"analysis-{source}-{suffix}"


def default_active_goal(goal: UserGoal) -> ActiveGoal:
    return ActiveGoal(
        id=_stable_id("goal", goal.value),
        goal=goal,
        title="Steadier energy",
        summary="Protect a calmer first decision so the rest of the day feels easier to steer.",
        status=GoalStatus.active,
        focusMetric="Consistency",
        currentSignalSummary="Build signal through scans and check-ins.",
        milestone=GoalMilestone(
            id=_stable_id("milestone", goal.value),
            title="Close one real loop",
            detail="Complete one scan and one follow-up check-in.",
            progressHint="The next signal should come from real usage, not theory.",
        ),
    )


def starter_profile(created_at: AppleTimestamp | None = None) -> UserProfile:
    return UserProfile(
        userContext=UserContext(
            goals=["clearSkin", "steadyEnergy", "gutCalm"],
            sensitivities=["fragranceSensitive"],
            dietStyle="flexitarian",
            skinConcerns=["blemishes", "dryness"],
            lifeStage="everyDay",
            optInCycleAware=False,
        ),
        frictions=["energyCrash", "bloating"],
        guidanceStyle="calmAndDirect",
        eatingRhythm="flexible",
        supplementStyle="simple",
        memoryEnabled=True,
        ageRange="30-39",
        restaurantFrequency="balanced",
        nutritionPriorities=["energy", "digestion", "skin"],
        consentFlags={
            "aiProcessing": True,
            "analytics": False,
            "notifications": False,
            "healthDataProcessing": True,
        },
        createdAt=_timestamp(created_at),
    )


def starter_home_request(
    install_id: str = "install-dev",
    created_at: AppleTimestamp | None = None,
) -> DailyHomeRequest:
    profile = starter_profile(created_at=created_at)
    return DailyHomeRequest(
        profile=profile,
        activeGoals=[default_active_goal(profile.userContext.goals[1])],
        installID=install_id,
    )


def starter_memory_item(created_at: AppleTimestamp | None = None) -> MemoryItem:
    resolved_timestamp = _timestamp(created_at)
    return MemoryItem(
        id=_stable_id("memory-item", "protein-forward-breakfast"),
        kind=MemoryItemKind.staple,
        title="Protein-forward breakfast",
        summary="A stronger first anchor is helping steady the rest of the day.",
        relatedProductID="breakfast-anchor",
        relatedProductName="Balanced Protein Yogurt",
        createdAt=resolved_timestamp,
        lastReferencedAt=resolved_timestamp,
    )


def starter_scan_decision(created_at: AppleTimestamp | None = None) -> ScanDecision:
    return ScanDecision(
        id=_stable_id("scan-decision", "balanced-protein-yogurt"),
        createdAt=_timestamp(created_at),
        productID="balanced-protein-yogurt",
        productName="Balanced Protein Yogurt",
        kind=ScanDecisionKind.saveToRoutine,
        note="Save as an easy repeat anchor.",
        relatedGoal=UserGoal.steadyEnergy,
    )


def starter_checkin_event(created_at: AppleTimestamp | None = None) -> CheckInEvent:
    resolved_timestamp = _timestamp(created_at)
    checkin = CheckInEntry(
        id=_stable_id("checkin-entry", "demo"),
        createdAt=resolved_timestamp,
        energy=4,
        skin=3,
        bloatingRelief=4,
        cravingControl=4,
        mood=4,
        note="Felt steadier after a calmer breakfast choice.",
    )
    return CheckInEvent(
        checkin_id=_stable_id("checkin-event", "demo"),
        timestamp=resolved_timestamp,
        local_profile_id="local-profile-dev",
        linked_scan_ids=[],
        energy=4,
        bloating=1,
        mood=4,
        cravings=2,
        skin=3,
        satiety=4,
        notes=checkin.note,
        read_helpful=True,
        legacy_entry=checkin,
    )


def starter_favorite_item(created_at: AppleTimestamp | None = None) -> FavoriteItem:
    return FavoriteItem(
        favorite_id=_stable_id("favorite-item", "demo"),
        scan_event_id=_stable_id("scan-event", "demo"),
        related_product_id="product-manual",
        created_at=_timestamp(created_at),
        title="Balanced Protein Yogurt",
        summary="Strong fit for calmer energy and digestion support.",
    )


def starter_history_sync_request() -> tuple[HistorySyncRequest, AnalysisEnvelope]:
    profile = starter_profile(created_at=FIXTURE_BASE_TIMESTAMP)
    scan_event_id = _stable_id("scan-event", "demo")
    scan_input = ScanInput(
        sourceType=ScanSource.manualLabel,
        rawText="protein, fiber, chia, blueberries",
        locale="en_US",
    )
    legacy = build_scan_analysis(scan_input, profile.userContext, created_at=FIXTURE_BASE_TIMESTAMP + 60)
    analysis = build_analysis_envelope(scan_input, profile.userContext, [], [], created_at=FIXTURE_BASE_TIMESTAMP + 60)
    event = ScanEvent(
        scan_id=scan_event_id,
        timestamp=FIXTURE_BASE_TIMESTAMP + 60,
        local_profile_id="local-profile-dev",
        input_type="manual",
        normalized_payload={
            "source": "manual",
            "entityName": legacy.resolvedProduct.name,
            "brand": legacy.resolvedProduct.brand,
            "productType": legacy.productType,
            "ingredients": [ingredient.name for ingredient in legacy.resolvedProduct.ingredients],
            "claims": legacy.resolvedProduct.claims,
            "extractedText": scan_input.rawText,
            "inferredTags": [],
        },
        analysis=analysis,
        legacy_analysis=legacy,
        source_agents=["BackendCompatibilityShim"],
        latency_ms=120,
    )
    return (
        HistorySyncRequest(
            installID="install-dev",
            scans=[event],
            checkIns=[starter_checkin_event(created_at=FIXTURE_BASE_TIMESTAMP + 120)],
            favorites=[starter_favorite_item(created_at=FIXTURE_BASE_TIMESTAMP + 180)],
            memoryItems=[starter_memory_item(created_at=FIXTURE_BASE_TIMESTAMP + 240)],
            scanDecisions=[starter_scan_decision(created_at=FIXTURE_BASE_TIMESTAMP + 300)],
        ),
        analysis,
    )


def fixture_models() -> dict[str, dict]:
    home_request = starter_home_request(created_at=FIXTURE_BASE_TIMESTAMP)
    sync_request, analysis = starter_history_sync_request()
    daily_home = build_daily_home_payload(
        state=UserState(),
        profile=home_request.profile,
        active_goals=home_request.activeGoals,
    )
    daily_home_response = DailyHomeResponse(
        payload=daily_home,
        payloadV2=build_daily_home_payload_v2(daily_home),
    )
    return {
        "analysis_envelope.json": fixture_payload(analysis),
        "daily_home_response.json": fixture_payload(daily_home_response),
        "user_profile.json": fixture_payload(home_request.profile),
        "memory_item.json": fixture_payload(starter_memory_item(created_at=FIXTURE_BASE_TIMESTAMP + 240)),
        "scan_decision.json": fixture_payload(starter_scan_decision(created_at=FIXTURE_BASE_TIMESTAMP + 300)),
        "history_sync_request.json": fixture_payload(sync_request),
    }
