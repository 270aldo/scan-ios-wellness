import Foundation

enum BackendSurfaceKind: String, CaseIterable, Codable, Hashable, Identifiable {
    case clientConfig
    case historySync
    case structuredScan
    case home
    case insights
    case profileSync
    case checkInSync
    case memorySync
    case decisionSync
    case favoriteSync

    var id: String { rawValue }

    var title: String {
        switch self {
        case .clientConfig:
            "Client config"
        case .historySync:
            "History sync"
        case .structuredScan:
            "Structured scan"
        case .home:
            "Home"
        case .insights:
            "Weekly insights"
        case .profileSync:
            "Profile sync"
        case .checkInSync:
            "Check-in sync"
        case .memorySync:
            "Memory sync"
        case .decisionSync:
            "Decision sync"
        case .favoriteSync:
            "Favorites sync"
        }
    }
}

enum BackendSurfaceState: String, Codable, Hashable {
    case unavailable
    case idle
    case syncPending
    case live
    case fallback
    case retryableError

    var title: String {
        switch self {
        case .unavailable:
            "Unavailable"
        case .idle:
            "Idle"
        case .syncPending:
            "Sync pending"
        case .live:
            "Live"
        case .fallback:
            "Fallback"
        case .retryableError:
            "Retryable error"
        }
    }
}

struct BackendSurfaceStatus: Codable, Hashable, Identifiable {
    var kind: BackendSurfaceKind
    var state: BackendSurfaceState
    var detail: String
    var updatedAt: Date?
    var attempts: Int
    var fallbackCount: Int

    var id: String { kind.rawValue }

    static func initial(kind: BackendSurfaceKind, hasBackend: Bool) -> BackendSurfaceStatus {
        BackendSurfaceStatus(
            kind: kind,
            state: hasBackend ? .idle : .unavailable,
            detail: hasBackend ? "Ready to sync." : "No backend configured in runtime settings.",
            updatedAt: nil,
            attempts: 0,
            fallbackCount: 0
        )
    }
}

func initialBackendStatuses(hasBackend: Bool) -> [BackendSurfaceKind: BackendSurfaceStatus] {
    Dictionary(
        uniqueKeysWithValues: BackendSurfaceKind.allCases.map {
            ($0, BackendSurfaceStatus.initial(kind: $0, hasBackend: hasBackend))
        }
    )
}
