import XCTest
import Darwin
@testable import CruzadorCore

final class DiagnosticsTests: XCTestCase {
    func root() throws -> URL {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: path) }
        return path
    }
    func testMalformedLibraryExportKeepsExactSourceAndUnknownFacts() throws {
        let root = try root(), store = LibraryStore(root: root.appendingPathComponent("library")); try store.prepare()
        let original = Data("{broken\n日本語".utf8); try original.write(to: store.manifest)
        let service = DiagnosticsService(store: store), capture = service.capture()
        XCTAssertEqual(capture.report.libraryStatus, "invalid"); XCTAssertNil(capture.report.bottles)
        XCTAssertEqual(capture.sourceLibrary, original); XCTAssertNotNil(capture.report.libraryError)
        let destination = root.appendingPathComponent("support.cruzadordiagnostics")
        try service.export(to: destination, includeSourceLibrary: true)
        XCTAssertEqual(try Data(contentsOf: destination.appendingPathComponent("source-library.json")), original)
        XCTAssertEqual(try Data(contentsOf: store.manifest), original)
        let report = try readReport(destination)
        XCTAssertTrue(report.sourceLibraryIncluded); XCTAssertFalse(report.logsIncluded)
        XCTAssertThrowsError(try service.export(to: destination))
        XCTAssertThrowsError(try service.export(to: store.root.appendingPathComponent("recursive")))
        XCTAssertThrowsError(try store.load())
    }
    func readReport(_ destination: URL) throws -> DiagnosticsReport {
        // Dates in the public JSON use ISO-8601. Decode through the same documented strategy.
        let source = try Data(contentsOf: destination.appendingPathComponent("report.json"))
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(DiagnosticsReport.self, from: source)
    }
    func testExportDefaultsOmitRawLibraryAndLogsAndNeverFollowExternalLinks() throws {
        let root = try root(), store = LibraryStore(root: root.appendingPathComponent("library")); try store.save(Library())
        let own = Data("own log\n".utf8); try own.write(to: store.logsRoot.appendingPathComponent("run.log"))
        let external = root.appendingPathComponent("outside.txt"); try Data("outside must stay outside".utf8).write(to: external)
        try FileManager.default.createSymbolicLink(at: store.logsRoot.appendingPathComponent("external.log"), withDestinationURL: external)
        let service = DiagnosticsService(store: store), minimal = root.appendingPathComponent("minimal")
        try service.export(to: minimal)
        XCTAssertFalse(FileManager.default.fileExists(atPath: minimal.appendingPathComponent("source-library.json").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: minimal.appendingPathComponent("Logs").path))
        let full = root.appendingPathComponent("with-logs"); try service.export(to: full, includeLogs: true)
        let report = try readReport(full)
        XCTAssertEqual(report.logs.first(where: { $0.source.hasSuffix("/run.log") })?.status, "copied")
        XCTAssertNotNil(report.logs.first(where: { $0.source.hasSuffix("/run.log") })?.sha256)
        XCTAssertEqual(report.logs.first(where: { $0.source.hasSuffix("/external.log") })?.status, "skipped")
        XCTAssertEqual(try Data(contentsOf: full.appendingPathComponent("Logs/run.log")), own)
        XCTAssertFalse(FileManager.default.fileExists(atPath: full.appendingPathComponent("Logs/external.log").path))
        XCTAssertEqual(try String(contentsOf: external, encoding: .utf8), "outside must stay outside")
    }
    func testUnreadableLibraryAndRegistryRemainUnknownRatherThanAbsent() async throws {
        guard geteuid() != 0 else { throw XCTSkip("Permission boundary requires an unprivileged user") }
        let root = try root(), store = LibraryStore(root: root.appendingPathComponent("library"))
        var bottle = Bottle(name: "Permissions", engine: Engine(kind: .wine, path: "/missing/wine")); bottle.state = .ready
        var library = Library(); library.bottles = [bottle]; try store.save(library)
        let prefix = store.prefix(for: bottle)
        try FileManager.default.createDirectory(at: prefix.appendingPathComponent("drive_c"), withIntermediateDirectories: true)
        let registry = prefix.appendingPathComponent("system.reg"); try Data("registry".utf8).write(to: registry)
        XCTAssertTrue(store.isReady(bottle))
        try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: registry.path)
        if case .unknown = store.health(of: bottle) {} else { XCTFail("An unreadable registry has unknown availability") }
        XCTAssertFalse(store.isReady(bottle))
        let service = DiagnosticsService(store: store)
        XCTAssertEqual(service.capture().report.bottles?[0].prefixStatus, "unknown")
        let log = store.logsRoot.appendingPathComponent("must-not-start.log")
        do { _ = try await BottleLifecycle(store: store).prepare(id: bottle.id, mode: .initialize, runner: CommandRunner(), log: log); XCTFail("Unknown file availability cannot start preparation") }
        catch { XCTAssertTrue(error.localizedDescription.contains(registry.path)) }
        XCTAssertFalse(FileManager.default.fileExists(atPath: log.path))
        try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: store.manifest.path)
        XCTAssertThrowsError(try store.observe()); XCTAssertThrowsError(try store.load())
        let unreadable = service.capture()
        XCTAssertEqual(unreadable.report.libraryStatus, "unreadable"); XCTAssertNil(unreadable.report.bottles)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: store.manifest.path)
        XCTAssertEqual(service.capture().report.libraryStatus, "valid")
    }
    func testRetainedRuntimeDiagnosticExport() throws {
        guard let path = ProcessInfo.processInfo.environment["CRUZADOR_DIAGNOSTICS_ROOT"] else { throw XCTSkip("Defina CRUZADOR_DIAGNOSTICS_ROOT para observar um prefixo real retido sem executá-lo.") }
        let store = LibraryStore(root: URL(fileURLWithPath: path))
        let bottle = try XCTUnwrap(try store.load().bottles.first)
        let destination = store.root.deletingLastPathComponent().appendingPathComponent("diagnostics-\(UUID())")
        let before = try Data(contentsOf: store.manifest)
        try DiagnosticsService(store: store).export(to: destination, bottleID: bottle.id, includeSourceLibrary: true, includeLogs: true)
        let report = try readReport(destination)
        XCTAssertEqual(report.libraryStatus, "valid")
        XCTAssertEqual(report.bottles?.first?.prefixStatus, "initialized")
        XCTAssertEqual(report.bottles?.first?.runtimeStatus, "manifest-validated")
        XCTAssertEqual(try Data(contentsOf: destination.appendingPathComponent("source-library.json")), before)
        XCTAssertEqual(try Data(contentsOf: store.manifest), before)
        XCTAssertTrue(report.logs.contains { $0.status == "copied" }); XCTAssertFalse(report.logs.contains { $0.status == "failed" })
        print("CRUZADOR_DIAGNOSTICS_EXPORT=\(destination.path)")
    }
}
