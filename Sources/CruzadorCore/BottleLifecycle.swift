import Foundation

public enum PrefixHealth: Equatable, Sendable {
    case absent, incomplete, initialized
}
public enum PreparationMode: Sendable { case initialize, repair }

/// Owns preparation transitions and their persistence. Readiness requires both
/// successful engine finalization and a structurally initialized prefix.
public struct BottleLifecycle: Sendable {
    public let store: LibraryStore
    public init(store: LibraryStore) { self.store = store }

    public func create(name: String, engine: Engine) throws -> Bottle {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw CruzadorError.invalid("Informe um nome para a bottle.") }
        let bottle = Bottle(name: name, engine: engine)
        _ = try EngineCommands.make(.initialize, bottle: bottle, store: store)
        var library = try store.load()
        library.bottles.append(bottle)
        try store.save(library)
        return bottle
    }

    public func recoverInterruptedPreparations() throws {
        var library = try store.load()
        var changed = false
        for index in library.bottles.indices where library.bottles[index].state == .preparing {
            library.bottles[index].state = .interrupted
            library.bottles[index].lastError = "A preparação anterior não teve conclusão registrada. Os arquivos foram preservados; a execução anterior pode precisar de diagnóstico."
            changed = true
        }
        if changed { try store.save(library) }
    }

    public func prepare(id: UUID, mode: PreparationMode, runner: CommandRunner, log: URL) async throws -> RunResult {
        var library = try store.load()
        guard let index = library.bottles.firstIndex(where: { $0.id == id }) else { throw CruzadorError.invalid("Bottle não encontrada na biblioteca.") }
        let bottle = library.bottles[index]
        if mode == .repair, store.health(of: bottle) != .initialized {
            throw CruzadorError.invalid("Reparar exige uma bottle inicializada. Use Preparar novamente para arquivos incompletos.")
        }
        let plan = try EngineCommands.make(mode == .repair ? .repair : .initialize, bottle: bottle, store: store)
        library.bottles[index].state = .preparing
        library.bottles[index].lastError = nil
        library.bottles[index].lastLogPath = log.path
        try store.save(library)
        let result: RunResult
        do { result = try await runner.run(plan, log: log) }
        catch {
            try finish(id: id, ready: false, reason: error.localizedDescription)
            throw error
        }
        let ready = result.exitCode == 0 && store.health(of: bottle) == .initialized
        let reason = ready ? nil : "Preparação incompleta (código \(result.exitCode)). Consulte o log; os arquivos foram preservados."
        try finish(id: id, ready: ready, reason: reason)
        if let reason { throw CruzadorError.invalid(reason) }
        return result
    }

    private func finish(id: UUID, ready: Bool, reason: String?) throws {
        var library = try store.load()
        guard let index = library.bottles.firstIndex(where: { $0.id == id }) else { throw CruzadorError.invalid("A bottle deixou de existir durante a preparação. Preserve os arquivos e o log.") }
        library.bottles[index].state = ready ? .ready : .failed
        library.bottles[index].lastError = reason
        try store.save(library)
    }
}
