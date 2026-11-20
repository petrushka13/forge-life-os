import SwiftUI
import ForgeCore

struct BusinessView: View {
    @Environment(AppStore.self) private var store
    @State private var showPayment = false
    @State private var kind: BusinessActivity.Kind = .conversation
    @State private var count = 1
    @State private var note = ""
    @State private var customerName = ""
    @State private var stage = "Qualified lead"
    var body: some View {
        ScreenContent {
            PageHeader(eyebrow: "45% OF LIFE MMR", title: "Value, validated.", subtitle: "Revenue → customers → conversations → qualified outreach → shipped product.")
            Metric(label: "This month", value: "\(ForgeStyle.money(store.session.monthlyRevenue())) KZT", footnote: "Target \(ForgeStyle.money(store.session.profile.targetRevenue)) KZT / month", symbol: "chart.line.uptrend.xyaxis")
            Button("Record payment") { showPayment = true }.forgePrimary()
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160))], spacing: 12) {
                Metric(label: "Paying customers", value: "\(store.session.customers.filter { $0.stage == "Paying customer" }.count)", footnote: "Actual payments", symbol: "person.crop.circle.badge.checkmark")
                ForEach(BusinessActivity.Kind.allCases, id: \.self) { activity in Metric(label: activity.rawValue, value: "\(store.session.activities.filter { $0.kind == activity && $0.date >= Date().addingTimeInterval(-30 * 86400) }.reduce(0) { $0 + $1.count })", footnote: "Last 30 days", symbol: "arrow.up.right") }
            }
            Card { VStack(alignment: .leading, spacing: 12) { Eyebrow(title: "Current bottleneck"); Text(store.aiMessage).font(.subheadline); Button("Analyze bottleneck") { Task { await store.askGM(.bottleneck) } }.buttonStyle(.bordered).disabled(store.aiBusy) } }
            Card { VStack(alignment: .leading, spacing: 12) { Text("Log a business outcome").font(.headline); Picker("Activity", selection: $kind) { ForEach(BusinessActivity.Kind.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) } }; Stepper("Count: \(count)", value: $count, in: 1...100); TextField("Result / customer / context", text: $note).textFieldStyle(.roundedBorder); Button("Record activity") { store.perform({ $0.activities.append(BusinessActivity(kind: kind, count: count, note: note)) }, success: "Activity logged. Complete an evidence-backed quest for rewards."); note = "" }.buttonStyle(.bordered).disabled(note.isEmpty); Text("Activity counts inform analytics. They do not independently mint XP or MMR.").font(.caption).foregroundStyle(.secondary) } }
            Card { VStack(alignment: .leading, spacing: 14) { Eyebrow(title: "Sales pipeline"); if store.session.customers.isEmpty { Text("Your first qualified lead starts here.").foregroundStyle(.secondary) }; ForEach(store.session.customers) { customer in HStack { Text(customer.name).font(.subheadline.weight(.medium)); Spacer(); Text(customer.stage).font(.caption).foregroundStyle(.secondary); Menu("Move") { ForEach(["Qualified lead", "Conversation", "Demo", "Proposal"], id: \.self) { value in Button(value) { store.perform { state in if let i = state.customers.firstIndex(where: { $0.id == customer.id }) { state.customers[i].stage = value } } } } }.font(.caption) } }; Divider(); TextField("Customer name", text: $customerName).textFieldStyle(.roundedBorder); Picker("Stage", selection: $stage) { ForEach(["Qualified lead", "Conversation", "Demo", "Proposal"], id: \.self) { Text($0) } }; Button("Add prospect") { store.perform { $0.customers.append(Customer(name: customerName, stage: stage)) }; customerName = "" }.buttonStyle(.bordered).disabled(customerName.isEmpty) } }
            Card { VStack(alignment: .leading, spacing: 12) { Eyebrow(title: "Payment history"); if store.session.revenue.isEmpty { Text("No payments recorded yet.").foregroundStyle(.secondary) }; ForEach(store.session.revenue.sorted { $0.date > $1.date }) { payment in HStack { VStack(alignment: .leading, spacing: 4) { Text(payment.client).font(.subheadline); Text(payment.date.formatted(date: .abbreviated, time: .omitted) + (payment.recurring ? " · recurring" : "")).font(.caption).foregroundStyle(.secondary) }; Spacer(); Text("\(ForgeStyle.money(payment.amount)) \(payment.currency)").font(.subheadline.weight(.semibold)).monospacedDigit() } } } }
        }.navigationTitle("Business").sheet(isPresented: $showPayment) { NavigationStack { RevenueForm().toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showPayment = false } } } }.sheetSizing() }
    }
}

