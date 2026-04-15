import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var sampleReadsExpanded = false

    private var featuredInsight: WeeklyInsight? {
        model.weeklyInsights.first
    }

    private var secondaryInsights: [WeeklyInsight] {
        Array(model.weeklyInsights.dropFirst().prefix(2))
    }

    var body: some View {
        WLScreen {
            if let latestRecord = model.latestRecord {
                HomeLatestReadHero(
                    record: latestRecord,
                    openProductRead: { model.latestAnalysis = latestRecord.analysis },
                    scanAnotherProduct: openScan
                )

                HomeInsightsSection(
                    featuredInsight: featuredInsight,
                    secondaryInsights: secondaryInsights
                )

                if !model.userContext.goals.isEmpty {
                    HomePrioritiesSection(goals: model.userContext.goals)
                }

                HomeSampleReadsSection(
                    packs: model.demoScenarioPacks,
                    isExpanded: $sampleReadsExpanded,
                    runScenario: runScenario
                )
            } else {
                HomeWelcomeHero(openScan: openScan)

                HomeSampleReadsSection(
                    packs: model.demoScenarioPacks,
                    isExpanded: $sampleReadsExpanded,
                    runScenario: runScenario
                )

                if !model.userContext.goals.isEmpty {
                    HomePrioritiesSection(goals: model.userContext.goals)
                }
            }
        }
        .navigationTitle("Today")
    }

    private func openScan() {
        withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
            model.selectedTab = .scan
        }
    }

    private func runScenario(_ scenario: DemoScenario) {
        Task {
            await model.runDemoScenario(scenario)
        }
    }
}

private struct HomeWelcomeHero: View {
    let openScan: () -> Void

    var body: some View {
        WLHeroCard {
                VStack(alignment: .leading, spacing: WLSpacing.l) {
                WLStatusBadge(
                    title: "Personal product reads",
                    systemImage: "sparkles",
                    tone: .accent,
                    style: .heroGlass
                )

                VStack(alignment: .leading, spacing: WLSpacing.s) {
                    Text(WLProductCopy.Home.emptyTitle)
                        .font(WLTypography.hero)
                        .foregroundStyle(.white)

                    Text(WLProductCopy.Home.emptySubtitle)
                        .font(WLTypography.body)
                        .foregroundStyle(Color.white.opacity(0.90))
                }

                WLPrimaryButton(
                    title: "Scan your first product",
                    systemImage: "viewfinder",
                    chrome: .heroPrimary
                ) {
                    openScan()
                }
            }
        }
    }
}

private struct HomeLatestReadHero: View {
    let record: ScanRecord
    let openProductRead: () -> Void
    let scanAnotherProduct: () -> Void

    private var leadingLens: LensScore? {
        record.analysis.lensScores.max(by: { $0.score < $1.score })
    }

    private var topOutcomes: [LensScore] {
        Array(record.analysis.lensScores.sorted(by: { $0.score > $1.score }).prefix(2))
    }

    var body: some View {
        WLHeroCard {
            VStack(alignment: .leading, spacing: WLSpacing.l) {
                WLHeroGlassGroup {
                    HStack(alignment: .center, spacing: WLSpacing.s) {
                        WLStatusBadge(
                            title: WLProductCopy.Home.latestReadTitle,
                            systemImage: "sparkles",
                            tone: .accent,
                            style: .heroGlass
                        )
                        WLPill(
                            title: record.analysis.productType.title,
                            tone: .neutral,
                            style: .heroGlass
                        )
                    }
                }

                VStack(alignment: .leading, spacing: WLSpacing.s) {
                    Text(record.analysis.resolvedProduct.name)
                        .font(WLTypography.hero)
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(record.analysis.overallSummary)
                        .font(WLTypography.body)
                        .foregroundStyle(Color.white.opacity(0.90))
                        .fixedSize(horizontal: false, vertical: true)
                }

                WLHeroGlassGroup {
                    HStack(spacing: WLSpacing.s) {
                        ForEach(topOutcomes) { outcome in
                            HomeOutcomeCard(score: outcome)
                        }
                    }
                }

                WLHeroGlassGroup {
                    HStack(spacing: WLSpacing.s) {
                        WLPrimaryButton(
                            title: "Open product read",
                            systemImage: "chart.xyaxis.line",
                            chrome: .heroPrimary
                        ) {
                            openProductRead()
                        }

                        WLSecondaryButton(
                            title: "Scan another product",
                            systemImage: "viewfinder",
                            chrome: .heroSecondary
                        ) {
                            scanAnotherProduct()
                        }
                    }
                }

                if let leadingLens {
                    Text("Leading lens: \(leadingLens.lens.title)")
                        .font(WLTypography.captionStrong)
                        .foregroundStyle(Color.white.opacity(0.82))
                }
            }
        }
    }
}

private struct HomeOutcomeCard: View {
    let score: LensScore

    var body: some View {
        WLAdaptiveGlassSurface(
            shape: .roundedRect(WLCorner.m),
            tint: Color.white.opacity(0.16),
            fallbackFill: Color.white.opacity(0.12),
            fallbackStroke: Color.white.opacity(0.10)
        ) {
            VStack(alignment: .leading, spacing: WLSpacing.xs) {
                HStack(spacing: WLSpacing.xs) {
                    WLIcon(systemName: score.lens.icon, color: .white, size: 13)
                    Text(score.lens.title)
                        .font(WLTypography.captionStrong)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }

                Text("\(score.score)")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(score.score >= 82 ? "Strong fit" : "Solid fit")
                    .font(WLTypography.caption)
                    .foregroundStyle(Color.white.opacity(0.82))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, WLSpacing.m)
            .padding(.vertical, 14)
        }
    }
}

