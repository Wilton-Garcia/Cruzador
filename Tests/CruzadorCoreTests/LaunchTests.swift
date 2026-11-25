import XCTest
@testable import CruzadorCore

final class LaunchTests: XCTestCase {
    func root() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return root
    }
    func testLaunchPreservesArgumentsWorkingDirectoryEnvironmentAndPrefix() async throws {
        let root = try root(); let wine = root.appendingPathComponent("wine")
        try "#!/bin/sh\nprintf '%s\\n' \"$PWD\" \"$APP_VALUE\" \"$WINEPREFIX\" \"$1\" \"$2\"\n".write(to: wine, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: wine.path)
        let program = root.appendingPathComponent("App with spaces.exe"); try Data().write(to: program)
        let options = try LaunchOptions.parse(workingDirectory: root.path, environmentJSON: #"{"APP_VALUE":"two words=a=b"}"#)
        let request = LaunchRequest(path: program.path, arguments: ["$(touch unwanted); literal"], options: options)
        let bottle = Bottle(name: "App", engine: Engine(kind: .wine, path: wine.path))
        let store = LibraryStore(root: root.appendingPathComponent("library"))
        let plan = try EngineCommands.make(.run(request), bottle: bottle, store: store)
        let result = try await CommandRunner().run(plan, log: root.appendingPathComponent("launch.log"))
        XCTAssertEqual(result.exitCode, 0)
        let output = try String(contentsOf: result.log, encoding: .utf8)
        let lines = output.components(separatedBy: "\n")
        let observed = try FileManager.default.attributesOfItem(atPath: lines[0])
        let chosen = try FileManager.default.attributesOfItem(atPath: root.path)
        XCTAssertEqual(observed[.systemFileNumber] as? NSNumber, chosen[.systemFileNumber] as? NSNumber)
        XCTAssertEqual(observed[.systemNumber] as? NSNumber, chosen[.systemNumber] as? NSNumber)
        XCTAssertEqual(plan.primary.workingDirectory?.path, root.path)
        XCTAssertEqual(lines.dropFirst().joined(separator: "\n"), "two words=a=b\n\(store.prefix(for: bottle).path)\n\(program.path)\n$(touch unwanted); literal\n")
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("unwanted").path))
        let app = WindowsApp(name: "App", path: request.path, arguments: request.arguments, options: options)
        let decoded = try JSONDecoder().decode(WindowsApp.self, from: JSONEncoder().encode(app))
        XCTAssertEqual(decoded.launchRequest, request)
    }
    func testInvalidOptionsDoNotOverrideIdentityOrLaunch() throws {
        for key in ["WINEPREFIX", "WINESERVER", "WINELOADER", "WINEDLLPATH", "CX_BOTTLE", "CX_BOTTLE_PATH"] {
            XCTAssertThrowsError(try LaunchOptions(environment: [key: "/other"]).validate())
        }
        XCTAssertThrowsError(try LaunchOptions(environment: ["A=B": "value"]).validate())
        XCTAssertThrowsError(try LaunchOptions.parse(workingDirectory: "relative", environmentJSON: "{}"))
        XCTAssertThrowsError(try LaunchOptions.parse(workingDirectory: "", environmentJSON: #"{"NUMBER":7}"#))
        XCTAssertThrowsError(try LaunchOptions.parse(workingDirectory: "", environmentJSON: "{broken"))
        let directory = (try root()).appendingPathComponent("directory.exe")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        XCTAssertThrowsError(try LaunchRequest(path: directory.path).validate())
    }
}
