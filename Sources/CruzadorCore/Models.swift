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
    public static let crossOver = Engine(kind: .crossOver, path: "/Applications/CrossOver.app")
}
public enum BottleState: String, Codable, Sendable { case preparing, ready, failed }
public struct WindowsApp: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var path: String
    public var arguments: [String]
    public init(name: String, path: String, arguments: [String] = []) {
        id = UUID(); self.name = name; self.path = path; self.arguments = arguments
    }
}
public struct Bottle: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public let engine: Engine
    public let createdAt: Date
    public var state: BottleState
    public var apps: [WindowsApp]
    public init(name: String, engine: Engine) {
        id = UUID(); self.name = name; self.engine = engine; createdAt = Date(); state = .preparing; apps = []
    }
}
public struct Library: Codable, Sendable {
    public var version = 1
    public var bottles: [Bottle] = []
    public init() {}
}
public enum CruzadorError: LocalizedError {
    case invalid(String)
    public var errorDescription: String? { switch self { case .invalid(let text): text } }
}
