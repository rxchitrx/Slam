import SwiftUI

@main
struct SlamAppApp: App {
    @StateObject private var appModel = AppEnvironment.makeAppModel()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(appModel)
        }
    }
}
