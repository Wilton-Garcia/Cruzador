import AppKit
import SwiftUI
import CruzadorCore

struct ContentView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 10) {
                    Image(systemName: "square.stack.3d.up.fill").font(.title).foregroundStyle(.teal)
                    VStack(alignment: .leading) {
                        Text("CRUZADOR").font(.headline).tracking(2)
                        Text("Windows, no seu Mac").font(.caption).foregroundStyle(.secondary)
                    }
                }.padding(.top, 15)
                TextField("Buscar bottles", text: $model.search).textFieldStyle(.roundedBorder)
                HStack { Text("BIBLIOTECA").font(.caption.weight(.semibold)).foregroundStyle(.secondary); Spacer(); Text("\(model.library.bottles.count)").foregroundStyle(.secondary) }
                List(selection: $model.selection) {
                    ForEach(model.filteredBottles) { bottle in
                        HStack(spacing: 12) {
                            Image(systemName: "shippingbox.fill").foregroundStyle(.teal)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(bottle.name).lineLimit(1)
                                Text(bottle.apps.count == 1 ? "1 aplicativo" : "\(bottle.apps.count) aplicativos").font(.caption).foregroundStyle(.secondary)
                            }
                        }.padding(.vertical, 7).tag(bottle.id)
                    }
                }.listStyle(.sidebar)
                Button { model.showCreate = true } label: { Label("Nova bottle", systemImage: "plus").frame(maxWidth: .infinity) }
                    .controlSize(.large).disabled(!model.canStart || !model.loaded)
                Button { model.importBottle() } label: { Label("Importar bottle…", systemImage: "square.and.arrow.down") }.disabled(!model.canStart || !model.loaded)
                SettingsLink { Label("Configurar motor", systemImage: "gearshape") }.buttonStyle(.plain).foregroundStyle(.secondary)
            }.padding(18).navigationSplitViewColumnWidth(min: 235, ideal: 260, max: 320)
        } detail: {
            VStack(spacing: 0) {
                if !model.loaded {
                    ContentUnavailableView {
                        Label("Biblioteca indisponível", systemImage: "exclamationmark.triangle")
                    } description: { Text("O arquivo da biblioteca não pôde ser lido. Preserve o arquivo antes de repará-lo.") } actions: {
                        Button("Tentar novamente") { model.reload() }
                        Button("Abrir pasta") { NSWorkspace.shared.open(model.store.root) }
                    }
                } else if let bottle = model.selected {
                    detail(bottle)
                } else {
                    ContentUnavailableView {
                        Label("Seu próximo aplicativo começa aqui", systemImage: "square.stack.3d.up")
                    } description: {
                        Text("Crie uma bottle para manter os arquivos e as configurações\nde seus programas Windows em um só lugar.")
                    } actions: {
                        Button("Criar primeira bottle") { model.showCreate = true }.buttonStyle(.borderedProminent).tint(.teal).disabled(!model.canStart)
                    }
                }
                Divider()
                HStack(spacing: 10) {
                    if model.busy { ProgressView().controlSize(.small) }
                    else { Image(systemName: "circle.fill").font(.system(size: 7)).foregroundStyle(.teal) }
                    Text(model.status).font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    if model.busy && model.canCancelOperation { Button(model.cancelling ? "Encerrando…" : "Cancelar operação") { model.cancelCurrentOperation() }.disabled(model.cancelling).help("No Wine, cancelar encerra os programas Windows desta bottle e aguarda o servidor.") }
                    if model.cleanupOperationID != nil { Button("Repetir encerramento") { model.retryCleanup() }.disabled(model.busy) }
                    if let log = model.lastLog { Button("Ver log") { NSWorkspace.shared.open(log) }.buttonStyle(.link) }
                }.padding(14).background(.bar)
            }
        }
        .tint(.teal)
        .sheet(isPresented: $model.showCreate) { CreateBottleView(model: model) }
        .sheet(isPresented: $model.showDiscovery) { if let report = model.discoveryReport { DiscoveredAppsView(model: model, report: report) } }
        .sheet(isPresented: $model.showRecipes) { if let catalog = model.recipeCatalog { RecipesView(model: model, catalog: catalog) } }
        .sheet(isPresented: $model.showInstall) { if let installer = model.selectedInstaller { InstallProgramView(model: model, installer: installer) } }
        .sheet(isPresented: $model.showRegister) { RegisterAppView(model: model, app: model.editingApp) }
        .alert("Não foi possível concluir", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button("OK") { model.error = nil }
            if let log = model.lastLog { Button("Abrir log") { NSWorkspace.shared.open(log) } }
        } message: { Text(model.error ?? "") }
    }
    private func detail(_ bottle: Bottle) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SUA BOTTLE").font(.caption.weight(.semibold)).tracking(2).foregroundStyle(.secondary)
                        Text(bottle.name).font(.system(size: 34, weight: .bold, design: .rounded)).textSelection(.enabled)
                        HStack(spacing: 10) {
                            Label(stateLabel(bottle), systemImage: bottle.state == .ready && model.store.isInitialized(bottle) ? "checkmark.circle.fill" : "exclamationmark.circle")
                            Text("·")
                            Text(bottle.engine.kind.displayName)
                        }.font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Menu {
                        Button(model.library.preferences.defaultBottleID == bottle.id ? "Bottle padrão" : "Usar como padrão") { model.makeDefault(bottle) }.disabled(model.library.preferences.defaultBottleID == bottle.id)
                        Button("Renomear…") { model.nameBottle(bottle, duplicate: false) }
                        Button("Duplicar…") { model.nameBottle(bottle, duplicate: true) }
                        Button("Exportar…") { model.exportBottle(bottle) }
                        Divider()
                        Button("Remover da biblioteca…", role: .destructive) { model.removeBottle(bottle) }
                    } label: { Label("Gerenciar", systemImage: "ellipsis.circle") }.disabled(!model.canStart)
                    Image(systemName: "shippingbox.fill").font(.system(size: 54)).foregroundStyle(.teal.gradient).padding(10)
                }
                HStack(spacing: 12) {
                    Button { model.openRecipes() } label: { Label("Receitas…", systemImage: "list.bullet.clipboard") }
                    Button { model.chooseProgram(installer: true) } label: { Label("Instalar programa", systemImage: "plus.circle.fill") }.buttonStyle(.borderedProminent)
                    Button { model.chooseProgram() } label: { Label("Executar arquivo…", systemImage: "play.fill") }
                    Button { NSWorkspace.shared.open(model.store.prefix(for: bottle)) } label: { Label("Abrir pasta", systemImage: "folder") }
                }.controlSize(.large).disabled(!model.canStart || !model.store.isReady(bottle))
                if !model.store.isReady(bottle) {
                    GroupBox {
                        HStack {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("A preparação ainda não foi concluída").fontWeight(.semibold)
                                Text(bottle.lastError ?? "Os arquivos parciais foram preservados. Consulte o log antes de tentar novamente.").font(.callout).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Preparar novamente") { model.perform(.initialize, bottle: bottle, title: "Preparando \(bottle.name)…") }.disabled(!model.canStart)
                        }.padding(12)
                    }
                }
                HStack {
                    Text("Aplicativos").font(.title2.weight(.semibold)); Spacer()
                    Button("Buscar instalados…") { model.discoverApps() }.disabled(!model.canStart)
                    Button { model.beginRegister() } label: { Label("Adicionar atalho", systemImage: "plus") }.disabled(!model.canStart || bottle.state != .ready)
                }
                if bottle.apps.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "app.dashed").font(.system(size: 36)).foregroundStyle(.secondary)
                        Text("Sua bottle está esperando o primeiro app").font(.headline)
                        Text("Instale um programa e adicione um atalho para o executável.\nUse Buscar instalados ou adicione um atalho manualmente.").multilineTextAlignment(.center).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity).padding(.vertical, 42).background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 16))
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 16)], spacing: 16) {
                        ForEach(bottle.apps) { app in
                            VStack(alignment: .leading, spacing: 16) {
                                Image(systemName: "app.fill").font(.system(size: 30)).foregroundStyle(.teal)
                                Text(app.name).font(.headline).lineLimit(2)
                                Text(URL(fileURLWithPath: app.path).lastPathComponent).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                Button { model.perform(.run(app.launchRequest), bottle: bottle, title: "Executando \(app.name)…") } label: {
                                    Label("Executar", systemImage: "play.fill").frame(maxWidth: .infinity)
                                }.disabled(!model.canStart || bottle.state != .ready)
                            }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
                                .background(.background, in: RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(.quaternary))
                                .contextMenu {
                                    Button("Editar atalho…") { model.beginRegister(app) }.disabled(!model.canStart)
                                    Button("Remover atalho") { model.removeShortcut(app, bottle: bottle) }.disabled(!model.canStart)
                                }
                        }
                    }
                }
                if let installations = bottle.installations, !installations.isEmpty {
                    GroupBox("Histórico de instalação") {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(Array(installations.suffix(5).reversed())) { record in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(URL(fileURLWithPath: record.sourcePath).lastPathComponent).fontWeight(.medium)
                                        Text(record.status.displayName).font(.caption).foregroundStyle(.secondary)
                                        if let code = record.macOSExitCode { Text("Saída macOS: \(code)").font(.caption2).foregroundStyle(.secondary) }
                                    }
                                    Spacer()
                                    Text(record.startedAt, style: .date).font(.caption)
                                    Button("Log") { NSWorkspace.shared.open(URL(fileURLWithPath: record.logPath)) }
                                }
                            }
                            Text("O resultado descreve o instalador. Cadastre o atalho do programa instalado para executá-lo.").font(.caption).foregroundStyle(.secondary)
                        }.padding(10)
                    }
                }
                Divider()
                Text("Ferramentas da bottle").font(.headline)
                HStack(spacing: 12) {
                    Button("Reparar bottle") { model.perform(.repair, bottle: bottle, title: "Reparando \(bottle.name)…") }
                    tool("Configurações Wine", "slider.horizontal.3", "winecfg", bottle)
                    tool("Registro", "list.bullet.rectangle", "regedit", bottle)
                    tool("Desinstalar programas", "minus.circle", "uninstaller", bottle)
                }.disabled(!model.canStart || !model.store.isReady(bottle))
                Text("Motor: \(bottle.engine.path)").font(.caption).foregroundStyle(.tertiary).textSelection(.enabled)
            }.padding(34)
        }
    }
    private func tool(_ title: String, _ symbol: String, _ command: String, _ bottle: Bottle) -> some View {
        Button { model.perform(.tool(command), bottle: bottle, title: "Abrindo \(title)…") } label: { Label(title, systemImage: symbol) }
    }
    private func stateLabel(_ bottle: Bottle) -> String {
        switch bottle.state {
        case .ready: model.store.isInitialized(bottle) ? "Pronta para usar" : "Arquivos ausentes"
        case .preparing: "Em preparação"
        case .failed: "Preparação incompleta"
        case .interrupted: "Preparação interrompida"
        }
    }
}

