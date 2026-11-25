import Foundation

public enum InstallerKind: String, Codable, Sendable { case exe, msi }
public enum InstallerMode: String, Codable, CaseIterable, Sendable {
    case interactive, passive, quiet
    public var displayName: String { switch self { case .interactive: "Interativo"; case .passive: "Progresso sem perguntas (MSI)"; case .quiet: "Sem interface (MSI)" } }
}
public struct InstallerInspection: Codable, Sendable, Equatable {
    public let path: String
    public let kind: InstallerKind
    public let peMachine: UInt16?
    public let size: UInt64
    public let modificationDate: Date
    public static func inspect(path: String) throws -> InstallerInspection {
        try LaunchRequest(path: path).validate()
        let url = URL(fileURLWithPath: path)
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard let size = attributes[.size] as? NSNumber, let modified = attributes[.modificationDate] as? Date else { throw CruzadorError.invalid("Não foi possível obter os metadados do instalador.") }
        let handle = try FileHandle(forReadingFrom: url); defer { try? handle.close() }
        let header = try handle.read(upToCount: 64) ?? Data()
        guard let kind = InstallerKind(rawValue: url.pathExtension.lowercased()) else { throw CruzadorError.invalid("Formato de instalador não suportado.") }
        var machine: UInt16?
        switch kind {
        case .msi:
            guard header.starts(with: [0xd0, 0xcf, 0x11, 0xe0, 0xa1, 0xb1, 0x1a, 0xe1]) else { throw CruzadorError.invalid("O arquivo .msi não tem a assinatura de armazenamento composto esperada.") }
        case .exe:
            guard header.count >= 64, header.starts(with: [0x4d, 0x5a]) else { throw CruzadorError.invalid("O arquivo .exe não tem um cabeçalho Windows válido.") }
            let offset = (0..<4).reduce(UInt64(0)) { $0 | (UInt64(header[0x3c + $1]) << ($1 * 8)) }
            guard size.uint64Value >= 6, offset <= size.uint64Value - 6 else { throw CruzadorError.invalid("Cabeçalho PE fora dos limites do arquivo.") }
            try handle.seek(toOffset: offset)
            let pe = try handle.read(upToCount: 6) ?? Data()
            guard pe.count == 6, pe.starts(with: [0x50, 0x45, 0, 0]) else { throw CruzadorError.invalid("Assinatura PE não encontrada no instalador.") }
            machine = UInt16(pe[4]) | UInt16(pe[5]) << 8
        }
        return InstallerInspection(path: path, kind: kind, peMachine: machine, size: size.uint64Value, modificationDate: modified)
    }
    public func validateCurrentMetadata() throws {
        let attributes = try FileManager.default.attributesOfItem(atPath: path)
        guard (attributes[.size] as? NSNumber)?.uint64Value == size, attributes[.modificationDate] as? Date == modificationDate else {
            throw CruzadorError.invalid("O instalador mudou depois de ser selecionado. Escolha o arquivo novamente.")
        }
    }
}
public struct InstallationRequest: Sendable {
    public let id: UUID
    public let inspection: InstallerInspection
    public let mode: InstallerMode
    public let arguments: [String]
    public let options: LaunchOptions
    public let recipeID: String?
    public let sourceURL: URL?
    public let sourceSHA256: String?
    public init(path: String, mode: InstallerMode = .interactive, arguments: [String] = [], options: LaunchOptions? = nil, recipeID: String? = nil, sourceURL: URL? = nil, sourceSHA256: String? = nil) throws {
        try self.init(inspection: InstallerInspection.inspect(path: path), mode: mode, arguments: arguments, options: options, recipeID: recipeID, sourceURL: sourceURL, sourceSHA256: sourceSHA256)
    }
    public init(inspection: InstallerInspection, mode: InstallerMode = .interactive, arguments: [String] = [], options: LaunchOptions? = nil, recipeID: String? = nil, sourceURL: URL? = nil, sourceSHA256: String? = nil) throws {
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
    public let inspection: InstallerInspection
    public var sourcePath: String { inspection.path }
    public var kind: InstallerKind { inspection.kind }
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
