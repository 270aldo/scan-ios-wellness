import Foundation

struct ScanVerdictRequest: Sendable {
    var input: ScanInput
    var legacyAnalysis: ScanAnalysis
    var structuredAnalysis: AnalysisEnvelope?
    var profile: UserProfile
    var recentScans: [ScanEvent]
    var recentCheckIns: [CheckInEvent]
    var biometrics: BiometricsSnapshot?
}

protocol ScanVerdictServing: Sendable {
    func generateVerdict(for request: ScanVerdictRequest) async -> LILADomain.ScanVerdict
}

struct DeterministicScanVerdictAgent: ScanVerdictServing {
    func generateVerdict(for request: ScanVerdictRequest) async -> LILADomain.ScanVerdict {
        let context = request.profile.lilaContext(biometrics: request.biometrics)
        let verdict: LILADomain.ScanVerdict

        if let structuredAnalysis = request.structuredAnalysis {
            verdict = structuredAnalysis.lilaVerdict(
                fallbackAnalysis: request.legacyAnalysis,
                context: context,
                biometrics: request.biometrics
            )
        } else {
            verdict = request.legacyAnalysis.lilaVerdict(
                context: context,
                biometrics: request.biometrics
            )
        }

        return enrich(
            verdict: verdict,
            recentScans: request.recentScans,
            recentCheckIns: request.recentCheckIns
        )
    }

    private func enrich(
        verdict: LILADomain.ScanVerdict,
        recentScans: [ScanEvent],
        recentCheckIns: [CheckInEvent]
    ) -> LILADomain.ScanVerdict {
        guard !recentScans.isEmpty || !recentCheckIns.isEmpty else {
            return verdict
        }

        var updated = verdict
        let historyNote = recentCheckIns.first.map {
            "Recent body signal: energy \($0.energy)/5, bloating \($0.bloating)/5."
        } ?? "Recent scan history is available for pattern-aware comparison."
        let historyFactor = LILADomain.UserHistoryFactor(
            pattern: historyNote,
            scansReferenced: min(recentScans.count, 5)
        )
        updated.reasoningBreakdown.userHistoryFactors = [historyFactor]
        updated.evidenceTier = .personalPattern
        return updated
    }
}
