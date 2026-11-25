import Foundation
import Darwin

public struct CommandPhaseResult: Codable, Sendable {
    public let phase: String
    public let executable: String
    public let arguments: [String]
    public let exitCode: Int32?
    public let launchError: String?
}
public struct RunResult: Sendable {
    public let exitCode: Int32
    public let log: URL
    public let cancelled: Bool
    public let cleanupFailures: [String]
    public let phases: [CommandPhaseResult]
    public func requireSuccess() throws {
        if cancelled { throw CommandRunnerError.cancelled(log: log.path, cleanupFailures: cleanupFailures, phases: phases) }
        if exitCode != 0 { throw CommandRunnerError.failed(log: log.path, phases: phases) }
    }
}
public enum CommandRunnerError: LocalizedError {
    case busy
    case cleanupPending
    case failed(log: String, phases: [CommandPhaseResult])
    case cancelled(log: String, cleanupFailures: [String], phases: [CommandPhaseResult])
    public var requiresBottleDiagnosis: Bool {
        if case .cancelled(_, let failures, _) = self { return !failures.isEmpty }
        return false
    }
    public var errorDescription: String? {
        switch self {
        case .busy: "Já há uma operação em execução neste supervisor."
        case .cleanupPending: "Há um encerramento não confirmado. Repita o encerramento ou consulte os logs antes de iniciar outra operação."
        case .failed(let log, let phases): "Operação não concluída. " + phases.filter { $0.exitCode != 0 }.map { "\($0.phase): " + ($0.launchError ?? "código \($0.exitCode.map(String.init) ?? "desconhecido")") }.joined(separator: "; ") + ". Log: \(log)"
        case .cancelled(let log, let failures, _): "Operação cancelada. Log: \(log)." + (failures.isEmpty ? "" : " Encerramento incompleto: " + failures.joined(separator: "; "))
        }
    }
}

