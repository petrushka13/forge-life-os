import SwiftUI
import ForgeCore

struct CommandCenter: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    private var session: GameSession { store.session }
    private var today: [Quest] { session.todayQuests() }
    private var level: LevelProgress { session.engine.level(totalXP: session.totalXP) }
    private var weekDelta: Int {
        let now = Date()
        return session.lifeMMRChange(since: now.addingTimeInterval(-7 * 86400), now: now)
    }
    private var momentum: String {
        if session.recoveries.contains(where: { Calendar.current.isDateInToday($0.date) }) { return "Recovery mode" }
        if today.filter({ $0.status == .completed }).count >= 2 { return "Strong momentum" }
        if Calendar.current.component(.hour, from: Date()) >= 17 && today.contains(where: { $0.priority == .main && $0.status == .active }) { return "At risk · recovery available" }
        return "Ready to execute"
    }
    var body: some View {
        ScreenContent {
            HStack(alignment: .top) { PageHeader(eyebrow: store.isDemo ? "DEMO WORKSPACE" : "SEASON 01 · BUILD SOMETHING VALUABLE", title: "Your next level is real.", subtitle: Date().formatted(.dateTime.weekday(.wide).day().month(.wide))); Spacer(); Button { router.sheet = .review } label: { Image(systemName: "moon").font(.title3).padding(12).background(Color.primary.opacity(0.05), in: Circle()) }.buttonStyle(.plain).accessibilityLabel("Daily review") }
            #if os(macOS)
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 22) {
                    VStack(spacing: 22) { hero; objective }.frame(minWidth: 450)
                    priorities.frame(minWidth: 310, maxWidth: 420)
                }
                VStack(spacing: 22) { hero; priorities; objective }
            }
            #else
            VStack(spacing: 22) { hero; priorities; objective }
            #endif
            Card {
                HStack(alignment: .top, spacing: 16) {
                    Image(systemName: "sparkle").font(.title2).foregroundStyle(ForgeStyle.accent).padding(12).background(ForgeStyle.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 10) { HStack { Eyebrow(title: "Game Master"); Text(session.profile.aiEnabled ? "Remote" : "Local planner").font(.caption2).foregroundStyle(.secondary) }; Text(store.aiMessage).font(.subheadline).lineSpacing(4); Button("Review priorities") { Task { await store.askGM(.bottleneck) } }.font(.caption.weight(.semibold)).disabled(store.aiBusy) }
                }
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 14)], spacing: 14) { bossCard; ghostCard }
            HStack(spacing: 12) { Button("Enter recovery") { store.perform({ $0.startRecovery() }, success: "Recovery quest ready. One concrete result is enough to restart.") }.buttonStyle(.bordered); Button("Earned access") { router.sheet = .rewards }.buttonStyle(.bordered); Button("Focus") { router.sheet = .focus }.buttonStyle(.bordered) }.font(.caption)
            if !store.commitments.isEmpty { Card { VStack(alignment: .leading, spacing: 12) { Eyebrow(title: "Today's calendar"); ForEach(store.commitments) { event in HStack { Text(event.title).font(.subheadline); Spacer(); Text(event.start, style: .time).font(.caption).foregroundStyle(.secondary) } } } } }
            Text("Make the move. Close FORGE. Do the work.").font(.caption).foregroundStyle(.tertiary).frame(maxWidth: .infinity).padding(.vertical, 8)
        }
    }
    private var priorities: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Today's priorities").font(.title2.weight(.semibold))
                    Text("Produce a result. Bring back evidence.").font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Button { router.sheet = .createQuest } label: { Image(systemName: "plus").padding(10).background(Color.primary.opacity(0.05), in: Circle()) }.buttonStyle(.plain).accessibilityLabel("Create quest")
            }
            ForEach(today) { quest in QuestRow(quest: quest) }
        }
    }
    private var domainColumns: [GridItem] {
        #if os(macOS)
        Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)
        #else
        Array(repeating: GridItem(.flexible(), spacing: 14), count: 2)
        #endif
    }
    private var hero: some View {
        Card {
            VStack(alignment: .leading, spacing: 22) {
                HStack { Eyebrow(title: "Life MMR"); Spacer(); Label(momentum, systemImage: "circle.fill").font(.caption.weight(.medium)).foregroundStyle(ForgeStyle.green).labelStyle(.titleAndIcon) }
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(session.lifeMMR)").font(.system(size: 72, weight: .semibold, design: .rounded)).tracking(-4).monospacedDigit().contentTransition(.numericText()).accessibilityLabel("Life MMR \(session.lifeMMR)").accessibilityIdentifier("dashboard.mmr")
                        HStack(spacing: 12) { Text(session.engine.rank(session.lifeMMR).uppercased()).accessibilityIdentifier("dashboard.rank").font(.system(size: 12, weight: .bold)).tracking(2).foregroundStyle(ForgeStyle.accent); Text("\(weekDelta >= 0 ? "+" : "")\(weekDelta) this week").font(.caption).foregroundStyle(.secondary) }
                    }
                    Spacer()
                    Image(systemName: "hexagon.fill").font(.system(size: 76)).foregroundStyle(ForgeStyle.accent.opacity(0.13)).overlay { Image(systemName: "bolt.fill").font(.system(size: 29)).foregroundStyle(ForgeStyle.accent) }.accessibilityHidden(true)
                }
                HStack {
                    Text("LEVEL \(level.level) · \(level.currentXP) / \(level.requiredXP) XP").accessibilityIdentifier("dashboard.level").font(.caption.weight(.semibold)).monospacedDigit()
                    Spacer()
                    Label("\(session.coins)", systemImage: "circle.hexagongrid").font(.caption.weight(.semibold)).accessibilityLabel("\(session.coins) Coins").accessibilityIdentifier("dashboard.coins")
                    Label("\(session.streaks().first?.current ?? 0)", systemImage: "flame").font(.caption.weight(.semibold)).accessibilityLabel("Execution streak \(session.streaks().first?.current ?? 0) days")
                }.foregroundStyle(.secondary)
                ProgressView(value: level.fraction).tint(ForgeStyle.accent).accessibilityLabel("Level progress")
                Rectangle().fill(Color.primary.opacity(0.08)).frame(height: 1)
                LazyVGrid(columns: domainColumns, alignment: .leading, spacing: 18) {
                    ForEach(Domain.allCases) { domain in
                        Button { if domain == .business { router.sheet = .business } else if domain == .health { router.sheet = .health } else { router.sheet = .ai } } label: {
                            VStack(alignment: .leading, spacing: 7) { Label(domain.title, systemImage: domain.symbol).font(.caption).foregroundStyle(.secondary); Text("\(session.ratings[domain] ?? 1000)").font(.title3.weight(.semibold)).monospacedDigit().foregroundStyle(.primary); Text(session.engine.rank(session.ratings[domain] ?? 1000)).font(.caption2).foregroundStyle(ForgeStyle.color(domain)) }.frame(maxWidth: .infinity, alignment: .leading)
                        }.buttonStyle(.plain)
                    }
                }
            }
        }.background(RadialGradient(colors: [ForgeStyle.accent.opacity(0.08), .clear], center: .topTrailing, startRadius: 10, endRadius: 500), in: RoundedRectangle(cornerRadius: 20))
    }
    private var objective: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack { Eyebrow(title: "12-month objective"); Spacer(); Button("Business ↗") { router.sheet = .business }.font(.caption).accessibilityIdentifier("business.open") }
                HStack(alignment: .firstTextBaseline, spacing: 6) { Text(ForgeStyle.money(session.monthlyRevenue())).font(.title.weight(.semibold)).monospacedDigit(); Text("/ \(ForgeStyle.money(session.profile.targetRevenue)) KZT").font(.subheadline).foregroundStyle(.secondary) }.minimumScaleFactor(0.65)
                ProgressView(value: min(1, session.monthlyRevenue() / max(1, session.profile.targetRevenue))).tint(ForgeStyle.accent).accessibilityLabel("Monthly income goal progress")
                HStack { Text("Monthly income · \(session.profile.objective)").font(.caption).foregroundStyle(.secondary); Spacer(); Button("Record payment") { router.sheet = .revenue }.font(.caption.weight(.semibold)) }
            }
        }
    }
    private var bossCard: some View {
        Card { VStack(alignment: .leading, spacing: 12) { HStack { Eyebrow(title: "Weekly Boss"); Spacer(); Image(systemName: "flag.checkered").foregroundStyle(ForgeStyle.accent) }
            if let boss = session.bosses.filter({ !$0.monthly }).max(by: { a, b in (session.quests.first { $0.id == a.questID }?.deadline ?? .distantPast) < (session.quests.first { $0.id == b.questID }?.deadline ?? .distantPast) }), let quest = session.quests.first(where: { $0.id == boss.questID }) {
                Text(quest.title).font(.headline).lineLimit(3); Text("\(quest.baseXP) base XP · \(quest.coinReward) base Coins").font(.caption).foregroundStyle(.secondary)
                HStack { Text(quest.status == .completed ? "Defeated" : "Due \(quest.deadline.formatted(.dateTime.weekday(.wide)))").font(.caption).foregroundStyle(ForgeStyle.green); Spacer(); if quest.status == .active { Button("Take on boss") { router.sheet = .complete(quest) }.font(.caption.weight(.semibold)) } }
            }
        } }
    }
    private var ghostCard: some View {
        let ghost = session.ghost()
        return Card { VStack(alignment: .leading, spacing: 12) { HStack { Eyebrow(title: "Your Ghost"); Spacer(); Image(systemName: "person.crop.circle.dashed").foregroundStyle(.secondary) }; Text("\(ghost.current) / \(ghost.best) actions").font(.title2.weight(.semibold)).monospacedDigit(); Text("Current seven days / personal best. Your previous best self sets the pace.").font(.caption).foregroundStyle(.secondary); ProgressView(value: Double(ghost.current), total: Double(max(1, ghost.best))).tint(ForgeStyle.green) } }
    }
}

