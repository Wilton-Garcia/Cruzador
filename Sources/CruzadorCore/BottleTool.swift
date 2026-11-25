import Foundation

/// One owner of tool identities, component checks and literal Windows arguments.
public enum BottleTool: String, CaseIterable, Sendable {
    case wineConfiguration = "winecfg", registryEditor = "regedit", uninstaller, commandPrompt = "cmd", gameControllers = "gamepads", taskManager = "taskmgr"
    private var components: [String] {
        switch self { case .gameControllers: ["control.exe", "joy.cpl"]; case .taskManager: ["taskmgr.exe"]; default: [] }
    }
    func arguments(bottle: Bottle, store: LibraryStore) throws -> [String] {
        guard !components.isEmpty else { return [rawValue] }
        let system = store.prefix(for: bottle).appendingPathComponent("drive_c/windows/system32")
        let machines = try components.map { component in
            do { return try WindowsPEHeader.inspect(system.appendingPathComponent(component)) }
            catch { throw CruzadorError.invalid("Ferramenta \(rawValue) indisponível: \(component). Prepare ou repare a bottle. \(error.localizedDescription)") }
        }
        guard Set(machines).count == 1, machines.allSatisfy({ [UInt16(0x14c), 0x8664].contains($0) }) else { throw CruzadorError.invalid("Componentes Windows de arquiteturas incompatíveis para \(rawValue). Repare a bottle.") }
        return [system.appendingPathComponent(components[0]).path] + Array(components.dropFirst())
    }
}
