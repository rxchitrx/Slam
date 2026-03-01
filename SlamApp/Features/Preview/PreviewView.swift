import SwiftUI

struct PreviewView: View {
    let artifact: ScanArtifact

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Preview placeholder")
                    .font(.headline)
                Text("Saved at: \(artifact.createdAt.formatted(date: .abbreviated, time: .shortened))")
                    .foregroundStyle(.secondary)
            }
            .padding(24)
            .navigationTitle("Preview")
        }
    }
}
