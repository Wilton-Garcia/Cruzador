import AppKit
import SwiftUI
import CruzadorCore

@main
struct CruzadorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene {
        Window("Cruzador", id: "library") {
            LibraryRootView(delegate: delegate).frame(minWidth: 980, minHeight: 650)
        }
        .defaultSize(width: 1140, height: 760)
        .defaultPosition(.center)
        .commands { LibraryCommands(model: delegate.model, showLibrary: delegate.showLibraryWindow) }
        Settings { EngineSettings(model: delegate.model).frame(width: 560).padding(28) }
    }
}
private struct LibraryRootView: View {
    let delegate: AppDelegate
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        ContentView(model: delegate.model).onAppear {
            let action = openWindow
            delegate.openLibraryWindow = { action(id: "library") }
            delegate.loadDocumentHistoryIfNeeded()
            NSLog("Cruzador library scene appeared; selected root: %@", delegate.model.store.root.path)
        }
    }
}

struct LibraryCommands: Commands {
    @ObservedObject var model: AppModel
    let showLibrary: () -> Void
    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Biblioteca") { showLibrary() }.keyboardShortcut("0")
            Button("Nova bottle…") { showLibrary(); model.presentation = .create }.keyboardShortcut("n").disabled(!model.canStart || !model.loaded || model.presentation != nil)
            Button("Abrir…") { showLibrary(); model.openFile() }.keyboardShortcut("o").disabled(model.busy || model.presentation != nil)
            Button("Buscar na biblioteca") { showLibrary(); model.searchFocusRequest = UUID() }.keyboardShortcut("f").disabled(model.presentation != nil)
            Button("Adicionar atalho…") { showLibrary(); model.beginRegister() }.keyboardShortcut("a", modifiers: [.command, .shift]).disabled(!model.canStart || model.presentation != nil || model.selected.map { !model.store.isReady($0) } != false)
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
    let model: AppModel = {
        switch ApplicationLibrarySelection.resolve(arguments: Array(CommandLine.arguments.dropFirst())) {
        case .success(let root): return AppModel(store: LibraryStore(root: root ?? LibraryStore.defaultRoot))
        case .failure(let error): return AppModel(startupError: error.localizedDescription)
        }
    }()
    var openLibraryWindow: (() -> Void)?
    private var documentHistoryLoaded = false
    func loadDocumentHistoryIfNeeded() {
        guard !documentHistoryLoaded else { return }
        model.loadRecentDocuments(); documentHistoryLoaded = true
    }
    func applicationDidFinishLaunching(_ notification: Notification) { loadDocumentHistoryIfNeeded() }
    func showLibraryWindow() {
        openLibraryWindow?()
        NSApp.activate(ignoringOtherApps: true)
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
        alert.informativeText = model.canCancelOperation ? "Cancele a operação pelo aplicativo ou feche o programa Windows e aguarde o encerramento antes de sair do Cruzador." : "Aguarde a conclusão da etapa atual antes de sair do Cruzador."
        alert.runModal(); return .terminateCancel
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
