import SwiftUI
import UniformTypeIdentifiers
import ForgeCore

struct JSONDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}
struct SettingsScreen: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif
    @State private var profile = UserProfile()
    @State private var config = GameConfig()
    @State private var rewards: [Reward] = []
    @State private var proxyToken = ""
    @State private var githubToken = ""
    @State private var export = false
    @State private var document = JSONDocument(data: Data())
    @State private var importing = false
    @State private var restore = false
    @State private var reset = false
    @State private var purge = false
    @State private var purgeSecrets = true
    @State private var resetText = ""
    @AppStorage("forge.appearance") private var appearance = "Dark"
    @AppStorage("forge.cloud") private var cloud = false
    @AppStorage("forge.notifications") private var notifications = false
    var body: some View {
        Form {
            settingsSection0
            settingsSection1
            settingsSection2
            settingsSection3
            settingsSection4
            settingsSection5
            settingsSection6
            settingsSection7
            settingsSection8
            settingsSection9
            settingsSection10

        }.formStyle(.grouped).disabled(store.isDemo || store.isTesting).onAppear { profile = store.session.profile; config = store.session.config; rewards = store.session.rewards; if !store.isDemo && !store.isTesting { loadCredentials() } }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            do {
                let url = try result.get()
                let scoped = url.startAccessingSecurityScopedResource(); defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                let bytes = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                guard bytes <= ForgeBackup.maximumBytes else { throw BackupError.tooLarge }
                try store.prepareRestore(Data(contentsOf: url)); restore = true
            } catch { store.error = error.localizedDescription }
        }
        .confirmationDialog("Restore validated backup? Current records will be backed up before replacement.", isPresented: $restore) {
            Button("Restore backup", role: .destructive) { do { try store.confirmRestore(); store.notify("Backup restored") } catch { store.error = error.localizedDescription } }
            Button("Cancel", role: .cancel) { store.restoreCandidate = nil }
        } message: { if let candidate = store.restoreCandidate { Text("\(candidate.profile.name) · \(candidate.quests.count) quests · \(candidate.totalXP) XP · \(candidate.coins) Coins") } }
        .fileExporter(isPresented: $export, document: document, contentType: .json, defaultFilename: "FORGE-export") { result in if case .failure(let error) = result { store.error = error.localizedDescription } }
        .confirmationDialog("Start Over? Previous revisions and backups remain recoverable.", isPresented: $reset) { Button("Start Over", role: .destructive) { if store.perform({ $0 = GameSession() }) { resetText = ""; router.sheet = .onboarding } } }
        .confirmationDialog("Permanently purge this local store and its backups? Export first. Other devices and external exports are not erased.", isPresented: $purge) {
            Button("Purge local data", role: .destructive) {
                do {
                    try store.purgeLocalData(credentials: purgeSecrets)
                    if purgeSecrets { proxyToken = ""; githubToken = "" }
                    resetText = ""
                    router.sheet = .onboarding
                } catch {
                    store.error = error.localizedDescription
                }
            }
        }
    }
    private var settingsSection0: some View {
        Section { PageHeader(eyebrow: "YOUR RULES, VISIBLE", title: "Settings", subtitle: "Keep configuration small. Put attention into real work.") }
    }
    private var settingsSection1: some View {
        Section("Objective & schedule") { TextField("Name", text: $profile.name); TextField("Objective", text: $profile.objective); TextField("Monthly target KZT", value: $profile.targetRevenue, format: .number); Stepper("Wake at \(profile.wakeHour):00", value: $profile.wakeHour, in: 0...23); Stepper("Sleep at \(profile.sleepHour):00", value: $profile.sleepHour, in: 0...23); Stepper("Work starts \(profile.workStartHour):00", value: $profile.workStartHour, in: 0...23); Stepper("Work ends \(profile.workEndHour):00", value: $profile.workEndHour, in: 0...23); Stepper("Training days: \(profile.trainingDays)", value: $profile.trainingDays, in: 0...7); Picker("Strictness preference", selection: $profile.strictness) { Text("High").tag("High"); Text("Balanced").tag("Balanced") }; Text("Strictness informs coaching. MMR rules below define actual consequences.").font(.caption).foregroundStyle(.secondary) }
    }
    private var settingsSection2: some View {
        Section("Life MMR weights · normalized automatically") { ForEach(Domain.allCases) { domain in HStack { Label(domain.title, systemImage: domain.symbol).frame(minWidth: 90, alignment: .leading); Slider(value: Binding(get: { config.weights[domain, default: 0] }, set: { config.weights[domain] = $0 }), in: 0...1); Text("\(Int(config.weights[domain, default: 0] * 100))").monospacedDigit().frame(width: 32) } }; Text("Life MMR is always derived. Changing weights changes the displayed composite, never the domain balances.").font(.caption).foregroundStyle(.secondary) }
    }
    private var settingsSection3: some View {
        Section("Transparent game rules") {
                LabeledContent("Neutral daily performance") { TextField("0.65", value: $config.neutralPerformance, format: .number).frame(width: 90) }
                Stepper("Daily multiplier: \(Int(config.dailyMultiplier))", value: $config.dailyMultiplier, in: 10...100, step: 5)
                Stepper("Maximum daily gain: \(config.maxDailyDelta)", value: $config.maxDailyDelta, in: 5...60)
                Stepper("Maximum daily loss: \(config.minDailyDelta)", value: $config.minDailyDelta, in: -60 ... -5)
                Stepper("Outcome bonus cap: \(config.maxOutcomeBonus)", value: $config.maxOutcomeBonus, in: 0...50)
                Stepper("Low-impact XP cap: \(config.lowImpactXPCap)", value: $config.lowImpactXPCap, in: 0...200, step: 10)
                Stepper("Low-impact Coin cap: \(config.lowImpactCoinCap)", value: $config.lowImpactCoinCap, in: 0...100, step: 5)
                Stepper("Daily Coin cap: \(config.dailyCoinCap)", value: $config.dailyCoinCap, in: 50...500, step: 10)
                Text("Δ = round(multiplier × (performance − neutral)), clamped to daily limits. Recovery halves a negative delta. During today only earned gains apply; yesterday's unfinished work settles on next launch. No planned work and planned health rest are neutral. Manual confidence: 60%. XP level cost: 200 × level^1.35.").font(.caption).foregroundStyle(.secondary)
                DisclosureGroup("Rank thresholds") { ForEach(config.ranks.indices, id: \.self) { index in LabeledContent(config.ranks[index].title) { TextField("Minimum MMR", value: $config.ranks[index].minimum, format: .number).frame(width: 100).disabled(index == 0) } } }
            }
    }
    private var settingsSection4: some View {
        Section("Reward economy") { ForEach($rewards) { $reward in VStack(alignment: .leading, spacing: 6) { Text(reward.title).font(.headline); Stepper("Cost: \(reward.cost) Coins", value: $reward.cost, in: 5...500, step: 5); Stepper("Duration: \(reward.minutes) min", value: $reward.minutes, in: 5...240, step: 5) }.padding(.vertical, 5) } }
    }
    private var settingsSection5: some View {
        Section("AI Game Master · optional") { Toggle("Use remote backend", isOn: $profile.aiEnabled); TextField("HTTPS backend endpoint /v1/plan", text: $profile.aiEndpoint); SecureField("Proxy access token (Keychain)", text: $proxyToken); Text("Only a compact goals/execution summary is sent when you request advice. The provider secret stays on the server. The local planner works with remote AI off.").font(.caption).foregroundStyle(.secondary) }
    }
    private var settingsSection6: some View {
        Section("Integrations") {
                TextField("GitHub owner/repository", text: $profile.githubRepository); SecureField("GitHub personal token (Keychain)", text: $githubToken)
                Button("Fetch GitHub proof") { if save() { Task { await store.importGitHub() } } }.disabled(profile.githubRepository.isEmpty)
                Button("Read today's calendar") { Task { await store.connectCalendar() } }
                Button("Read Apple Health on iPhone") { Task { await store.connectHealth() } }
                Button("Screen Time / focus setup") { router.sheet = .focus }
                ForEach(store.session.integrations) { integration in VStack(alignment: .leading, spacing: 4) { Text("\(integration.name) · \(integration.state.rawValue)").font(.subheadline.weight(.medium)); Text(integration.message).font(.caption).foregroundStyle(.secondary) } }
                Button("Import n8n / VS Code evidence") { if save() { Task { await store.importExternalEvidence() } } }; Text("n8n and VS Code use the private backend configured above. Imports never complete quests or earn rewards by themselves. LeetCode uses manual proof.").font(.caption).foregroundStyle(.secondary)
            }
    }
    private var settingsSection7: some View {
        Section("Privacy & sync") { Text(store.repository?.syncMessage ?? "Storage unavailable").font(.caption); if Capabilities.cloud { Toggle("iCloud sync (restart required)", isOn: $cloud) } else { Text("iCloud is not enabled in this build. Configure the private container and entitlements using INTEGRATIONS.md to opt in.").font(.caption).foregroundStyle(.secondary) }; Button("Export all data as JSON") { do { document = JSONDocument(data: try ForgeBackup(session: store.session).encoded()); export = true } catch { store.error = error.localizedDescription } }; Button("Restore backup…") { importing = true }; Button("Export redacted diagnostics…") { do { document = JSONDocument(data:try ForgeBackup.encoder.encode(ForgeDiagnostics(session:store.session,version:Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "1.0",capabilities:["health":Capabilities.health,"cloud":Capabilities.cloud,"screenTime":Capabilities.screenTime]))); export = true } catch { store.error = error.localizedDescription } }; Text("Automatic backups: last seven saved versions. Exports include personal records and evidence, never Keychain credentials.").font(.caption).foregroundStyle(.secondary) }
    }
    private var settingsSection8: some View {
        Section("Experience") { Picker("Appearance", selection: $appearance) { Text("Dark").tag("Dark"); Text("Light").tag("Light"); Text("System").tag("System") }; Toggle("Meaningful animations", isOn: $profile.animations); Toggle("Completion haptics (iPhone)", isOn: $profile.haptics); Toggle("Completion sound", isOn: $profile.sound); Toggle("Sparse quest, recovery, boss and reward reminders", isOn: $notifications).onChange(of: notifications) { _, value in if value { Task { do { try await ForgeNotifications.enableMorning(hour: profile.wakeHour) } catch { notifications = false; store.error = error.localizedDescription } } } else { ForgeNotifications.disable() } }; Button("Explore isolated demo") {
                #if os(macOS)
                openWindow(id: "forge-demo")
                #else
                router.sheet = .demo
                #endif
            }.disabled(store.isDemo) }
    }
    private var settingsSection9: some View {
        Section { Button("Save settings") { save() }.forgePrimary(); Text("Save applies your configuration locally. Reduce Motion always overrides animation preferences.").font(.caption).foregroundStyle(.secondary) }
    }
    private var settingsSection10: some View {
        Section("Start over / delete local data") { Text("Start Over keeps recoverable history and backups. Purge removes records, revisions and backups from this local store. Other devices and downloaded exports must be erased separately.").font(.caption); TextField("Type RESET or PURGE", text: $resetText); Button("Start Over", role: .destructive) { reset = true }.disabled(resetText != "RESET"); Toggle("Also erase FORGE Keychain credentials", isOn: $purgeSecrets); Button("Purge local FORGE data", role: .destructive) { purge = true }.disabled(resetText != "PURGE") }
    }
    private func loadCredentials() {
        do { proxyToken = try Keychain.readValue("proxy-token") ?? ""; githubToken = try Keychain.readValue("github-token") ?? "" }
        catch { store.error = error.localizedDescription }
    }
    @discardableResult private func save() -> Bool {
        guard config.isValid, profile.targetRevenue.isFinite, profile.targetRevenue > 0, !profile.name.isEmpty else { store.error = GameError.invalidConfiguration.localizedDescription; return false }
        if profile.aiEnabled { guard let url = URL(string: profile.aiEndpoint), PrivateHTTP.validEndpoint(url) else { store.error = "Use HTTPS for the AI endpoint, or localhost for development."; return false } }
        do { var candidate = store.session; candidate.profile = profile; candidate.config = config; candidate.rewards = rewards; try candidate.validateForStorage(); try Keychain.transaction(["proxy-token": proxyToken, "github-token": githubToken]) { try store.mutate { $0.profile = profile; $0.config = config; $0.rewards = rewards; if !$0.goals.isEmpty { $0.goals[0].title = profile.objective; $0.goals[0].target = profile.targetRevenue } } }; store.notify("Settings saved"); if notifications { Task { do { try await ForgeNotifications.enableMorning(hour: profile.wakeHour) } catch { store.error = error.localizedDescription } } }; return true } catch { store.error = error.localizedDescription; return false }
    }
}
