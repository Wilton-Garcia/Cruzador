import AppKit
import SwiftUI
import CruzadorCore

struct InstallationHistoryView: View {
    @ObservedObject var model: AppModel
    let bottle: Bottle
    @State private var selection: UUID?
    var records: [InstallationRecord] { (bottle.installations ?? []).reversed() }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Histórico de \(bottle.name)").font(.title2.bold())
            HSplitView {
                List(records, selection: $selection) { record in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(URL(fileURLWithPath: record.sourcePath).lastPathComponent).lineLimit(2)
                        Text(record.status.displayName).font(.caption).foregroundStyle(.secondary)
                        Text(record.startedAt, style: .date).font(.caption2)
                    }.tag(record.id).padding(.vertical, 4)
                }.frame(minWidth: 210, idealWidth: 240)
                if let record = records.first(where: { $0.id == selection }) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            Text(record.status.displayName).font(.headline)
                            Text(record.sourcePath).font(.caption).textSelection(.enabled)
                            LabeledContent("Início", value: record.startedAt.formatted())
                            LabeledContent("Término", value: record.finishedAt?.formatted() ?? "Não registrado")
                            LabeledContent("Código macOS", value: record.macOSExitCode.map(String.init) ?? "Não registrado")
                            if let recipe = record.recipeID { LabeledContent("Receita", value: recipe) }
                            if let source = record.sourceURL { Link("Origem declarada", destination: source) }
                            if let hash = record.sourceSHA256 { Text("SHA-256: \(hash)").font(.caption).textSelection(.enabled) }
                            if let error = record.error { Text(error).foregroundStyle(.orange).textSelection(.enabled) }
                            DisclosureGroup("Opções registradas") {
                                VStack(alignment: .leading) {
                                    Text(record.arguments.joined(separator: "\n"))
                                    Text(record.options.workingDirectory ?? "Pasta de trabalho não registrada")
                                    Text(record.options.environmentJSON)
                                }.font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                            }
                            if let phases = record.phases {
                                DisclosureGroup("Fases observadas (\(phases.count))") {
                                    ForEach(Array(phases.enumerated()), id: \.offset) { _, phase in
                                        VStack(alignment: .leading) {
                                            Text("\(phase.phase): \(phase.exitCode.map(String.init) ?? "sem código")").fontWeight(.medium)
                                            Text(phase.executable).textSelection(.enabled)
                                            if let error = phase.launchError { Text(error).foregroundStyle(.orange) }
                                        }.font(.caption).padding(.vertical, 3)
                                    }
                                }
                            }
                            Button("Abrir log") { NSWorkspace.shared.open(URL(fileURLWithPath: record.logPath)) }
                            Text("O resultado descreve o instalador; não comprova que o aplicativo instalado está funcionando.").font(.caption).foregroundStyle(.secondary)
                        }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else { ContentUnavailableView("Selecione uma instalação", systemImage: "clock.arrow.circlepath") }
            }
            HStack { Spacer(); Button("Fechar") { model.dismissPresentation(.history) }.keyboardShortcut(.cancelAction) }
        }.padding(24).frame(width: 800, height: 560)
        .onAppear { selection = records.first?.id }
    }
}
