import Combine
import Foundation
import simd

enum TrackingState: String, Codable, Sendable {
    case normal
    case limited
    case unavailable
}

enum ScanError: Error, LocalizedError, Equatable, Sendable {
    case unsupportedDevice
    case permissionDenied
    case alreadyScanning
    case notScanning
    case captureFailed(String)
    case processingFailed(String)
    case exportFailed(String)
    case persistenceFailed(String)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedDevice:
            return "This iPhone does not support LiDAR room capture."
        case .permissionDenied:
            return "Camera access is required to scan a room."
        case .alreadyScanning:
            return "A scan is already in progress."
        case .notScanning:
            return "No active scan to stop."
        case .captureFailed(let message):
            return "Room capture failed: \(message)"
        case .processingFailed(let message):
            return "Room processing failed: \(message)"
        case .exportFailed(let message):
            return "USDZ export failed: \(message)"
        case .persistenceFailed(let message):
            return "Storage failed: \(message)"
        case .unknown(let message):
            return "Unexpected error: \(message)"
        }
    }
}

enum ScanState: Equatable, Sendable {
    case idle
    case preparing
    case scanning
    case stopping
    case completed
    case failed(ScanError)
}

struct ScanTelemetry: Equatable, Sendable {
    var trackingState: TrackingState
    var coverage: Double
    var confidence: Double
    var elapsedSeconds: Int

    static let empty = ScanTelemetry(
        trackingState: .unavailable,
        coverage: 0,
        confidence: 0,
        elapsedSeconds: 0
    )
}

struct CompletionAssessment: Equatable, Sendable {
    var shouldSuggestComplete: Bool
    var reasons: [String]

    static let empty = CompletionAssessment(shouldSuggestComplete: false, reasons: [])
}

struct ScanMetadata: Codable, Equatable, Sendable {
    var roomDimensions: SIMD3<Float>?
    var wallCount: Int
    var openingCount: Int
    var objectCount: Int
    var durationSeconds: Int
    var confidence: Double
}

struct ScanArtifact: Equatable, Sendable {
    var usdzURL: URL
    var metadata: ScanMetadata
    var createdAt: Date
}

protocol RoomScanning: AnyObject {
    func start() throws
    func stop() async throws -> ScanArtifact

    var state: AnyPublisher<ScanState, Never> { get }
    var telemetry: AnyPublisher<ScanTelemetry, Never> { get }
}

protocol LatestScanStore {
    func saveLatest(_ artifact: ScanArtifact) throws
    func loadLatest() throws -> ScanArtifact?
    func clearLatest() throws
}

protocol ScanExporter {
    func makeShareableCopy(from artifact: ScanArtifact) throws -> URL
}
