import Foundation
import simd

struct CompletionHeuristicResult {
    var assessment: CompletionAssessment
    var stabilityScore: Double
}

struct CompletionHeuristic {
    private var maxDimensionHistory: [Float] = []

    mutating func reset() {
        maxDimensionHistory.removeAll(keepingCapacity: true)
    }

    mutating func evaluate(
        wallCount: Int,
        estimatedDimensions: SIMD3<Float>?,
        trackingState: TrackingState,
        elapsedSeconds: Int
    ) -> CompletionHeuristicResult {
        if let estimatedDimensions {
            let horizontalMax = max(abs(estimatedDimensions.x), abs(estimatedDimensions.z))
            if horizontalMax > 0 {
                maxDimensionHistory.append(horizontalMax)
                if maxDimensionHistory.count > 3 {
                    maxDimensionHistory.removeFirst(maxDimensionHistory.count - 3)
                }
            }
        }

        let stability = computeStability()
        let isStable = stability >= 0.95

        var reasons: [String] = []
        if wallCount < 4 {
            reasons.append("Need more wall coverage")
        }
        if elapsedSeconds < 30 {
            reasons.append("Keep scanning for at least 30s")
        }
        if trackingState != .normal {
            reasons.append("Tracking needs to be normal")
        }
        if !isStable {
            reasons.append("Geometry is still changing")
        }

        let shouldSuggestComplete = reasons.isEmpty
        return CompletionHeuristicResult(
            assessment: CompletionAssessment(
                shouldSuggestComplete: shouldSuggestComplete,
                reasons: reasons
            ),
            stabilityScore: stability
        )
    }

    private func computeStability() -> Double {
        guard maxDimensionHistory.count >= 3,
              let minimum = maxDimensionHistory.min(),
              let maximum = maxDimensionHistory.max(),
              maximum > 0
        else {
            return 0.4
        }

        let variance = Double((maximum - minimum) / maximum)
        if variance <= 0.05 {
            return 1.0
        }

        return max(0, 1 - (variance / 0.20))
    }
}
