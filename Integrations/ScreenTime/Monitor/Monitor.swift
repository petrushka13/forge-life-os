import Foundation
import FamilyControls
import ManagedSettings
import DeviceActivity

final class ForgeMonitor: DeviceActivityMonitor {
    let settings = ManagedSettingsStore(named:.init("forge-policy"))
    var defaults: UserDefaults? { (Bundle.main.object(forInfoDictionaryKey:"ForgeAppGroup") as? String).flatMap { $0.isEmpty ? nil : UserDefaults(suiteName:$0) } }
    func applyPolicy() {
        let now = Date()
        guard (defaults?.object(forKey:"rewardEnd") as? Date ?? .distantPast) <= now else { settings.clearAllSettings(); return }
        guard defaults?.bool(forKey:"earned") == true || (defaults?.object(forKey:"focusEnd") as? Date ?? .distantPast) > now || defaults?.bool(forKey:"limitReached") == true else { settings.clearAllSettings(); return }
        guard let data=defaults?.data(forKey:"selection"),let selection=try? JSONDecoder().decode(FamilyActivitySelection.self,from:data) else { settings.clearAllSettings(); return }
        settings.shield.applications=selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        settings.shield.applicationCategories=selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
        settings.shield.webDomains=selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
    }
    override func intervalDidStart(for activity:DeviceActivityName) {
        super.intervalDidStart(for:activity)
        if activity.rawValue == "forge-limit" { defaults?.set(false,forKey:"limitReached") }
        applyPolicy()
    }
    override func intervalDidEnd(for activity:DeviceActivityName) {
        super.intervalDidEnd(for:activity)
        if activity.rawValue == "forge-focus" { defaults?.removeObject(forKey:"focusEnd") }
        if activity.rawValue == "forge-reward" { defaults?.removeObject(forKey:"rewardEnd") }
        applyPolicy()
    }
    override func eventDidReachThreshold(_ event:DeviceActivityEvent.Name,activity:DeviceActivityName) {
        super.eventDidReachThreshold(event,activity:activity)
        defaults?.set(true,forKey:"limitReached");applyPolicy()
    }
}
