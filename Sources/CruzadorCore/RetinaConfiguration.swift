import Foundation
import CryptoKit

public enum RetinaMode: String, CaseIterable, Sendable { case automatic, enabled, disabled
    public var displayName: String { switch self { case .automatic: "Padrão do Wine"; case .enabled: "Ativar alta resolução"; case .disabled: "Desativar alta resolução" } }
}
public struct SavedRetina: Sendable {
    public let mode: RetinaMode?
    public let description: String
    public let registrySHA256: String
}
/// The Wine registry is the owner of this choice; the library does not cache a second setting.
public struct RetinaConfiguration: Sendable {
    public let store: LibraryStore
    public init(store: LibraryStore) { self.store = store }
    private let key = #"Software\Wine\Mac Driver"#
    private func validate(_ bottle: Bottle) throws {
        guard bottle.engine.kind == .packagedWine, try WineRuntime(root: URL(fileURLWithPath: bottle.engine.path)).manifest.version == "11.21" else { throw CruzadorError.invalid("A opção Retina foi integrada ao Wine 11.21 incluído. Este outro motor ainda não foi validado.") }
    }
    public func saved(in bottle: Bottle) throws -> SavedRetina {
        try validate(bottle)
        let file = store.prefix(for: bottle).appendingPathComponent("user.reg")
        let facts = try file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard facts.isRegularFile == true, facts.isSymbolicLink != true else { throw CruzadorError.invalid("Registro de usuário não é um arquivo regular da bottle.") }
        let data = try Data(contentsOf: file)
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard let text = String(data: data, encoding: .utf8) else { return SavedRetina(mode: nil, description: "Registro sem codificação UTF-8 reconhecida", registrySHA256: digest) }
        let document = WineRegistryDocument(text: text, selecting: { $0.caseInsensitiveCompare(key) == .orderedSame })
        let keys = document.keys
        let values = keys.flatMap(\.values).filter { $0.name?.caseInsensitiveCompare("RetinaMode") == .orderedSame }
        if !document.warnings.isEmpty || keys.count > 1 || values.count > 1 { return SavedRetina(mode: nil, description: "Valor desconhecido: registro ambíguo ou malformado", registrySHA256: digest) }
        guard let value = values.first else { return SavedRetina(mode: .automatic, description: "Padrão do Wine (sem substituição RetinaMode)", registrySHA256: digest) }
        guard let string = value.string else { return SavedRetina(mode: nil, description: "Tipo de RetinaMode desconhecido: " + value.type, registrySHA256: digest) }
        // Wine 11.21 IS_OPTION_TRUE reads the first character of the string.
        let enabled = string.first.map { "yYtT1".contains($0) } ?? false
        return SavedRetina(mode: enabled ? .enabled : .disabled, description: enabled ? "Alta resolução ativada no registro salvo" : "Alta resolução desativada no registro salvo", registrySHA256: digest)
    }
    public func apply(_ mode: RetinaMode, bottleID: UUID, runner: CommandRunner, log: URL, operationID: UUID = UUID()) async throws -> SavedRetina {
        guard let bottle = try store.load().bottles.first(where: { $0.id == bottleID }), store.isReady(bottle) else { throw CruzadorError.invalid("Selecione uma bottle pronta.") }
        try validate(bottle)
        do {
            let idle = try await runner.run(EngineCommands.make(.waitForIdle, bottle: bottle, store: store), log: log, operationID: operationID)
            try idle.requireSuccess()
            let previous = try saved(in: bottle)
            if previous.mode == mode { return previous }
            let backups = store.root.appendingPathComponent("Backups"); try FileManager.default.createDirectory(at: backups, withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: store.prefix(for: bottle).appendingPathComponent("user.reg"), to: backups.appendingPathComponent("retina-\(UUID()).reg"))
            let arguments: [String]
            switch mode {
            case .automatic: arguments = ["delete", "HKCU\\" + key, "/v", "RetinaMode", "/f"]
            case .enabled, .disabled: arguments = ["add", "HKCU\\" + key, "/v", "RetinaMode", "/t", "REG_SZ", "/d", mode == .enabled ? "Y" : "N", "/f"]
            }
            let executable = store.prefix(for: bottle).appendingPathComponent("drive_c/windows/system32/reg.exe")
            let command = try EngineCommands.make(.run(LaunchRequest(path: executable.path, arguments: arguments)), bottle: bottle, store: store)
            let final = try EngineCommands.make(.waitForIdle, bottle: bottle, store: store)
            let applied = try await runner.run(EnginePlan(primary: command.primary, finalization: [final.primary], cancellation: command.cancellation, cancellationWarning: command.cancellationWarning), log: log, operationID: operationID)
            try applied.requireSuccess()
            let observed = try saved(in: bottle)
            guard observed.mode == mode else { throw CruzadorError.invalid("O registro não confirmou a escolha Retina. Preserve os logs e o backup; o estado não foi presumido.") }
            return observed
        } catch { try BottleOperationRecovery(store: store).record(error, bottleID: bottleID); throw error }
    }
}
