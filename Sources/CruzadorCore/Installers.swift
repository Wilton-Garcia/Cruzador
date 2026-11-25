import Foundation

public enum InstallerMode: String, Codable, CaseIterable, Sendable {
    case interactive, passive, quiet
    public var displayName: String { switch self { case .interactive: "Interativo"; case .passive: "Progresso sem perguntas (MSI)"; case .quiet: "Sem interface (MSI)" } }
}
public struct InstallationRequest: Sendable {
    public let id: UUID
    public let inspection: WindowsFileInspection
    public let mode: InstallerMode
    public let arguments: [String]
    public let options: LaunchOptions
    public let recipeID: String?
    public let sourceURL: URL?
    public let sourceSHA256: String?
    public init(path: String, mode: InstallerMode = .interactive, arguments: [String] = [], options: LaunchOptions? = nil, recipeID: String? = nil, sourceURL: URL? = nil, sourceSHA256: String? = nil) throws {
        try self.init(inspection: WindowsFileInspection.inspect(path: path), mode: mode, arguments: arguments, options: options, recipeID: recipeID, sourceURL: sourceURL, sourceSHA256: sourceSHA256)
    }
    public init(inspection: WindowsFileInspection, mode: InstallerMode = .interactive, arguments: [String] = [], options: LaunchOptions? = nil, recipeID: String? = nil, sourceURL: URL? = nil, sourceSHA256: String? = nil) throws {
        id = UUID(); self.inspection = inspection; self.mode = mode; self.arguments = arguments
        self.recipeID = recipeID; self.sourceURL = sourceURL; self.sourceSHA256 = sourceSHA256
        self.options = options ?? LaunchOptions(workingDirectory: URL(fileURLWithPath: inspection.path).deletingLastPathComponent().path)
        try validate()
    }
    public func validate() throws {
        try LaunchRequest(path: inspection.path, arguments: arguments, options: options).validate()
        try inspection.validateCurrentMetadata()
        guard inspection.kind == .msi || mode == .interactive else { throw CruzadorError.invalid("Instaladores EXE têm opções próprias. Use modo interativo e informe somente os argumentos documentados pelo fornecedor.") }
    }
    public func windowsArguments(msiLog: URL) throws -> [String] {
        try validate()
        if inspection.kind == .exe { return [inspection.path] + arguments }
        let ui: [String] = switch mode { case .interactive: []; case .passive: ["/qb"]; case .quiet: ["/qn"] }
        return ["msiexec", "/i", inspection.path, "/norestart", "/L*V", msiLog.path] + ui + arguments
    }
}
public enum InstallationStatus: String, Codable, Sendable {
    case running, completed, cancelled, unconfirmed, launchFailed, interrupted
    public var displayName: String {
        switch self { case .running: "Em andamento"; case .completed: "Instalador concluído"; case .cancelled: "Cancelado"; case .unconfirmed: "Resultado não confirmado"; case .launchFailed: "Falha na execução"; case .interrupted: "Conclusão não registrada" }
    }
}
public struct InstallationRecord: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let inspection: WindowsFileInspection
    public var sourcePath: String { inspection.path }
    public var kind: WindowsFileKind { inspection.kind }
    public let options: LaunchOptions
    public let recipeID: String?
    public let sourceURL: URL?
    public let sourceSHA256: String?
    public let mode: InstallerMode
    public let arguments: [String]
    public let startedAt: Date
    public let logPath: String
    public var status: InstallationStatus
    public var finishedAt: Date?
    public var macOSExitCode: Int32?
    public var error: String?
    public var phases: [CommandPhaseResult]?

}
public struct InstallationService: Sendable {
    public let store: LibraryStore
    public init(store: LibraryStore) { self.store = store }
    public func run(_ request: InstallationRequest, bottle: Bottle, runner: CommandRunner, log: URL, operationID: UUID = UUID()) async throws -> RunResult {
        var library = try store.load()
        guard let index = library.bottles.firstIndex(where: { $0.id == bottle.id }) else { throw CruzadorError.invalid("Bottle não encontrada.") }
        let current = library.bottles[index]
        guard store.isReady(current) else { throw CruzadorError.invalid("Prepare a bottle antes de instalar programas.") }
        let plan = try EngineCommands.make(.install(request), bottle: current, store: store)
        let record = InstallationRecord(id: request.id, inspection: request.inspection, options: request.options, recipeID: request.recipeID, sourceURL: request.sourceURL, sourceSHA256: request.sourceSHA256, mode: request.mode, arguments: request.arguments, startedAt: Date(), logPath: log.path, status: .running)
        library.bottles[index].installations = (library.bottles[index].installations ?? []) + [record]
        try store.save(library)
        let result: RunResult
        do { result = try await runner.run(plan, log: log, operationID: operationID) }
        catch {
            let phases: [CommandPhaseResult]?
            let status: InstallationStatus
            switch error {
            case CommandRunnerError.cancelled(_, _, let observed): phases = observed; status = .cancelled
            case CommandRunnerError.failed(_, let observed): phases = observed; status = .launchFailed
            default: phases = nil; status = .launchFailed
            }
            try finish(id: request.id, bottleID: bottle.id, status: status, code: nil, error: error.localizedDescription, phases: phases)
            throw error
        }
        let status: InstallationStatus = result.cancelled ? .cancelled : result.exitCode == 0 ? .completed : .unconfirmed
        try finish(id: request.id, bottleID: bottle.id, status: status, code: result.exitCode, error: result.cleanupFailures.isEmpty ? nil : result.cleanupFailures.joined(separator: "; "), phases: result.phases)
        try result.requireSuccess()
        return result
    }
    public func recoverInterrupted() throws {
        var library = try store.load(); var changed = false
        for bottle in library.bottles.indices {
            guard var records = library.bottles[bottle].installations else { continue }
            for index in records.indices where records[index].status == .running { records[index].status = .interrupted; changed = true }
            library.bottles[bottle].installations = records
        }
        if changed { try store.save(library) }
    }
    private func finish(id: UUID, bottleID: UUID, status: InstallationStatus, code: Int32?, error: String?, phases: [CommandPhaseResult]?) throws {
        var library = try store.load()
        guard let bottle = library.bottles.firstIndex(where: { $0.id == bottleID }), let index = library.bottles[bottle].installations?.firstIndex(where: { $0.id == id }) else { throw CruzadorError.invalid("O histórico da instalação deixou de existir. Preserve o log.") }
        library.bottles[bottle].installations?[index].status = status
        library.bottles[bottle].installations?[index].finishedAt = Date()
        library.bottles[bottle].installations?[index].macOSExitCode = code
        library.bottles[bottle].installations?[index].error = error
        library.bottles[bottle].installations?[index].phases = phases
        try store.save(library)
    }
}
