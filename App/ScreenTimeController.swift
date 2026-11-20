#if os(iOS)
import SwiftUI
import FamilyControls
import ManagedSettings
import DeviceActivity
import ForgeCore

@MainActor @Observable final class ScreenTimeController {
    static let shared = ScreenTimeController()
    var selection = FamilyActivitySelection()
    var authorized: Bool { Capabilities.screenTime && AuthorizationCenter.shared.authorizationStatus == .approved }
    private let settings = ManagedSettingsStore(named: .init("forge-policy"))
    private var defaults: UserDefaults? { (Bundle.main.object(forInfoDictionaryKey: "ForgeAppGroup") as? String).flatMap { $0.isEmpty ? nil : UserDefaults(suiteName: $0) } }
    init() { if let data = defaults?.data(forKey: "selection"), let value = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) { selection = value } }
    func authorize() async throws {
        guard Capabilities.screenTime, defaults != nil else { throw GameError.invalidConfiguration }
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
    }
    func saveSelection() throws {
        guard authorized, let defaults else { throw GameError.invalidConfiguration }
        defaults.set(try JSONEncoder().encode(selection), forKey: "selection")
    }
    func shield() {
        settings.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        settings.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
        settings.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
    }
    private func schedule(_ name: String, minutes: Int, events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:], repeats: Bool = false) throws {
        guard authorized, !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty || !selection.webDomainTokens.isEmpty else { throw GameError.invalidInput }
        try saveSelection()
        let now = Date(), end = now.addingTimeInterval(Double(max(15, minutes)) * 60)
        let components: Set<Calendar.Component> = [.year,.month,.day,.hour,.minute,.second]
        let start = repeats ? DateComponents(hour: 0, minute: 0) : Calendar.current.dateComponents(components, from: now)
        let finish = repeats ? DateComponents(hour: 23, minute: 59) : Calendar.current.dateComponents(components, from: end)
        try DeviceActivityCenter().startMonitoring(.init(name), during: DeviceActivitySchedule(intervalStart: start, intervalEnd: finish, repeats: repeats), events: events)
    }
    func beginFocus(minutes: Int) throws { try schedule("forge-focus", minutes: minutes); defaults?.set(Date().addingTimeInterval(Double(minutes)*60), forKey:"focusEnd"); shield() }
    func enableEarnedAccess() throws {
        try schedule("forge-earned-policy", minutes: 1440, repeats: true)
        defaults?.set(true, forKey:"earned"); shield()
    }
    func grant(minutes: Int) throws {
        guard authorized, defaults?.bool(forKey:"earned") == true else { throw GameError.invalidConfiguration }
        guard (15...1440).contains(minutes), (defaults?.object(forKey: "focusEnd") as? Date ?? .distantPast) <= Date() else { throw GameError.invalidInput }
        try schedule("forge-reward", minutes: minutes)
        defaults?.set(Date().addingTimeInterval(Double(minutes)*60), forKey:"rewardEnd")
        settings.clearAllSettings()
    }
    func revokeGrant() { defaults?.removeObject(forKey:"rewardEnd"); DeviceActivityCenter().stopMonitoring([.init("forge-reward")]); shield() }
    func dailyLimit(minutes: Int) throws {
        let event = DeviceActivityEvent(applications:selection.applicationTokens,categories:selection.categoryTokens,webDomains:selection.webDomainTokens,threshold:DateComponents(minute:minutes))
        try schedule("forge-limit", minutes: 1440, events:[.init("forge-threshold"):event], repeats:true)
        defaults?.set(true,forKey:"limitEnabled")
    }
    func emergencyOverride() {
        defaults?.set(false,forKey:"earned"); defaults?.set(false,forKey:"limitEnabled"); defaults?.set(false,forKey:"limitReached"); defaults?.removeObject(forKey:"focusEnd"); defaults?.removeObject(forKey:"rewardEnd")
        DeviceActivityCenter().stopMonitoring(); settings.clearAllSettings()
    }
    func eraseSelection() { emergencyOverride(); selection = FamilyActivitySelection(); defaults?.removeObject(forKey:"selection") }
    var earned: Bool { defaults?.bool(forKey:"earned") == true }
}

struct ScreenTimeSetup: View {
    @Environment(AppStore.self) private var store
    @State private var picker = false
    @State private var limit = 60
    @Bindable var controller = ScreenTimeController.shared
    var body: some View {
        VStack(alignment:.leading,spacing:14) {
            Text("iPhone distraction policy").font(.headline)
            Text(controller.authorized ? "Authorized. Selection stays opaque and local." : "Authorize individual Screen Time to choose distractions.").font(.caption)
            Button("Authorize Screen Time") { Task { do { try await controller.authorize() } catch { store.error = error.localizedDescription } } }
            Button("Choose apps and categories") { picker = true }.disabled(!controller.authorized)
            Button("Enable Earned Access") { do { try controller.enableEarnedAccess() } catch { store.error = error.localizedDescription } }.disabled(!controller.authorized)
            Stepper("Daily limit: \(limit) minutes",value:$limit,in:15...240,step:15)
            Button("Apply daily limit") { do { try controller.dailyLimit(minutes:limit) } catch { store.error = error.localizedDescription } }.disabled(!controller.authorized)
            Text("Emergency override is always available below. Revoking authorization bypasses restrictions; FORGE cannot reliably detect every bypass. Usage remains inside Apple's report extension.").font(.caption)
            if controller.authorized { DeviceActivityReport(.init("FORGE Total Usage"), filter:DeviceActivityFilter(segment:.daily(during:Calendar.current.dateInterval(of:.day,for:Date())!))).frame(height:180) }
        }.familyActivityPicker(isPresented:$picker,selection:$controller.selection).onChange(of:controller.selection) { _,_ in do { try controller.saveSelection() } catch { store.error = error.localizedDescription } }
    }
}
#endif
