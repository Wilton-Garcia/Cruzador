import XCTest
@testable import CruzadorCore

final class GraphicsTests: XCTestCase {
    func package() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        for name in ["wine", "wineserver"] {
            let file = root.appendingPathComponent("bin/" + name)
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try "#!/bin/sh\nprintf '%s' \"$WINE_D3D_CONFIG\"\n".write(to: file, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: file.path)
        }
        try Data("Fixture license".utf8).write(to: root.appendingPathComponent("LICENSE"))
        let manifest = WineRuntimeManifest(version: "11.21", sourceURL: "https://example.invalid/fixture", sourceRevision: "fixture", architectures: ["x86_64"], licenseFiles: ["LICENSE"])
        try JSONEncoder().encode(manifest).write(to: root.appendingPathComponent("runtime.json"))
        for architecture in ["x86_64-windows", "i386-windows"] {
            var bytes = Data(repeating: 0, count: 70); bytes[0] = 0x4d; bytes[1] = 0x5a; bytes[0x3c] = 64
            bytes.replaceSubrange(64..<70, with: architecture == "x86_64-windows" ? [0x50, 0x45, 0, 0, 0x64, 0x86] : [0x50, 0x45, 0, 0, 0x4c, 0x01])
            for name in ["wined3d.dll", "winevulkan.dll"] {
                let file = root.appendingPathComponent("lib/wine/\(architecture)/\(name)")
                try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true); try bytes.write(to: file)
            }
        }
        let icd = root.appendingPathComponent("share/vulkan/icd.d/MoltenVK_icd.json")
        try FileManager.default.createDirectory(at: icd.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("driver fixture, not a real GPU driver".utf8).write(to: root.appendingPathComponent("lib/libMoltenVK.dylib"))
        try Data(#"{"file_format_version":"1.0.0","ICD":{"library_path":"../../../lib/libMoltenVK.dylib","api_version":"1.4.0"}}"#.utf8).write(to: icd)
        return root
    }
    func testGraphicsRequestsPersistAndShortcutOverrideRemainsExplicit() async throws {
        let root = try package(), store = LibraryStore(root: root.appendingPathComponent("data"))
        let engine = Engine(kind: .packagedWine, path: root.path)
        let bottle = Bottle(name: "Graphics", engine: engine)
        var library = Library(); library.bottles = [bottle]; try store.save(library)
        let settings = BottleSettings(graphics: .vulkan)
        try await BottleSettingsStore(store: store).save(settings, bottleID: bottle.id, runner: CommandRunner())
        let saved = try store.load().bottles[0]
        XCTAssertEqual(saved.requestedSettings.graphics, .vulkan)
        let plan = try EngineCommands.make(.tool(.wineConfiguration), bottle: saved, store: store)
        XCTAssertEqual(plan.primary.environment["WINE_D3D_CONFIG"], "renderer=vulkan")
        let result = try await CommandRunner().run(plan, log: root.appendingPathComponent("graphics.log"))
        XCTAssertEqual(try String(contentsOf: result.log, encoding: .utf8), "renderer=vulkan")
        let program = root.appendingPathComponent("app.exe"); try Data().write(to: program)
        let request = LaunchRequest(path: program.path, options: LaunchOptions(environment: ["WINE_D3D_CONFIG": "renderer=gl,csmt=0"]))
        let overridden = try EngineCommands.make(.run(request), bottle: saved, store: store)
        XCTAssertEqual(overridden.primary.environment["WINE_D3D_CONFIG"], "renderer=gl,csmt=0")
        XCTAssertNil(overridden.cancellation.first?.environment["WINE_D3D_CONFIG"])
    }
    func testMissingOrEscapedGraphicsComponentsNeverBecomeAvailable() throws {
        let root = try package(), engine = Engine(kind: .packagedWine, path: root.path)
        XCTAssertTrue(GraphicsConfiguration.inspect(.vulkan, engine: engine).requestSupported)
        try FileManager.default.removeItem(at: root.appendingPathComponent("lib/wine/i386-windows/wined3d.dll"))
        let missing = GraphicsConfiguration.inspect(.vulkan, engine: engine)
        XCTAssertFalse(missing.requestSupported); XCTAssertFalse(missing.componentPaths.isEmpty)
        XCTAssertThrowsError(try GraphicsConfiguration.environment(backend: .vulkan, engine: engine, explicitOverride: nil))
        XCTAssertEqual(try GraphicsConfiguration.environment(backend: .automatic, engine: engine, explicitOverride: nil), [:])
        let valid = try package(), icd = valid.appendingPathComponent("share/vulkan/icd.d/MoltenVK_icd.json")
        try Data(#"{"file_format_version":"1.0.0","ICD":{"library_path":"../../../../../outside.dylib","api_version":"1.4.0"}}"#.utf8).write(to: icd)
        XCTAssertFalse(GraphicsConfiguration.inspect(.vulkan, engine: Engine(kind: .packagedWine, path: valid.path)).requestSupported)
    }
    func testCleanupDoesNotDependOnBrokenGraphicsConfiguration() throws {
        let root = try package(), store = LibraryStore(root: root.appendingPathComponent("data"))
        var bottle = Bottle(name: "Broken graphics", engine: Engine(kind: .packagedWine, path: root.path)); bottle.configuration = BottleSettings(graphics: .vulkan)
        try FileManager.default.removeItem(at: root.appendingPathComponent("lib/libMoltenVK.dylib"))
        XCTAssertThrowsError(try EngineCommands.make(.tool(.wineConfiguration), bottle: bottle, store: store))
        XCTAssertNoThrow(try EngineCommands.make(.waitForIdle, bottle: bottle, store: store))
    }
    func testRealRuntimeGraphicsRequestsAndFrameProbe() async throws {
        guard let rootPath = ProcessInfo.processInfo.environment["CRUZADOR_GRAPHICS_ROOT"], let probePath = ProcessInfo.processInfo.environment["CRUZADOR_D3D9_PROBE"] else { throw XCTSkip("Defina CRUZADOR_GRAPHICS_ROOT e CRUZADOR_D3D9_PROBE para testar o motor próprio com a prova 3D própria.") }
        let store = LibraryStore(root: URL(fileURLWithPath: rootPath))
        var bottle = try XCTUnwrap(try store.load().bottles.first)
        guard bottle.engine.kind == .packagedWine else { throw CruzadorError.invalid("O cenário exige o pacote Wine próprio.") }
        let output = store.root.appendingPathComponent("graphics-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let runner = CommandRunner()
        var observations: [[String: Any]] = []
        for backend in [GraphicsBackend.openGL, .vulkan] {
            let support = GraphicsConfiguration.inspect(backend, engine: bottle.engine)
            XCTAssertTrue(support.requestSupported, support.reason)
            bottle.configuration = BottleSettings(graphics: backend)
            let cmd = store.prefix(for: bottle).appendingPathComponent("drive_c/windows/system32/cmd.exe")
            let echo = try EngineCommands.make(.run(LaunchRequest(path: cmd.path, arguments: ["/c", "echo", "%WINE_D3D_CONFIG%"])), bottle: bottle, store: store)
            let echoed = try await runner.run(echo, log: output.appendingPathComponent(backend.rawValue + "-environment.log"))
            try echoed.requireSuccess()
            let value = try String(contentsOf: echoed.log, encoding: .utf8)
            XCTAssertTrue(value.contains(backend == .openGL ? "renderer=gl" : "renderer=vulkan"))
            let plan = try EngineCommands.make(.run(LaunchRequest(path: probePath, options: LaunchOptions(environment: ["WINEDEBUG": "err+winediag"]))), bottle: bottle, store: store)
            let id = UUID()
            let watchdog = Task {
                do { try await Task.sleep(for: .seconds(30)) } catch { return }
                await runner.cancel(operationID: id)
            }
            defer { watchdog.cancel() }
            let diagnostic = try await runner.run(plan, log: output.appendingPathComponent(backend.rawValue + "-frame.log"), operationID: id)
            let text = try String(contentsOf: diagnostic.log, encoding: .utf8)
            let marker = text.contains("CRUZADOR_D3D9_FRAME_OK")
            observations.append(["backend": backend.rawValue, "component_paths": support.componentPaths, "environment_log": echoed.log.path, "frame_exit": diagnostic.exitCode, "frame_cancelled": diagnostic.cancelled, "frame_log": diagnostic.log.path, "frame_success_marker": marker])
            XCTAssertFalse(diagnostic.cancelled)
            XCTAssertEqual(diagnostic.exitCode, 0, text)
            XCTAssertTrue(marker, text)

        }
        let ended = try await runner.run(EngineCommands.make(.waitForIdle, bottle: bottle, store: store), log: output.appendingPathComponent("server-wait.log"))
        try ended.requireSuccess()
        let report: [String: Any] = ["probe": probePath, "probe_sha256": try ArtifactCache.sha256(of: URL(fileURLWithPath: probePath)), "observations": observations, "limitations": ["A single D3D9 clear/present API sequence does not establish pixel correctness, performance or game compatibility.", "Each frame probe had a 30-second cancellation watchdog."]]
        let repository = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]).write(to: repository.appendingPathComponent(".local/real-graphics.json"), options: .atomic)
    }

}
