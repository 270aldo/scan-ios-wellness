import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                heroCard
                goalStrip
                latestScanSection
                weeklyInsightsSection
                demoPacksSection
            }
            .padding(20)
        }
        .navigationTitle("Today")
        .background(Color(red: 0.98, green: 0.97, blue: 0.99))
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Inside-out clarity")
                .font(.title.bold())
                .foregroundStyle(.white)
            Text("Scan what you eat or apply, then turn the noise into a calm next step.")
                .foregroundStyle(.white.opacity(0.9))

            if let lastDemoScenario = model.lastDemoScenario {
                Button("Replay \(lastDemoScenario.title)") {
                    Task {
                        await model.runDemoScenario(lastDemoScenario)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.white)
                .foregroundStyle(Color.accentColor)

                Button("Open guided scan surface") {
                    model.selectedTab = .scan
                }
                .buttonStyle(.bordered)
                .tint(.white)
                .foregroundStyle(.white)
            } else {
                Button("Open guided scan surface") {
                    model.selectedTab = .scan
                }
                .buttonStyle(.borderedProminent)
                .tint(.white)
                .foregroundStyle(Color.accentColor)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.85, green: 0.35, blue: 0.54),
                    Color(red: 0.45, green: 0.53, blue: 0.94)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
    }

    private var goalStrip: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current priorities")
                .font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(model.userContext.goals) { goal in
                        Text(goal.title)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color.white, in: Capsule())
                    }
                }
            }
        }
    }

    private var latestScanSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Latest scan")
                .font(.headline)
            if let latestRecord = model.latestRecord {
                VStack(alignment: .leading, spacing: 10) {
                    Text(latestRecord.analysis.resolvedProduct.name)
                        .font(.title3.weight(.semibold))
                    Text(latestRecord.analysis.overallSummary)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        ForEach(latestRecord.analysis.lensScores.prefix(3)) { score in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(score.lens.title)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Text("\(score.score)")
                                    .font(.title3.bold())
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                    }
                }
                .padding(18)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            } else {
                emptyCard(title: "No scans yet", message: "Run your first pantry or vanity scan to start building patterns.")
            }
        }
    }

    private var weeklyInsightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weekly signals")
                .font(.headline)

            ForEach(model.weeklyInsights) { insight in
                VStack(alignment: .leading, spacing: 6) {
                    Text(insight.title)
                        .font(.subheadline.weight(.bold))
                    Text(insight.summary)
                        .foregroundStyle(.secondary)
                    Text(insight.callToAction)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
        }
    }

    private var demoPacksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("1-tap demo scenarios")
                .font(.headline)
            ForEach(model.demoScenarioPacks) { pack in
                VStack(alignment: .leading, spacing: 12) {
                    Label(pack.title, systemImage: pack.icon)
                        .font(.subheadline.weight(.bold))
                    Text(pack.subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 14) {
                            ForEach(pack.scenarios) { scenario in
                                Button {
                                    Task {
                                        await model.runDemoScenario(scenario)
                                    }
                                } label: {
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text(scenario.title)
                                            .font(.subheadline.weight(.bold))
                                            .foregroundStyle(.primary)
                                        Text(scenario.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(scenario.expectedHighlight)
                                            .font(.caption)
                                            .foregroundStyle(.primary)
                                        Label(scenario.expectedLensBias.title, systemImage: scenario.expectedLensBias.icon)
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(Color.accentColor)
                                    }
                                    .frame(width: 240, alignment: .leading)
                                    .padding(16)
                                    .background(Color.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
    }

    private func emptyCard(title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(message)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}