struct SkillsScreen: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    var body: some View {
        ScreenContent {
            PageHeader(eyebrow: "DUAL-UTILITY CAPABILITY", title: "Earn your expertise.", subtitle: "Build a business. Keep a career option. Mastery requires proof.")
            HStack { let verified = store.session.skillProgress.filter { $0.state == .verified || $0.state == .mastered }.count; Text("\(verified) / \(store.session.skills.count) verified").font(.headline); Spacer(); Label("Prerequisites enforced", systemImage: "link").font(.caption).foregroundStyle(.secondary) }
            ForEach(["Python", "Backend", "Databases", "AI Engineering", "Automation", "Product Engineering", "Sales"], id: \.self) { category in
                VStack(alignment: .leading, spacing: 12) {
                    Eyebrow(title: category)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 12)], spacing: 12) {
                        ForEach(store.session.skills.filter { $0.category == category }) { skill in
                            let state = store.session.state(for: skill)
                            Button { router.sheet = .skill(skill) } label: { Card { VStack(alignment: .leading, spacing: 14) { HStack { Image(systemName: state == .locked ? "lock" : state == .verified || state == .mastered ? "checkmark.seal.fill" : "circle.dotted").foregroundStyle(state == .verified || state == .mastered ? ForgeStyle.green : ForgeStyle.accent); Spacer(); Text(state.rawValue == "testReady" ? "Test ready" : state.rawValue.capitalized).font(.caption).foregroundStyle(.secondary) }; Text(skill.title).font(.headline); Text(skill.objective).font(.caption).foregroundStyle(.secondary).lineLimit(3); let prerequisites = store.session.skillEdges.filter { $0.skillID == skill.id }.compactMap { edge in store.session.skills.first { $0.id == edge.prerequisiteID }?.title }; if !prerequisites.isEmpty { Label(prerequisites.joined(separator: ", "), systemImage: "arrow.turn.down.right").font(.caption2).foregroundStyle(.secondary) } } } }.buttonStyle(.plain).accessibilityIdentifier("skill.open." + skill.title).opacity(state == .locked ? 0.6 : 1)
                        }
                    }
                }
            }
        }
    }
}

struct SkillForm: View {
    var skill: Skill
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var state: SkillState = .learning
    @State private var proof = ""
    var body: some View {
        Form {
            Section { Text(skill.title).font(.title2.weight(.semibold)); Text(skill.objective).foregroundStyle(.secondary); Text("Verification is self-attested in V1. Link an independent implementation, exercise, debugging report or boss result. State changes alone do not earn XP.").font(.caption).foregroundStyle(.secondary) }
            if store.session.state(for: skill) == .locked { Section { Label("Verify prerequisite skills to unlock this capability.", systemImage: "lock") } }
            else { Section("Record capability") { Picker("State", selection: $state) { ForEach(SkillState.allCases.filter { $0 != .locked }, id: \.self) { Text($0.rawValue.capitalized).tag($0) } }.pickerStyle(.menu).accessibilityIdentifier("skill.state"); TextField("Practical evidence / project link", text: $proof, axis: .vertical).accessibilityIdentifier("skill.evidence").lineLimit(3...8); Button("Save progress") { do { try store.mutate { try $0.updateSkill(skill.id, state: state, proof: proof) }; dismiss() } catch { store.error = error.localizedDescription } }.forgePrimary() } }
        }.formStyle(.grouped).navigationTitle("Skill evidence").onAppear { state = store.session.state(for: skill); proof = store.session.skillProgress.first { $0.skillID == skill.id }?.proof ?? "" }
    }
}

