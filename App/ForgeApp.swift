import SwiftUI
import ForgeCore
import Darwin

@main
struct ForgeApp: App {
    @State private var store: AppStore
    init() {
        if CommandLine.arguments.contains("--storage-benchmark") {
            do { try PersistenceSmoke.benchmark(); exit(0) }
            catch { print("FORGE storage benchmark failed: \(error)"); exit(1) }
        }
        if CommandLine.arguments.contains("--smoke-test") {
            do { try PersistenceSmoke.run(); print("FORGE persistence smoke test passed"); exit(0) }
            catch { print("FORGE persistence smoke failed: \(error)"); exit(1) }
        }
        _store = State(initialValue: AppStore(demo: CommandLine.arguments.contains("--demo")))
    }
    var body: some Scene {
        WindowGroup("FORGE") { RootView(store: store) }
        #if os(macOS)
        .defaultSize(width: 1240, height: 860)
        #endif
        #if os(macOS)
        Window("FORGE Demo", id: "forge-demo") { DemoView() }
            .defaultSize(width: 1240, height: 860)
        #endif
    }
}
