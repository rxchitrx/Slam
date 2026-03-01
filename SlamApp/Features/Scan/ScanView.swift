import RoomPlan
import SwiftUI

struct ScanView: View {
    let onFinished: (ScanArtifact) -> Void
    let onClose: () -> Void

    @StateObject private var scanner = RoomScannerService()
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                RoomCaptureViewContainer(captureView: scanner.captureView)
                    .ignoresSafeArea()

                VStack {
                    statusCard
                    if scanner.scanState == .scanning && scanner.completionAssessment.shouldSuggestComplete {
                        suggestionBanner
                    }
                    Spacer()
                    instructionCard
                    controls
                }
                .padding(16)
            }
            .navigationTitle("Scan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        onClose()
                    }
                }
            }
            .alert("Scan Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        errorMessage = nil
                    }
                }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Unknown error")
            }
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("State: \(scanner.scanState.label)")
                .font(.headline)

            HStack {
                Text("Tracking: \(scanner.currentTelemetry.trackingState.rawValue.capitalized)")
                Spacer()
                Text("Elapsed: \(scanner.currentTelemetry.elapsedSeconds)s")
            }

            HStack {
                Text("Coverage: \(Int(scanner.currentTelemetry.coverage * 100))%")
                Spacer()
                Text("Confidence: \(Int(scanner.currentTelemetry.confidence * 100))%")
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var instructionCard: some View {
        Text(scanner.latestInstructionMessage)
            .font(.subheadline)
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button {
                startScan()
            } label: {
                Text("Start")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(scanner.scanState == .scanning || scanner.scanState == .stopping)

            Button {
                stopScan()
            } label: {
                Text("Stop")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(scanner.scanState != .scanning)
        }
        .padding(.top, 4)
    }

    private var suggestionBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(.green)
            Text("Coverage looks good. You can stop scanning now.")
                .font(.subheadline.weight(.medium))
            Spacer()
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func startScan() {
        do {
            try scanner.start()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func stopScan() {
        Task {
            do {
                let artifact = try await scanner.stop()
                onFinished(artifact)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

private extension ScanState {
    var label: String {
        switch self {
        case .idle:
            return "Idle"
        case .preparing:
            return "Preparing"
        case .scanning:
            return "Scanning"
        case .stopping:
            return "Stopping"
        case .completed:
            return "Completed"
        case .failed:
            return "Failed"
        }
    }
}
