import Foundation

enum Capabilities {
    static var health: Bool {
        #if os(iOS) && FORGE_HEALTH_ENABLED
        true
        #else
        false
        #endif
    }
    static var cloud: Bool {
        #if FORGE_CLOUD_ENABLED
        !(Bundle.main.object(forInfoDictionaryKey: "ForgeCloudContainer") as? String ?? "").isEmpty
        #else
        false
        #endif
    }
    static var screenTime: Bool {
        #if os(iOS) && FORGE_SCREEN_TIME_ENABLED
        let extensions = Bundle.main.builtInPlugInsURL
        return ["ForgeMonitor.appex", "ForgeReport.appex"].allSatisfy { name in extensions.map { FileManager.default.fileExists(atPath: $0.appendingPathComponent(name).path) } ?? false }
        #else
        false
        #endif
    }
}
