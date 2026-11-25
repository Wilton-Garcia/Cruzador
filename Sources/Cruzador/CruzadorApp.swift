import AppKit
import SwiftUI
import CruzadorCore

@main
struct CruzadorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene {
        Settings { EngineSettings(model: delegate.model).frame(width: 560).padding(28) }
        .commands { LibraryCommands(model: delegate.model, showLibrary: delegate.showLibraryWindow) }
    }
}
struct LibraryCommands: Commands {
    @ObservedObject var model: AppModel
    let showLibrary: () -> Void
    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Biblioteca") { showLibrary() }.keyboardShortcut("0")
            Button("Nova bottle…") { showLibrary(); model.showCreate = true }.keyboardShortcut("n").disabled(!model.canStart || !model.loaded)
            Button("Abrir…") { showLibrary(); model.openFile() }.keyboardShortcut("o")
            Menu("Abrir recentes") {
                ForEach(model.recentDocuments, id: \.self) { url in
                    Button(url.lastPathComponent) { showLibrary(); model.receiveExternal([url]) }
                }
                Divider()
                Button("Limpar menu") { model.clearRecentDocuments() }.disabled(model.recentDocuments.isEmpty)
            }
        }
    }
}
/// Owns the single library window and external events, including cold file opens.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()
    private var libraryWindow: NSWindow?
    func applicationDidFinishLaunching(_ notification: Notification) { showLibraryWindow() }
    func showLibraryWindow() {
        if libraryWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1140, height: 760), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = "Cruzador"
            window.contentMinSize = NSSize(width: 980, height: 650)
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: ContentView(model: model).frame(minWidth: 980, minHeight: 650))
            window.center()
            libraryWindow = window
        }
        NSApp.setActivationPolicy(.regular)
        libraryWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        NSLog("Cruzador library window: visible=%d", libraryWindow?.isVisible == true)
    }
    func application(_ application: NSApplication, open urls: [URL]) {
        showLibraryWindow()
        model.receiveExternal(urls)
        NSLog("Cruzador external opening: received=%ld pending=%ld", urls.count, model.incomingRequests.count)
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showLibraryWindow(); return false
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard model.busy else { return .terminateNow }
        let alert = NSAlert(); alert.messageText = "Há uma operação em andamento"
        alert.informativeText = "Cancele a operação pelo aplicativo ou feche o programa Windows e aguarde o encerramento antes de sair do Cruzador."
        alert.runModal(); return .terminateCancel
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
