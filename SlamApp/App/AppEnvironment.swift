import Foundation

enum AppEnvironment {
    @MainActor
    static func makeAppModel() -> AppModel {
        let scanStore = FileLatestScanStore()
        let exporter = DefaultScanExporter()
        return AppModel(latestScanStore: scanStore, scanExporter: exporter)
    }
}