/// Retains each Process until its termination callback. Cancellation is scoped to
/// an operation UUID and runs the engine's declared cleanup before completion.
public actor CommandRunner {
    private final class Operation {
        let id: UUID
        let plan: EnginePlan
        let log: URL
        var processes: [UUID: Process] = [:]
        var cancelled = false
        var cleanup: Task<[CommandPhaseResult], Never>?
        init(id: UUID, plan: EnginePlan, log: URL) { self.id = id; self.plan = plan; self.log = log }
    }
    private struct PendingCleanup { let plan: EnginePlan; let log: URL }
    private var pendingCleanup: [UUID: PendingCleanup] = [:]
    private var active: Operation?
    public init() {}
    public func isRunning(operationID: UUID) -> Bool { active?.id == operationID }

    public func pendingCleanupIDs() -> [UUID] { Array(pendingCleanup.keys) }
    public func retryCleanup(failedOperationID: UUID, operationID: UUID = UUID()) async throws -> RunResult {
        guard let pending = pendingCleanup[failedOperationID], let first = pending.plan.cancellation.first else {
            throw CruzadorError.invalid("Não há um encerramento automático disponível para esta operação. Preserve os logs e verifique o motor antes de retomar.")
        }
        let plan = EnginePlan(primary: first, finalization: Array(pending.plan.cancellation.dropFirst()), cancellation: pending.plan.cancellation)
        let log = pending.log.deletingPathExtension().appendingPathExtension("cleanup-\(UUID().uuidString).log")
        pendingCleanup.removeValue(forKey: failedOperationID)
        do {
            let result = try await run(plan, log: log, operationID: operationID)
            try result.requireSuccess()
            return result
        } catch {
            pendingCleanup.removeValue(forKey: operationID)
            pendingCleanup[failedOperationID] = pending
            throw error
        }
    }

    @discardableResult
    public func cancel(operationID: UUID) -> Bool {
        guard let operation = active, operation.id == operationID else { return false }
        guard !operation.cancelled else { return true }
        operation.cancelled = true
        for process in operation.processes.values where process.isRunning { process.terminate() }
        let commands = operation.plan.cancellation, log = operation.log
        operation.cleanup = Task { await self.cleanup(commands, operationID: operationID, log: log) }
        return true
    }
    public func run(_ command: Command, log: URL, operationID: UUID = UUID()) async throws -> RunResult {
        try await run(EnginePlan(primary: command), log: log, operationID: operationID)
    }
    public func run(_ plan: EnginePlan, log: URL, operationID: UUID = UUID()) async throws -> RunResult {
        try Task.checkCancellation()
        guard active == nil else { throw CommandRunnerError.busy }
        guard pendingCleanup.isEmpty else { throw CommandRunnerError.cleanupPending }
        try FileManager.default.createDirectory(at: log.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data().write(to: log)
        active = Operation(id: operationID, plan: plan, log: log)
        defer { active = nil }
        return try await withTaskCancellationHandler {
            var phases = [await perform(plan.primary, phase: "primary", operationID: operationID, log: log, cleanup: false)]
            for command in plan.finalization {
                if active?.cancelled == true { break }
                phases.append(await perform(command, phase: "finalization", operationID: operationID, log: log, cleanup: false))
            }
            let cancellationPhases = await active?.cleanup?.value ?? []
            phases.append(contentsOf: cancellationPhases)
            let cancelled = active?.cancelled == true
            var failures = cancellationPhases.compactMap { phase -> String? in
                if let error = phase.launchError { return error }
                if phase.exitCode != 0 { return "\(phase.executable) terminou com \(phase.exitCode.map(String.init) ?? "código desconhecido")" }
                return nil
            }
            if cancelled, let warning = plan.cancellationWarning { failures.append(warning) }
            if cancelled && !failures.isEmpty { pendingCleanup[operationID] = PendingCleanup(plan: plan, log: log) }
            guard let primaryExit = phases[0].exitCode else {
                if cancelled { throw CommandRunnerError.cancelled(log: log.path, cleanupFailures: failures, phases: phases) }
                throw CommandRunnerError.failed(log: log.path, phases: phases)
            }
            if !cancelled && phases.contains(where: { $0.launchError != nil }) { throw CommandRunnerError.failed(log: log.path, phases: phases) }
            let failure = phases.filter { $0.phase != "cancellation" }.compactMap(\.exitCode).first(where: { $0 != 0 }) ?? primaryExit
            return RunResult(exitCode: failure, log: log, cancelled: cancelled, cleanupFailures: failures, phases: phases)
        } onCancel: {
            Task { await self.cancel(operationID: operationID) }
        }
    }
    private func cleanup(_ commands: [Command], operationID: UUID, log: URL) async -> [CommandPhaseResult] {
        var phases: [CommandPhaseResult] = []
        for command in commands {
            phases.append(await perform(command, phase: "cancellation", operationID: operationID, log: log, cleanup: true))
        }
        return phases
    }
    private func perform(_ command: Command, phase: String, operationID: UUID, log: URL, cleanup: Bool) async -> CommandPhaseResult {
        do {
            let code = try await runOne(command, operationID: operationID, log: log, cleanup: cleanup)
            return CommandPhaseResult(phase: phase, executable: command.executable.path, arguments: command.arguments, exitCode: code, launchError: nil)
        } catch {
            return CommandPhaseResult(phase: phase, executable: command.executable.path, arguments: command.arguments, exitCode: nil, launchError: error.localizedDescription)
        }
    }
    private func runOne(_ command: Command, operationID: UUID, log: URL, cleanup: Bool) async throws -> Int32 {
        guard let operation = active, operation.id == operationID else { throw CruzadorError.invalid("A operação não pertence mais a este supervisor.") }
        if operation.cancelled && !cleanup { throw CancellationError() }
        let descriptor = Darwin.open(log.path, O_WRONLY | O_APPEND)
        guard descriptor >= 0 else { throw CruzadorError.invalid("Não foi possível abrir o log: \(String(cString: strerror(errno)))") }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        defer { try? handle.close() }
        let process = Process(), processID = UUID()
        process.executableURL = command.executable; process.arguments = command.arguments
        var environment = ProcessInfo.processInfo.environment
        for key in environment.keys where key.hasPrefix("CX_") || key.hasPrefix("WINE") { environment.removeValue(forKey: key) }
        environment.merge(command.environment) { _, selected in selected }
        process.environment = environment; process.currentDirectoryURL = command.workingDirectory
        process.standardInput = FileHandle.nullDevice; process.standardOutput = handle; process.standardError = handle
        operation.processes[processID] = process
        defer { operation.processes.removeValue(forKey: processID) }
        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { process in continuation.resume(returning: process.terminationStatus) }
            do { try process.run() }
            catch { process.terminationHandler = nil; continuation.resume(throwing: error) }
        }
    }
}