struct CreateBottleView: View {
    @ObservedObject var model: AppModel
    @State private var name = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Label("Nova bottle", systemImage: "shippingbox.fill").font(.title2.bold())
            Text("Um ambiente separado para seus programas e jogos Windows.").foregroundStyle(.secondary)
            TextField("Nome, por exemplo: Meus jogos", text: $name).textFieldStyle(.roundedBorder).onSubmit { model.create(name: name) }
            VStack(alignment: .leading, spacing: 6) {
                Text(model.engineKind.displayName).fontWeight(.medium)
                Text(model.enginePath).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                Text("O motor será executado para preparar os arquivos da bottle.").font(.caption).foregroundStyle(.secondary)
            }
            HStack { Button("Cancelar") { model.showCreate = false }.keyboardShortcut(.cancelAction); Spacer(); Button("Criar bottle") { model.create(name: name) }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction).disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
        }.padding(30).frame(width: 470)
    }
}
struct RegisterAppView: View {
    @ObservedObject var model: AppModel
    @State private var name = ""
    @State private var path = ""
    @State private var arguments = ""
    @State private var workingDirectory = ""
    @State private var environmentJSON = "{}"
    init(model: AppModel, app: WindowsApp?) {
        self.model = model
        _name = State(initialValue: app?.name ?? "")
        _path = State(initialValue: app?.path ?? "")
        _arguments = State(initialValue: app?.arguments.joined(separator: "\n") ?? "")
        _workingDirectory = State(initialValue: app?.options?.workingDirectory ?? "")
        _environmentJSON = State(initialValue: app?.options?.environmentJSON ?? "{}")
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(model.editingApp == nil ? "Adicionar atalho" : "Editar atalho").font(.title2.bold())
            TextField("Nome do aplicativo", text: $name).textFieldStyle(.roundedBorder)
            HStack {
                TextField("Caminho do executável", text: $path).textFieldStyle(.roundedBorder)
                Button("Escolher…") {
                    let panel = NSOpenPanel(); panel.canChooseDirectories = false
                    if let bottle = model.selected { panel.directoryURL = model.store.prefix(for: bottle).appendingPathComponent("drive_c") }
                    if panel.runModal() == .OK, let url = panel.url { path = url.path; if name.isEmpty { name = url.deletingPathExtension().lastPathComponent } }
                }
            }
            Text("Argumentos opcionais, um por linha").font(.caption).foregroundStyle(.secondary)
            TextEditor(text: $arguments).font(.system(.body, design: .monospaced)).frame(height: 90).border(.quaternary)
            TextField("Pasta de trabalho opcional (caminho absoluto)", text: $workingDirectory).textFieldStyle(.roundedBorder)
            Text("Variáveis de ambiente em JSON, por exemplo: {\"LANG\": \"pt_BR.UTF-8\"}").font(.caption).foregroundStyle(.secondary)
            TextEditor(text: $environmentJSON).font(.system(.body, design: .monospaced)).frame(height: 85).border(.quaternary)
            HStack { Button("Cancelar") { model.showRegister = false }.keyboardShortcut(.cancelAction); Spacer(); Button("Salvar atalho") { model.register(name: name, path: path, arguments: arguments, workingDirectory: workingDirectory, environmentJSON: environmentJSON) }.buttonStyle(.borderedProminent).disabled(name.isEmpty || path.isEmpty) }
        }.padding(30).frame(width: 520)
    }
}
struct EngineSettings: View {
    @ObservedObject var model: AppModel
    var body: some View {
        Form {
            Text("Motor de compatibilidade").font(.title2.bold())
            Text("O Wine incluído prepara seus ambientes Windows. Cada bottle mantém o motor escolhido no momento da criação.").foregroundStyle(.secondary)
            Picker("Motor", selection: Binding(get: { model.engineKind }, set: { model.selectEngine($0) })) {
                Text("Wine externo").tag(EngineKind.wine)
                Text("Pacote Wine do Cruzador").tag(EngineKind.packagedWine)
                Text("CrossOver externo (comparação/legado)").tag(EngineKind.crossOver)
            }
            TextField(model.engineKind == .crossOver ? "Caminho do CrossOver.app" : model.engineKind == .packagedWine ? "Pasta do pacote com runtime.json" : "Caminho do executável wine", text: $model.enginePath)
            Button("Escolher…") {
                let panel = NSOpenPanel(); panel.canChooseDirectories = model.engineKind != .wine; panel.canChooseFiles = true; panel.treatsFilePackagesAsDirectories = false
                if panel.runModal() == .OK, let url = panel.url { model.enginePath = url.path; model.saveEngine() }
            }
            Text("O pacote incluído é a opção padrão. Motores externos são opcionais e usam bottles separadas.").font(.caption).foregroundStyle(.secondary)
            if model.engineKind == .packagedWine {
                Button("Usar pacote incluído no aplicativo") { model.enginePath = WineRuntime.bundledRoot.path; model.saveEngine() }
            }
            Button("Salvar configuração") { model.saveEngine() }.buttonStyle(.borderedProminent)
        }.disabled(model.busy)
    }
}