private struct HomePrioritiesSection: View {
    let goals: [UserGoal]

    var body: some View {
        VStack(alignment: .leading, spacing: WLSpacing.m) {
            WLSectionHeader(
                title: WLProductCopy.Home.prioritiesTitle,
                subtitle: WLProductCopy.Home.prioritiesSubtitle,
                systemImage: "line.3.horizontal.decrease.circle"
            )

            WLPrimaryCard {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: WLSpacing.s) {
                        ForEach(goals) { goal in
                            WLPill(title: goal.title, tone: .accent)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }
}

private struct HomeInsightsSection: View {
    let featuredInsight: WeeklyInsight?
    let secondaryInsights: [WeeklyInsight]

    var body: some View {
        VStack(alignment: .leading, spacing: WLSpacing.m) {
            WLSectionHeader(
                title: WLProductCopy.Home.weeklySignalsTitle,
                subtitle: WLProductCopy.Home.weeklySignalsSubtitle,
                systemImage: "waveform.path.ecg"
            )

            if let featuredInsight {
                WLPrimaryCard {
                    VStack(alignment: .leading, spacing: WLSpacing.m) {
                        WLStatusBadge(title: "Leading signal", systemImage: "waveform.path.ecg", tone: .accent)

                        Text(featuredInsight.title)
                            .font(WLTypography.title)
                            .foregroundStyle(WLPalette.ink)

                        Text(featuredInsight.summary)
                            .font(WLTypography.body)
                            .foregroundStyle(WLPalette.inkSoft)

                        Text(featuredInsight.callToAction)
                            .font(WLTypography.bodyEmphasis)
                            .foregroundStyle(WLPalette.rose)
                    }
                }
            }

            ForEach(secondaryInsights) { insight in
                WLCompactCard {
                    VStack(alignment: .leading, spacing: WLSpacing.s) {
                        Text(insight.title)
                            .font(WLTypography.bodyEmphasis)
                            .foregroundStyle(WLPalette.ink)

                        Text(insight.summary)
                            .font(WLTypography.body)
                            .foregroundStyle(WLPalette.inkSoft)
                    }
                }
            }
        }
    }
}

private struct HomeSampleReadsSection: View {
    let packs: [DemoScenarioPack]
    @Binding var isExpanded: Bool
    let runScenario: (DemoScenario) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: WLSpacing.m) {
            Button {
                withAnimation(.spring(response: 0.30, dampingFraction: 0.88)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(alignment: .center, spacing: WLSpacing.s) {
                    WLSectionHeader(
                        title: WLProductCopy.Home.sampleReadsTitle,
                        subtitle: WLProductCopy.Home.sampleReadsSubtitle,
                        systemImage: "sparkles"
                    )

                    Spacer()

                    WLIcon(
                        systemName: isExpanded ? "chevron.up" : "chevron.down",
                        color: WLPalette.inkSoft,
                        size: 14
                    )
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                ForEach(packs) { pack in
                    HomeSampleReadPackCard(
                        pack: pack,
                        runScenario: runScenario
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }
}

private struct HomeSampleReadPackCard: View {
    let pack: DemoScenarioPack
    let runScenario: (DemoScenario) -> Void

    var body: some View {
        WLCompactCard {
            VStack(alignment: .leading, spacing: WLSpacing.m) {
                Label(pack.title, systemImage: pack.icon)
                    .font(WLTypography.bodyEmphasis)
                    .foregroundStyle(WLPalette.ink)

                Text(pack.subtitle)
                    .font(WLTypography.caption)
                    .foregroundStyle(WLPalette.inkSoft)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: WLSpacing.s) {
                        ForEach(pack.scenarios) { scenario in
                            Button(action: { runScenario(scenario) }) {
                                VStack(alignment: .leading, spacing: WLSpacing.s) {
                                    Text(scenario.title)
                                        .font(WLTypography.bodyEmphasis)
                                        .foregroundStyle(WLPalette.ink)
                                        .multilineTextAlignment(.leading)

                                    Text(scenario.subtitle)
                                        .font(WLTypography.caption)
                                        .foregroundStyle(WLPalette.inkSoft)
                                        .multilineTextAlignment(.leading)

                                    Spacer(minLength: 0)

                                    WLStatusBadge(
                                        title: scenario.expectedLensBias.title,
                                        systemImage: scenario.expectedLensBias.icon,
                                        tone: .accent
                                    )
                                }
                                .frame(width: 212)
                                .frame(minHeight: 160, alignment: .leading)
                                .padding(WLSpacing.m)
                                .background(
                                    RoundedRectangle(cornerRadius: WLCorner.m, style: .continuous)
                                        .fill(
                                            LinearGradient(
                                                colors: [Color.white.opacity(0.98), WLPalette.canvasWarm],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: WLCorner.m, style: .continuous)
                                        .stroke(WLPalette.stroke)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }
}

#Preview("Home") {
    NavigationStack {
        HomeView()
            .environment(AppModel())
    }
}
