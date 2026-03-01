import SwiftUI

struct ScanView: View {
    let onFinished: (ScanArtifact) -> Void
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Scan screen placeholder")
                    .font(.headline)
                Text("RoomPlan integration comes in Milestone 2")
                    .foregroundStyle(.secondary)
            }
            .padding(24)
            .navigationTitle("Scan")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        onClose()
                    }
                }
            }
        }
    }
}
