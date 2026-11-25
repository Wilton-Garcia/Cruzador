import AppKit
import SwiftUI
import CruzadorCore

struct CompatibilityView: View {
    @ObservedObject var model: AppModel
    let bottle: Bottle
    @State private var appID: UUID?
    @State private var version = ""
    @State private var result: CompatibilityResult = .limited
    @State private var notes = ""
    @State private var reports: [CompatibilityReport] = []
    private var store: CompatibilityStore { CompatibilityStore(library: model.store) }
    private var active: Bool { model.canStart && model.presentation == .compatibility }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Compatibilidade — \(bottle.name)").font(.title2.bold())
            Text("Registre sua observação manual. Cada avaliação identifica versão, executável, motor e macOS; ela não é uma certificação automática.").foregroundStyle(.secondary)
            Picker("Aplicativo", selection: $appID) {
                Text("Selecione…").tag(nil as UUID?)
                ForEach(bottle.apps) { Text($0.name).tag(Optional($0.id)) }
            }
            TextField("Versão do aplicativo testado", text: $version)
            Picker("Resultado", selection: $result) { ForEach(CompatibilityResult.allCases, id: \.self) { Text($0.displayName).tag($0) } }
            TextField("O que funcionou, limitações e passos testados", text: $notes, axis: .vertical).lineLimit(3...6)
            Button("Registrar avaliação") {
                guard active, let appID else { return }
                do { try store.record(bottleID: bottle.id, appID: appID, appVersion: version, result: result, notes: notes); notes = ""; try refresh() }
                catch { model.error = error.localizedDescription }
            }.disabled(!active || appID == nil || version.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(reports.filter { $0.bottleID == bottle.id }) { report in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack { Text("\(report.appName) \(report.appVersion) — \(report.result.displayName)").bold(); Spacer(); Button("Arquivar") { guard active else { return }; do { try store.archive(id: report.id); try refresh() } catch { model.error = error.localizedDescription } } }
                            Text(report.notes).textSelection(.enabled)
                            Text("\(report.engine.kind.displayName) \(report.runtimeVersion ?? "versão desconhecida") · \(report.operatingSystem)").font(.caption).foregroundStyle(.secondary)
                            Text(report.observedAt, style: .date).font(.caption)
                        }
                    }
                    if reports.filter({ $0.bottleID == bottle.id }).isEmpty { Text("Nenhuma avaliação registrada nesta bottle.").foregroundStyle(.secondary) }
                }
            }.frame(minHeight: 140)
            HStack {
                Button("Exportar todas as avaliações…") { export() }.disabled(!active || reports.isEmpty)
                Spacer(); Button("Fechar") { model.dismissPresentation(.compatibility) }.keyboardShortcut(.cancelAction)
            }
        }.padding(28).frame(width: 700, height: 600).onAppear { do { try refresh() } catch { model.error = error.localizedDescription } }
    }
    private func refresh() throws { reports = try store.reports() }
    private func export() {
        guard active else { return }
        let panel = NSSavePanel(); panel.nameFieldStringValue = "compatibilidade-cruzador.json"; panel.message = "Exporta todas as avaliações, incluindo notas e caminhos do motor."
        guard panel.runModal() == .OK, let url = panel.url, active else { return }
        do { try store.export(to: url) } catch { model.error = error.localizedDescription }
    }
}