struct InstallProgramView: View {
    @ObservedObject var model: AppModel
    let installer: WindowsFileInspection
    @State private var mode = InstallerMode.interactive
    @State private var arguments = ""
    @State private var workingDirectory: String
    @State private var environmentJSON = "{}"
    init(model: AppModel, installer: WindowsFileInspection) {
        self.model = model; self.installer = installer
        _workingDirectory = State(initialValue: URL(fileURLWithPath: installer.path).deletingLastPathComponent().path)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Instalar programa", systemImage: "shippingbox").font(.title2.bold())
            Text(URL(fileURLWithPath: installer.path).lastPathComponent).font(.headline)
            Text("Destino: \(model.selected?.name ?? "Nenhuma bottle")").foregroundStyle(.secondary)
            Text("\(installer.kind.rawValue.uppercased()) · \(installer.size.formatted()) bytes").font(.caption).foregroundStyle(.secondary)
            if installer.kind == .msi {
                Picker("Interface", selection: $mode) { ForEach(InstallerMode.allCases, id: \.self) { Text($0.displayName).tag($0) } }
                Text("Será criado um log MSI detalhado. O Cruzador solicita execução sem reinício automático.").font(.caption).foregroundStyle(.secondary)
            } else {
                Text("O EXE abrirá sua própria interface. Argumentos silenciosos dependem do fornecedor.").font(.caption).foregroundStyle(.secondary)
            }
            Text("Argumentos adicionais, um por linha").font(.caption)
            TextEditor(text: $arguments).font(.system(.body, design: .monospaced)).frame(height: 65).border(.quaternary)
            TextField("Pasta de trabalho", text: $workingDirectory).textFieldStyle(.roundedBorder)
            DisclosureGroup("Variáveis de ambiente (JSON)") {
                TextEditor(text: $environmentJSON).font(.system(.body, design: .monospaced)).frame(height: 75).border(.quaternary)
            }
            HStack {
                Button("Cancelar") { model.showInstall = false }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Iniciar instalação") { model.installSelected(mode: mode, arguments: arguments, workingDirectory: workingDirectory, environmentJSON: environmentJSON) }.buttonStyle(.borderedProminent).disabled(!model.canStart)
            }
        }.padding(28).frame(width: 560)
    }
}

