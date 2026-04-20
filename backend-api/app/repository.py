from __future__ import annotations

from collections import defaultdict
from dataclasses import dataclass, field
import logging
from threading import Lock
from typing import Protocol

from app.config import Settings
from app.contracts import (
    ActiveGoal,
    CheckInEntry,
    CheckInEvent,
    FavoriteItem,
    FirstWeekPlan,
    HistorySyncRequest,
    MemoryItem,
    ScanDecision,
    ScanEvent,
    UserContext,
    UserProfile,
)

try:
    from google.cloud import firestore
except ImportError:  # pragma: no cover - optional in local bootstrap
    firestore = None


logger = logging.getLogger(__name__)


@dataclass
class UserState:
    profile: UserProfile | None = None
    active_goals: list[ActiveGoal] = field(default_factory=list)
    first_week_plan: FirstWeekPlan | None = None
    user_context: UserContext | None = None
    legacy_checkins: list[CheckInEntry] = field(default_factory=list)
    checkin_events: dict[str, CheckInEvent] = field(default_factory=dict)
    scan_events: dict[str, ScanEvent] = field(default_factory=dict)
    favorites: dict[str, FavoriteItem] = field(default_factory=dict)
    memory_items: dict[str, MemoryItem] = field(default_factory=dict)
    scan_decisions: dict[str, ScanDecision] = field(default_factory=dict)


class StateRepository(Protocol):
    def get_state(self, install_id: str) -> UserState: ...
    def save_profile(self, install_id: str, profile: UserProfile, active_goals: list[ActiveGoal], first_week_plan: FirstWeekPlan | None) -> None: ...
    def save_checkin(self, install_id: str, checkin: CheckInEntry, user_context: UserContext) -> None: ...
    def save_checkin_event(self, install_id: str, event: CheckInEvent) -> None: ...
    def save_scan_decision(self, install_id: str, decision: ScanDecision) -> None: ...
    def save_favorite(self, install_id: str, favorite: FavoriteItem) -> None: ...
    def upsert_memory_items(self, install_id: str, memory_items: list[MemoryItem]) -> None: ...
    def sync_history(self, request: HistorySyncRequest) -> UserState: ...


def _payload_equals(left, right) -> bool:
    return left.model_dump(by_alias=True, mode="json") == right.model_dump(by_alias=True, mode="json")


def _log_history_conflict(entity_name: str, item_id: str, reason: str) -> None:
    logger.warning("history_sync_conflict entity=%s id=%s reason=%s", entity_name, item_id, reason)


def _merge_append_only_map(target: dict, incoming_items: list, *, entity_name: str) -> None:
    for item in incoming_items:
        existing = target.get(item.id)
        if existing is None:
            target[item.id] = item
            continue
        if not _payload_equals(existing, item):
            _log_history_conflict(entity_name, item.id, "discarded_conflicting_update")


def _merge_scan_decisions(target: dict[str, ScanDecision], incoming_items: list[ScanDecision]) -> None:
    for item in incoming_items:
        existing = target.get(item.id)
        if existing is None:
            target[item.id] = item
            continue
        if _payload_equals(existing, item):
            continue

        existing_resolved = existing.resolvedAt
        incoming_resolved = item.resolvedAt

        if incoming_resolved is None:
            _log_history_conflict("scan_decision", item.id, "discarded_non_monotonic_update")
            continue

        if existing_resolved is None or incoming_resolved > existing_resolved:
            target[item.id] = item
            continue

        _log_history_conflict("scan_decision", item.id, "discarded_stale_resolved_at")


def _merge_history_into_state(state: UserState, request: HistorySyncRequest) -> UserState:
    _merge_append_only_map(state.scan_events, request.scans, entity_name="scan_event")
    _merge_append_only_map(state.checkin_events, request.checkIns, entity_name="checkin_event")
    _merge_append_only_map(state.favorites, request.favorites, entity_name="favorite")
    _merge_append_only_map(state.memory_items, request.memoryItems, entity_name="memory_item")
    _merge_scan_decisions(state.scan_decisions, request.scanDecisions)
    return state


class InMemoryStateRepository:
    def __init__(self) -> None:
        self._lock = Lock()
        self._states: dict[str, UserState] = defaultdict(UserState)

    def get_state(self, install_id: str) -> UserState:
        with self._lock:
            return self._states[install_id]

    def save_profile(self, install_id: str, profile: UserProfile, active_goals: list[ActiveGoal], first_week_plan: FirstWeekPlan | None) -> None:
        with self._lock:
            state = self._states[install_id]
            state.profile = profile
            state.user_context = profile.userContext
            state.active_goals = active_goals
            state.first_week_plan = first_week_plan

    def save_checkin(self, install_id: str, checkin: CheckInEntry, user_context: UserContext) -> None:
        with self._lock:
            state = self._states[install_id]
            state.legacy_checkins = [checkin] + [entry for entry in state.legacy_checkins if entry.id != checkin.id]
            state.user_context = user_context

    def save_checkin_event(self, install_id: str, event: CheckInEvent) -> None:
        with self._lock:
            self._states[install_id].checkin_events[event.id] = event

    def save_scan_decision(self, install_id: str, decision: ScanDecision) -> None:
        with self._lock:
            self._states[install_id].scan_decisions[decision.id] = decision

    def save_favorite(self, install_id: str, favorite: FavoriteItem) -> None:
        with self._lock:
            self._states[install_id].favorites[favorite.id] = favorite

    def upsert_memory_items(self, install_id: str, memory_items: list[MemoryItem]) -> None:
        with self._lock:
            state = self._states[install_id]
            for item in memory_items:
                state.memory_items[item.id] = item

    def sync_history(self, request: HistorySyncRequest) -> UserState:
        with self._lock:
            state = self._states[request.installID]
            return _merge_history_into_state(state, request)


