import Foundation

struct DefaultScanExporter: ScanExporter {
    private let fileManager: FileManager
    private let exportDirectory: URL?

    init(fileManager: FileManager = .default, exportDirectory: URL? = nil) {
        self.fileManager = fileManager
        self.exportDirectory = exportDirectory
    }

    func makeShareableCopy(from artifact: ScanArtifact) throws -> URL {
        guard fileManager.fileExists(atPath: artifact.usdzURL.path) else {
            throw ScanError.exportFailed("USDZ file is missing.")
        }

        let directory = try resolvedExportDirectory()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let timestamp = Self.timestampFormatter.string(from: Date())
        let destination = directory.appendingPathComponent("slam-scan-\(timestamp).usdz")

        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }

        do {
            try fileManager.copyItem(at: artifact.usdzURL, to: destination)
        } catch {
            throw ScanError.exportFailed(error.localizedDescription)
        }

        return destination
    }

    private func resolvedExportDirectory() throws -> URL {
        if let exportDirectory {
            return exportDirectory
        }

        let root = try fileManager.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return root.appendingPathComponent("Exports", isDirectory: true)
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()
}
