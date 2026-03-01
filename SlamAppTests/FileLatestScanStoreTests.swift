@testable import SlamApp
import Foundation
import XCTest

final class FileLatestScanStoreTests: XCTestCase {
    func testSaveAndLoadLatestScan() throws {
        let tempRoot = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let sourceURL = tempRoot.appendingPathComponent("source-1.usdz")
        try Data([1, 2, 3]).write(to: sourceURL)

        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let metadata = ScanMetadata(
            roomDimensions: SIMD3<Float>(4, 3, 2),
            wallCount: 4,
            openingCount: 2,
            objectCount: 5,
            durationSeconds: 66,
            confidence: 0.8
        )

        let artifact = ScanArtifact(usdzURL: sourceURL, metadata: metadata, createdAt: createdAt)
        let store = FileLatestScanStore(baseDirectory: tempRoot)

        try store.saveLatest(artifact)
        let loaded = try store.loadLatest()

        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.metadata, metadata)
        XCTAssertEqual(loaded?.createdAt, createdAt)

        let latestURL = tempRoot.appendingPathComponent("LatestScan/latest.usdz")
        XCTAssertEqual(loaded?.usdzURL.path, latestURL.path)
        XCTAssertEqual(try Data(contentsOf: latestURL), Data([1, 2, 3]))
    }

    func testSaveReplacesPreviousLatestScan() throws {
        let tempRoot = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let firstURL = tempRoot.appendingPathComponent("source-1.usdz")
        let secondURL = tempRoot.appendingPathComponent("source-2.usdz")
        try Data([7, 7]).write(to: firstURL)
        try Data([9, 9]).write(to: secondURL)

        let store = FileLatestScanStore(baseDirectory: tempRoot)

        try store.saveLatest(
            ScanArtifact(
                usdzURL: firstURL,
                metadata: ScanMetadata(
                    roomDimensions: nil,
                    wallCount: 4,
                    openingCount: 1,
                    objectCount: 1,
                    durationSeconds: 40,
                    confidence: 0.6
                ),
                createdAt: Date(timeIntervalSince1970: 1)
            )
        )

        let replacementMetadata = ScanMetadata(
            roomDimensions: SIMD3<Float>(2, 2, 2),
            wallCount: 5,
            openingCount: 2,
            objectCount: 4,
            durationSeconds: 55,
            confidence: 0.9
        )
        try store.saveLatest(
            ScanArtifact(usdzURL: secondURL, metadata: replacementMetadata, createdAt: Date(timeIntervalSince1970: 2))
        )

        let loaded = try store.loadLatest()
        XCTAssertEqual(loaded?.metadata, replacementMetadata)

        let latestURL = tempRoot.appendingPathComponent("LatestScan/latest.usdz")
        XCTAssertEqual(try Data(contentsOf: latestURL), Data([9, 9]))
    }

    func testClearRemovesLatestScan() throws {
        let tempRoot = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let sourceURL = tempRoot.appendingPathComponent("source.usdz")
        try Data([1]).write(to: sourceURL)

        let store = FileLatestScanStore(baseDirectory: tempRoot)
        try store.saveLatest(
            ScanArtifact(
                usdzURL: sourceURL,
                metadata: ScanMetadata(roomDimensions: nil, wallCount: 4, openingCount: 1, objectCount: 1, durationSeconds: 30, confidence: 0.5),
                createdAt: Date()
            )
        )

        try store.clearLatest()
        XCTAssertNil(try store.loadLatest())
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
