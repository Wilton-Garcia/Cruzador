import XCTest
@testable import CruzadorCore

extension BottleMaintenanceTests {
    func toolComponents(_ names: [String], bottle: Bottle, store: LibraryStore) throws -> URL {
        let system = store.prefix(for: bottle).appendingPathComponent("drive_c/windows/system32")
        try FileManager.default.createDirectory(at: system, withIntermediateDirectories: true)
        var pe = Data(repeating: 0, count: 70); pe[0] = 0x4d; pe[1] = 0x5a; pe[0x3c] = 64; pe.replaceSubrange(64..<70, with: [0x50, 0x45, 0, 0, 0x64, 0x86])
        for name in names { try pe.write(to: system.appendingPathComponent(name)) }
        return system
    }
    func testGameControllerPlanUsesItsOwnPanelAndRejectsMissingOrMalformedComponents() throws {
        let (maintenance, bottle) = try fixture(), store = maintenance.store
        XCTAssertThrowsError(try EngineCommands.make(.tool(.gameControllers), bottle: bottle, store: store))
        let system = try toolComponents(["control.exe", "joy.cpl"], bottle: bottle, store: store)
        let plan = try EngineCommands.make(.tool(.gameControllers), bottle: bottle, store: store)
        XCTAssertEqual(plan.primary.executable.path, bottle.engine.path)
        XCTAssertEqual(plan.primary.arguments, [system.appendingPathComponent("control.exe").path, "joy.cpl"])
        XCTAssertEqual(plan.primary.environment["WINEPREFIX"], store.prefix(for: bottle).path)
        XCTAssertEqual(plan.cancellation.map(\.arguments), [["-k"], ["-w"]])
        try Data("malformed".utf8).write(to: system.appendingPathComponent("joy.cpl"))
        XCTAssertThrowsError(try EngineCommands.make(.tool(.gameControllers), bottle: bottle, store: store))
        _ = try toolComponents(["joy.cpl"], bottle: bottle, store: store)
        let handle = try FileHandle(forWritingTo: system.appendingPathComponent("joy.cpl")); try handle.seek(toOffset: 68); try handle.write(contentsOf: Data([0x4c, 0x01])); try handle.close()
        XCTAssertThrowsError(try EngineCommands.make(.tool(.gameControllers), bottle: bottle, store: store))
    }
}

extension BottleMaintenanceTests {
    func testTaskManagerPlanIsScopedToTheRequestedBottle() throws {
        let (maintenance, bottle) = try fixture(), store = maintenance.store
        let system = try toolComponents(["taskmgr.exe"], bottle: bottle, store: store)
        let other = Bottle(name: "Other", engine: bottle.engine)
        let plan = try EngineCommands.make(.tool(.taskManager), bottle: bottle, store: store)
        XCTAssertEqual(plan.primary.arguments, [system.appendingPathComponent("taskmgr.exe").path])
        XCTAssertEqual(plan.primary.environment["WINEPREFIX"], store.prefix(for: bottle).path)
        XCTAssertThrowsError(try EngineCommands.make(.tool(.taskManager), bottle: other, store: store))
    }
}
