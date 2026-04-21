import SwiftUI

struct BackendAdminView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            WLScreen {
                runtimeCard
                clientConfigCard
                surfaceStatusCard
            }
            .navigationTitle("Backend Admin")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .font(WLTypography.captionStrong)
                }
            }
        }
    }

    private var runtimeCard: some View {
        WLPrimaryCard {
            VStack(alignment: .leading, spacing: WLSpacing.m) {
                WLSectionHeader(
                    title: "Runtime",
                    subtitle: "How this build is currently wired before any remote overrides.",
                    systemImage: "server.rack"
                )

                runtimeRow(label: "Backend base URL", value: model.services.configuration.backendBaseURL?.absoluteString ?? "Not configured")
                runtimeRow(label: "Agent service URL", value: model.services.configuration.agentServiceBaseURL?.absoluteString ?? "Not configured")
                runtimeRow(label: "Auth mode", value: model.backendAuthModeTitle)
                runtimeRow(
                    label: "Backend debug surface",
                    value: model.services.configuration.isBackendDebugSurfaceEnabled ? "Enabled" : "Disabled"
                )
                runtimeRow(label: "Firebase", value: model.services.configuration.isFirebaseEnabled ? "Enabled" : "Disabled")
                runtimeRow(label: "Firebase options plist", value: model.services.configuration.firebaseOptionsPlistName ?? "GoogleService-Info")
                runtimeRow(label: "Firebase bootstrap", value: model.services.firebaseBootstrapState.title)
                runtimeRow(label: "Demo scans", value: model.services.configuration.useDemoData ? "Enabled" : "Disabled")
                runtimeRow(label: "StoreKit", value: model.services.configuration.isStoreKitEnabled ? "Enabled" : "Disabled")
                runtimeRow(
                    label: "App Check debug provider",
                    value: model.services.configuration.useAppCheckDebugProvider ? "Enabled" : "Disabled"
                )
            }
        }
    }

    private var clientConfigCard: some View {
        WLCompactCard {
            VStack(alignment: .leading, spacing: WLSpacing.m) {
                WLSectionHeader(
                    title: "Remote client config",
                    subtitle: "The current backend-managed flags, versions, and kill switches.",
                    systemImage: "switch.2"
                )

                if let config = model.remoteClientConfig {
                    runtimeRow(label: "Environment", value: config.environment)
                    runtimeRow(label: "Minimum version", value: "\(config.minimumSupportedVersion) (\(config.minimumSupportedBuild))")
                    runtimeRow(label: "Copy version", value: config.copyVersion)
                    runtimeRow(label: "Persistence", value: config.persistenceMode)
                    runtimeRow(label: "Firebase auth", value: config.firebaseAuthEnforced ? "Enforced" : "Open")
                    runtimeRow(label: "App Check", value: config.appCheckEnforced ? "Enforced" : "Open")
                    runtimeRow(label: "Agent provider", value: config.agentProviderMode)
                    runtimeRow(label: "Updated", value: config.updatedAt.formatted(date: .abbreviated, time: .shortened))

                    VStack(alignment: .leading, spacing: WLSpacing.s) {
                        Text("Flags")
                            .font(WLTypography.captionStrong)
                            .foregroundStyle(WLPalette.inkSoft)

                        flowPills(config.flags.flagRows)
                    }

                    VStack(alignment: .leading, spacing: WLSpacing.s) {
                        Text("Kill switches")
                            .font(WLTypography.captionStrong)
                            .foregroundStyle(WLPalette.inkSoft)

                        flowPills(config.killSwitchRows)
                    }
                } else {
                    Text("No remote client config has been applied yet. The app is running on bundled defaults and local fallback.")
                        .font(WLTypography.body)
                        .foregroundStyle(WLPalette.inkSoft)
                }
            }
        }
    }

    private var surfaceStatusCard: some View {
        WLCompactCard {
            VStack(alignment: .leading, spacing: WLSpacing.m) {
                WLSectionHeader(
                    title: "Backend surfaces",
                    subtitle: "Each critical surface shows its last known state, detail, and fallback count.",
                    systemImage: "waveform.path.ecg.rectangle"
                )

                ForEach(model.backendStatusList) { status in
                    VStack(alignment: .leading, spacing: WLSpacing.s) {
                        HStack(alignment: .top, spacing: WLSpacing.s) {
                            WLStatusBadge(
                                title: status.state.title,
                                systemImage: status.state.systemImage,
                                tone: status.state.badgeTone
                            )

                            VStack(alignment: .leading, spacing: WLSpacing.xs) {
                                Text(status.kind.title)
                                    .font(WLTypography.bodyEmphasis)
                                    .foregroundStyle(WLPalette.ink)

                                Text(status.detail)
                                    .font(WLTypography.caption)
                                    .foregroundStyle(WLPalette.inkSoft)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Spacer(minLength: WLSpacing.s)
                        }

                        HStack(spacing: WLSpacing.s) {
                            WLPill(title: "Attempts \(status.attempts)", tone: .neutral)
                            WLPill(title: "Fallbacks \(status.fallbackCount)", tone: status.fallbackCount == 0 ? .soft : .accent)
                            if let updatedAt = status.updatedAt {
                                WLPill(title: updatedAt.formatted(date: .omitted, time: .shortened), tone: .soft)
                            }
                        }
                    }

                    if status.id != model.backendStatusList.last?.id {
                        Divider()
                            .overlay(WLPalette.stroke.opacity(0.6))
                    }
                }
            }
        }
    }

    private func runtimeRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: WLSpacing.xs) {
            Text(label)
                .font(WLTypography.captionStrong)
                .foregroundStyle(WLPalette.inkSoft)

            Text(value.isEmpty ? "Not set" : value)
                .font(WLTypography.body)
                .foregroundStyle(WLPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func flowPills(_ rows: [BackendFlagRow]) -> some View {
        VStack(alignment: .leading, spacing: WLSpacing.s) {
            ForEach(rows) { row in
                HStack(spacing: WLSpacing.s) {
                    WLPill(title: row.label, tone: row.isEnabled ? .accent : .soft)
                    WLPill(title: row.isEnabled ? "On" : "Off", tone: row.isEnabled ? .accent : .neutral)
                    Spacer(minLength: 0)
                }
            }
        }
    }
}

private struct BackendFlagRow: Identifiable {
    let label: String
    let isEnabled: Bool

    var id: String { label }
}

private extension BackendSurfaceState {
    var badgeTone: WLStatusBadge.Tone {
        switch self {
        case .live:
            .success
        case .fallback, .retryableError:
            .caution
        case .unavailable, .idle, .syncPending:
            .accent
        }
    }

    var systemImage: String {
        switch self {
        case .unavailable:
            "icloud.slash"
        case .idle:
            "pause.circle"
        case .syncPending:
            "arrow.trianglehead.2.clockwise"
        case .live:
            "checkmark.circle"
        case .fallback:
            "arrow.uturn.backward.circle"
        case .retryableError:
            "exclamationmark.triangle"
        }
    }
}

private extension WellnessFeatureFlags {
    var flagRows: [BackendFlagRow] {
        [
            BackendFlagRow(label: "New onboarding", isEnabled: newOnboarding),
            BackendFlagRow(label: "New home", isEnabled: newHome),
            BackendFlagRow(label: "Home surface v2", isEnabled: homeSurfaceV2),
            BackendFlagRow(label: "Strategist", isEnabled: strategist),
            BackendFlagRow(label: "Daily brief", isEnabled: dailyBrief),
            BackendFlagRow(label: "Structured analysis", isEnabled: structuredAnalysis),
            BackendFlagRow(label: "Meal snapshot", isEnabled: mealSnapshot),
            BackendFlagRow(label: "Safety guard", isEnabled: safetyGuard),
            BackendFlagRow(label: "Pattern agent", isEnabled: patternAgent),
            BackendFlagRow(label: "Weekly insight v2", isEnabled: weeklyInsightV2),
            BackendFlagRow(label: "Menu scanner", isEnabled: menuScanner),
            BackendFlagRow(label: "Pantry MVP", isEnabled: pantryMVP),
            BackendFlagRow(label: "Contextual paywall", isEnabled: contextualPaywall),
            BackendFlagRow(label: "Entitlements v2", isEnabled: entitlementsV2),
        ]
    }
}

private extension ClientConfigResponse {
    var killSwitchRows: [BackendFlagRow] {
        [
            BackendFlagRow(label: "Scan disabled", isEnabled: killSwitches.scanDisabled),
            BackendFlagRow(label: "Strategist disabled", isEnabled: killSwitches.strategistDisabled),
            BackendFlagRow(label: "Home disabled", isEnabled: killSwitches.homeDisabled),
        ]
    }
}
