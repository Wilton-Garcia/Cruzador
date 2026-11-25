import Foundation

/// The library owns one sheet at a time; incoming files retain their separate queue.
enum AppPresentation: String, Identifiable {
    case compatibility, create, register, installer, recipes, discovery, bottleSettings, history, diagnostics, incoming
    var id: String { rawValue }
}
