import XCTest
@testable import CruzadorCore

final class InstallerTests: XCTestCase {
    func root() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return root
    }
    func testPEBoundsModesAndMetadataChangesAreValidated() throws {
        let root = try root(), exe = root.appendingPathComponent("Setup.exe")
        var bytes = Data(repeating: 0, count: 70); bytes[0] = 0x4d; bytes[1] = 0x5a; bytes[0x3c] = 64
        bytes.replaceSubrange(64..<70, with: [0x50, 0x45, 0, 0, 0x64, 0x86])
        try bytes.write(to: exe)
        let inspection = try WindowsFileInspection.inspect(path: exe.path)
        XCTAssertEqual(inspection.peMachine, 0x8664)
        XCTAssertThrowsError(try InstallationRequest(inspection: inspection, mode: .quiet))
        bytes[0x3c] = 255; try bytes.write(to: exe)
        XCTAssertThrowsError(try WindowsFileInspection.inspect(path: exe.path))
        XCTAssertThrowsError(try inspection.validateCurrentMetadata())
        try Data("not executable".utf8).write(to: exe)
        XCTAssertThrowsError(try WindowsFileInspection.inspect(path: exe.path))
    }
    func testMSIArgumentsAndFailedResultAreRecordedWithoutClaimingInstallation() async throws {
        let root = try root(), store = LibraryStore(root: root.appendingPathComponent("library"))
        let wine = root.appendingPathComponent("wine")
        try "#!/bin/sh\nprintf '%s\\n' \"$@\"\nexit 194\n".write(to: wine, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: wine.path)
        let msi = root.appendingPathComponent("Package with spaces.msi")
        try Data([0xd0, 0xcf, 0x11, 0xe0, 0xa1, 0xb1, 0x1a, 0xe1]).write(to: msi)
        var bottle = Bottle(name: "Installer", engine: Engine(kind: .wine, path: wine.path)); bottle.state = .ready
        let prefix = store.prefix(for: bottle)
        try FileManager.default.createDirectory(at: prefix.appendingPathComponent("drive_c"), withIntermediateDirectories: true)
        try Data().write(to: prefix.appendingPathComponent("system.reg"))
        var library = Library(); library.bottles = [bottle]; try store.save(library)
        let request = try InstallationRequest(path: msi.path, mode: .quiet, arguments: ["PROPERTY=two words"])
        let plan = try EngineCommands.make(.install(request), bottle: bottle, store: store)
        XCTAssertEqual(plan.primary.arguments.suffix(2), ["/qn", "PROPERTY=two words"])
        XCTAssertEqual(plan.primary.workingDirectory?.path, root.path)
        let service = InstallationService(store: store)
        do {
            _ = try await service.run(request, bottle: bottle, runner: CommandRunner(), log: store.logsRoot.appendingPathComponent("install.log"))
            XCTFail("A nonzero Unix status must not imply successful installation or reboot")
        } catch CommandRunnerError.failed {}
        let record = try XCTUnwrap(try store.load().bottles[0].installations?.first)
        XCTAssertEqual(record.status, .unconfirmed); XCTAssertEqual(record.macOSExitCode, 194)
        XCTAssertNotNil(record.finishedAt); XCTAssertEqual(record.phases?.first?.exitCode, 194)
        library = try store.load(); library.bottles[0].installations?[0].status = .running; library.bottles[0].installations?[0].finishedAt = nil; library.bottles[0].installations?[0].macOSExitCode = nil; try store.save(library)
        try service.recoverInterrupted()
        XCTAssertEqual(try store.load().bottles[0].installations?[0].status, .interrupted)
        let saved = try Data(contentsOf: store.manifest); try service.recoverInterrupted()
        XCTAssertEqual(try Data(contentsOf: store.manifest), saved)
    }
}
