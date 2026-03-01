import RoomPlan
import SwiftUI

struct RoomCaptureViewContainer: UIViewRepresentable {
    let captureView: RoomCaptureView

    func makeUIView(context: Context) -> RoomCaptureView {
        captureView
    }

    func updateUIView(_ uiView: RoomCaptureView, context: Context) {
    }
}
