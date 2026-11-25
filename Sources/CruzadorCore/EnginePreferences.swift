import Foundation

/// Owns the persisted engine pair. Missing preferences select the bundled engine;
/// incomplete or unknown preferences require an explicit selection instead of fallback.
public enum EnginePreferences {
    public static func load(from defaults: UserDefaults, bundledRoot: URL = WineRuntime.bundledRoot) throws -> Engine {
        let kind = defaults.string(forKey: "engineKind")
        let path = defaults.string(forKey: "enginePath")
        if defaults.object(forKey: "engineKind") == nil && defaults.object(forKey: "enginePath") == nil { return Engine(kind: .packagedWine, path: bundledRoot.path) }
        guard let kind, let selected = EngineKind(rawValue: kind), let path, path.hasPrefix("/") else {
            throw CruzadorError.invalid("A seleção de motor salva está incompleta ou não é reconhecida. Escolha o motor nas configurações e salve novamente.")
        }
        return Engine(kind: selected, path: path)
    }
    public static func save(_ engine: Engine, to defaults: UserDefaults) throws {
        guard engine.path.hasPrefix("/") else { throw CruzadorError.invalid("Escolha um caminho absoluto para o motor antes de salvar.") }
        defaults.set(engine.kind.rawValue, forKey: "engineKind")
        defaults.set(engine.path, forKey: "enginePath")
    }
}
