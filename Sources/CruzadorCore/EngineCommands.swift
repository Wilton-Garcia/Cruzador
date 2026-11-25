import Foundation

public struct Command: Sendable {
    public let executable: URL
    public let arguments: [String]
    public let environment: [String: String]
    public let workingDirectory: URL?
    public init(executable: URL, arguments: [String], environment: [String: String], workingDirectory: URL? = nil) {
        self.executable = executable; self.arguments = arguments; self.environment = environment; self.workingDirectory = workingDirectory
    }
}
public struct EnginePlan: Sendable {
    public let primary: Command
    public let finalization: [Command]
    public init(primary: Command, finalization: [Command] = []) { self.primary = primary; self.finalization = finalization }
}
public enum BottleAction: Sendable { case initialize, repair, waitForIdle, run(String, [String]), install(String), tool(String) }
public enum EngineCommands {
    public static func make(_ action: BottleAction, bottle: Bottle, store: LibraryStore) throws -> EnginePlan {
        guard bottle.engine.path.hasPrefix("/") else { throw CruzadorError.invalid("Selecione um caminho absoluto para o motor.") }
        let engineURL = URL(fileURLWithPath: bottle.engine.path)
        let prefix = store.prefix(for: bottle)
        var environment = ["WINEPREFIX": prefix.path]
        var executable: URL
        var arguments: [String]
        var finalization: [Command] = []
        switch bottle.engine.kind {
        case .crossOver:
            let base = engineURL.appendingPathComponent("Contents/SharedSupport/CrossOver")
            environment["CX_BOTTLE_PATH"] = store.bottlesRoot.path
            environment["CX_BOTTLE"] = bottle.id.uuidString
            switch action {
            case .initialize:
                if FileManager.default.fileExists(atPath: prefix.path) {
                    guard FileManager.default.isReadableFile(atPath: prefix.appendingPathComponent("cxbottle.conf").path) else {
                        throw CruzadorError.invalid("A preparação deixou arquivos sem configuração válida. Preserve essa bottle para diagnóstico e crie outra; o Cruzador não sobrescreverá os arquivos parciais.")
                    }
                    executable = base.appendingPathComponent("bin/wine")
                    arguments = ["--bottle", bottle.id.uuidString, "--scope", "private", "--no-gui", "--wl-app", "wineboot.exe", "--", "--init"]
                } else {
                    executable = base.appendingPathComponent("bin/cxbottle")
                    arguments = ["--bottle", bottle.id.uuidString, "--scope", "private", "--create", "--template", "win10_64", "--description", bottle.name]
                }
            case .waitForIdle:
                throw CruzadorError.invalid("A manutenção usa o motor Wine independente. O adaptador CrossOver é reservado para comparação e execução legada.")
            case .repair:
                executable = base.appendingPathComponent("bin/wine")
                arguments = ["--bottle", bottle.id.uuidString, "--scope", "private", "--no-gui", "--wait", "--", "wineboot", "--update"]
            default:
                executable = base.appendingPathComponent("bin/wine")
                arguments = ["--bottle", bottle.id.uuidString, "--scope", "private", "--no-gui", "--wait", "--"] + (try windowsArguments(action))
            }
        case .wine, .packagedWine:
            if bottle.engine.kind == .packagedWine {
                let runtime = try WineRuntime(root: engineURL)
                executable = runtime.wine
                environment["WINESERVER"] = runtime.server.path
            } else {
                executable = engineURL
            }
            switch action {
            case .initialize, .repair, .waitForIdle:
                let server = environment["WINESERVER"].map { URL(fileURLWithPath: $0) } ?? engineURL.deletingLastPathComponent().appendingPathComponent("wineserver")
                guard FileManager.default.isExecutableFile(atPath: server.path) else { throw CruzadorError.invalid("wineserver não está disponível ao lado do motor selecionado: \(server.path)") }
                if case .waitForIdle = action {
                    executable = server; arguments = ["-w"]
                } else {
                    arguments = ["wineboot", modeFlag(action)]
                    finalization = [Command(executable: server, arguments: ["-w"], environment: environment)]
                }
            default: arguments = try windowsArguments(action)
            }
        }
        guard FileManager.default.isExecutableFile(atPath: executable.path) else {
            throw CruzadorError.invalid("Motor indisponível em \(executable.path). Escolha uma instalação existente nas configurações.")
        }
        return EnginePlan(primary: Command(executable: executable, arguments: arguments, environment: environment), finalization: finalization)
    }
    private static func modeFlag(_ action: BottleAction) -> String {
        if case .repair = action { return "--update" }
        return "--init"
    }
    private static func windowsArguments(_ action: BottleAction) throws -> [String] {
        switch action {
        case .run(let path, let arguments):
            try validateProgram(path)
            return (URL(fileURLWithPath: path).pathExtension.lowercased() == "msi" ? ["msiexec", "/i", path] : [path]) + arguments
        case .install(let path):
            try validateProgram(path)
            return URL(fileURLWithPath: path).pathExtension.lowercased() == "msi" ? ["msiexec", "/i", path] : [path]
        case .tool(let name):
            guard ["winecfg", "regedit", "uninstaller", "cmd"].contains(name) else { throw CruzadorError.invalid("Ferramenta desconhecida.") }
            return [name]
        case .initialize, .repair, .waitForIdle: return []
        }
    }
    private static func validateProgram(_ path: String) throws {
        guard path.hasPrefix("/"), FileManager.default.isReadableFile(atPath: path), ["exe", "msi"].contains(URL(fileURLWithPath: path).pathExtension.lowercased()) else {
            throw CruzadorError.invalid("Selecione um arquivo Windows existente (.exe ou .msi).")
        }
    }
}

public struct RunResult: Sendable {
    public let exitCode: Int32
    public let log: URL
}
/// Runs away from the UI actor; output goes directly to disk, never a blocking pipe.
public actor CommandRunner {
    public init() {}
    public func run(_ plan: EnginePlan, log: URL) throws -> RunResult {
        let primary = try runOne(plan.primary, log: log, append: false)
        var failure = primary.exitCode
        for command in plan.finalization {
            let result = try runOne(command, log: log, append: true)
            if failure == 0 { failure = result.exitCode }
        }
        return RunResult(exitCode: failure, log: log)
    }
    public func run(_ command: Command, log: URL) throws -> RunResult {
        try runOne(command, log: log, append: false)
    }
    private func runOne(_ command: Command, log: URL, append: Bool) throws -> RunResult {
        try FileManager.default.createDirectory(at: log.deletingLastPathComponent(), withIntermediateDirectories: true)
        if !append || !FileManager.default.fileExists(atPath: log.path) {
            guard FileManager.default.createFile(atPath: log.path, contents: nil) else { throw CruzadorError.invalid("Não foi possível criar o log.") }
        }
        let handle = try FileHandle(forWritingTo: log)
        defer { try? handle.close() }
        if append { try handle.seekToEnd() }
        let process = Process()
        process.executableURL = command.executable; process.arguments = command.arguments
        var environment = ProcessInfo.processInfo.environment
        // Inherited CrossOver/Wine routing must not override the selected bottle.
        for key in environment.keys where key.hasPrefix("CX_") || key.hasPrefix("WINE") { environment.removeValue(forKey: key) }
        environment.merge(command.environment) { _, selected in selected }
        process.environment = environment; process.currentDirectoryURL = command.workingDirectory
        process.standardInput = FileHandle.nullDevice; process.standardOutput = handle; process.standardError = handle
        try process.run()
        process.waitUntilExit()
        return RunResult(exitCode: process.terminationStatus, log: log)
    }
}
