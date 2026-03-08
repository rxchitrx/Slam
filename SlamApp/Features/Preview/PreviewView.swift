import SceneKit
import SwiftUI

enum PreviewMode: String, CaseIterable, Identifiable {
    case model3D
    case floorPlan2D

    var id: String { rawValue }
}

struct PreviewView: View {
    struct SharePayload: Identifiable {
        let id = UUID()
        let url: URL
    }

    let artifact: ScanArtifact
    let exportUSDZAction: (ScanArtifact) throws -> URL
    let exportPDFAction: (ScanArtifact) throws -> URL

    @State private var previewMode: PreviewMode = .model3D
    @State private var quickLookPresented = false
    @State private var sharePayload: SharePayload?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                modePicker
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                previewContent
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                metadataCard
                actionButtons
            }
            .padding(16)
            .navigationTitle("Preview")
            .fullScreenCover(isPresented: $quickLookPresented) {
                ZStack {
                    QuickLookPreview(url: artifact.usdzURL)
                    
                    VStack {
                        HStack {
                            Spacer()
                            Button {
                                quickLookPresented = false
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title)
                                    .foregroundColor(.white)
                                    .shadow(radius: 4)
                            }
                            .padding()
                        }
                        Spacer()
                    }
                }
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
            .onAppear {
                determineDefaultMode()
            }
        }
    }

    private var modePicker: some View {
        Picker("Preview Mode", selection: $previewMode) {
            Text("3D").tag(PreviewMode.model3D)
            Text("2D Plan").tag(PreviewMode.floorPlan2D)
        }
        .pickerStyle(.segmented)
    }

    private var previewContent: some View {
        Group {
            switch previewMode {
            case .model3D:
                model3DView
            case .floorPlan2D:
                floorPlan2DView
            }
        }
    }

    private var model3DView: some View {
        Group {
            if let scene = try? SCNScene(url: artifact.usdzURL, options: nil) {
                SceneView(
                    scene: scene,
                    options: [.allowsCameraControl, .autoenablesDefaultLighting]
                )
            } else {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.quaternary)
                    .overlay {
                        Text("Unable to load in-app 3D preview.")
                            .foregroundStyle(.secondary)
                    }
            }
        }
    }

    private var floorPlan2DView: some View {
        Group {
            if let floorPlan = artifact.metadata.floorPlan {
                FloorPlanView(plan: floorPlan)
            } else {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.quaternary)
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: "map")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text("2D floor plan unavailable for this scan.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("The room geometry could not be processed.")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding()
                    }
            }
        }
    }

    private var metadataCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Saved: \(artifact.createdAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.headline)

            if let dimensions = artifact.metadata.roomDimensions {
                Text("Room: \(String(format: "%.2f", dimensions.x))m × \(String(format: "%.2f", dimensions.z))m")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text("Walls: \(artifact.metadata.wallCount), Openings: \(artifact.metadata.openingCount), Objects: \(artifact.metadata.objectCount)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
                Text("Confidence: \(Int(artifact.metadata.confidence * 100))%")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if artifact.metadata.floorPlan != nil {
                    Spacer()
                    Text("2D plan available")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }

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
        VStack(spacing: 12) {
            Button {
                quickLookPresented = true
            } label: {
                Text("Quick Look")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            HStack(spacing: 12) {
                Button {
                    exportUSDZ()
                } label: {
                    Text("Export USDZ")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    exportPDF()
                } label: {
                    Text("Export PDF Plan")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(artifact.metadata.floorPlan == nil)
            }
        }
    }

    private func determineDefaultMode() {
        do {
            _ = try SCNScene(url: artifact.usdzURL, options: nil)
        } catch {
            if artifact.metadata.floorPlan != nil {
                previewMode = .floorPlan2D
            }
        }
    }

    private func exportUSDZ() {
        do {
            let url = try exportUSDZAction(artifact)
            sharePayload = SharePayload(url: url)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func exportPDF() {
        do {
            let url = try exportPDFAction(artifact)
            sharePayload = SharePayload(url: url)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}