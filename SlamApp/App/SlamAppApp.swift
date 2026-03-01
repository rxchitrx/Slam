import Foundation
import SwiftUI

@main
struct SlamAppApp: App {
    init() {
        // RoomPlan + RealityKit can hit Metal debug-layer assertions on some
        // iOS 26.x / Xcode 26 debug runs. Force-disable Metal validation for
        // this app process to keep capture responsive.
        setenv("MTL_DEBUG_LAYER", "0", 1)
        setenv("METAL_DEVICE_WRAPPER_TYPE", "0", 1)
        setenv("MTL_SHADER_VALIDATION", "0", 1)
    }

    @StateObject private var appModel = AppEnvironment.makeAppModel()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(appModel)
        }
    }
}
