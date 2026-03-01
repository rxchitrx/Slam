import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var showScan = false
    @State private var showPreview = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Slam")
                    .font(.largeTitle.weight(.bold))

                Text("LiDAR room scan prototype")
                    .foregroundStyle(.secondary)

                Button("Start Room Scan") {
                    showScan = true
                }
                .buttonStyle(.borderedProminent)

                Button("Open Latest Scan") {
                    showPreview = true
                }
                .buttonStyle(.bordered)
                .disabled(appModel.latestScan == nil)

                if let latest = appModel.latestScan {
                    VStack(spacing: 8) {
                        Text("Latest saved scan")
                            .font(.headline)
                        Text(latest.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 12)
                }
            }
            .padding(24)
            .navigationTitle("Home")
            .fullScreenCover(isPresented: $showScan) {
                ScanView(
                    onFinished: { artifact in
                        appModel.handleCompletedScan(artifact)
                        showScan = false
                    },
                    onClose: {
                        showScan = false
                    }
                )
            }
            .sheet(isPresented: $showPreview) {
                if let artifact = appModel.latestScan {
                    PreviewView(
                        artifact: artifact,
                        exportAction: { scan in
                            try appModel.makeExportURL(for: scan)
                        }
                    )
                } else {
                    Text("No saved scan found.")
                }
            }
            .alert("Error", isPresented: Binding(
                get: { appModel.lastErrorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        appModel.lastErrorMessage = nil
                    }
                }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(appModel.lastErrorMessage ?? "Unknown error")
            }
        }
    }
}