struct QuestRow: View {
    let quest: Quest
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            Button { if quest.status == .active { router.sheet = .complete(quest) } } label: { Image(systemName: quest.status == .completed ? "checkmark.circle.fill" : quest.status == .missed ? "exclamationmark.circle" : "circle").font(.system(size: 25, weight: .light)).foregroundStyle(quest.status == .completed ? ForgeStyle.green : ForgeStyle.color(quest.domain)).padding(.top, 2) }.buttonStyle(.plain).disabled(quest.status != .active).accessibilityLabel("Complete \(quest.title)").accessibilityIdentifier("quest.complete.\(quest.priority.rawValue)")
            VStack(alignment: .leading, spacing: 10) {
                HStack { Eyebrow(title: quest.type == .recovery ? "Recovery quest" : quest.priority.rawValue + " quest"); Spacer(); Text("\(quest.estimatedMinutes) min").font(.caption2).foregroundStyle(.secondary) }
                Text(quest.title).font(.system(.body, weight: .semibold)).foregroundStyle(quest.status == .completed ? .secondary : .primary).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) { DomainPill(domain: quest.domain); Text("\(quest.baseXP) base XP · \(quest.coinReward) base Coins").font(.caption2).foregroundStyle(.secondary); Spacer() }
                if let evidence = store.session.evidence.first(where: { $0.questID == quest.id }) { Text("\(evidence.source.rawValue) · \(Int(evidence.confidence * 100))% confidence · \(evidence.note)").font(.caption2).foregroundStyle(.secondary).lineLimit(2) }
            }
            if quest.status == .active { Menu { Button("Complete with evidence") { router.sheet = .complete(quest) }; if quest.type != .boss && quest.type != .recovery { Button("Edit quest") { router.sheet = .editQuest(quest) } } } label: { Image(systemName: "ellipsis").foregroundStyle(.secondary).padding(5) }.menuStyle(.borderlessButton).fixedSize() }
        }.padding(18).background(Color.primary.opacity(quest.priority == .main ? 0.055 : 0.025), in: RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(quest.priority == .main && quest.status == .active ? ForgeStyle.accent.opacity(0.4) : Color.primary.opacity(0.07), lineWidth: 1))
    }
}

