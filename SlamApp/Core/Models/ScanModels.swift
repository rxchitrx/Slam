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
    var floorPlan: FloorPlanData?
}

struct ScanArtifact: Equatable, Sendable {
    var usdzURL: URL
    var metadata: ScanMetadata
    var createdAt: Date
}

@MainActor
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
    func makeUSDZShareableCopy(from artifact: ScanArtifact) throws -> URL
    func makeFloorPlanPDF(from artifact: ScanArtifact) throws -> URL
}

struct FloorPlanData: Codable, Equatable, Sendable {
    var version: Int
    var unit: String
    var bounds: FloorPlanBounds
    var walls: [FloorPlanWallSegment]
    var openings: [FloorPlanOpening]
    var objects: [FloorPlanObject]
    var majorDimensions: [FloorPlanDimension]
    var renderDefaults: FloorPlanRenderDefaults
}

struct FloorPlanBounds: Codable, Equatable, Sendable {
    var minX: Float
    var minZ: Float
    var maxX: Float
    var maxZ: Float
}

struct FloorPlanWallSegment: Codable, Equatable, Sendable, Identifiable {
    var id: UUID
    var startX: Float
    var startZ: Float
    var endX: Float
    var endZ: Float
    var lengthMeters: Float

    var start: SIMD2<Float> {
        SIMD2(startX, startZ)
    }

    var end: SIMD2<Float> {
        SIMD2(endX, endZ)
    }
}

struct FloorPlanOpening: Codable, Equatable, Sendable, Identifiable {
    var id: UUID
    var kind: FloorPlanOpeningKind
    var centerX: Float
    var centerZ: Float
    var rotationRadians: Float
    var widthMeters: Float
    var depthMeters: Float
    var hostWallID: UUID?

    var center: SIMD2<Float> {
        SIMD2(centerX, centerZ)
    }
}

enum FloorPlanOpeningKind: String, Codable, Sendable {
    case door
    case window
    case opening
}

struct FloorPlanObject: Codable, Equatable, Sendable, Identifiable {
    var id: UUID
    var kind: FloorPlanObjectKind
    var label: String
    var centerX: Float
    var centerZ: Float
    var sizeX: Float
    var sizeZ: Float
    var rotationRadians: Float

    var center: SIMD2<Float> {
        SIMD2(centerX, centerZ)
    }

    var size: SIMD2<Float> {
        SIMD2(sizeX, sizeZ)
    }
}

enum FloorPlanObjectKind: String, Codable, Sendable {
    case storage
    case bed
    case chair
    case sofa
    case table
    case cabinet
    case appliance
    case toilet
    case sink
    case bathtub
    case refrigerator
    case stove
    case washerDryer
    case television
    case unknown
}

struct FloorPlanDimension: Codable, Equatable, Sendable, Identifiable {
    var id: UUID
    var startX: Float
    var startZ: Float
    var endX: Float
    var endZ: Float
    var text: String

    var start: SIMD2<Float> {
        SIMD2(startX, startZ)
    }

    var end: SIMD2<Float> {
        SIMD2(endX, endZ)
    }
}

struct FloorPlanRenderDefaults: Codable, Equatable, Sendable {
    var preferredPaddingMeters: Float
    var wallThicknessMeters: Float
    var openingStrokeMeters: Float
}
