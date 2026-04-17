from __future__ import annotations

from collections import defaultdict
from dataclasses import dataclass, field
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
            for item in request.scans:
                state.scan_events[item.id] = item
            for item in request.checkIns:
                state.checkin_events[item.id] = item
            for item in request.favorites:
                state.favorites[item.id] = item
            for item in request.memoryItems:
                state.memory_items[item.id] = item
            for item in request.scanDecisions:
                state.scan_decisions[item.id] = item
            return state


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
        root = self._root(request.installID)
        for item in request.scans:
            root.collection("scan_events").document(item.id).set(item.model_dump(by_alias=True, mode="json"))
        for item in request.checkIns:
            root.collection("checkin_events").document(item.id).set(item.model_dump(by_alias=True, mode="json"))
        for item in request.favorites:
            root.collection("favorites").document(item.id).set(item.model_dump(by_alias=True, mode="json"))
        for item in request.memoryItems:
            root.collection("memory_items").document(item.id).set(item.model_dump(by_alias=True, mode="json"))
        for item in request.scanDecisions:
            root.collection("scan_decisions").document(item.id).set(item.model_dump(by_alias=True, mode="json"))
        return self.get_state(request.installID)


def build_repository(settings: Settings) -> StateRepository:
    if settings.use_firestore:
        return FirestoreStateRepository()
    return InMemoryStateRepository()
