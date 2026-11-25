import AppKit
import SwiftUI
import CruzadorCore

@main
struct CruzadorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var model = AppModel()
    var body: some Scene {
        WindowGroup {
            ContentView(model: model).frame(minWidth: 980, minHeight: 650)
                .onAppear { delegate.model = model; NSApp.setActivationPolicy(.regular); NSApp.activate(ignoringOtherApps: true) }
        }
        .defaultSize(width: 1140, height: 760)
        .commands { CommandGroup(replacing: .newItem) { Button("Nova bottle…") { model.showCreate = true }.keyboardShortcut("n").disabled(!model.canStart || !model.loaded) } }
        Settings { EngineSettings(model: model).frame(width: 560).padding(28) }
    }
}
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var model: AppModel?
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard model?.busy == true else { return .terminateNow }
        let alert = NSAlert(); alert.messageText = "Há uma operação em andamento"
        alert.informativeText = "Cancele a operação pelo aplicativo ou feche o programa Windows e aguarde o encerramento antes de sair do Cruzador."
        alert.runModal(); return .terminateCancel
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