struct RecipesView: View {
    @ObservedObject var model: AppModel
    let catalog: RecipeCatalog
    @State private var selectedID: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("Instalar por receita", systemImage: "list.bullet.clipboard").font(.title2.bold())
            Text("Destino: \(model.selected?.name ?? "Nenhuma bottle")").foregroundStyle(.secondary)
            List(catalog.recipes, selection: $selectedID) { recipe in
                VStack(alignment: .leading, spacing: 6) {
                    HStack { Text(recipe.name).font(.headline); Spacer(); Text(recipe.version).foregroundStyle(.secondary) }
                    Text(recipe.summary).font(.callout)
                }.padding(.vertical, 6).tag(recipe.id)
            }.frame(height: 180)
            if let recipe = catalog.recipes.first(where: { $0.id == selectedID }) {
                Link("Site do fornecedor", destination: recipe.homepage)
                Text(recipe.dependencies.isEmpty ? "Sem dependências adicionais declaradas." : "Dependências: " + recipe.dependencies.joined(separator: ", ")).font(.caption).foregroundStyle(.secondary)
                Text("A receita baixa o instalador fixado, verifica seu conteúdo e executa as opções declaradas. Argumentos: \(recipe.arguments.joined(separator: " "))").font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Button("Cancelar") { model.showRecipes = false }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Instalar receita") { if let selectedID { model.installRecipe(id: selectedID, catalog: catalog) } }.buttonStyle(.borderedProminent).disabled(selectedID == nil || !model.canStart)
            }
        }.padding(28).frame(width: 580)
    }
}

