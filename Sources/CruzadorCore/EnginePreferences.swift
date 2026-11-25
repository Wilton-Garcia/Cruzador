import Foundation

private struct StoredEngineSelection: Codable {
    let formatVersion: Int
    let engine: Engine
}

/// Owns migration of the legacy pair to one versioned, atomically replaced value.
public enum EnginePreferences {
    public static func load(from defaults: UserDefaults, bundledRoot: URL = WineRuntime.bundledRoot) throws -> Engine {
        if defaults.object(forKey: "engineSelection") != nil {
            guard let data = defaults.data(forKey: "engineSelection"), let selection = try? JSONDecoder().decode(StoredEngineSelection.self, from: data), selection.formatVersion == 1, selection.engine.path.hasPrefix("/") else {
                throw invalidSelection()
            }
            return selection.engine
        }
        let kind = defaults.string(forKey: "engineKind")
        let path = defaults.string(forKey: "enginePath")
        if defaults.object(forKey: "engineKind") == nil && defaults.object(forKey: "enginePath") == nil { return Engine(kind: .packagedWine, path: bundledRoot.path) }
        guard let kind, let selected = EngineKind(rawValue: kind), let path, path.hasPrefix("/") else { throw invalidSelection() }
        return Engine(kind: selected, path: path)
    }
    public static func save(_ engine: Engine, to defaults: UserDefaults) throws {
        guard engine.path.hasPrefix("/") else { throw CruzadorError.invalid("Escolha um caminho absoluto para o motor antes de salvar.") }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(StoredEngineSelection(formatVersion: 1, engine: engine))
        if defaults.data(forKey: "engineSelection") == data { return }
        if let original = defaults.object(forKey: "engineSelection") {
            let backup = try PropertyListSerialization.data(fromPropertyList: ["engineSelection": original], format: .binary, options: 0)
            defaults.set(backup, forKey: "engineSelectionBackup")
        } else if defaults.object(forKey: "engineSelectionLegacyBackup") == nil {
            var previous: [String: Any] = [:]
            for key in ["engineKind", "enginePath"] { if let value = defaults.object(forKey: key) { previous[key] = value } }
            if !previous.isEmpty {
                let backup = try PropertyListSerialization.data(fromPropertyList: previous, format: .binary, options: 0)
                defaults.set(backup, forKey: "engineSelectionLegacyBackup")
            }
        }
        defaults.set(data, forKey: "engineSelection")
    }
    private static func invalidSelection() -> CruzadorError {
        .invalid("A seleção de motor salva está incompleta ou não é reconhecida. Escolha o motor nas configurações e salve novamente.")
    }
}
