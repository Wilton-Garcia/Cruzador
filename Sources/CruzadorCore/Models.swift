import Foundation

public enum EngineKind: String, Codable, CaseIterable, Sendable {
    case crossOver, wine, packagedWine
    public var displayName: String {
        switch self {
        case .crossOver: "CrossOver"
        case .wine: "Wine externo"
        case .packagedWine: "Wine do Cruzador"
        }
    }
}
public struct Engine: Codable, Equatable, Sendable {
    public var kind: EngineKind
    public var path: String
    public init(kind: EngineKind, path: String) { self.kind = kind; self.path = path }
}
public enum BottleState: String, Codable, Sendable { case preparing, ready, failed, interrupted }
public struct WindowsApp: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var path: String
    public var arguments: [String]
    public var options: LaunchOptions?
    public var launchRequest: LaunchRequest { LaunchRequest(path: path, arguments: arguments, options: options ?? LaunchOptions()) }
    public init(name: String, path: String, arguments: [String] = [], options: LaunchOptions? = nil) {
        id = UUID(); self.name = name; self.path = path; self.arguments = arguments; self.options = options
    }
}
public struct Bottle: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public let engine: Engine
    public let createdAt: Date
    public var state: BottleState
    public var lastError: String?
    public var lastLogPath: String?
    public var installations: [InstallationRecord]?
    public var apps: [WindowsApp]
    public var configuration: BottleSettings?
    public var requestedSettings: BottleSettings { configuration ?? BottleSettings() }
    public init(name: String, engine: Engine) {
        id = UUID(); self.name = name; self.engine = engine; createdAt = Date(); state = .preparing; apps = []
    }
}
public struct LibraryPreferences: Codable, Sendable {
    public var defaultBottleID: UUID?
    public init(defaultBottleID: UUID? = nil) { self.defaultBottleID = defaultBottleID }
}
public struct Library: Codable, Sendable {
    public static let currentVersion = 4
    public var version = currentVersion
    public var preferences = LibraryPreferences()
    public var bottles: [Bottle] = []
    public init() {}
    private enum CodingKeys: String, CodingKey { case version, preferences, bottles }
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        bottles = try container.decode([Bottle].self, forKey: .bottles)
        preferences = try container.decodeIfPresent(LibraryPreferences.self, forKey: .preferences) ?? LibraryPreferences()
    }
}
public enum CruzadorError: LocalizedError {
    case invalid(String)
    public var errorDescription: String? { switch self { case .invalid(let text): text } }
}
