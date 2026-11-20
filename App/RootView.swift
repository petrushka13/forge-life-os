import SwiftUI
import ForgeCore
import Observation

enum Screen: String, CaseIterable, Identifiable {
    case command = "Command Center", quests = "Quests", progress = "Progress", skills = "Skills", settings = "Settings"
    var id: String { rawValue }
    var symbol: String { switch self { case .command: "square.grid.2x2"; case .quests: "checkmark.circle"; case .progress: "chart.xyaxis.line"; case .skills: "point.3.connected.trianglepath.dotted"; case .settings: "slider.horizontal.3" } }
}
enum SheetRoute: Identifiable {
    case onboarding, createQuest, complete(Quest), editQuest(Quest), revenue, business, review, rewards, health, skill(Skill), ai, demo, focus
    var id: String {
        switch self { case .onboarding: "onboarding"; case .createQuest: "create"; case .complete(let q): "complete-\(q.id)"; case .editQuest(let q): "edit-\(q.id)"; case .revenue: "revenue"; case .business: "business"; case .review: "review"; case .rewards: "rewards"; case .health: "health"; case .skill(let s): "skill-\(s.id)"; case .ai: "ai"; case .demo: "demo"; case .focus: "focus" }
    }
}
@MainActor @Observable final class AppRouter { var sheet: SheetRoute? }

struct RootView: View {
    @Bindable var store: AppStore
    @State private var router = AppRouter()
    @State private var selection: Screen? = .command
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("forge.appearance") private var appearance = "Dark"
    private var nativeProbe: Bool {
        #if DEBUG
        store.isTesting && CommandLine.arguments.contains("--native-editor-probe")
        #else
        false
        #endif
    }
    var body: some View {
        Group {
            if nativeProbe {
                #if DEBUG
                NativeEditorProbe()
                #endif
            } else if !store.syncConflicts.isEmpty {
                SyncConflictView()
            } else if store.launchError != nil {
                StorageRecoveryView()
            } else {
                #if os(macOS)
                NavigationSplitView {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 10) { Image(systemName: "flame.fill").foregroundStyle(ForgeStyle.accent).font(.title2); Text("FORGE").font(.title2.weight(.heavy)).tracking(3) }.padding(24).padding(.top, 8)
                        Text("REAL LIFE. RANKED.").font(.system(size: 9, weight: .medium)).tracking(2).foregroundStyle(.secondary).padding(.horizontal, 24).padding(.bottom, 28)
                        List(Screen.allCases, selection: $selection) { screen in Label(screen.rawValue, systemImage: screen.symbol).tag(screen).padding(.vertical, 8) }.listStyle(.sidebar)
                        VStack(alignment: .leading, spacing: 12) { Rectangle().fill(Color.primary.opacity(0.08)).frame(height: 1); HStack { Image(systemName: "person.crop.circle.fill").font(.title); VStack(alignment: .leading) { Text(store.session.profile.name).font(.subheadline.weight(.semibold)); Text(store.isDemo ? "Demo · isolated data" : store.isTesting ? "Test · isolated data" : "Personal workspace").font(.caption).foregroundStyle(.secondary) }; Spacer() }; Label("Local-first", systemImage: "lock.shield").font(.caption2).foregroundStyle(.secondary) }.padding(24)
                    }.navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 270)
                } detail: { screen(selection ?? .command) }
                .frame(minWidth: 920, minHeight: 680)
                #else
                TabView { ForEach(Screen.allCases) { page in NavigationStack { screen(page).navigationTitle(page == .command ? "FORGE" : page.rawValue).navigationBarTitleDisplayMode(.inline) }.tabItem { Label(page == .command ? "Home" : page.rawValue, systemImage: page.symbol) } } }
                #endif
            }
        }
        .environment(store).environment(router).tint(ForgeStyle.accent)
        .preferredColorScheme(appearance == "System" ? nil : appearance == "Dark" ? .dark : .light)
        .task { if !nativeProbe && !store.session.profile.onboarded && store.launchError == nil && store.syncConflicts.isEmpty { router.sheet = .onboarding } }
        .onChange(of: scenePhase) { _, phase in if phase == .active { store.refreshDay() } }
        .task { while !Task.isCancelled { try? await Task.sleep(for: .seconds(60)); store.refreshDay() } }
        .sheet(item: $router.sheet) { route in
            SheetHost(route: route).environment(store).environment(router).tint(ForgeStyle.accent).sheetSizing()
                .interactiveDismissDisabled(route.id == "onboarding")
        }
        .alert("FORGE", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) { Button("OK") { store.error = nil } } message: { Text(store.error ?? "") }
        .overlay(alignment: .bottom) {
            if let toast = store.toast { Label(toast, systemImage: "checkmark.seal.fill").font(.subheadline.weight(.medium)).padding(16).background(.regularMaterial, in: Capsule()).overlay(Capsule().strokeBorder(ForgeStyle.green.opacity(0.5))).padding(24).accessibilityAddTraits(.updatesFrequently).transition(.move(edge: .bottom).combined(with: .opacity)) }
        }
        .animation(reduceMotion || !store.session.profile.animations ? nil : .spring(duration: 0.4), value: store.toast)
    }
    @ViewBuilder private func screen(_ screen: Screen) -> some View {
        switch screen { case .command: CommandCenter(); case .quests: QuestsScreen(); case .progress: ProgressScreen(); case .skills: SkillsScreen(); case .settings: SettingsScreen() }
    }
}
#if DEBUG
/// Isolated control experiment for SDK keyboard layout diagnostics. No FORGE layout.
private struct NativeEditorProbe: View {
    @State private var value = ""
    @FocusState private var focused: Bool
    var body: some View {
        Text("Native SwiftUI editor probe").sheet(isPresented: .constant(true)) {
            NavigationStack {
                Form { TextField("Native result", text: $value, axis: .vertical).lineLimit(3...7).focused($focused).accessibilityIdentifier("native.editor") }
                    .navigationTitle("Native editor")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("Done") { focused = false } }
                        #if os(iOS)
                        ToolbarItemGroup(placement: .keyboard) { Button("Hide keyboard") { focused = false } }
                        #endif
                    }
            }
        }
    }
}
#endif

struct SheetHost: View {
    var route: SheetRoute
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Group {
                switch route {
                case .onboarding: OnboardingView()
                case .createQuest: QuestEditor()
                case .editQuest(let quest): QuestEditor(existing: quest)
                case .complete(let quest): CompleteQuestView(quest: quest)
                case .revenue: RevenueForm()
                case .business: BusinessView()
                case .review: ReviewForm()
                case .rewards: RewardsView()
                case .health: HealthForm()
                case .skill(let skill): SkillForm(skill: skill)
                case .ai: AIProposalView()
                case .demo: DemoView()
                case .focus: FocusView()
                }
            }.toolbar { if route.id != "onboarding" { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } } }
        }
    }
}
struct DemoView: View {
    @State private var demo = AppStore(demo: true)
    var body: some View { RootView(store: demo) }
}
