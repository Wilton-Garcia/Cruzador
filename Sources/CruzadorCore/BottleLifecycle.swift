import Foundation

public enum PrefixHealth: Equatable, Sendable {
    case absent, incomplete, initialized
    case unknown(String)
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

    public func prepare(id: UUID, mode: PreparationMode, runner: CommandRunner, log: URL, operationID: UUID = UUID()) async throws -> RunResult {
        var library = try store.load()
        guard let index = library.bottles.firstIndex(where: { $0.id == id }) else { throw CruzadorError.invalid("Bottle não encontrada na biblioteca.") }
        let bottle = library.bottles[index]
        let health = store.health(of: bottle)
        if case .unknown(let reason) = health { throw CruzadorError.invalid("Não foi possível verificar os arquivos antes de preparar: \(reason)") }
        if mode == .repair, health != .initialized {
            throw CruzadorError.invalid("Reparar exige uma bottle inicializada. Use Preparar novamente para arquivos incompletos.")
        }
        let plan = try EngineCommands.make(mode == .repair ? .repair : .initialize, bottle: bottle, store: store)
        library.bottles[index].state = .preparing
        library.bottles[index].lastError = nil
        library.bottles[index].lastLogPath = log.path
        try store.save(library)
        let result: RunResult
        do { result = try await runner.run(plan, log: log, operationID: operationID) }
        catch {
            do { try finish(id: id, ready: false, reason: error.localizedDescription) }
            catch let persistenceFailure { throw BottleOperationRecovery.preservingShutdownFailure(error, persistenceFailure: persistenceFailure) }
            throw error
        }
        let finalHealth = store.health(of: bottle)
        let ready = !result.cancelled && result.exitCode == 0 && finalHealth == .initialized
        var operationFailure: Error?
        do { try result.requireSuccess() }
        catch { operationFailure = error }
        if operationFailure == nil, !ready {
            if case .unknown(let failure) = finalHealth { operationFailure = CruzadorError.invalid("Preparação sem prontidão confirmada: \(failure)") }
            else { operationFailure = CruzadorError.invalid("Preparação incompleta. Consulte o log; os arquivos foram preservados.") }
        }
        let reason = operationFailure?.localizedDescription
        do { try finish(id: id, ready: ready, reason: reason) }
        catch {
            if let operationFailure { throw BottleOperationRecovery.preservingShutdownFailure(operationFailure, persistenceFailure: error) }
            throw error
        }
        if let operationFailure { throw operationFailure }
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
