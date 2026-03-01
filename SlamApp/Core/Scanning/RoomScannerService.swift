import ARKit
import AVFoundation
import Combine
import Foundation
import RoomPlan
import UIKit

@MainActor
final class RoomScannerService: NSObject, ObservableObject, RoomScanning {
    @Published private(set) var scanState: ScanState = .idle
    @Published private(set) var currentTelemetry: ScanTelemetry = .empty
    @Published private(set) var latestInstructionMessage: String = "Move steadily around the room."

    lazy var captureView: RoomCaptureView = {
        let view = RoomCaptureView(frame: .zero)
        view.isModelEnabled = true
        view.captureSession.delegate = self
        return view
    }()

    var state: AnyPublisher<ScanState, Never> {
        $scanState.eraseToAnyPublisher()
    }

    var telemetry: AnyPublisher<ScanTelemetry, Never> {
        $currentTelemetry.eraseToAnyPublisher()
    }

    private let fileManager = FileManager.default

    private var startDate: Date?
    private var stopContinuation: CheckedContinuation<ScanArtifact, Error>?

    func start() throws {
        guard RoomCaptureSession.isSupported else {
            throw ScanError.unsupportedDevice
        }

        let permission = AVCaptureDevice.authorizationStatus(for: .video)
        if permission == .denied || permission == .restricted {
            throw ScanError.permissionDenied
        }

        guard scanState != .scanning, scanState != .stopping else {
            throw ScanError.alreadyScanning
        }

        scanState = .preparing
        currentTelemetry = .empty
        latestInstructionMessage = Self.instructionMessage(for: .normal)
        startDate = Date()

        var configuration = RoomCaptureSession.Configuration()
        configuration.isCoachingEnabled = true
        captureView.captureSession.run(configuration: configuration)

        scanState = .scanning
    }

    func stop() async throws -> ScanArtifact {
        guard scanState == .scanning else {
            throw ScanError.notScanning
        }

        guard stopContinuation == nil else {
            throw ScanError.captureFailed("Stop already in progress.")
        }

        scanState = .stopping
        return try await withCheckedThrowingContinuation { [weak self] continuation in
            guard let self else {
                continuation.resume(throwing: ScanError.unknown("Scanner unavailable."))
                return
            }

            self.stopContinuation = continuation
            self.captureView.captureSession.stop()
        }
    }

    private func finishStop(with result: Result<ScanArtifact, ScanError>) {
        let continuation = stopContinuation
        stopContinuation = nil

        switch result {
        case .success(let artifact):
            scanState = .completed
            continuation?.resume(returning: artifact)
        case .failure(let error):
            scanState = .failed(error)
            continuation?.resume(throwing: error)
        }
    }

    private func updateTelemetry(wallCount: Int, trackingState: TrackingState) {
        let elapsed = elapsedSeconds()
        let coverage = min(Double(wallCount) / 4.0, 1.0)
        let confidence = min(1, max(0, trackingState.score * 0.65 + coverage * 0.35))

        currentTelemetry = ScanTelemetry(
            trackingState: trackingState,
            coverage: coverage,
            confidence: confidence,
            elapsedSeconds: elapsed
        )
    }

    private func handleEnd(data: CapturedRoomData, error: Error?) async {
        if let error {
            finishStop(with: .failure(.captureFailed(error.localizedDescription)))
            return
        }

        do {
            let roomBuilder = RoomBuilder(options: [.beautifyObjects])
            let room = try await roomBuilder.capturedRoom(from: data)
            let artifact = try makeArtifact(from: room)
            finishStop(with: .success(artifact))
        } catch {
            finishStop(with: .failure(.processingFailed(error.localizedDescription)))
        }
    }

    private func makeArtifact(from room: CapturedRoom) throws -> ScanArtifact {
        let outputDirectory = fileManager.temporaryDirectory.appendingPathComponent("SlamScans", isDirectory: true)
        try fileManager.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        let usdzURL = outputDirectory.appendingPathComponent("scan-\(UUID().uuidString).usdz")
        do {
            try room.export(to: usdzURL, exportOptions: [.model, .mesh])
        } catch {
            throw ScanError.exportFailed(error.localizedDescription)
        }

        let metadata = ScanMetadata(
            roomDimensions: estimateRoomDimensions(from: room),
            wallCount: room.walls.count,
            openingCount: room.openings.count,
            objectCount: room.objects.count,
            durationSeconds: elapsedSeconds(),
            confidence: currentTelemetry.confidence
        )

        return ScanArtifact(usdzURL: usdzURL, metadata: metadata, createdAt: Date())
    }

    private func estimateRoomDimensions(from room: CapturedRoom) -> SIMD3<Float>? {
        guard let floor = room.floors.first else {
            return nil
        }

        let wallHeight = room.walls.map { $0.dimensions.y }.max() ?? 0
        return SIMD3(
            abs(floor.dimensions.x),
            max(abs(wallHeight), abs(floor.dimensions.y)),
            abs(floor.dimensions.z)
        )
    }

    private func elapsedSeconds() -> Int {
        guard let startDate else { return 0 }
        return max(0, Int(Date().timeIntervalSince(startDate)))
    }

    nonisolated private static func mapTrackingState(_ state: ARCamera.TrackingState?) -> TrackingState {
        guard let state else {
            return .unavailable
        }

        switch state {
        case .normal:
            return .normal
        case .notAvailable:
            return .unavailable
        case .limited:
            return .limited
        }
    }

    nonisolated private static func instructionMessage(for instruction: RoomCaptureSession.Instruction) -> String {
        switch instruction {
        case .normal:
            return "Move steadily around the room."
        case .moveCloseToWall:
            return "Move closer to the wall for better detail."
        case .moveAwayFromWall:
            return "Move slightly away from the wall."
        case .slowDown:
            return "Slow down your movement to improve tracking."
        case .turnOnLight:
            return "Lighting is low. Turn on more lights if possible."
        case .lowTexture:
            return "Point at textured surfaces to improve tracking."
        @unknown default:
            return "Continue scanning the room."
        }
    }
}

extension RoomScannerService: RoomCaptureSessionDelegate {
    nonisolated func captureSession(_ session: RoomCaptureSession, didUpdate room: CapturedRoom) {
        let wallCount = room.walls.count
        let trackingState = Self.mapTrackingState(session.arSession.currentFrame?.camera.trackingState)
        Task { @MainActor in
            self.updateTelemetry(wallCount: wallCount, trackingState: trackingState)
        }
    }

    nonisolated func captureSession(_ session: RoomCaptureSession, didProvide instruction: RoomCaptureSession.Instruction) {
        let message = Self.instructionMessage(for: instruction)
        Task { @MainActor in
            self.latestInstructionMessage = message
        }
    }

    nonisolated func captureSession(_ session: RoomCaptureSession, didEndWith data: CapturedRoomData, error: Error?) {
        Task { @MainActor in
            await self.handleEnd(data: data, error: error)
        }
    }
}

private extension TrackingState {
    var score: Double {
        switch self {
        case .normal:
            return 1.0
        case .limited:
            return 0.55
        case .unavailable:
            return 0.2
        }
    }
}
