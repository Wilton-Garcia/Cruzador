import Foundation

public struct BottleRecoveryError: LocalizedError {
    public let shutdownFailure: CommandRunnerError
    public let persistenceReason: String
    public var errorDescription: String? { "\(shutdownFailure.localizedDescription)\nNão foi possível preservar o diagnóstico na biblioteca: \(persistenceReason)" }
}
/// Persists uncertainty about shutdown; it never converts a callback into proof of cleanup.
public struct BottleOperationRecovery: Sendable {
    public let store: LibraryStore
    public init(store: LibraryStore) { self.store = store }
    public static func shutdownFailure(in error: Error) -> CommandRunnerError? {
        if let recovery = error as? BottleRecoveryError { return recovery.shutdownFailure }
        guard let failure = error as? CommandRunnerError, failure.requiresBottleDiagnosis else { return nil }
        return failure
    }
    public static func preservingShutdownFailure(_ operation: Error, persistenceFailure: Error) -> Error {
        guard let shutdown = shutdownFailure(in: operation) else { return persistenceFailure }
        return BottleRecoveryError(shutdownFailure: shutdown, persistenceReason: persistenceFailure.localizedDescription)
    }
    @discardableResult
    public func record(_ error: Error, bottleID: UUID) throws -> Bool {
        guard let failure = Self.shutdownFailure(in: error) else { return false }
        do {
            var library = try store.load()
            guard let index = library.bottles.firstIndex(where: { $0.id == bottleID }) else { throw CruzadorError.invalid("A bottle do encerramento não confirmado não existe na biblioteca.") }
            library.bottles[index].state = .interrupted
            library.bottles[index].lastError = failure.localizedDescription
            if case .cancelled(let log, _, _) = failure { library.bottles[index].lastLogPath = log }
            try store.save(library)
        } catch { throw Self.preservingShutdownFailure(failure, persistenceFailure: error) }
        return true
    }
}
