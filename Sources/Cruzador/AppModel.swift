import AppKit
import SwiftUI
import UniformTypeIdentifiers
import CruzadorCore

@MainActor
final class AppModel: ObservableObject {
    @Published var library = Library()
    @Published var selection: UUID?
    @Published var busy = false
    @Published var cancelling = false
    @Published private(set) var preparingBottleID: UUID?
    @Published var cleanupOperationID: UUID?
    private var activeOperationID: UUID?
    @Published var status = "Sua biblioteca Windows no Mac"
    @Published var error: String?
    @Published var lastLog: URL?
    @Published var editingApp: WindowsApp?
    @Published var selectedInstaller: WindowsFileInspection?
    @Published var recipeCatalog: RecipeCatalog?
    private var recipeTask: Task<Void, Never>?
    @Published var discoveryReport: AppDiscoveryReport?
    @Published var incomingRequests: [ExternalOpenRequest] = []
    @Published var recentDocuments: [URL] = []
    @Published var presentation: AppPresentation?
    @Published var searchFocusRequest = UUID()
    @Published var search = ""
    @Published var engineKind: EngineKind = .packagedWine
    @Published var enginePath = WineRuntime.bundledRoot.path
    private var enginePreferenceError: String?
    @Published private(set) var installerPreferences = InstallerPreferences()
    @Published private(set) var installerPreferenceProblem: String?
    @Published var cacheStatus = "Cache ainda não inspecionado"
    @Published var loaded = false
    let store: LibraryStore
    private let preferences: UserDefaults
    private let documents: any DocumentHistory
    private let runner = CommandRunner()
    var canCancelOperation: Bool { activeOperationID != nil }
    var canStart: Bool { !busy && cleanupOperationID == nil }
    var selected: Bottle? { library.bottles.first { $0.id == selection } }
    var searchResults: [LibrarySearchMatch] { LibrarySearch(text: search).results(in: library) }
    var filteredBottles: [Bottle] { searchResults.map(\.bottle) }
    func filteredApps(in bottle: Bottle) -> [WindowsApp] { searchResults.first { $0.bottle.id == bottle.id }?.apps ?? [] }
    init(store: LibraryStore = LibraryStore(root: LibraryStore.defaultRoot), preferences: UserDefaults = .standard, documents: (any DocumentHistory)? = nil) {
        self.store = store; self.preferences = preferences; self.documents = documents ?? SystemDocumentHistory()
        do {
            let engine = try EnginePreferences.load(from: preferences)
            engineKind = engine.kind; enginePath = engine.path
        } catch { enginePreferenceError = error.localizedDescription }
        do {
            try store.migrateIfNeeded()
            try BottleLifecycle(store: store).recoverInterruptedPreparations()
            try InstallationService(store: store).recoverInterrupted()
        }
        catch { self.error = error.localizedDescription }
        do { installerPreferences = try InstallerPreferencesStore(library: store).load() }
        catch { installerPreferenceProblem = error.localizedDescription; self.error = "Preferências de instalação inválidas: " + error.localizedDescription }
        reload()
        if let enginePreferenceError { error = enginePreferenceError }
    }
    func reload() {
        guard !busy else { return }
        do {
            library = try store.load(); loaded = true
            if selection == nil { selection = library.preferences.defaultBottleID ?? library.bottles.first?.id }
        } catch { loaded = false; self.error = "Não foi possível abrir a biblioteca: \(error.localizedDescription)" }
    }
    func saveEngine() {
        do {
            try EnginePreferences.save(Engine(kind: engineKind, path: enginePath), to: preferences)
            enginePreferenceError = nil
        } catch { self.error = error.localizedDescription }
    }
    func selectEngine(_ kind: EngineKind) {
        engineKind = kind
        enginePath = kind == .packagedWine ? WineRuntime.bundledRoot.path : ""
    }
    private func persist(_ next: Library) throws { try store.save(next); library = next }
    func create(name: String) {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, loaded, canStart, presentation == .create else { return }
        do {
            if let enginePreferenceError { throw CruzadorError.invalid(enginePreferenceError) }
            let bottle = try BottleLifecycle(store: store).create(name: name, engine: Engine(kind: engineKind, path: enginePath))
            library = try store.load()
            selection = bottle.id; dismissPresentation(.create)
            perform(.initialize, bottle: bottle, title: "Preparando \(name)…")
        } catch { self.error = error.localizedDescription }
    }
    func perform(_ action: BottleAction, bottle: Bottle, title: String) {
        guard loaded, canStart else { return }
        do {
            switch action {
            case .initialize, .repair: break
            default:
                guard store.isReady(bottle) else { throw CruzadorError.invalid("A bottle ainda não está pronta. Use Preparar novamente ou consulte o log.") }
            }
            let command: EnginePlan?
            switch action {
            case .initialize, .repair, .reboot, .install: command = nil
            default: command = try EngineCommands.make(action, bottle: bottle, store: store)
            }
            let log = store.logsRoot.appendingPathComponent("\(Date().timeIntervalSince1970)-\(UUID().uuidString).log")
            let operationID = UUID()
            activeOperationID = operationID; cancelling = false
            switch action { case .initialize, .repair, .reboot: preparingBottleID = bottle.id; default: preparingBottleID = nil }
            busy = true; status = title; lastLog = log
            Task {
                defer { busy = false; activeOperationID = nil; cancelling = false; preparingBottleID = nil }
                do {
                    let result: RunResult
                    switch action {
                    case .initialize, .repair, .reboot:
                        result = try await BottleLifecycle(store: store).prepare(id: bottle.id, mode: {
                            if case .repair = action { return .repair }; if case .reboot = action { return .reboot }; return .initialize
                        }(), runner: runner, log: log, operationID: operationID)
                        library = try store.load()
                    case .install(let request):
                        result = try await InstallationService(store: store).run(request, bottle: bottle, runner: runner, log: log, operationID: operationID)
                        library = try store.load()
                    default:
                        guard let command else { throw CruzadorError.invalid("Plano de execução ausente.") }
                        result = try await runner.run(command, log: log, operationID: operationID)
                    }
                    try result.requireSuccess()
                    status = "Operação concluída"
                } catch {
                    status = "Operação não concluída"
                    let message = preserveShutdownFailure(error, bottleID: bottle.id, operationID: operationID)
                    do { library = try store.load() }
                    catch { self.error = "\(message)\nNão foi possível reler a biblioteca: \(error.localizedDescription)"; return }
                    self.error = message
                }
            }
        } catch { self.error = error.localizedDescription }
    }
    private func preserveShutdownFailure(_ error: Error, bottleID: UUID, operationID: UUID) -> String {
        guard let failure = BottleOperationRecovery.shutdownFailure(in: error) else { return error.localizedDescription }
        cleanupOperationID = operationID
        do {
            try BottleOperationRecovery(store: store).record(error, bottleID: bottleID)
            library = try store.load()
            return error.localizedDescription
        } catch {
            if let recovery = error as? BottleRecoveryError { return recovery.localizedDescription }
            return BottleOperationRecovery.preservingShutdownFailure(failure, persistenceFailure: error).localizedDescription
        }
    }
    func exportDiagnostics(includeSourceLibrary: Bool, includeLogs: Bool, selectedBottleOnly: Bool) {
        guard !busy else { return }
        let panel = NSSavePanel(); panel.nameFieldStringValue = "Cruzador-suporte.cruzadordiagnostics"
        panel.message = "Salva um pacote local. Nenhum dado será enviado."
        guard panel.runModal() == .OK, let destination = panel.url else { return }
        let bottleID = selectedBottleOnly ? selection : nil
        let service = DiagnosticsService(store: store)
        busy = true; status = "Preparando diagnóstico local…"
        Task {
            defer { busy = false }
            do {
                let result = try await Task.detached(priority: .userInitiated) { try service.export(to: destination, bottleID: bottleID, includeSourceLibrary: includeSourceLibrary, includeLogs: includeLogs) }.value
                dismissPresentation(.diagnostics); status = "Diagnóstico exportado; revise os arquivos antes de compartilhar"
                NSWorkspace.shared.activateFileViewerSelecting([result])
            } catch { self.error = error.localizedDescription; status = "Diagnóstico não concluído" }
        }
    }
    func loadRecentDocuments() { recentDocuments = documents.urls }
    func dismissPresentation(_ expected: AppPresentation) {
        if presentation == expected { presentation = nil }
    }
    func reviewIncoming() {
        guard !busy, presentation == nil, !incomingRequests.isEmpty else { return }
        presentation = .incoming
    }
    func receiveExternal(_ urls: [URL]) {
        for url in urls {
            do { incomingRequests.append(try ExternalOpenRequest(source: url)) }
            catch { self.error = "\(url.absoluteString): \(error.localizedDescription)" }
        }
        reviewIncoming()
    }
    func discardIncoming() {
        if !incomingRequests.isEmpty { incomingRequests.removeFirst() }
        dismissPresentation(.incoming)
    }
    func openFile() {
        guard !busy, presentation == nil else { return }
        let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = true
        panel.allowsMultipleSelection = true; panel.treatsFilePackagesAsDirectories = false
        panel.message = "Abra um programa Windows, atalho ou transferência do Cruzador."
        guard panel.runModal() == .OK else { return }
        receiveExternal(panel.urls)
    }
    func clearRecentDocuments() {
        documents.clear()
        recentDocuments = []
    }
    func acceptIncoming(bottleID: UUID?, install: Bool) {
        guard loaded, canStart, let incoming = incomingRequests.first else { return }
        do {
            let current = try store.load()
            switch incoming.target {
            case .launcher(let reference):
                let resolved = try reference.resolve(in: current)
                guard store.isReady(resolved.bottle) else { throw CruzadorError.invalid("A bottle do atalho precisa ser preparada antes de executar.") }
                selection = resolved.bottle.id
                perform(.run(resolved.app.launchRequest), bottle: resolved.bottle, title: "Executando \(resolved.app.name)…")
                guard busy else { return }
            case .windowsFile(let url):
                guard let bottle = current.bottles.first(where: { $0.id == bottleID }), store.isReady(bottle) else { throw CruzadorError.invalid("Selecione uma bottle pronta.") }
                let inspection = try WindowsFileInspection.inspect(path: url.path)
                selection = bottle.id
                if install {
                    selectedInstaller = inspection; presentation = .installer
                } else {
                    perform(.run(LaunchRequest(path: url.path)), bottle: bottle, title: "Executando \(url.lastPathComponent)…")
                    guard busy else { return }
                }
            case .bottlePackage(let url):
                if let enginePreferenceError { throw CruzadorError.invalid(enginePreferenceError) }
                let engine = Engine(kind: engineKind, path: enginePath)
                maintenance("Importando bottle…") { service in try service.importBottle(from: url, engine: engine).id }
            }
            if incoming.source.isFileURL {
                documents.note(incoming.source)
                recentDocuments = documents.urls
            }
            discardIncoming()
        } catch { self.error = error.localizedDescription }
    }
    func exportLauncher(_ app: WindowsApp, bottle: Bottle) {
        guard canStart else { return }
        let panel = NSSavePanel(); panel.allowedContentTypes = [UTType(filenameExtension: "cruzadorapp") ?? .data]
        panel.nameFieldStringValue = app.name + ".cruzadorapp"
        panel.message = "O arquivo referencia este atalho na biblioteca atual. Ele não contém o programa Windows."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let reference = LauncherReference(bottleID: bottle.id, appID: app.id)
            _ = try reference.resolve(in: store.load())
            try reference.write(to: url)
            NSWorkspace.shared.activateFileViewerSelecting([url])
            status = "Atalho exportado"
        } catch { self.error = error.localizedDescription }
    }
    func copyLauncherLink(_ app: WindowsApp, bottle: Bottle) {
        let link = LauncherReference(bottleID: bottle.id, appID: app.id).link
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(link.absoluteString, forType: .string)
        status = "Link do atalho copiado"
    }
    func chooseProgram(installer: Bool = false) {
        guard let bottle = selected, canStart else { return }
        let panel = NSOpenPanel(); panel.canChooseDirectories = false
        panel.allowedContentTypes = ["exe", "msi"].compactMap { UTType(filenameExtension: $0) }
        panel.message = installer ? "Escolha o instalador Windows" : "Escolha o executável Windows"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        if installer {
            do { selectedInstaller = try WindowsFileInspection.inspect(path: url.path); presentation = .installer }
            catch { self.error = error.localizedDescription }
        } else { perform(.run(LaunchRequest(path: url.path)), bottle: bottle, title: "Executando programa…") }
    }
    func installSelected(mode: InstallerMode, arguments: String, workingDirectory: String, environmentJSON: String) {
        guard let inspection = selectedInstaller, let bottle = selected, canStart, presentation == .installer else { return }
        do {
            try requireInstallerPreferences()
            let options = try LaunchOptions.parse(workingDirectory: workingDirectory, environmentJSON: environmentJSON)
            let request = try InstallationRequest(inspection: inspection, mode: mode, arguments: arguments.isEmpty ? [] : arguments.components(separatedBy: "\n"), options: options)
            dismissPresentation(.installer)
            perform(.install(request), bottle: bottle, title: "Instalando \(URL(fileURLWithPath: inspection.path).lastPathComponent)…")
        } catch { self.error = error.localizedDescription }
    }
    private func requireInstallerPreferences() throws {
        if let installerPreferenceProblem { throw CruzadorError.invalid("Corrija e salve as preferências de instalação antes de instalar: " + installerPreferenceProblem) }
    }
    func saveInstallerPreferences(_ preferences: InstallerPreferences) {
        guard canStart else { return }
        do {
            try InstallerPreferencesStore(library: store).save(preferences)
            installerPreferences = try InstallerPreferencesStore(library: store).load(); installerPreferenceProblem = nil
            cacheStatus = "Preferências salvas; inspecione o cache selecionado"; status = "Preferências de instalação salvas"
        } catch { self.error = error.localizedDescription }
    }
    func inspectInstallerCache(clear: Bool = false) {
        guard canStart else { return }
        let root: URL
        do { try requireInstallerPreferences(); root = try installerPreferences.cacheRoot(library: store) }
        catch { self.error = error.localizedDescription; return }
        busy = true; status = "Inspecionando instaladores armazenados…"
        Task {
            defer { busy = false }
            do {
                let inventory = try await Task.detached { try InstallerCacheInventory.scan(root: root) }.value
                cacheStatus = "\(inventory.availableCount) instaladores presentes, \(inventory.missingCount) recibos sem arquivo, \(inventory.unavailableCount) entradas indisponíveis, \(inventory.knownBytes.formatted()) bytes; \(inventory.unrecognized.count) itens não reconhecidos preservados."
                guard clear else { status = "Cache inspecionado"; return }
                guard !inventory.ownedPaths.isEmpty else { status = "Nenhum arquivo reconhecido para mover"; return }
                let alert = NSAlert(); alert.messageText = "Mover o cache reconhecido para a Lixeira?"
                alert.informativeText = "Somente instaladores e recibos reconhecidos serão movidos. Outros arquivos serão mantidos. O modo somente-cache precisará desses arquivos novamente para reinstalar."
                alert.addButton(withTitle: "Mover para a Lixeira"); alert.addButton(withTitle: "Cancelar")
                guard alert.runModal() == .alertFirstButtonReturn else { status = "Limpeza cancelada"; return }
                let reportFile = store.logsRoot.appendingPathComponent("cache-cleanup-\(UUID()).json")
                try FileManager.default.createDirectory(at: store.logsRoot, withIntermediateDirectories: true)
                try Data("{\"status\":\"started\"}\n".utf8).write(to: reportFile, options: .withoutOverwriting)
                lastLog = reportFile
                let result = try await Task.detached { try InstallerCacheCleaner.clear(root: root) }.value
                let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                do { try encoder.encode(result).write(to: reportFile, options: .atomic) }
                catch {
                    status = "\(result.moves.count) arquivos movidos; falha ao registrar resultado"
                    self.error = status + ": " + error.localizedDescription + "\n" + result.moves.map { $0.source.path + " → " + ($0.destination?.path ?? "destino não informado pelo macOS") }.joined(separator: "\n")
                    return
                }
                status = "\(result.moves.count) arquivos movidos para a Lixeira"
                cacheStatus = status + "; \(result.unrecognized.count) itens não reconhecidos preservados."
                if !result.errors.isEmpty { self.error = "A limpeza foi parcial: " + result.errors.joined(separator: "\n") }

            } catch { self.error = error.localizedDescription; status = "Cache não pôde ser inspecionado" }
        }
    }
    func saveBottleSettings(_ settings: BottleSettings, bottleID: UUID) {
        guard canStart, presentation == .bottleSettings else { return }
        let operationID = UUID()
        busy = true; activeOperationID = operationID; cancelling = false
        status = "Salvando opções; mudanças de sincronização aguardam o servidor…"
        Task {
            defer { busy = false; activeOperationID = nil; cancelling = false; preparingBottleID = nil }
            do {
                try await BottleSettingsStore(store: store).save(settings, bottleID: bottleID, runner: runner, operationID: operationID)
                library = try store.load(); dismissPresentation(.bottleSettings)
                status = "Configuração salva para os próximos processos Windows"
            } catch {
                self.error = preserveShutdownFailure(error, bottleID: bottleID, operationID: operationID)
                status = "Configuração não salva; confira o diagnóstico"
            }
        }
    }

    func discoverApps() {
        guard let bottle = selected, canStart else { return }
        busy = true; status = "Buscando aplicativos na bottle…"
        let discovery = AppDiscovery(store: store)
        Task {
            defer { busy = false }
            do {
                discoveryReport = try await Task.detached(priority: .userInitiated) { try discovery.scan(bottle) }.value
                presentation = .discovery; status = "Busca concluída; confira a cobertura e os candidatos"
            } catch { self.error = error.localizedDescription; status = "Busca não concluída" }
        }
    }
    func addDiscovered(_ ids: Set<String>, report: AppDiscoveryReport) {
        guard canStart else { return }
        do {
            try AppDiscovery(store: store).add(ids: ids, from: report)
            library = try store.load(); selection = report.bottleID
            dismissPresentation(.discovery); status = "Atalhos adicionados"
        } catch { self.error = error.localizedDescription }
    }
    func openRecipes() {
        guard canStart else { return }
        do { recipeCatalog = try RecipeCatalog(data: Data(contentsOf: RecipeCatalog.bundledURL)); presentation = .recipes }
        catch { self.error = "Não foi possível abrir o catálogo incluído: \(error.localizedDescription)" }
    }
    func installRecipe(id: String, catalog: RecipeCatalog) {
        guard let bottle = selected, store.isReady(bottle), canStart, presentation == .recipes else { return }
        let cacheRoot: URL
        do { try requireInstallerPreferences(); cacheRoot = try installerPreferences.cacheRoot(library: store) }
        catch { self.error = error.localizedDescription; return }
        let operationID = UUID()
        let service = RecipeInstallationService(store: store, runner: runner, cache: ArtifactCache(root: cacheRoot, downloadPolicy: installerPreferences.downloadPolicy), operationID: operationID)
        dismissPresentation(.recipes); busy = true; cancelling = false; activeOperationID = operationID
        status = "Preparando receita…"
        recipeTask = Task {
            defer { busy = false; cancelling = false; activeOperationID = nil; recipeTask = nil }
            do {
                _ = try await service.install(id: id, bottleID: bottle.id, catalog: catalog) { message in
                    await MainActor.run { if self.activeOperationID == operationID { self.status = message } }
                }
                library = try store.load()
                lastLog = library.bottles.first(where: { $0.id == bottle.id })?.installations?.last.map { URL(fileURLWithPath: $0.logPath) }
                status = "Receita concluída; atalhos verificados"
            } catch {
                let message = preserveShutdownFailure(error, bottleID: bottle.id, operationID: operationID)
                do {
                    library = try store.load()
                    lastLog = library.bottles.first(where: { $0.id == bottle.id })?.installations?.last.map { URL(fileURLWithPath: $0.logPath) }
                } catch { self.error = "\(message)\n\(error.localizedDescription)"; return }
                self.error = message; status = "Receita não concluída"
            }
        }
    }
    func beginRegister(_ app: WindowsApp? = nil) {
        guard canStart, presentation == nil, let bottle = selected, app != nil || store.isReady(bottle) else { return }
        editingApp = app; presentation = .register
    }
    func register(name: String, path: String, arguments: String, workingDirectory: String, environmentJSON: String) {
        guard let selected, canStart, presentation == .register else { return }
        do {
            let options = try LaunchOptions.parse(workingDirectory: workingDirectory, environmentJSON: environmentJSON)
            let request = LaunchRequest(path: path, arguments: arguments.isEmpty ? [] : arguments.components(separatedBy: "\n"), options: options)
            try request.validate()
            let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { throw CruzadorError.invalid("Informe um nome para o aplicativo.") }
            var next = try store.load()
            guard let index = next.bottles.firstIndex(where: { $0.id == selected.id }) else { return }
            var app = WindowsApp(name: name, path: path, arguments: request.arguments, options: options)
            if let editingApp {
                guard let appIndex = next.bottles[index].apps.firstIndex(where: { $0.id == editingApp.id }) else { throw CruzadorError.invalid("O atalho não existe mais nesta bottle.") }
                app.id = editingApp.id; next.bottles[index].apps[appIndex] = app
            } else { next.bottles[index].apps.append(app) }
            try persist(next); dismissPresentation(.register)
        } catch { self.error = error.localizedDescription }
    }
    func removeShortcut(_ app: WindowsApp, bottle: Bottle) {
        guard !busy else { return }
        do {
            var next = try store.load()
            guard let index = next.bottles.firstIndex(where: { $0.id == bottle.id }) else { return }
            next.bottles[index].apps.removeAll { $0.id == app.id }; try persist(next)
        } catch { self.error = error.localizedDescription }
    }
    private func maintenance(_ title: String, bottleID: UUID? = nil, operation: @escaping @Sendable (BottleMaintenance) async throws -> UUID?) {
        guard loaded, canStart else { return }
        busy = true; status = title; cancelling = false
        let service = BottleMaintenance(store: store, runner: runner)
        activeOperationID = service.operationID
        Task {
            defer { busy = false; activeOperationID = nil; cancelling = false; preparingBottleID = nil }
            do {
                let selectedID = try await operation(service)
                library = try store.load()
                selection = selectedID ?? library.bottles.first?.id
                status = "Operação concluída"
            } catch {
                status = "Operação não concluída"
                if let bottleID { self.error = preserveShutdownFailure(error, bottleID: bottleID, operationID: service.operationID) }
                else { self.error = error.localizedDescription }
            }
        }
    }
    func cancelCurrentOperation() {
        guard let operationID = activeOperationID, busy, !cancelling else { return }
        cancelling = true; status = "Solicitando encerramento…"
        let recipe = recipeTask
        Task {
            let accepted = await runner.cancel(operationID: operationID)
            recipe?.cancel()
            if activeOperationID == operationID {
                status = accepted || recipe != nil ? "Aguardando encerramento e limpeza…" : "A fase atual não tem processo cancelável. Aguarde sua conclusão."
                if !accepted && recipe == nil { cancelling = false }
            }
        }
    }
    func retryCleanup() {
        guard let failedID = cleanupOperationID, !busy else { return }
        let operationID = UUID(); activeOperationID = operationID; busy = true; cancelling = false
        status = "Repetindo encerramento…"
        Task {
            defer { busy = false; activeOperationID = nil; cancelling = false; preparingBottleID = nil }
            do {
                let result = try await runner.retryCleanup(failedOperationID: failedID, operationID: operationID)
                lastLog = result.log; cleanupOperationID = nil
                status = "Encerramento concluído. Prepare a bottle novamente antes de retomar."
            } catch { self.error = error.localizedDescription; status = "Encerramento não confirmado" }
        }
    }
    func makeDefault(_ bottle: Bottle) {
        guard !busy else { return }
        do {
            var next = try store.load(); next.preferences.defaultBottleID = bottle.id
            try persist(next); status = "Bottle padrão: \(bottle.name)"
        } catch { self.error = error.localizedDescription }
    }
    func nameBottle(_ bottle: Bottle, duplicate: Bool) {
        guard !busy else { return }
        let alert = NSAlert(); alert.messageText = duplicate ? "Duplicar bottle" : "Renomear bottle"
        let field = NSTextField(string: duplicate ? bottle.name + " — cópia" : bottle.name)
        field.frame = NSRect(x: 0, y: 0, width: 320, height: 24); alert.accessoryView = field
        alert.addButton(withTitle: duplicate ? "Duplicar" : "Renomear"); alert.addButton(withTitle: "Cancelar")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let name = field.stringValue
        maintenance(duplicate ? "Copiando bottle…" : "Renomeando bottle…", bottleID: bottle.id) { service in
            if duplicate { return try await service.duplicate(id: bottle.id, name: name).id }
            try service.rename(id: bottle.id, name: name); return bottle.id
        }
    }
    private func choosePublication() -> URL? {
        let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false
        panel.treatsFilePackagesAsDirectories = false; panel.message = "Escolha uma publicação .cruzadorbottle com publication.json."
        return panel.runModal() == .OK ? panel.url : nil
    }
    func applyRetina(_ mode: RetinaMode, bottle: Bottle) {
        guard canStart, presentation == .retina else { return }
        let log = store.logsRoot.appendingPathComponent("retina-\(UUID()).log"); lastLog = log
        maintenance("Aplicando alta resolução; aguardando programas fecharem…", bottleID: bottle.id) { service in
            _ = try await RetinaConfiguration(store: service.store).apply(mode, bottleID: bottle.id, runner: service.runner, log: log, operationID: service.operationID)
            return bottle.id
        }
    }
    func rebootBottle(_ bottle: Bottle) {
        guard canStart, store.isReady(bottle) else { return }
        let alert = NSAlert(); alert.messageText = "Reiniciar a bottle \(bottle.name)?"
        alert.informativeText = "Salve e feche os programas desta bottle. O Cruzador aguardará seu encerramento e executará a reinicialização simulada do Wine."
        alert.addButton(withTitle: "Reiniciar bottle"); alert.addButton(withTitle: "Cancelar")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        perform(.reboot, bottle: bottle, title: "Reiniciando \(bottle.name)…")
    }
    func openBottleShell(_ bottle: Bottle) {
        guard canStart else { return }
        do {
            let current = try store.load()
            guard let selected = current.bottles.first(where: { $0.id == bottle.id }) else { throw CruzadorError.invalid("Bottle não encontrada.") }
            let script = try BottleShell.prepare(bottle: selected, store: store)
            NSWorkspace.shared.open([script], withApplicationAt: URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app"), configuration: NSWorkspace.OpenConfiguration()) { _, failure in
                Task { @MainActor in
                    if let failure { self.error = "Não foi possível abrir o Terminal: \(failure.localizedDescription). O script foi preservado em \(script.path)." }
                    else if self.canStart { self.status = "Shell aberto no Terminal. Feche os programas Windows antes de reparar ou exportar a bottle." }
                }
            }
        } catch { self.error = error.localizedDescription }
    }
    func publishBottle(_ bottle: Bottle, newRevision: Bool = false) {
        guard canStart else { return }
        let previous: URL?
        if newRevision { guard let chosen = choosePublication() else { return }; previous = chosen } else { previous = nil }
        let panel = NSSavePanel(); panel.nameFieldStringValue = bottle.name + ".cruzadorbottle"
        panel.message = "Publica uma cópia completa, incluindo arquivos e dados pessoais da bottle. Escolha uma pasta nova; o compartilhamento é manual."
        guard panel.runModal() == .OK, let target = panel.url else { return }
        maintenance("Publicando cópia versionada…", bottleID: bottle.id) { service in
            _ = try await BottlePublicationService(maintenance: service).publish(bottleID: bottle.id, previous: previous, destination: target)
            return bottle.id
        }
    }
    func receivePublication(updating bottle: Bottle? = nil) {
        guard canStart else { return }
        if let enginePreferenceError { error = enginePreferenceError; return }
        guard let package = choosePublication() else { return }
        let engine = bottle?.engine ?? Engine(kind: engineKind, path: enginePath)
        maintenance("Recebendo publicação; a versão anterior será mantida…") { service in
            try BottlePublicationService(maintenance: service).receive(package, engine: engine, updating: bottle?.id).id
        }
    }
    func exportBottle(_ bottle: Bottle) {
        guard !busy else { return }
        let panel = NSSavePanel(); panel.nameFieldStringValue = bottle.name + ".cruzadorbottle"
        panel.message = "Escolha um novo pacote. Feche os programas Windows antes de exportar."
        guard panel.runModal() == .OK, let destination = panel.url else { return }
        maintenance("Exportando bottle…", bottleID: bottle.id) { service in
            try await service.export(id: bottle.id, destination: destination); return bottle.id
        }
    }
    func importBottle() {
        guard !busy else { return }
        if let enginePreferenceError { error = enginePreferenceError; return }
        let panel = NSOpenPanel(); panel.canChooseFiles = false; panel.canChooseDirectories = true
        panel.treatsFilePackagesAsDirectories = true
        panel.message = "Selecione a pasta .cruzadorbottle que contém bottle.json e Prefix. Ela será copiada e usará o motor selecionado nas configurações."
        guard panel.runModal() == .OK, let source = panel.url else { return }
        let engine = Engine(kind: engineKind, path: enginePath)
        maintenance("Importando bottle…") { service in try service.importBottle(from: source, engine: engine).id }
    }
    func removeBottle(_ bottle: Bottle) {
        guard !busy else { return }
        let alert = NSAlert(); alert.messageText = "Remover \(bottle.name) da biblioteca?"
        alert.informativeText = "Feche os programas Windows. Os arquivos serão movidos para a pasta Removed da biblioteca e poderão ser importados novamente."
        alert.addButton(withTitle: "Remover e preservar cópia"); alert.addButton(withTitle: "Cancelar")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        maintenance("Removendo bottle…", bottleID: bottle.id) { service in _ = try await service.remove(id: bottle.id); return nil }
    }

}
