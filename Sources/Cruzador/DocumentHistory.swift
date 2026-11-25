import AppKit

@MainActor
protocol DocumentHistory {
    var urls: [URL] { get }
    func note(_ url: URL)
    func clear()
}
/// Native document history is accessed after application startup, not during model construction.
@MainActor
struct SystemDocumentHistory: DocumentHistory {
    var urls: [URL] { NSDocumentController.shared.recentDocumentURLs }
    func note(_ url: URL) { NSDocumentController.shared.noteNewRecentDocumentURL(url) }
    func clear() { NSDocumentController.shared.clearRecentDocuments(nil) }
}
