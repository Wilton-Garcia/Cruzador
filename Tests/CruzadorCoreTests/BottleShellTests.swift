import XCTest
@testable import CruzadorCore

extension BottleMaintenanceTests {
    func testShellPreservesLiteralOptionsAndSelectsOnlyItsBottleAndWine() async throws {
        let (maintenance, original) = try fixture()
        let store = maintenance.store
        var library = try store.load()
        library.bottles[0].configuration?.executionOptions.environment["CRUZADOR_LITERAL"] = "quote' $(touch should-not-exist); literal"
        try store.save(library)
        let script = try BottleShell.prepare(bottle: library.bottles[0], store: store)
        let process = Process(), input = Pipe(), output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh"); process.arguments = [script.path]
        process.standardInput = input; process.standardOutput = output; process.standardError = output
        process.environment = ["HOME": store.root.path, "USER": "fixture", "LOGNAME": "fixture", "TERM": "dumb", "TMPDIR": store.root.path, "WINEPREFIX": "/wrong", "CX_BOTTLE": "foreign", "CRUZADOR_AMBIENT": "do-not-retain"]
        try process.run()
        try input.fileHandleForWriting.write(contentsOf: Data("printf '%s\\n' \"$WINEPREFIX\" \"$CRUZADOR_WINE\" \"$CRUZADOR_LITERAL\" \"${CX_BOTTLE-unset}\" \"${CRUZADOR_AMBIENT-unset}\" \"$PWD\"\nexit\n".utf8))
        try input.fileHandleForWriting.close()
        for _ in 0..<500 { if !process.isRunning { break }; try await Task.sleep(for: .milliseconds(10)) }
        if process.isRunning { process.terminate(); process.waitUntilExit(); XCTFail("Shell did not finish") }
        process.waitUntilExit()
        let text = String(decoding: try output.fileHandleForReading.readToEnd() ?? Data(), as: UTF8.self)
        XCTAssertEqual(process.terminationStatus, 0)
        XCTAssertTrue(text.contains(store.prefix(for: original).path))
        XCTAssertTrue(text.contains(original.engine.path))
        XCTAssertTrue(text.contains("quote' $(touch should-not-exist); literal"))
        XCTAssertEqual(text.components(separatedBy: "unset").count - 1, 2)
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.prefix(for: original).appendingPathComponent("drive_c/should-not-exist").path))
    }
}
