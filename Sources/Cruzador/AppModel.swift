import AppKit
import SwiftUI
import UniformTypeIdentifiers
import CruzadorCore

@MainActor
final class AppModel: ObservableObject {
    @Published var library = Library()
    @Published var selection: UUID?
    @Published var busy = false
    @Published var status = "Sua biblioteca Windows no Mac"
    @Published var error: String?
    @Published var lastLog: URL?
    @Published var showCreate = false
    @Published var showRegister = false
    @Published var search = ""
    @Published var engineKind: EngineKind = .crossOver
    @Published var enginePath = "/Applications/CrossOver.app"
    @Published var loaded = false
    let store = LibraryStore(root: LibraryStore.defaultRoot)
    private let runner = CommandRunner()
    var selected: Bottle? { library.bottles.first { $0.id == selection } }
    var filteredBottles: [Bottle] { library.bottles.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) } }
    init() {
        if let raw = UserDefaults.standard.string(forKey: "engineKind"), let kind = EngineKind(rawValue: raw) { engineKind = kind }
        if let path = UserDefaults.standard.string(forKey: "enginePath") { enginePath = path }
        reload()
    }
    func reload() {
        do {
            library = try store.load(); loaded = true
            if selection == nil { selection = library.bottles.first?.id }
        } catch { loaded = false; self.error = "Não foi possível abrir a biblioteca: \(error.localizedDescription)" }
    }
    func saveEngine() {
        UserDefaults.standard.set(engineKind.rawValue, forKey: "engineKind")
        UserDefaults.standard.set(enginePath, forKey: "enginePath")
    }
    private func persist(_ next: Library) throws { try store.save(next); library = next }
    func create(name: String) {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, loaded, !busy else { return }
        let bottle = Bottle(name: name, engine: Engine(kind: engineKind, path: enginePath))
        do {
            _ = try EngineCommands.make(.initialize, bottle: bottle, store: store)
            var next = library; next.bottles.append(bottle); try persist(next)
            selection = bottle.id; showCreate = false
            perform(.initialize, bottle: bottle, title: "Preparando \(name)…")
        } catch { self.error = error.localizedDescription }
    }
    func perform(_ action: BottleAction, bottle: Bottle, title: String) {
        guard loaded, !busy else { return }
        do {
            switch action {
            case .initialize: break
            default:
                guard bottle.state == .ready, store.isInitialized(bottle) else { throw CruzadorError.invalid("A bottle ainda não está pronta. Use Preparar novamente ou consulte o log.") }
            }
            let command = try EngineCommands.make(action, bottle: bottle, store: store)
            let log = store.logsRoot.appendingPathComponent("\(Date().timeIntervalSince1970)-\(UUID().uuidString).log")
            busy = true; status = title; lastLog = log
            Task {
                defer { busy = false }
                do {
                    let result = try await runner.run(command, log: log)
                    if case .initialize = action {
                        var next = library
                        if let index = next.bottles.firstIndex(where: { $0.id == bottle.id }) {
                            next.bottles[index].state = result.exitCode == 0 && store.isInitialized(bottle) ? .ready : .failed
                        }
                        try persist(next)
                    }
                    guard result.exitCode == 0 else { throw CruzadorError.invalid("O motor terminou com código \(result.exitCode). Consulte o log para os detalhes.") }
                    if case .initialize = action, !store.isInitialized(bottle) { throw CruzadorError.invalid("O motor não gerou uma bottle válida. Consulte o log.") }
                    status = "Operação concluída"
                } catch {
                    status = "Operação não concluída"
                    // Preserve the record and partial prefix for diagnosis/retry.
                    if case .initialize = action {
                        var next = library
                        if let index = next.bottles.firstIndex(where: { $0.id == bottle.id }) { next.bottles[index].state = .failed }
                        do { try persist(next) } catch { self.error = "Falha ao salvar o estado: \(error.localizedDescription)"; return }
                    }
                    self.error = error.localizedDescription
                }
            }
        } catch { self.error = error.localizedDescription }
    }
    func chooseProgram(installer: Bool = false) {
        guard let bottle = selected, !busy else { return }
        let panel = NSOpenPanel(); panel.canChooseDirectories = false
        panel.allowedContentTypes = ["exe", "msi"].compactMap { UTType(filenameExtension: $0) }
        panel.message = installer ? "Escolha o instalador Windows" : "Escolha o executável Windows"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        perform(installer ? .install(url.path) : .run(url.path, []), bottle: bottle, title: installer ? "Instalando programa…" : "Executando programa…")
    }
    func register(name: String, path: String, arguments: String) {
        guard let selected, !busy else { return }
        do {
            _ = try EngineCommands.make(.run(path, []), bottle: selected, store: store)
            let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { throw CruzadorError.invalid("Informe um nome para o aplicativo.") }
            var next = library
            guard let index = next.bottles.firstIndex(where: { $0.id == selected.id }) else { return }
            next.bottles[index].apps.append(WindowsApp(name: name, path: path, arguments: arguments.isEmpty ? [] : arguments.components(separatedBy: "\n")))
            try persist(next); showRegister = false
        } catch { self.error = error.localizedDescription }
    }
    func removeShortcut(_ app: WindowsApp, bottle: Bottle) {
        guard !busy else { return }
        do {
            var next = library
            guard let index = next.bottles.firstIndex(where: { $0.id == bottle.id }) else { return }
            next.bottles[index].apps.removeAll { $0.id == app.id }; try persist(next)
        } catch { self.error = error.localizedDescription }
    }
}
