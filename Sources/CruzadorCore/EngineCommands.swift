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
    public let prerequisites: [Command]
    public let finalization: [Command]
    public let cancellation: [Command]
    public let cancellationWarning: String?
    public init(primary: Command, prerequisites: [Command] = [], finalization: [Command] = [], cancellation: [Command] = [], cancellationWarning: String? = nil) {
        self.primary = primary; self.prerequisites = prerequisites; self.finalization = finalization; self.cancellation = cancellation; self.cancellationWarning = cancellationWarning
    }
}
public enum BottleAction: Sendable { case initialize, repair, reboot, waitForIdle, run(LaunchRequest), install(InstallationRequest), tool(BottleTool) }
public enum EngineCommands {
    public static func make(_ action: BottleAction, bottle: Bottle, store: LibraryStore) throws -> EnginePlan {
        guard bottle.engine.path.hasPrefix("/") else { throw CruzadorError.invalid("Selecione um caminho absoluto para o motor.") }
        let engineURL = URL(fileURLWithPath: bottle.engine.path)
        let prefix = store.prefix(for: bottle)
        var environment = ["WINEPREFIX": prefix.path]
        var executable: URL
        var arguments: [String]
        var finalization: [Command] = []
        var cancellation: [Command] = []
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
            case .reboot:
                throw CruzadorError.invalid("A reinicialização usa o Wine independente do Cruzador.")
            case .waitForIdle:
                throw CruzadorError.invalid("A manutenção usa o motor Wine independente. O adaptador CrossOver é reservado para comparação e execução legada.")
            case .repair:
                executable = base.appendingPathComponent("bin/wine")
                arguments = ["--bottle", bottle.id.uuidString, "--scope", "private", "--no-gui", "--wait", "--", "wineboot", "--update"]
            default:
                executable = base.appendingPathComponent("bin/wine")
                arguments = ["--bottle", bottle.id.uuidString, "--scope", "private", "--no-gui", "--wait", "--"] + (try windowsArguments(action, bottle: bottle, store: store))
            }
        case .wine, .packagedWine:
            if bottle.engine.kind == .packagedWine {
                let runtime = try WineRuntime(root: engineURL)
                executable = runtime.wine
                environment["WINESERVER"] = runtime.server.path
            } else {
                executable = engineURL
            }
            let server = environment["WINESERVER"].map { URL(fileURLWithPath: $0) } ?? engineURL.deletingLastPathComponent().appendingPathComponent("wineserver")
            if FileManager.default.isExecutableFile(atPath: server.path) {
                environment["WINESERVER"] = server.path
                cancellation = [Command(executable: server, arguments: ["-k"], environment: environment), Command(executable: server, arguments: ["-w"], environment: environment)]
            }
            switch action {
            case .initialize, .repair, .reboot, .waitForIdle:
                guard FileManager.default.isExecutableFile(atPath: server.path) else { throw CruzadorError.invalid("wineserver não está disponível ao lado do motor selecionado: \(server.path)") }
                if case .waitForIdle = action {
                    executable = server; arguments = ["-w"]
                } else {
                    if case .reboot = action { arguments = ["wineboot", "--restart"] }
                    else { arguments = ["wineboot", modeFlag(action)] }
                    finalization = [Command(executable: server, arguments: ["-w"], environment: environment)]
                }
            default: arguments = try windowsArguments(action, bottle: bottle, store: store)
            }
        }
        guard FileManager.default.isExecutableFile(atPath: executable.path) else {
            throw CruzadorError.invalid("Motor indisponível em \(executable.path). Escolha uma instalação existente nas configurações.")
        }
        var workingDirectory: URL?
        let options: LaunchOptions?
        switch action { case .run(let request): options = request.options; case .install(let request): options = request.options; default: options = nil }
        if case .waitForIdle = action {} else {
            let settings = bottle.requestedSettings
            try settings.executionOptions.validate()
            let synchronization = try SynchronizationConfiguration.environment(settings: settings, engine: bottle.engine)
            try SynchronizationConfiguration.validateOverride(options?.environment["WINEMSYNC"], global: synchronization, engine: bottle.engine)
            var selected = settings.executionOptions.environment
            selected.merge(synchronization) { _, value in value }
            if let options { selected.merge(options.environment) { _, value in value } }
            environment.merge(try GraphicsConfiguration.environment(backend: settings.graphics, engine: bottle.engine, explicitOverride: selected["WINE_D3D_CONFIG"])) { _, value in value }
            environment.merge(selected) { _, value in value }
            workingDirectory = (options?.workingDirectory ?? settings.executionOptions.workingDirectory).map { URL(fileURLWithPath: $0) }
        }
        if case .reboot = action {
            guard let server = environment["WINESERVER"] else { throw CruzadorError.invalid("Servidor Wine ausente para reinicialização.") }
            let restart = Command(executable: executable, arguments: arguments, environment: environment, workingDirectory: workingDirectory)
            return EnginePlan(primary: restart, prerequisites: [Command(executable: URL(fileURLWithPath: server), arguments: ["-w"], environment: environment)], finalization: finalization, cancellation: cancellation)
        }
        return EnginePlan(primary: Command(executable: executable, arguments: arguments, environment: environment, workingDirectory: workingDirectory), finalization: finalization, cancellation: cancellation,
                          cancellationWarning: cancellation.isEmpty ? "O motor não forneceu um encerramento verificável do servidor da bottle. Seus processos podem continuar ativos; consulte o log antes de retomar." : nil)
    }
    private static func modeFlag(_ action: BottleAction) -> String {
        if case .repair = action { return "--update" }
        return "--init"
    }
    private static func windowsArguments(_ action: BottleAction, bottle: Bottle, store: LibraryStore) throws -> [String] {
        switch action {
        case .run(let request):
            try request.validate()
            return (URL(fileURLWithPath: request.path).pathExtension.lowercased() == "msi" ? ["msiexec", "/i", request.path] : [request.path]) + request.arguments
        case .install(let request):
            return try request.windowsArguments(msiLog: store.logsRoot.appendingPathComponent("installer-\(request.id).msi.log"))
        case .tool(let tool): return try tool.arguments(bottle: bottle, store: store)
        case .initialize, .repair, .reboot, .waitForIdle: return []
        }
    }

}