struct DiscoveredAppsView: View {
    @ObservedObject var model: AppModel
    let report: AppDiscoveryReport
    @State private var selectedIDs: Set<String> = []
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Aplicativos encontrados", systemImage: "magnifyingglass").font(.title2.bold())
            Text("\(report.registeredSoftware.count) registros de software · \(report.executables.count) candidatos executáveis").foregroundStyle(.secondary)
            Text("Escolha os executáveis para criar atalhos. A busca não executa os arquivos nem comprova sua compatibilidade.").font(.callout).foregroundStyle(.secondary)
            List(report.executables, selection: $selectedIDs) { candidate in
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(candidate.name).font(.headline)
                        Spacer()
                        if model.library.bottles.first(where: { $0.id == report.bottleID })?.apps.contains(where: { $0.path == candidate.inspection.path }) == true { Text("Atalho existente").font(.caption).foregroundStyle(.secondary) }
                    }
                    Text(candidate.id).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    let related = report.registeredSoftware.filter { candidate.registeredSoftwareIDs.contains($0.id) }.compactMap(\.name)
                    if !related.isEmpty { Text(related.joined(separator: "; ")).font(.caption).foregroundStyle(.secondary) }
                }.padding(.vertical, 5).tag(candidate.id)
            }.frame(height: 260)
            DisclosureGroup("Cobertura e avisos (\(report.warnings.count))") {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(report.limitations, id: \.self) { Text($0) }
                        ForEach(Array(report.warnings.enumerated()), id: \.offset) { _, warning in Text(warning).foregroundStyle(.orange) }
                    }.font(.caption).frame(maxWidth: .infinity, alignment: .leading)
                }.frame(maxHeight: 150)
            }
            HStack {
                Button("Fechar") { model.showDiscovery = false }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Adicionar selecionados") { model.addDiscovered(selectedIDs, report: report) }.buttonStyle(.borderedProminent).disabled(selectedIDs.isEmpty || !model.canStart)
            }
        }.padding(28).frame(width: 720)
    }
}
