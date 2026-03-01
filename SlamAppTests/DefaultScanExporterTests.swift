@testable import SlamApp
import XCTest

final class DefaultScanExporterTests: XCTestCase {
    func testExporterCreatesShareableCopy() throws {
        let tempRoot = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let sourceURL = tempRoot.appendingPathComponent("source.usdz")
        try Data([4, 5, 6]).write(to: sourceURL)

        let exporter = DefaultScanExporter(exportDirectory: tempRoot.appendingPathComponent("exports"))
        let artifact = ScanArtifact(
            usdzURL: sourceURL,
            metadata: ScanMetadata(roomDimensions: nil, wallCount: 4, openingCount: 0, objectCount: 0, durationSeconds: 30, confidence: 0.7),
            createdAt: Date()
        )

        let exportedURL = try exporter.makeShareableCopy(from: artifact)
        XCTAssertTrue(FileManager.default.fileExists(atPath: exportedURL.path))
        XCTAssertEqual(try Data(contentsOf: exportedURL), Data([4, 5, 6]))
        XCTAssertNotEqual(exportedURL.path, sourceURL.path)
    }

    func testExporterThrowsForMissingSourceFile() throws {
        let tempRoot = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let exporter = DefaultScanExporter(exportDirectory: tempRoot)
        let missingSource = tempRoot.appendingPathComponent("missing.usdz")
        let artifact = ScanArtifact(
            usdzURL: missingSource,
            metadata: ScanMetadata(roomDimensions: nil, wallCount: 0, openingCount: 0, objectCount: 0, durationSeconds: 0, confidence: 0),
            createdAt: Date()
        )

        XCTAssertThrowsError(try exporter.makeShareableCopy(from: artifact))
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
