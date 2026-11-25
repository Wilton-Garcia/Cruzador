import XCTest
@testable import CruzadorCore

final class DiscoveryTests: XCTestCase {
    func testRegistryEscapesMalformedAndDuplicateValuesPreserveUnknowns() throws {
        let text = #"""
        WINE REGISTRY Version 2

        [Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\App] 123
        "DisplayName"="Caf\xe9 \xd83d\xde00"
        "InstallLocation"=str(2):"C:\\Program Files\\App\\"
        "Unsupported"=hex:01,02
        "Bad"="\xd800"
        "Duplicate"="first"
        "duplicate"="second"
        "unterminated
        "After"="valid"
        """#
        let document = WineRegistryDocument(text: text, selecting: { _ in true })
        let key = try XCTUnwrap(document.keys.first)
        XCTAssertEqual(key.path, #"Software\Microsoft\Windows\CurrentVersion\Uninstall\App"#)
        XCTAssertEqual(key.string(named: "DisplayName"), "Café 😀")
        XCTAssertEqual(key.string(named: "InstallLocation"), #"C:\Program Files\App\"#)
        XCTAssertNil(key.string(named: "Bad")); XCTAssertNil(key.string(named: "Duplicate"))
        XCTAssertEqual(key.string(named: "After"), "valid")
        XCTAssertEqual(key.values.first(where: { $0.name == "Unsupported" })?.raw, "hex:01,02")
        XCTAssertTrue(key.values.contains(where: { $0.type == "malformed" && $0.raw.contains("d800") }))
        XCTAssertEqual(document.warnings.count, 3)
    }
    func testFileDiscoverySkipsLinksAndAddsOnlySelectedUnchangedCandidates() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let store = LibraryStore(root: root.appendingPathComponent("library"))
        let bottle = Bottle(name: "Discovery", engine: Engine(kind: .wine, path: "/selected/wine"))
        let prefix = store.prefix(for: bottle), programs = prefix.appendingPathComponent("drive_c/Program Files/App")
        try FileManager.default.createDirectory(at: programs, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: prefix.appendingPathComponent("dosdevices"), withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(atPath: prefix.appendingPathComponent("dosdevices/c:").path, withDestinationPath: "../drive_c")
        var data = Data(repeating: 0, count: 70); data[0] = 0x4d; data[1] = 0x5a; data[0x3c] = 64
        data.replaceSubrange(64..<70, with: [0x50, 0x45, 0, 0, 0x64, 0x86])
        let exe = programs.appendingPathComponent("app.exe"); try data.write(to: exe)
        let outside = root.appendingPathComponent("outside"); try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        try data.write(to: outside.appendingPathComponent("hidden.exe"))
        try FileManager.default.createSymbolicLink(at: programs.appendingPathComponent("linked-directory"), withDestinationURL: outside)
        let registry = #"""
        WINE REGISTRY Version 2
        [Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\App] 123
        "DisplayName"="Registered application"
        "InstallLocation"="C:\\Program Files\\App\\"
        """#
        try registry.write(to: prefix.appendingPathComponent("system.reg"), atomically: true, encoding: .utf8)
        var library = Library(); library.bottles = [bottle]; try store.save(library)
        try Data("not a directory".utf8).write(to: prefix.appendingPathComponent("drive_c/Program Files (x86)"))
        let discovery = AppDiscovery(store: store), report = try discovery.scan(bottle)
        XCTAssertEqual(report.warnings.count, 1)
        XCTAssertFalse(report.absentRoots.contains(prefix.appendingPathComponent("drive_c/Program Files (x86)").path))
        XCTAssertEqual(report.executables.count, 1); XCTAssertEqual(report.registeredSoftware.count, 1)
        XCTAssertEqual(report.executables[0].registeredSoftwareIDs.count, 1)
        XCTAssertTrue(report.absentRoots.contains(prefix.appendingPathComponent("user.reg").path))
        try discovery.add(ids: [report.executables[0].id], from: report)
        try discovery.add(ids: [report.executables[0].id], from: report)
        XCTAssertEqual(try store.load().bottles[0].apps.count, 1)
        try Data("changed".utf8).write(to: exe)
        XCTAssertThrowsError(try discovery.add(ids: [report.executables[0].id], from: report))
        XCTAssertThrowsError(try discovery.add(ids: ["unknown"], from: report))
        XCTAssertEqual(try store.load().bottles[0].apps.count, 1)
    }
    func testUnknownRegistryFormatKeepsCoverageWarning() {
        let document = WineRegistryDocument(text: "Windows Registry Editor Version 5.00", selecting: { _ in true })
        XCTAssertTrue(document.keys.isEmpty); XCTAssertEqual(document.warnings.count, 1)
    }
    func testRealRetainedWinePrefixDiscovery() throws {
        guard let root = ProcessInfo.processInfo.environment["CRUZADOR_DISCOVERY_ROOT"] else { throw XCTSkip("Defina CRUZADOR_DISCOVERY_ROOT para observar uma bottle de teste já criada.") }
        let store = LibraryStore(root: URL(fileURLWithPath: root))
        let bottle = try XCTUnwrap(try store.load().bottles.first)
        let report = try AppDiscovery(store: store).scan(bottle)
        XCTAssertTrue(report.registeredSoftware.contains { $0.name?.contains("7-Zip") == true })
        XCTAssertTrue(report.executables.contains { $0.inspection.path.hasSuffix("/7z.exe") })
        XCTAssertTrue(report.executables.contains { $0.inspection.path.hasSuffix("/7zFM.exe") })
        let repository = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(report).write(to: repository.appendingPathComponent(".local/real-discovery.json"), options: .atomic)
    }
}
