import Foundation

struct FileLatestScanStore: LatestScanStore {
    private struct StoredLatestScan: Codable {
        var metadata: ScanMetadata
        var createdAt: Date
    }

    private let fileManager: FileManager
    private let baseDirectory: URL?

    init(fileManager: FileManager = .default, baseDirectory: URL? = nil) {
        self.fileManager = fileManager
        self.baseDirectory = baseDirectory
    }

    func saveLatest(_ artifact: ScanArtifact) throws {
        let directory = try latestDirectoryURL()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let sourceUSDZ = artifact.usdzURL
        guard fileManager.fileExists(atPath: sourceUSDZ.path) else {
            throw ScanError.persistenceFailed("Source USDZ file does not exist.")
        }

        let stagingUSDZ = directory.appendingPathComponent(".tmp-\(UUID().uuidString).usdz")
        let latestUSDZ = directory.appendingPathComponent("latest.usdz")

        try copyToStaging(source: sourceUSDZ, staging: stagingUSDZ)

        if fileManager.fileExists(atPath: latestUSDZ.path) {
            try fileManager.removeItem(at: latestUSDZ)
        }
        try fileManager.moveItem(at: stagingUSDZ, to: latestUSDZ)

        let record = StoredLatestScan(metadata: artifact.metadata, createdAt: artifact.createdAt)
        let payload = try JSONEncoder().encode(record)
        try payload.write(to: metadataURL(in: directory), options: .atomic)
    }

    func loadLatest() throws -> ScanArtifact? {
        let directory = try latestDirectoryURL()
        let latestUSDZ = directory.appendingPathComponent("latest.usdz")
        let metadataURL = metadataURL(in: directory)

        guard fileManager.fileExists(atPath: latestUSDZ.path),
              fileManager.fileExists(atPath: metadataURL.path)
        else {
            return nil
        }

        let payload = try Data(contentsOf: metadataURL)
        let record = try JSONDecoder().decode(StoredLatestScan.self, from: payload)
        return ScanArtifact(usdzURL: latestUSDZ, metadata: record.metadata, createdAt: record.createdAt)
    }

    func clearLatest() throws {
        let directory = try latestDirectoryURL()
        guard fileManager.fileExists(atPath: directory.path) else {
            return
        }
        try fileManager.removeItem(at: directory)
    }

    private func latestDirectoryURL() throws -> URL {
        let rootDirectory: URL
        if let baseDirectory {
            rootDirectory = baseDirectory
        } else {
            rootDirectory = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
        }

        return rootDirectory.appendingPathComponent("LatestScan", isDirectory: true)
    }

    private func metadataURL(in latestDirectory: URL) -> URL {
        latestDirectory.appendingPathComponent("latest-metadata.json")
    }

    private func copyToStaging(source: URL, staging: URL) throws {
        do {
            if fileManager.fileExists(atPath: staging.path) {
                try fileManager.removeItem(at: staging)
            }
            try fileManager.copyItem(at: source, to: staging)
        } catch {
            throw ScanError.persistenceFailed(error.localizedDescription)
        }
    }
}
