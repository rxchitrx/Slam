import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var latestScan: ScanArtifact?
    @Published var lastErrorMessage: String?

    private let latestScanStore: LatestScanStore
    private let scanExporter: ScanExporter

    init(latestScanStore: LatestScanStore, scanExporter: ScanExporter) {
        self.latestScanStore = latestScanStore
        self.scanExporter = scanExporter
        loadLatestScan()
    }

    func loadLatestScan() {
        do {
            latestScan = try latestScanStore.loadLatest()
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func handleCompletedScan(_ artifact: ScanArtifact) {
        do {
            try latestScanStore.saveLatest(artifact)
            latestScan = try latestScanStore.loadLatest()
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func clearLatestScan() {
        do {
            try latestScanStore.clearLatest()
            latestScan = nil
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func makeUSDZExportURL(for artifact: ScanArtifact) throws -> URL {
        try scanExporter.makeUSDZShareableCopy(from: artifact)
    }

    func makeFloorPlanPDFURL(for artifact: ScanArtifact) throws -> URL {
        try scanExporter.makeFloorPlanPDF(from: artifact)
    }
}
