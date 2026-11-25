import XCTest
@testable import CruzadorCore

final class BottleMaintenanceTests: XCTestCase {
    func fixture(serverExit: Int = 0) throws -> (BottleMaintenance, Bottle) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        for name in ["wine", "wineserver"] {
            let path = root.appendingPathComponent(name)
            try "#!/bin/sh\nexit \(name == "wineserver" ? serverExit : 0)\n".write(to: path, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path.path)
        }
        let store = LibraryStore(root: root.appendingPathComponent("library"))
        var bottle = Bottle(name: "Source", engine: Engine(kind: .wine, path: root.appendingPathComponent("wine").path))
        let prefix = store.prefix(for: bottle)
        try FileManager.default.createDirectory(at: prefix.appendingPathComponent("drive_c"), withIntermediateDirectories: true)
        try Data("registry".utf8).write(to: prefix.appendingPathComponent("system.reg"))
        try Data("user data".utf8).write(to: prefix.appendingPathComponent("drive_c/test.exe"))
        try FileManager.default.createSymbolicLink(atPath: prefix.appendingPathComponent("local-link").path, withDestinationPath: prefix.appendingPathComponent("drive_c").path)
        try FileManager.default.createSymbolicLink(atPath: prefix.appendingPathComponent("external-link").path, withDestinationPath: "/")
        bottle.state = .ready; bottle.apps = [WindowsApp(name: "App", path: prefix.appendingPathComponent("drive_c/test.exe").path, options: LaunchOptions(workingDirectory: prefix.appendingPathComponent("drive_c").path))]
        bottle.configuration = BottleSettings(executionOptions: LaunchOptions(workingDirectory: prefix.appendingPathComponent("drive_c").path, environment: ["VALUE": "literal"]))
        var library = Library(); library.bottles = [bottle]; try store.save(library)
        return (BottleMaintenance(store: store, runner: CommandRunner()), bottle)
    }
    func testRenameDuplicateExportImportAndRecoverableRemoval() async throws {
        let (maintenance, bottle) = try fixture()
        try maintenance.rename(id: bottle.id, name: "../ 日本語")
        XCTAssertEqual(try maintenance.store.load().bottles[0].id, bottle.id)
        let copy = try await maintenance.duplicate(id: bottle.id, name: "Copy")
        XCTAssertNotEqual(copy.id, bottle.id)
        let prefix = maintenance.store.prefix(for: copy)
        XCTAssertEqual(copy.apps[0].path, prefix.appendingPathComponent("drive_c/test.exe").path)
        XCTAssertEqual(copy.apps[0].options?.workingDirectory, prefix.appendingPathComponent("drive_c").path)
        XCTAssertEqual(copy.requestedSettings.executionOptions.workingDirectory, prefix.appendingPathComponent("drive_c").path)
        XCTAssertEqual(copy.requestedSettings.executionOptions.environment, ["VALUE": "literal"])
        XCTAssertEqual(try FileManager.default.destinationOfSymbolicLink(atPath: prefix.appendingPathComponent("local-link").path), prefix.appendingPathComponent("drive_c").path)
        XCTAssertEqual(try FileManager.default.destinationOfSymbolicLink(atPath: prefix.appendingPathComponent("external-link").path), "/")
        do {
            try await maintenance.export(id: copy.id, destination: prefix.appendingPathComponent("recursive.cruzadorbottle"))
            XCTFail("Export into its own prefix must fail")
        } catch {}
        let package = maintenance.store.root.appendingPathComponent("backup.cruzadorbottle")
        try await maintenance.export(id: copy.id, destination: package)
        let imported = try maintenance.importBottle(from: package, engine: bottle.engine)
        XCTAssertEqual(imported.state, .interrupted)
        XCTAssertEqual(imported.requestedSettings.executionOptions.workingDirectory, maintenance.store.prefix(for: imported).appendingPathComponent("drive_c").path)
        XCTAssertEqual(maintenance.store.health(of: imported), .initialized)
        var preferred = try maintenance.store.load()
        preferred.preferences.defaultBottleID = copy.id
        try maintenance.store.save(preferred)
        let recovery = try await maintenance.remove(id: copy.id)
        XCTAssertNil(try maintenance.store.load().preferences.defaultBottleID)
        XCTAssertFalse(try maintenance.store.load().bottles.contains { $0.id == copy.id })
        XCTAssertFalse(FileManager.default.fileExists(atPath: prefix.path))
        XCTAssertEqual(try Data(contentsOf: recovery.appendingPathComponent("Prefix/drive_c/test.exe")), Data("user data".utf8))
        let restored = try maintenance.importBottle(from: recovery, engine: bottle.engine)
        XCTAssertEqual(maintenance.store.health(of: restored), .initialized)
        XCTAssertTrue(FileManager.default.fileExists(atPath: maintenance.store.prefix(for: bottle).path))
    }
    func testServerFailurePreventsCopyAndRemoval() async throws {
        let (maintenance, bottle) = try fixture(serverExit: 6)
        do { _ = try await maintenance.duplicate(id: bottle.id, name: "Copy"); XCTFail("Expected wait failure") } catch {}
        do { _ = try await maintenance.remove(id: bottle.id); XCTFail("Expected wait failure") } catch {}
        XCTAssertEqual(try maintenance.store.load().bottles.count, 1)
        XCTAssertEqual(maintenance.store.health(of: bottle), .initialized)
    }
    func testMalformedTransferCannotCreateRecord() throws {
        let (maintenance, bottle) = try fixture()
        let package = maintenance.store.root.appendingPathComponent("invalid.cruzadorbottle")
        try FileManager.default.createDirectory(at: package, withIntermediateDirectories: true)
        try Data("{}".utf8).write(to: package.appendingPathComponent("bottle.json"))
        XCTAssertThrowsError(try maintenance.importBottle(from: package, engine: bottle.engine))
        XCTAssertEqual(try maintenance.store.load().bottles.count, 1)
    }
}
