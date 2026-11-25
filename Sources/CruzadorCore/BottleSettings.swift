import Foundation

public enum GraphicsBackend: String, Codable, CaseIterable, Sendable {
    case automatic, openGL, vulkan
    public var displayName: String { switch self { case .automatic: "Padrão do motor"; case .openGL: "WineD3D / OpenGL"; case .vulkan: "WineD3D / Vulkan (experimental)" } }
}
public struct BottleSettings: Codable, Equatable, Sendable {
    public var graphics: GraphicsBackend
    public var synchronization: SynchronizationMode
    public var executionOptions: LaunchOptions
    public init(graphics: GraphicsBackend = .automatic, synchronization: SynchronizationMode = .automatic, executionOptions: LaunchOptions = LaunchOptions()) {
        self.graphics = graphics; self.synchronization = synchronization; self.executionOptions = executionOptions
    }
    private enum CodingKeys: String, CodingKey { case graphics, synchronization, executionOptions }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        graphics = try values.decodeIfPresent(GraphicsBackend.self, forKey: .graphics) ?? .automatic
        synchronization = try values.decodeIfPresent(SynchronizationMode.self, forKey: .synchronization) ?? .automatic
        executionOptions = try values.decodeIfPresent(LaunchOptions.self, forKey: .executionOptions) ?? LaunchOptions()
    }
}
public struct GraphicsSupport: Identifiable, Codable, Sendable {
    public var id: GraphicsBackend { backend }
    public let backend: GraphicsBackend
    public let requestSupported: Bool
    public let reason: String
    public let componentPaths: [String]
    public let limitations: [String]
}
private struct VulkanICD: Decodable {
    struct Driver: Decodable { let library_path: String; let api_version: String }
    let file_format_version: String
    let ICD: Driver
}
public enum GraphicsConfiguration {
    public static func inspect(_ backend: GraphicsBackend, engine: Engine) -> GraphicsSupport {
        let limits = ["Presença de componentes e suporte à opção não comprovam inicialização da GPU ou compatibilidade de jogos.", "DXVK, D3DMetal e DLSS não são instalados por esta seleção."]
        if backend == .automatic { return GraphicsSupport(backend: backend, requestSupported: true, reason: "Mantém a escolha do motor e do registro Wine.", componentPaths: [], limitations: limits) }
        guard engine.kind == .packagedWine else { return GraphicsSupport(backend: backend, requestSupported: false, reason: "A seleção explícita foi integrada ao pacote Wine do Cruzador. Use o padrão para motores externos.", componentPaths: [], limitations: limits) }
        var paths: [String] = []
        do {
            let runtime = try WineRuntime(root: URL(fileURLWithPath: engine.path))
            guard runtime.manifest.version == "11.21" else { throw CruzadorError.invalid("Esta versão do pacote ainda não teve a configuração WineD3D validada. Use o padrão do motor.") }
            var files = ["lib/wine/x86_64-windows/wined3d.dll", "lib/wine/i386-windows/wined3d.dll"]
            if backend == .vulkan { files += ["lib/wine/x86_64-windows/winevulkan.dll", "lib/wine/i386-windows/winevulkan.dll", "share/vulkan/icd.d/MoltenVK_icd.json"] }
            func component(_ path: URL) throws {
                let resolved = path.resolvingSymlinksInPath()
                guard resolved.path.hasPrefix(runtime.root.path + "/"), (try resolved.resourceValues(forKeys: [.isRegularFileKey])).isRegularFile == true, FileManager.default.isReadableFile(atPath: resolved.path) else { throw CruzadorError.invalid("Componente gráfico indisponível ou externo ao pacote: \(path.path)") }
                if path.pathExtension.lowercased() == "dll" {
                    let expected: UInt16 = path.path.contains("/i386-windows/") ? 0x14c : 0x8664
                    guard try WindowsPEHeader.inspect(resolved) == expected else { throw CruzadorError.invalid("Arquitetura PE inesperada no componente gráfico: \(path.path)") }
                }
                paths.append(path.path)
            }
            for file in files { try component(runtime.root.appendingPathComponent(file)) }
            if backend == .vulkan {
                let icdURL = runtime.root.appendingPathComponent("share/vulkan/icd.d/MoltenVK_icd.json")
                let icd = try JSONDecoder().decode(VulkanICD.self, from: Data(contentsOf: icdURL))
                guard icd.file_format_version == "1.0.0", !icd.ICD.api_version.isEmpty, !icd.ICD.library_path.hasPrefix("/") else { throw CruzadorError.invalid("Manifesto Vulkan não suportado.") }
                try component(icdURL.deletingLastPathComponent().appendingPathComponent(icd.ICD.library_path).standardizedFileURL)
            }
            return GraphicsSupport(backend: backend, requestSupported: true, reason: "Componentes presentes; opção WineD3D reconhecida no código upstream Wine 11.21.", componentPaths: paths, limitations: limits)
        } catch { return GraphicsSupport(backend: backend, requestSupported: false, reason: error.localizedDescription, componentPaths: paths, limitations: limits) }
    }
    public static func environment(backend: GraphicsBackend, engine: Engine, explicitOverride: String?) throws -> [String: String] {
        if let explicitOverride { return ["WINE_D3D_CONFIG": explicitOverride] }
        let support = inspect(backend, engine: engine)
        guard support.requestSupported else { throw CruzadorError.invalid(support.reason) }
        switch backend { case .automatic: return [:]; case .openGL: return ["WINE_D3D_CONFIG": "renderer=gl"]; case .vulkan: return ["WINE_D3D_CONFIG": "renderer=vulkan"] }
    }
}
public struct BottleSettingsStore: Sendable {
    public let store: LibraryStore
    public init(store: LibraryStore) { self.store = store }
    public func save(_ settings: BottleSettings, bottleID: UUID, runner: CommandRunner, operationID: UUID = UUID()) async throws {
        let library = try store.load()
        guard let bottle = library.bottles.first(where: { $0.id == bottleID }) else { throw CruzadorError.invalid("Bottle não encontrada.") }
        try settings.executionOptions.validate()
        _ = try GraphicsConfiguration.environment(backend: settings.graphics, engine: bottle.engine, explicitOverride: settings.executionOptions.environment["WINE_D3D_CONFIG"])
        let next = try SynchronizationConfiguration.environment(settings: settings, engine: bottle.engine)
        if bottle.requestedSettings == settings { return }
        let previous = try SynchronizationConfiguration.environment(settings: bottle.requestedSettings, engine: bottle.engine)
        if previous != next, store.health(of: bottle) != .absent {
            let result = try await runner.run(EngineCommands.make(.waitForIdle, bottle: bottle, store: store), log: store.logsRoot.appendingPathComponent("settings-\(operationID).log"), operationID: operationID)
            try result.requireSuccess()
        }
        var current = try store.load()
        guard let index = current.bottles.firstIndex(where: { $0.id == bottleID }), current.bottles[index].requestedSettings == bottle.requestedSettings else { throw CruzadorError.invalid("A configuração mudou durante a espera. Confira e tente novamente.") }
        current.bottles[index].configuration = settings
        try store.save(current)
    }
}
