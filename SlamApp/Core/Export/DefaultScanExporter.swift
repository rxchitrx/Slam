import Foundation

struct DefaultScanExporter: ScanExporter {
    func makeShareableCopy(from artifact: ScanArtifact) throws -> URL {
        throw ScanError.exportFailed("Not implemented yet.")
    }
}
