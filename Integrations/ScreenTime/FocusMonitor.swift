// Add to a Device Activity Monitor extension target, never the main app target.
import DeviceActivity
import ManagedSettings

final class FocusMonitor: DeviceActivityMonitor {
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        ManagedSettingsStore(named: .init("forge-focus")).clearAllSettings()
    }
}
