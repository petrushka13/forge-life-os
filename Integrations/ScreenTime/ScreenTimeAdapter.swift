// Optional iOS target source. Not included in the default application build.
// Requires the monitor extension below to be embedded before use.
#if os(iOS)
import FamilyControls
import ManagedSettings
import DeviceActivity
import Foundation

@MainActor final class ScreenTimeAdapter {
    private let settings = ManagedSettingsStore(named: .init("forge-focus"))
    private let activity = DeviceActivityName("forge-focus")
    func authorize() async throws { try await AuthorizationCenter.shared.requestAuthorization(for: .individual) }
    func begin(selection: FamilyActivitySelection, minutes: Int) throws {
        guard AuthorizationCenter.shared.authorizationStatus == .approved, minutes >= 15, minutes <= 180 else { throw NSError(domain: "FORGE", code: 1) }
        let now = Date(), end = now.addingTimeInterval(Double(minutes) * 60)
        let components: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        let schedule = DeviceActivitySchedule(intervalStart: Calendar.current.dateComponents(components, from: now), intervalEnd: Calendar.current.dateComponents(components, from: end), repeats: false)
        // Register expiration before applying any shield.
        try DeviceActivityCenter().startMonitoring(activity, during: schedule)
        settings.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        settings.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
        settings.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
    }
    func emergencyOverride() {
        settings.clearAllSettings()
        DeviceActivityCenter().stopMonitoring([activity])
    }
}
#endif
