import XCTest
@testable import CruzadorCore

final class LibraryMigrationTests: XCTestCase {
    func store() throws -> LibraryStore {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return LibraryStore(root: root)
    }
    func testVersionOneMigrationPreservesExactBackupAndIsIdempotent() throws {
        let store = try store()
        let original = Data("{\n  \"version\": 1, \"bottles\": []\n}\n".utf8)
        try original.write(to: store.manifest)
        try store.migrateIfNeeded()
        XCTAssertEqual(try store.load().version, 4)
        let backup = store.root.appendingPathComponent("library-v1.json.bak")
        XCTAssertEqual(try Data(contentsOf: backup), original)
        let migrated = try Data(contentsOf: store.manifest)
        try store.migrateIfNeeded()
        XCTAssertEqual(try Data(contentsOf: store.manifest), migrated)
        try store.save(Library())
        XCTAssertEqual(try Data(contentsOf: backup), original)
    }
    func testUnknownVersionAndInvalidOutgoingMetadataNeverOverwrite() throws {
        let store = try store()
        let unknown = Data("{\"version\":99,\"bottles\":[]}".utf8)
        try unknown.write(to: store.manifest)
        XCTAssertThrowsError(try store.migrateIfNeeded())
        XCTAssertThrowsError(try store.save(Library()))
        XCTAssertEqual(try Data(contentsOf: store.manifest), unknown)
        try FileManager.default.removeItem(at: store.manifest)
        var invalid = Library(); invalid.preferences.defaultBottleID = UUID()
        XCTAssertThrowsError(try store.save(invalid))
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.manifest.path))
        let bottle = Bottle(name: "Duplicate", engine: Engine(kind: .wine, path: "/chosen/wine"))
        invalid.preferences.defaultBottleID = nil; invalid.bottles = [bottle, bottle]
        XCTAssertThrowsError(try store.save(invalid))
    }
    func testDefaultBottleSurvivesRoundTrip() throws {
        let store = try store(); var library = Library()
        let bottle = Bottle(name: "Default", engine: Engine(kind: .wine, path: "/chosen/wine"))
        library.bottles = [bottle]; library.preferences.defaultBottleID = bottle.id
        try store.save(library)
        XCTAssertEqual(try store.load().preferences.defaultBottleID, bottle.id)
    }
}
