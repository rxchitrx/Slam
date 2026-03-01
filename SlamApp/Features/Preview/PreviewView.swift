import SceneKit
import SwiftUI

struct PreviewView: View {
    struct SharePayload: Identifiable {
        let id = UUID()
        let url: URL
    }

    let artifact: ScanArtifact
    let exportAction: (ScanArtifact) throws -> URL

    @State private var quickLookPresented = false
    @State private var sharePayload: SharePayload?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                if let scene = try? SCNScene(url: artifact.usdzURL, options: nil) {
                    SceneView(
                        scene: scene,
                        options: [.allowsCameraControl, .autoenablesDefaultLighting]
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.quaternary)
                        .overlay {
                            Text("Unable to load in-app 3D preview.")
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                metadataCard
                actionButtons
            }
            .padding(16)
            .navigationTitle("Preview")
            .sheet(isPresented: $quickLookPresented) {
                QuickLookPreview(url: artifact.usdzURL)
            }
            .sheet(item: $sharePayload) { payload in
                ShareSheet(activityItems: [payload.url])
            }
            .alert("Preview Error", isPresented: Binding(
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

    private var metadataCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Saved: \(artifact.createdAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.headline)
            Text("Walls: \(artifact.metadata.wallCount), Openings: \(artifact.metadata.openingCount), Objects: \(artifact.metadata.objectCount)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Confidence: \(Int(artifact.metadata.confidence * 100))%")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if artifact.metadata.confidence < 0.55 {
                Label("Low confidence scan. Re-scan slowly for better geometry.", systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                quickLookPresented = true
            } label: {
                Text("Quick Look")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button {
                exportUSDZ()
            } label: {
                Text("Export USDZ")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func exportUSDZ() {
        do {
            let url = try exportAction(artifact)
            sharePayload = SharePayload(url: url)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