class FirestoreStateRepository:
    def __init__(self) -> None:
        if firestore is None:  # pragma: no cover - environment-dependent
            raise RuntimeError("google-cloud-firestore is not installed.")
        self._db = firestore.Client()

    def _root(self, install_id: str):
        return self._db.collection("wellness_users").document(install_id)

    def _read_collection(self, root, name: str, model_cls):
        docs = root.collection(name).stream()
        return {doc.id: model_cls.model_validate(doc.to_dict()) for doc in docs}

    def get_state(self, install_id: str) -> UserState:
        root = self._root(install_id)
        doc = root.get()
        base = doc.to_dict() if doc.exists else {}
        profile = UserProfile.model_validate(base["profile"]) if base.get("profile") else None
        active_goals = [ActiveGoal.model_validate(item) for item in base.get("active_goals", [])]
        first_week_plan = FirstWeekPlan.model_validate(base["first_week_plan"]) if base.get("first_week_plan") else None
        user_context = profile.userContext if profile else None
        return UserState(
            profile=profile,
            active_goals=active_goals,
            first_week_plan=first_week_plan,
            user_context=user_context,
            checkin_events=self._read_collection(root, "checkin_events", CheckInEvent),
            scan_events=self._read_collection(root, "scan_events", ScanEvent),
            favorites=self._read_collection(root, "favorites", FavoriteItem),
            memory_items=self._read_collection(root, "memory_items", MemoryItem),
            scan_decisions=self._read_collection(root, "scan_decisions", ScanDecision),
        )

    def save_profile(self, install_id: str, profile: UserProfile, active_goals: list[ActiveGoal], first_week_plan: FirstWeekPlan | None) -> None:
        root = self._root(install_id)
        root.set(
            {
                "profile": profile.model_dump(by_alias=True, mode="json"),
                "active_goals": [goal.model_dump(by_alias=True, mode="json") for goal in active_goals],
                "first_week_plan": first_week_plan.model_dump(by_alias=True, mode="json") if first_week_plan else None,
            },
            merge=True,
        )

    def save_checkin(self, install_id: str, checkin: CheckInEntry, user_context: UserContext) -> None:
        root = self._root(install_id)
        root.collection("legacy_checkins").document(checkin.id).set(checkin.model_dump(by_alias=True, mode="json"))
        root.set({"user_context": user_context.model_dump(by_alias=True, mode="json")}, merge=True)

    def save_checkin_event(self, install_id: str, event: CheckInEvent) -> None:
        self._root(install_id).collection("checkin_events").document(event.id).set(event.model_dump(by_alias=True, mode="json"))

    def save_scan_decision(self, install_id: str, decision: ScanDecision) -> None:
        self._root(install_id).collection("scan_decisions").document(decision.id).set(decision.model_dump(by_alias=True, mode="json"))

    def save_favorite(self, install_id: str, favorite: FavoriteItem) -> None:
        self._root(install_id).collection("favorites").document(favorite.id).set(favorite.model_dump(by_alias=True, mode="json"))

    def upsert_memory_items(self, install_id: str, memory_items: list[MemoryItem]) -> None:
        root = self._root(install_id).collection("memory_items")
        for item in memory_items:
            root.document(item.id).set(item.model_dump(by_alias=True, mode="json"))

    def sync_history(self, request: HistorySyncRequest) -> UserState:
        state = _merge_history_into_state(self.get_state(request.installID), request)
        root = self._root(request.installID)
        for item in state.scan_events.values():
            root.collection("scan_events").document(item.id).set(item.model_dump(by_alias=True, mode="json"))
        for item in state.checkin_events.values():
            root.collection("checkin_events").document(item.id).set(item.model_dump(by_alias=True, mode="json"))
        for item in state.favorites.values():
            root.collection("favorites").document(item.id).set(item.model_dump(by_alias=True, mode="json"))
        for item in state.memory_items.values():
            root.collection("memory_items").document(item.id).set(item.model_dump(by_alias=True, mode="json"))
        for item in state.scan_decisions.values():
            root.collection("scan_decisions").document(item.id).set(item.model_dump(by_alias=True, mode="json"))
        return state


def build_repository(settings: Settings) -> StateRepository:
    if settings.use_firestore:
        return FirestoreStateRepository()
    return InMemoryStateRepository()
