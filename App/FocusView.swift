import SwiftUI
import ForgeCore

struct FocusView: View {
    @Environment(AppStore.self) private var store
    @State private var minutes = 45
    @State private var end: Date?
    @State private var reason = ""
    @State private var overrideAt: Date?
    @State private var now = Date()
    private var focusKey: String { store.isDemo ? "forge.demo.focusEnd" : "forge.focusEnd" }
    var body: some View {
        ScreenContent {
            PageHeader(eyebrow: "PROTECTED WORK", title: "One window. One output.", subtitle: "Focus timer. Signed iPhone builds can also apply an explicit Screen Time policy.")
            #if os(iOS)
            if Capabilities.screenTime && !store.isDemo && !store.isTesting { Card { ScreenTimeSetup() } }
            #endif
            Card { VStack(alignment: .leading, spacing: 18) {
                if let end, end > now { Text(end, style: .timer).font(.system(size: 54, weight: .medium, design: .rounded)).monospacedDigit(); Text("Close FORGE and work on your Main Quest. A timer is context, not proof of an outcome.").foregroundStyle(.secondary); Button("End early") { overrideAt = Date().addingTimeInterval(Double(store.session.screenRules.first?.overrideDelay ?? 15)) }.buttonStyle(.bordered).disabled(overrideAt != nil) }
                else { Stepper("Focus: \(minutes) minutes", value: $minutes, in: 15...180, step: 5); Button("Start focus timer") { do {
                        #if os(iOS)
                        if Capabilities.screenTime && !store.isDemo && !store.isTesting { try ScreenTimeController.shared.beginFocus(minutes:minutes) }
                        #endif
                        end = Date().addingTimeInterval(Double(minutes * 60)); UserDefaults.standard.set(end, forKey: focusKey)
                    } catch { store.error = error.localizedDescription } }.forgePrimary() }
                if let overrideAt { TextField("Why are you ending this window?", text: $reason).textFieldStyle(.roundedBorder); Text("No automatic penalty in the timer-only build. The interruption is logged for your review.").font(.caption).foregroundStyle(.secondary); Button(now < overrideAt ? "Wait \(Int(ceil(overrideAt.timeIntervalSince(now)))) seconds" : "Confirm interruption") {
                    #if os(iOS)
                    if !store.isDemo && !store.isTesting { ScreenTimeController.shared.emergencyOverride() }
                    #endif
                    store.perform({ $0.bypasses.append(BypassEvent(reason: reason)) }, success: "Interruption recorded. Recovery remains available."); end = nil; self.overrideAt = nil; UserDefaults.standard.removeObject(forKey: focusKey) }.buttonStyle(.bordered).disabled(now < overrideAt || reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
            } }
            Button("Request emergency override") { overrideAt = Date().addingTimeInterval(Double(store.session.screenRules.first?.overrideDelay ?? 15)) }.buttonStyle(.bordered).disabled(overrideAt != nil)
            Text("iPhone Screen Time architecture and embedded monitor/report extensions are included in the repository. They require Family Controls entitlements, an app group and signing. Usage reports stay inside Apple’s extension sandbox. macOS has no system Screen Time blocking integration in V1.").font(.caption).foregroundStyle(.secondary)
            if !store.session.bypasses.isEmpty { Eyebrow(title: "Focus interruptions"); ForEach(store.session.bypasses.sorted { $0.date > $1.date }.prefix(20)) { event in HStack { Text(event.reason).font(.subheadline); Spacer(); Text(event.date.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary) } } }
        }.navigationTitle("Focus window").onAppear { end = UserDefaults.standard.object(forKey: focusKey) as? Date }.task { while !Task.isCancelled { try? await Task.sleep(for: .seconds(1)); now = Date() } }
    }
}
