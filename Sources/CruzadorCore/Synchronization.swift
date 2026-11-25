import Foundation

public enum SynchronizationMode: String, Codable, CaseIterable, Sendable {
    case automatic, server, msync
    public var displayName: String {
        switch self { case .automatic: "Padrão do motor"; case .server: "Servidor Wine"; case .msync: "MSync" }
    }
}
/// Owns the bottle-wide client/server protocol choice. Per-app overrides must agree.
public enum SynchronizationConfiguration {
    public static func supportsMSync(engine: Engine) -> Bool {
        guard engine.kind == .packagedWine, let runtime = try? WineRuntime(root: URL(fileURLWithPath: engine.path)) else { return false }
        // This source revision and package were verified together; a feature name alone is not proof.
        return runtime.manifest.sourceRevision == "9f3f6447844add700bc0dde650e4f398fd5f69ab" && runtime.manifest.features?.contains("msync") == true
    }
    public static func environment(settings: BottleSettings, engine: Engine) throws -> [String: String] {
        let supported = supportsMSync(engine: engine)
        let selected: String?
        switch settings.synchronization {
        case .automatic: selected = supported ? "0" : nil
        case .server:
            guard supported || (engine.kind == .packagedWine && (try? WineRuntime(root: URL(fileURLWithPath: engine.path)))?.manifest.version == "11.21") else { throw CruzadorError.invalid("Modo de servidor não validado neste motor; use o padrão.") }
            selected = supported ? "0" : nil
        case .msync:
            guard supported else { throw CruzadorError.invalid("MSync exige o pacote WineCX opcional validado, com macOS 26 ou posterior. O Wine 11.21 padrão não oferece MSync.") }
            selected = "1"
        }
        if let raw = settings.executionOptions.environment["WINEMSYNC"] {
            guard supported else { throw CruzadorError.invalid("WINEMSYNC não foi validado neste motor. Remova a variável ou selecione o pacote MSync compatível.") }
            let value = try flag(raw)
            if let selected, value != (selected == "1") { throw CruzadorError.invalid("WINEMSYNC conflita com o modo selecionado para a bottle.") }
            return ["WINEMSYNC": raw]
        }
        return selected.map { ["WINEMSYNC": $0] } ?? [:]
    }
    /// Compare the protocol selected by Wine, preserving literal environment values for launch.
    /// An invalid old selection is unknown and must be drained before a correction is saved.
    public static func requiresServerWait(from previous: BottleSettings, to next: BottleSettings, engine: Engine) throws -> Bool {
        let nextEnvironment = try environment(settings: next, engine: engine)
        guard let previousEnvironment = try? environment(settings: previous, engine: engine) else { return true }
        return try flag(previousEnvironment["WINEMSYNC"] ?? "0") != flag(nextEnvironment["WINEMSYNC"] ?? "0")
    }
    public static func validateOverride(_ value: String?, global: [String: String], engine: Engine) throws {
        guard let value else { return }
        guard supportsMSync(engine: engine), try flag(value) == flag(global["WINEMSYNC"] ?? "0") else { throw CruzadorError.invalid("O atalho deve usar o mesmo WINEMSYNC da bottle. Altere a sincronização nas opções da bottle e aguarde o servidor encerrar.") }
    }
    private static func flag(_ raw: String) throws -> Bool {
        guard let number = Int32(raw), String(number) == raw else { throw CruzadorError.invalid("WINEMSYNC deve ser um inteiro decimal de 32 bits, sem espaços; zero desativa e os demais valores ativam.") }
        return number != 0
    }
}
