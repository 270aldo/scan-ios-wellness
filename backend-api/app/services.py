from __future__ import annotations

from dataclasses import dataclass
from uuid import NAMESPACE_URL, uuid5

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
    Ingredient,
    LensScore,
    MedicalSafety,
    MemoryItem,
    MemoryItemKind,
    OpenLoop,
    PatternContext,
    ProductCandidate,
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
    ScanInput,
    ScanSource,
    StrategistNote,
    StructuredLensScores,
    SwapPriority,
    SwapSuggestion,
    TodayFocus,
    UserContext,
    UserGoal,
    UserLifecycleState,
    UserProfile,
    WeeklyInsight,
    WeeklyInsightsResponse,
    WellnessFeatureFlags,
    fixture_payload,
)
from app.date_utils import apple_timestamp_now
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
    settings: object

    def client_config(self) -> ClientConfigResponse:
        return ClientConfigResponse(
            environment=self.settings.env,
            minimumSupportedVersion=self.settings.minimum_supported_version,
            minimumSupportedBuild=self.settings.minimum_supported_build,
            copyVersion=self.settings.copy_version,
            flags=WellnessFeatureFlags(),
            killSwitches=ClientKillSwitches(),
            updatedAt=apple_timestamp_now(),
        )

    def analyze_product(self, input: ScanInput, user_context: UserContext) -> ScanAnalysis:
        return build_scan_analysis(input=input, user_context=user_context)

    def analyze_structured(self, input: ScanInput, profile: UserProfile, recent_scans: list[ScanEvent], recent_checkins: list[CheckInEvent]) -> AnalysisEnvelope:
        return build_analysis_envelope(
            input=input,
            user_context=profile.userContext,
            recent_scans=recent_scans,
            recent_checkins=recent_checkins,
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
    created_at: AppleTimestamp | None = None,
) -> ScanAnalysis:
    tokens = _tokens(input)
    product_type = _product_type_for_input(input)
    resolved_timestamp = _timestamp(created_at)
    product = ProductCandidate(
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
    lens_scores = build_lens_scores(tokens, user_context)
    overall_score = int(sum(score.score for score in lens_scores) / max(len(lens_scores), 1))
    reasons = build_reasons(tokens, overall_score)
    warnings = build_warnings(tokens, overall_score)
    alternatives: list[AlternativeSuggestion] = []
    if overall_score < 62:
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
        overallSummary=summary_for_score(overall_score),
        topReasons=reasons,
        warnings=warnings,
        alternatives=alternatives,
        confidence=confidence_for_tokens(tokens, input),
        disclaimer=DISCLAIMER,
    )


def build_analysis_envelope(
    input: ScanInput,
    user_context: UserContext,
    recent_scans: list[ScanEvent],
    recent_checkins: list[CheckInEvent],
    created_at: AppleTimestamp | None = None,
) -> AnalysisEnvelope:
    analysis = build_scan_analysis(input, user_context, created_at=created_at)
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
        verdict=verdict,
        overall_score=overall,
        lens_scores=StructuredLensScores(
            skin=lens_map.get("glowSkin", 0),
            hormones=lens_map.get("hormoneBalance", 0),
            gut=lens_map.get("gutComfort", 0),
            energy=lens_map.get("energyMood", 0),
            body_comp=lens_map.get("bodyCompositionStrength", 0),
        ),
        why_today=build_why_today(overall, recent_checkins, input.sourceType),
        green_flags=[reason.title for reason in analysis.topReasons if reason.impact == ReasonImpact.positive][:4],
        red_flags=analysis.warnings[:4],
        recommended_actions=build_recommended_actions(overall),
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


def build_lens_scores(tokens: list[str], user_context: UserContext) -> list[LensScore]:
    sugarish = any(token in {"sugar", "syrup", "fries", "soda"} for token in tokens)
    calming = any(token in {"fiber", "protein", "chia", "greens", "salad"} for token in tokens)
    skincare = any(token in {"niacinamide", "peptides", "hyaluronic"} for token in tokens)
    baseline = 72 if calming else 58 if sugarish else 66
    bonuses = {
        "glowSkin": 8 if skincare else 0,
        "hormoneBalance": 6 if calming else -6 if sugarish else 0,
        "gutComfort": 8 if calming else -8 if sugarish else 0,
        "energyMood": 6 if calming else -10 if sugarish else 0,
        "bodyCompositionStrength": 5 if calming else -5 if sugarish else 0,
    }
    if UserGoal.gutCalm in user_context.goals:
        bonuses["gutComfort"] += 4
    if UserGoal.steadyEnergy in user_context.goals:
        bonuses["energyMood"] += 4
    return [
        LensScore(lens="glowSkin", score=max(25, min(92, baseline + bonuses["glowSkin"])), summary=score_summary(baseline + bonuses["glowSkin"])),
        LensScore(lens="hormoneBalance", score=max(25, min(92, baseline + bonuses["hormoneBalance"])), summary=score_summary(baseline + bonuses["hormoneBalance"])),
        LensScore(lens="gutComfort", score=max(25, min(92, baseline + bonuses["gutComfort"])), summary=score_summary(baseline + bonuses["gutComfort"])),
        LensScore(lens="energyMood", score=max(25, min(92, baseline + bonuses["energyMood"])), summary=score_summary(baseline + bonuses["energyMood"])),
        LensScore(lens="bodyCompositionStrength", score=max(25, min(92, baseline + bonuses["bodyCompositionStrength"])), summary=score_summary(baseline + bonuses["bodyCompositionStrength"])),
    ]


def build_reasons(tokens: list[str], overall_score: int) -> list[ReasonItem]:
    reasons = [
        ReasonItem(
            id=_stable_id("reason", "signal-quality"),
            title="Signal quality",
            detail="The backend is returning the same structured shape the client already expects.",
            impact=ReasonImpact.positive,
        )
    ]
    if any(token in {"fiber", "protein", "greens"} for token in tokens):
        reasons.append(
            ReasonItem(
                id=_stable_id("reason", "steadier-anchor"),
                title="Steadier anchor",
                detail="Protein and fiber cues often support calmer energy and digestion reads.",
                impact=ReasonImpact.positive,
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


def build_warnings(tokens: list[str], overall_score: int) -> list[str]:
    warnings: list[str] = []
    if any(token in {"sugar", "syrup", "fries", "soda"} for token in tokens):
        warnings.append("Higher sugar or heavier-processing cues may soften the fit.")
    if overall_score < 55:
        warnings.append("Use this as directional guidance and verify with a follow-up check-in.")
    if not warnings:
        warnings.append("Consumer wellness guidance only.")
    return warnings[:3]


def summary_for_score(score: int) -> str:
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


def confidence_for_tokens(tokens: list[str], input: ScanInput) -> ConfidenceLevel:
    if input.barcode:
        return ConfidenceLevel.high
    if len(tokens) >= 3:
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


def build_why_today(overall: int, recent_checkins: list[CheckInEvent], source: ScanSource) -> list[str]:
    reasons = [
        "This read is being structured server-side to match the app contract without removing the local fallback."
    ]
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


def build_recommended_actions(overall: int) -> list[str]:
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