struct QuestsScreen: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    @State private var filter = "Today"
    var body: some View {
        ScreenContent {
            PageHeader(eyebrow: "EXECUTION", title: "Work that counts.", subtitle: "Outcomes over activity. Three priorities, then optional work.")
            HStack { Picker("Quest filter", selection: $filter) { ForEach(["Today", "Bosses", "History"], id: \.self) { Text($0) } }.pickerStyle(.segmented); Button { router.sheet = .createQuest } label: { Image(systemName: "plus") }.buttonStyle(.bordered) }
            if filter == "Today" { ForEach(store.session.todayQuests()) { QuestRow(quest: $0) } }
            else if filter == "Bosses" { ForEach(store.session.quests.filter { $0.type == .boss }.sorted { $0.deadline > $1.deadline }) { QuestRow(quest: $0) } }
            else { let history = store.session.quests.filter { $0.status == .completed || $0.status == .missed }.sorted { $0.deadline > $1.deadline }; if history.isEmpty { ContentUnavailableView("History starts with your first result", systemImage: "clock", description: Text("Complete a quest to create your first evidence-backed record.")) }; ForEach(history.prefix(100)) { quest in VStack(alignment: .leading, spacing: 8) { Text(quest.deadline.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(.secondary); QuestRow(quest: quest) } } }
            Card { VStack(alignment: .leading, spacing: 12) { Eyebrow(title: "Bad start ≠ game over"); Text("Recovery shrinks the challenge to one achievable result. It softens today's loss without awarding a full winning day.").font(.subheadline).foregroundStyle(.secondary); Button("Start recovery") { store.perform({ $0.startRecovery() }, success: "Recovery quest added") }.forgePrimary() } }
            Button(store.aiBusy ? "Preparing…" : "Propose a daily plan") { Task { await store.askGM(.dailyPlan); if store.proposals != nil { router.sheet = .ai } } }.buttonStyle(.bordered).disabled(store.aiBusy)
        }
    }
}
