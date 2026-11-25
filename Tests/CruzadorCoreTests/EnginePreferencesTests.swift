import XCTest
@testable import CruzadorCore

final class EnginePreferencesTests: XCTestCase {
    func preferences() throws -> UserDefaults {
        let name = "CruzadorTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        addTeardownBlock { UserDefaults(suiteName: name)?.removePersistentDomain(forName: name) }
        return defaults
    }
    func testNewLibrarySelectsOnlyBundledRuntime() throws {
        let defaults = try preferences()
        let root = URL(fileURLWithPath: "/Custom Cruzador.app/Contents/Resources/Runtime")
        XCTAssertEqual(try EnginePreferences.load(from: defaults, bundledRoot: root), Engine(kind: .packagedWine, path: root.path))
        XCTAssertNil(defaults.object(forKey: "enginePath"))
    }
    func testExistingExplicitSelectionIsPreserved() throws {
        let defaults = try preferences()
        let selected = Engine(kind: .crossOver, path: "/Custom Location/CrossOver.app")
        defaults.set(selected.kind.rawValue, forKey: "engineKind")
        defaults.set(selected.path, forKey: "enginePath")
        XCTAssertEqual(try EnginePreferences.load(from: defaults), selected)
        defaults.set("future-engine", forKey: "engineKind")
        XCTAssertThrowsError(try EnginePreferences.load(from: defaults))
        XCTAssertEqual(defaults.string(forKey: "enginePath"), selected.path)
        XCTAssertEqual(defaults.string(forKey: "engineKind"), "future-engine")
    }
    func testIncompletePreferencesAreNotCombinedWithDefaults() throws {
        let defaults = try preferences()
        defaults.set("/old/selected/path", forKey: "enginePath")
        XCTAssertThrowsError(try EnginePreferences.load(from: defaults))
        XCTAssertThrowsError(try EnginePreferences.save(Engine(kind: .wine, path: "relative"), to: defaults))
        XCTAssertEqual(defaults.string(forKey: "enginePath"), "/old/selected/path")
        XCTAssertNil(defaults.string(forKey: "engineKind"))
        defaults.removeObject(forKey: "enginePath")
        defaults.set(["unexpected"], forKey: "engineKind")
        XCTAssertThrowsError(try EnginePreferences.load(from: defaults))
    }
    func testVersionedSelectionPreservesLegacyBackupAndDoesNotFallBack() throws {
        let defaults = try preferences()
        defaults.set("crossOver", forKey: "engineKind")
        defaults.set("/Selected/CrossOver.app", forKey: "enginePath")
        let selected = Engine(kind: .packagedWine, path: "/Own/Runtime")
        try EnginePreferences.save(selected, to: defaults)
        XCTAssertEqual(try EnginePreferences.load(from: defaults), selected)
        let backup = try XCTUnwrap(defaults.data(forKey: "engineSelectionLegacyBackup"))
        let original = try PropertyListSerialization.propertyList(from: backup, format: nil) as? [String: String]
        XCTAssertEqual(original?["enginePath"], "/Selected/CrossOver.app")
        try EnginePreferences.save(selected, to: defaults)
        XCTAssertNil(defaults.object(forKey: "engineSelectionBackup"))
        defaults.set(Data("{broken".utf8), forKey: "engineSelection")
        XCTAssertThrowsError(try EnginePreferences.load(from: defaults))
        try EnginePreferences.save(selected, to: defaults)
        XCTAssertNotNil(defaults.object(forKey: "engineSelectionBackup"))
        XCTAssertEqual(defaults.data(forKey: "engineSelectionLegacyBackup"), backup)
    }

}
