@testable import SlamApp
import XCTest

final class CompletionHeuristicTests: XCTestCase {
    func testSuggestsCompletionWhenConditionsAreMet() {
        var heuristic = CompletionHeuristic()
        let dimensions = SIMD3<Float>(4.0, 2.8, 3.2)

        _ = heuristic.evaluate(
            wallCount: 4,
            estimatedDimensions: dimensions,
            trackingState: .normal,
            elapsedSeconds: 10
        )
        _ = heuristic.evaluate(
            wallCount: 4,
            estimatedDimensions: SIMD3<Float>(4.02, 2.8, 3.18),
            trackingState: .normal,
            elapsedSeconds: 32
        )
        let result = heuristic.evaluate(
            wallCount: 4,
            estimatedDimensions: SIMD3<Float>(4.01, 2.8, 3.19),
            trackingState: .normal,
            elapsedSeconds: 40
        )

        XCTAssertTrue(result.assessment.shouldSuggestComplete)
        XCTAssertTrue(result.assessment.reasons.isEmpty)
        XCTAssertGreaterThan(result.stabilityScore, 0.9)
    }

    func testDoesNotSuggestCompletionWhenTrackingIsLimited() {
        var heuristic = CompletionHeuristic()
        let dimensions = SIMD3<Float>(4.0, 2.8, 3.2)

        _ = heuristic.evaluate(
            wallCount: 4,
            estimatedDimensions: dimensions,
            trackingState: .limited,
            elapsedSeconds: 40
        )
        _ = heuristic.evaluate(
            wallCount: 4,
            estimatedDimensions: dimensions,
            trackingState: .limited,
            elapsedSeconds: 45
        )
        let result = heuristic.evaluate(
            wallCount: 4,
            estimatedDimensions: dimensions,
            trackingState: .limited,
            elapsedSeconds: 50
        )

        XCTAssertFalse(result.assessment.shouldSuggestComplete)
        XCTAssertTrue(result.assessment.reasons.contains("Tracking needs to be normal"))
    }

    func testStabilityDropsWhenGeometryChangesTooMuch() {
        var heuristic = CompletionHeuristic()

        _ = heuristic.evaluate(
            wallCount: 4,
            estimatedDimensions: SIMD3<Float>(3.5, 2.8, 3.0),
            trackingState: .normal,
            elapsedSeconds: 35
        )
        _ = heuristic.evaluate(
            wallCount: 4,
            estimatedDimensions: SIMD3<Float>(4.5, 2.8, 3.8),
            trackingState: .normal,
            elapsedSeconds: 40
        )
        let result = heuristic.evaluate(
            wallCount: 4,
            estimatedDimensions: SIMD3<Float>(5.5, 2.8, 4.5),
            trackingState: .normal,
            elapsedSeconds: 45
        )

        XCTAssertFalse(result.assessment.shouldSuggestComplete)
        XCTAssertTrue(result.assessment.reasons.contains("Geometry is still changing"))
        XCTAssertLessThan(result.stabilityScore, 0.95)
    }
}
