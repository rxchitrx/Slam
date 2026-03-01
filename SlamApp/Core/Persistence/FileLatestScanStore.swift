import Foundation

struct FileLatestScanStore: LatestScanStore {
    func saveLatest(_ artifact: ScanArtifact) throws {
        throw ScanError.persistenceFailed("Not implemented yet.")
    }

    func loadLatest() throws -> ScanArtifact? {
        nil
    }

    func clearLatest() throws {
    }
}
