import XCTest
@testable import CruzadorCore

final class NativeToolPlanTests: XCTestCase {
    /// Emits the production command plan for a retained test library; does not execute it.
    func testEmitSelectedToolPlanForNativeInspection() throws {
        let environment = ProcessInfo.processInfo.environment
        guard let root = environment["CRUZADOR_TOOL_PLAN_ROOT"], let output = environment["CRUZADOR_TOOL_PLAN_OUTPUT"], let raw = environment["CRUZADOR_TOOL_PLAN_NAME"] else { throw XCTSkip("Opt-in: emite plano para inspeção nativa em biblioteca de teste retida.") }
        guard root.hasPrefix("/"), output.hasPrefix("/"), let tool = BottleTool(rawValue: raw) else { throw CruzadorError.invalid("Entrada do plano de inspeção inválida.") }
        let store = LibraryStore(root: URL(fileURLWithPath: root))
        let bottle = try XCTUnwrap(try store.load().bottles.first); XCTAssertTrue(store.isReady(bottle))
        let plan = try EngineCommands.make(.tool(tool), bottle: bottle, store: store)
        func encode(_ command: Command) -> [String: Any] {
            var record: [String: Any] = ["executable": command.executable.path, "arguments": command.arguments, "environment": command.environment]
            if let directory = command.workingDirectory { record["workingDirectory"] = directory.path }; return record
        }
        let data: [String: Any] = ["formatVersion": 1, "root": root, "tool": raw, "primary": encode(plan.primary), "cancellation": plan.cancellation.map(encode), "finalization": plan.finalization.map(encode)]
        try JSONSerialization.data(withJSONObject: data, options: [.prettyPrinted, .sortedKeys]).write(to: URL(fileURLWithPath: output), options: .withoutOverwriting)
    }
}