struct RewardsView: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        ScreenContent {
            PageHeader(eyebrow: "EARNED ACCESS", title: "\(store.session.coins) Coins", subtitle: "Entertainment follows meaningful action. Coins cannot be purchased.")
            if let active = store.session.redemptions.last(where: { $0.expiresAt > Date() }) { Card { VStack(alignment: .leading, spacing: 10) { Label(active.title + " active", systemImage: "timer").font(.headline); Text(active.expiresAt, style: .timer).monospacedDigit(); Text("Until \(active.expiresAt.formatted(date: .omitted, time: .shortened)). Access follows the configured mode: a timer on Mac and default builds, or authorized Earned Access on iPhone. App shielding requires signed-device verification.").font(.caption).foregroundStyle(.secondary) } } }
            ForEach(store.session.rewards) { reward in Card { HStack(spacing: 16) { Image(systemName: reward.symbol).font(.title2).foregroundStyle(ForgeStyle.accent); VStack(alignment: .leading, spacing: 5) { Text(reward.title).font(.headline); Text("\(reward.minutes) minutes · \(reward.cost) Coins").font(.caption).foregroundStyle(.secondary) }; Spacer(); Button("Redeem") { store.redeemReward(reward) }.buttonStyle(.bordered).disabled(store.session.coins < reward.cost || store.session.redemptions.contains { $0.expiresAt > Date() }) } } }
            Eyebrow(title: "Redemptions")
            ForEach(store.session.redemptions.sorted { $0.startsAt > $1.startsAt }.prefix(20)) { redemption in HStack { Text(redemption.title); Spacer(); Text("−\(redemption.cost) · \(redemption.startsAt.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(.secondary) } }
        }.navigationTitle("Reward vault")
    }
}

struct AIProposalView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var replaceBoss = false
    var body: some View {
        ScreenContent {
            PageHeader(eyebrow: store.session.profile.aiEnabled ? "REMOTE GAME MASTER" : "LOCAL GAME MASTER", title: "A specific next move.", subtitle: "Advice proposes work. Local rules determine rewards.")
            Card { Text(store.aiMessage).lineSpacing(5) }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 130))]) { Button("Daily plan") { Task { await store.askGM(.dailyPlan) } }; Button("Bottleneck") { Task { await store.askGM(.bottleneck) } }; Button("Weekly review") { Task { await store.askGM(.weeklySummary) } }; Button("Recovery") { Task { await store.askGM(.recovery) } }; Button("Weekly boss") { Task { await store.askGM(.weeklyBoss) } } }.buttonStyle(.bordered).disabled(store.aiBusy)
            if let proposal = store.proposals { ForEach(proposal.quests) { item in Card { VStack(alignment: .leading, spacing: 10) { DomainPill(domain: item.domain); Text(item.title).font(.headline); Text(item.details).font(.subheadline).foregroundStyle(.secondary); Text("\(item.minutes) min · \(item.priority.rawValue)").font(.caption) } } }; Text(store.proposalAction == .dailyPlan ? "Accepting replaces untouched generated templates. Manual and completed quests remain." : "Accepting adds the proposed challenge using FORGE's local reward rules.").font(.caption).foregroundStyle(.secondary); if store.proposalAction == .weeklyBoss { Toggle("Replace the current untouched weekly boss", isOn: $replaceBoss) }; Button("Accept proposal") { if store.acceptPlan(replaceBoss: replaceBoss) { dismiss() } }.forgePrimary() }
            if store.aiBusy { ProgressView("Preparing a bounded proposal…") }
        }.navigationTitle("Game Master")
    }
}
