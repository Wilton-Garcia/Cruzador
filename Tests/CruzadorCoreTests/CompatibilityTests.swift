import XCTest
@testable import CruzadorCore

final class CompatibilityTests: XCTestCase {
    func testManualReportIdentifiesExecutableAndExportsAndArchivesWithoutDeletingHistory() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let library = LibraryStore(root: root), reports = CompatibilityStore(library: library)
        XCTAssertEqual(try reports.reports().count, 0)
        try library.prepare()
        var pe = Data(repeating: 0, count: 70); pe[0] = 0x4d; pe[1] = 0x5a; pe[0x3c] = 64; pe.replaceSubrange(64..<70, with: [0x50, 0x45, 0, 0, 0x64, 0x86])
        let file = root.appendingPathComponent("test.exe"); try pe.write(to: file)
        var bottle = Bottle(name: "Test", engine: Engine(kind: .wine, path: "/selected/wine"))
        let app = WindowsApp(name: "Windows app", path: file.path); bottle.apps = [app]
        var data = Library(); data.bottles = [bottle]; try library.save(data)
        let report = try reports.record(bottleID: bottle.id, appID: app.id, appVersion: "1.0", result: .limited, notes: "Opens; printing not tested")
        XCTAssertEqual(report.executableSHA256, try ArtifactCache.sha256(of: file)); XCTAssertNil(report.runtimeVersion)
        XCTAssertEqual(report.observationKind, "manual-user-observation")
        XCTAssertEqual(try reports.reports().map(\.id), [report.id])
        let exported = root.appendingPathComponent("matrix.json"); try reports.export(to: exported)
        let matrix = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: exported)) as? [String: Any])
        XCTAssertEqual((matrix["reports"] as? [[String: Any]])?.first?["notes"] as? String, report.notes)
        XCTAssertThrowsError(try reports.export(to: exported))
        try reports.archive(id: report.id); XCTAssertTrue(try reports.reports().isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: reports.root.appendingPathComponent("Archived/\(report.id).json").path))
        XCTAssertThrowsError(try reports.record(bottleID: bottle.id, appID: UUID(), appVersion: "1", result: .works, notes: "stale app"))
        XCTAssertThrowsError(try reports.record(bottleID: bottle.id, appID: app.id, appVersion: " ", result: .works, notes: "empty version"))
    }
    func testMalformedReportsAreNotPresentedAsNoRatings() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let store = CompatibilityStore(library: LibraryStore(root: root))
        try FileManager.default.createDirectory(at: store.root, withIntermediateDirectories: true)
        let file = store.root.appendingPathComponent(UUID().uuidString + ".json")
        try Data("invalid".utf8).write(to: file)
        XCTAssertThrowsError(try store.reports())
        XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), "invalid")
    }
}
