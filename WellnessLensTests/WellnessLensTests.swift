import XCTest
@testable import WellnessLens

final class WellnessLensTests: XCTestCase {
    func testDemoScenarioCatalogShipsThreePacks() {
        XCTAssertEqual(DemoScenarioCatalog.packs.count, 3)
        XCTAssertEqual(DemoScenarioCatalog.packs.map(\.kind), [.food, .supplement, .skincarePersonalCare])
        XCTAssertTrue(DemoScenarioCatalog.packs.allSatisfy { !$0.scenarios.isEmpty })
    }

    func testEnergyDrinkScoresPoorlyForEnergyAndHormones() async throws {
        let service = DemoScanService()
        let result = try await service.analyze(
            input: ScanInput(
                sourceType: .manualBarcode,
                barcode: "850000002",
                capturedImageRef: nil,
                rawText: nil,
                productTypeHint: nil,
                locale: "en_US"
            ),
            userContext: .starter
        )

        let energyScore = result.lensScores.first(where: { $0.lens == .energyMood })?.score ?? 0
        let hormoneScore = result.lensScores.first(where: { $0.lens == .hormoneBalance })?.score ?? 0

        XCTAssertLessThan(energyScore, 55)
        XCTAssertLessThan(hormoneScore, 55)
        XCTAssertFalse(result.alternatives.isEmpty)
    }

    func testBarrierSerumScoresWellForGlowSkin() async throws {
        let service = DemoScanService()
        let result = try await service.analyze(
            input: ScanInput(
                sourceType: .manualBarcode,
                barcode: "850000006",
                capturedImageRef: nil,
                rawText: nil,
                productTypeHint: nil,
                locale: "en_US"
            ),
            userContext: .starter
        )

        let glowScore = result.lensScores.first(where: { $0.lens == .glowSkin })?.score ?? 0
        XCTAssertGreaterThan(glowScore, 80)
        XCTAssertTrue(result.topReasons.contains(where: { $0.impact == .positive }))
    }

    func testSkincareLabelScenarioResolvesToGlowFriendlyRead() async throws {
        let service = DemoScanService()
        let scenario = try XCTUnwrap(DemoScenarioCatalog.scenario(id: "topical-serum-label"))
        let result = try await service.analyze(
            input: scenario.scanInput,
            userContext: .starter
        )

        let glowScore = result.lensScores.first(where: { $0.lens == .glowSkin })?.score ?? 0
        XCTAssertGreaterThan(glowScore, 75)
        XCTAssertEqual(result.source, .manualLabel)
    }

    func testWeeklyInsightEngineHighlightsSoftGutWindow() async throws {
        let service = DemoScanService()
        let result = try await service.analyze(
            input: ScanInput(
                sourceType: .manualBarcode,
                barcode: "850000002",
                capturedImageRef: nil,
                rawText: nil,
                productTypeHint: nil,
                locale: "en_US"
            ),
            userContext: .starter
        )

        let history = [ScanRecord(createdAt: .now, analysis: result)]
        let checkIns = [
            CheckInEntry(createdAt: .now, energy: 2, skin: 3, bloatingRelief: 2, cravingControl: 2, mood: 3, note: "Rough week")
        ]
        let insights = WeeklyInsightEngine().generate(history: history, checkIns: checkIns)

        XCTAssertFalse(insights.isEmpty)
        XCTAssertTrue(insights.contains(where: { $0.title.localizedCaseInsensitiveContains("gut") || $0.summary.localizedCaseInsensitiveContains("energy") }))
    }
}
