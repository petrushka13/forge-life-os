import SwiftUI
import ForgeCore

struct OnboardingView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var profile = UserProfile()
    @State private var weights = GameConfig().weights
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Image(systemName: "flame.fill").font(.system(size: 42)).foregroundStyle(ForgeStyle.accent)
                PageHeader(eyebrow: "WELCOME TO FORGE", title: "Build a life worth ranking.", subtitle: "One clear objective. Three daily priorities. Real evidence.")
                VStack(alignment: .leading, spacing: 16) {
                    TextField("Name", text: $profile.name).textFieldStyle(.roundedBorder)
                    TextField("Primary objective", text: $profile.objective).textFieldStyle(.roundedBorder)
                    LabeledContent("Target monthly income · KZT") { TextField("5,000,000", value: $profile.targetRevenue, format: .number).textFieldStyle(.roundedBorder).frame(maxWidth: 180) }
                    LabeledContent("Current monthly income · KZT") { TextField("0", value: $profile.baselineRevenue, format: .number).textFieldStyle(.roundedBorder).frame(maxWidth: 180) }
                    Text("Current income is a baseline for this month; future months use recorded payments.").font(.caption).foregroundStyle(.secondary)
                }
                DisclosureGroup("Schedule & priorities") {
                    VStack(alignment: .leading, spacing: 14) {
                        Stepper("Wake: \(profile.wakeHour):00", value: $profile.wakeHour, in: 0...23)
                        Stepper("Sleep: \(profile.sleepHour):00", value: $profile.sleepHour, in: 0...23)
                        Stepper("Work starts: \(profile.workStartHour):00", value: $profile.workStartHour, in: 0...23)
                        Stepper("Work ends: \(profile.workEndHour):00", value: $profile.workEndHour, in: 0...23)
                        Stepper("Training: \(profile.trainingDays) days / week", value: $profile.trainingDays, in: 0...7)
                        Picker("Strictness", selection: $profile.strictness) { Text("High").tag("High"); Text("Balanced").tag("Balanced") }
                        ForEach(Domain.allCases) { domain in HStack { Text(domain.title); Slider(value: Binding(get: { weights[domain, default: 0] }, set: { weights[domain] = $0 }), in: 0...1); Text("\(Int(weights[domain, default: 0] * 100))%").monospacedDigit().frame(width: 44) } }
                    }.padding(.top, 12)
                }
                DisclosureGroup("Rewards & coaching") {
                    TextField("Distractions to avoid (optional)", text:Binding(get:{profile.distractionNotes ?? ""},set:{profile.distractionNotes=$0})).textFieldStyle(.roundedBorder)
                    Picker("AI tone",selection:$profile.aiTone) { Text("Strict rational coach").tag("Strict rational coach"); Text("Concise practical coach").tag("Concise practical coach") }
                    ForEach(SeedData.rewards.map(\.title), id: \.self) { title in
                        Toggle("Offer \(title) as a reward", isOn: Binding(get: { (profile.rewardPreferences ?? SeedData.rewards.map(\.title)).contains(title) }, set: { enabled in
                            var selected = profile.rewardPreferences ?? SeedData.rewards.map(\.title)
                            selected.removeAll { $0 == title }; if enabled { selected.append(title) }; profile.rewardPreferences = selected
                        }))
                    }
                    Text("Reward costs can be changed in Settings. Optional Apple app selection is available after onboarding.").font(.caption).foregroundStyle(.secondary)
                }
                Label("Private by default. Permissions and AI are optional and can be configured after your first result.", systemImage: "lock.shield").font(.subheadline).foregroundStyle(.secondary)
                Button("Enter the Command Center") {
                    guard !profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !profile.objective.isEmpty, profile.targetRevenue.isFinite, profile.targetRevenue > 0, profile.baselineRevenue.isFinite, profile.baselineRevenue >= 0, weights.values.reduce(0, +) > 0 else { store.error = GameError.invalidInput.localizedDescription; return }
                    do { try store.mutate { $0.config.weights = weights; $0.onboard(profile: profile) }; dismiss() } catch { store.error = error.localizedDescription }
                }.forgePrimary()
            }.padding(32)
        }.navigationTitle("A clear starting point")
    }
}

struct CompleteQuestView: View {
    let quest: Quest
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var note = ""
    @State private var reference = ""
    @State private var selectedCommit = ""
    @State private var selectedExternal = ""
    @State private var selectedHealth = ""
    @State private var submitted = false
    @FocusState private var evidenceFocused: Bool
    var body: some View {
        Form {
            Section { DomainPill(domain: quest.domain); Text(quest.title).font(.title2.weight(.semibold)); Text(quest.details).foregroundStyle(.secondary) }
            Section("What changed in the real world?") { TextEditor(text: $note).frame(minHeight: 100).accessibilityLabel("Describe the concrete result").accessibilityIdentifier("quest.evidence").focused($evidenceFocused); TextField("Proof link (optional)", text: $reference); Text(quest.evidenceRequirement).font(.caption).foregroundStyle(.secondary) }
            if quest.domain == .builder && !store.gitProofs.isEmpty { Section("Imported GitHub evidence") { Picker("Relevant commit", selection: $selectedCommit) { Text("Manual confirmation").tag(""); ForEach(store.gitProofs) { Text($0.title).tag($0.id) } }; Text("Select a commit only if it demonstrates this quest's outcome. Commit counts earn no rewards.").font(.caption).foregroundStyle(.secondary) } }
            if quest.domain == .health, let summary = store.session.health.first(where: { Calendar.current.isDateInToday($0.date) }) {
                Section("Corresponding health evidence") {
                    Picker("Relevant measurement", selection: $selectedHealth) {
                        Text("Manual confirmation").tag("")
                        ForEach(["steps", "workouts", "cardioMinutes", "sleepHours"].filter { summary.metric($0).state == .available && summary.metric($0).source == "Apple Health" }, id: \.self) { name in Text(name).tag("forge-health:\(summary.id):\(name)") }
                    }
                    Text("Select only a measurement that supports this health quest. It does not complete any quest automatically.").font(.caption).foregroundStyle(.secondary)
                }
            }
            if !store.session.evidenceInbox.isEmpty {
                Section("Automation / coding evidence") {
                    Picker("Relevant record", selection: $selectedExternal) {
                        Text("No external reference").tag("")
                        ForEach(store.session.evidenceInbox.filter { record in !store.session.evidence.contains { $0.externalEventID == record.id } }) { record in
                            Text("\(record.project) · \(record.kind) · \(record.date?.formatted(date: .abbreviated, time: .shortened) ?? record.timestamp)").tag(record.id)
                        }
                    }.onChange(of: selectedExternal) { _, value in if !value.isEmpty { selectedCommit = "" } }
                    Text("Activity is a reference, not proof that all acceptance criteria passed. Describe the output yourself. Imports confer no rewards.").font(.caption).foregroundStyle(.secondary)
                }
            }
            Section {
                let confidence = store.session.evidenceInbox.first { $0.id == selectedExternal }?.source.confidence ?? (!selectedHealth.isEmpty && quest.domain == .health ? 1 : selectedCommit.isEmpty ? 0.6 : 0.9)
                let reward = store.session.engine.rewards(for: quest, confidence: confidence)
                LabeledContent("Evidence", value: "Reference confidence: \(Int(confidence * 100))%")
                LabeledContent("Before daily caps", value: "+\(reward.xp) XP · +\(reward.coins) Coins")
                Text("Manual real work counts. Daily caps apply to the final reward; the ledger records the actual amount.").font(.caption).foregroundStyle(.secondary)
                Button("Record result & claim rewards") { submitted = true; if store.complete(quest, note: note, reference: reference, gitProof: store.gitProofs.first { $0.id == selectedCommit }, externalProof: store.session.evidenceInbox.first { $0.id == selectedExternal }, healthReference: selectedHealth) { dismiss() } else { submitted = false } }.forgePrimary().disabled(note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || submitted)
            }
        }.formStyle(.grouped).navigationTitle("Bring back evidence")
        #if os(iOS)
        // The simulator SDK emits invalid-frame diagnostics for keyboard toolbars,
        // including in the isolated native editor control. Keep dismissal native
        // without creating that keyboard accessory layout.
        .scrollDismissesKeyboard(.interactively)
        .toolbar { ToolbarItem(placement: .confirmationAction) { if evidenceFocused { Button("Hide keyboard") { evidenceFocused = false } } } }
        #endif
    }
}

struct QuestEditor: View {
    var existing: Quest? = nil
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var details = ""
    @State private var domain: Domain = .business
    @State private var priority: Priority = .optional
    @State private var type: QuestType = .outcome
    @State private var minutes = 30
    @State private var deadline = Date()
    @State private var impact = 1.0
    @State private var difficulty = 1.0
    var body: some View {
        Form {
            Section("Define an observable output") { TextField("Quest title", text: $title); TextField("Definition of done", text: $details, axis: .vertical).lineLimit(2...5); Picker("Domain", selection: $domain) { ForEach(Domain.allCases) { Text($0.title).tag($0) } }; Picker("Priority", selection: $priority) { ForEach(Priority.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) } }; Picker("Type", selection: $type) { ForEach(QuestType.allCases.filter { $0 != .boss && $0 != .recovery }, id: \.self) { Text($0.rawValue.capitalized).tag($0) } } }
            Section("Scope") { Stepper("Estimate: \(minutes) minutes", value: $minutes, in: 5...180, step: 5); DatePicker("Deadline", selection: $deadline, in: Date()..., displayedComponents: [.date]); LabeledContent("Impact") { Slider(value: $impact, in: 0.1...1.5); Text(impact.formatted(.number.precision(.fractionLength(1)))) }; LabeledContent("Difficulty") { Slider(value: $difficulty, in: 0.5...1.5); Text(difficulty.formatted(.number.precision(.fractionLength(1)))) }; Text("Maximum three mandatory quests per day. Additional work stays optional. Completed quests are immutable.").font(.caption).foregroundStyle(.secondary) }
            Button(existing == nil ? "Create quest" : "Save quest") {
                do {
                    let due = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: deadline)!
                    try store.mutate { state in
                        if let existing, let index = state.quests.firstIndex(where: { $0.id == existing.id }) {
                            guard state.quests[index].status == .active else { throw GameError.alreadyCompleted }
                            guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw GameError.invalidInput }
                            let otherRequired = state.quests.filter { $0.id != existing.id && Calendar.current.isDate($0.deadline, inSameDayAs: due) && $0.priority != .optional && $0.status != .archived && $0.type != .boss && $0.type != .recovery }.count
                            guard priority == .optional || otherRequired < 3 else { throw GameError.invalidInput }
                            state.quests[index].title = title; state.quests[index].details = details; state.quests[index].domain = domain; state.quests[index].priority = priority; state.quests[index].type = type; state.quests[index].estimatedMinutes = minutes; state.quests[index].deadline = due; state.quests[index].impact = impact; state.quests[index].difficulty = difficulty
                        } else { try state.addQuest(Quest(title: title, details: details, domain: domain, type: type, priority: priority, difficulty: difficulty, impact: impact, baseXP: priority == .main ? state.config.mainQuestXP : state.config.standardQuestXP, coinReward: priority == .main ? state.config.mainQuestCoins : state.config.standardQuestCoins, estimatedMinutes: minutes, deadline: due)) }
                    }; dismiss()
                } catch { store.error = error.localizedDescription }
            }.forgePrimary().disabled(title.isEmpty)
        }.formStyle(.grouped).navigationTitle(existing == nil ? "New quest" : "Edit quest").onAppear { if let q = existing { title = q.title; details = q.details; domain = q.domain; priority = q.priority; type = q.type; minutes = q.estimatedMinutes; deadline = q.deadline; impact = q.impact; difficulty = q.difficulty } }
    }
}

struct RevenueForm: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var amount = 0.0
    @State private var currency = "KZT"
    @State private var client = ""
    @State private var source = "Direct"
    @State private var date = Date()
    @State private var recurring = false
    @State private var note = ""
    var body: some View {
        Form {
            Section("Payment received") { TextField("Amount", value: $amount, format: .number).accessibilityIdentifier("revenue.amount"); Picker("Currency", selection: $currency) { Text("KZT").tag("KZT"); Text("USD").tag("USD"); Text("EUR").tag("EUR") }; TextField("Client", text: $client).accessibilityIdentifier("revenue.client"); TextField("Source", text: $source); DatePicker("Date", selection: $date, in: ...Date(), displayedComponents: [.date]); Toggle("Recurring payment", isOn: $recurring); TextField("Note (optional)", text: $note, axis: .vertical) }
            Section { Text("Only received KZT payments count toward the KZT monthly goal. Other currencies are recorded without an invented exchange rate. A recurring flag describes this payment; it does not create future revenue.").font(.caption).foregroundStyle(.secondary); Button("Record payment") { do { try store.mutate { try $0.addRevenue(RevenueEntry(amount: amount, currency: currency, client: client, source: source, date: date, recurring: recurring, note: note)) }; store.notify("Payment recorded. A real outcome."); dismiss() } catch { store.error = error.localizedDescription } }.forgePrimary().accessibilityIdentifier("revenue.record").disabled(amount <= 0 || client.isEmpty) }
        }.formStyle(.grouped).navigationTitle("Record revenue")
    }
}

struct ReviewForm: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var moved = ""
    @State private var blocked = ""
    @State private var correct = true
    @State private var energy = 3
    @State private var rating = 3
    @State private var note = ""
    var body: some View {
        Form {
            Section("60-second review") { TextField("What moved forward?", text: $moved, axis: .vertical); TextField("What blocked you?", text: $blocked, axis: .vertical); Toggle("Today's Main Quest was correct", isOn: $correct); Stepper("Energy: \(energy) / 5", value: $energy, in: 1...5); Stepper("Day rating: \(rating) / 5", value: $rating, in: 1...5); TextField("Optional note", text: $note, axis: .vertical) }
            Button("Save review") { if store.perform({ state in
                let review = DailyReview(moved: moved, blocked: blocked, mainQuestCorrect: correct, energy: energy, rating: rating, note: note)
                if let index = state.reviews.firstIndex(where: { Calendar.current.isDateInToday($0.date) }) { state.reviews[index] = review } else { state.reviews.append(review) }
            }, success: "Review saved. Tomorrow's context is clearer.") { dismiss() } }.forgePrimary()
        }.formStyle(.grouped).navigationTitle("Close the day").onAppear { if let r = store.session.reviews.first(where: { Calendar.current.isDateInToday($0.date) }) { moved = r.moved; blocked = r.blocked; correct = r.mainQuestCorrect; energy = r.energy; rating = r.rating; note = r.note } }
    }
}

struct HealthForm: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var summary = HealthSummary()
    private func metricBinding<T>(_ path: WritableKeyPath<HealthSummary,T>, _ name: String) -> Binding<T> {
        Binding(get: { summary[keyPath:path] }, set: { value in
            summary[keyPath:path] = value
            if summary.metrics == nil { summary.metrics = [:] }
            summary.metrics![name] = HealthMetric(source:"Manual",state:.available)
        })
    }
    var body: some View {
        Form {
            Section("Today's summary") { TextField("Sleep hours", value: metricBinding(\.sleepHours, "sleepHours"), format: .number); Stepper("Steps: \(summary.steps)", value: metricBinding(\.steps, "steps"), in: 0...100_000, step: 500); Stepper("Workouts: \(summary.workouts)", value: metricBinding(\.workouts, "workouts"), in: 0...5); Stepper("Cardio: \(summary.cardioMinutes) minutes", value: metricBinding(\.cardioMinutes, "cardioMinutes"), in: 0...300, step: 5); TextField("Water · liters", value: metricBinding(\.waterLiters, "waterLiters"), format: .number); Stepper("Screen Time: \(summary.screenMinutes) minutes", value: metricBinding(\.screenMinutes, "screenMinutes"), in: 0...1440, step: 10); Stepper("Coding / deep work: \(summary.codingMinutes) minutes", value: metricBinding(\.codingMinutes, "codingMinutes"), in: 0...1440, step: 15) }
            Section("Measurement availability") { ForEach(["sleepHours","steps","workouts","cardioMinutes","weight","waterLiters","screenMinutes","codingMinutes"],id: \.self) { name in let metric = summary.metric(name); LabeledContent(name,value:"\(metric.state.rawValue) · \(metric.source)") }; Text("Change a field to record a manual measurement. Unmeasured values remain missing; an imported metric never erases an unrelated field.").font(.caption) }
            Section("Wake & body mass (optional)") {
                DatePicker("Wake time",selection:Binding(get:{summary.wakeTime ?? Date()},set:{value in summary.wakeTime=value;if summary.metrics == nil {summary.metrics=[:]};summary.metrics!["wakeTime"]=HealthMetric(source:"Manual",state:.available)}),displayedComponents:.hourAndMinute)
                TextField("Body mass · kg",value:Binding(get:{summary.weight ?? 0},set:{value in summary.weight=value > 0 ? value : nil;if summary.metrics == nil {summary.metrics=[:]};summary.metrics!["weight"]=HealthMetric(source:"Manual",state:value > 0 ? .available : .missing)}),format:.number)
                if let consistency = store.session.engine.wakeConsistency(store.session.health) { LabeledContent("Wake consistency (7 recorded days)",value:"\(consistency) / 100") } else { Text("Consistency needs at least two measured wake times.").font(.caption) }
            }
            Section("Explainable components") { ForEach(store.session.engine.healthComponents(summary).sorted(by: { $0.key < $1.key }), id: \.key) { key, value in LabeledContent(key, value: "\(value) / 100") }; Text("Activity = steps / 8,000. Sleep and recovery = hours / 8. Strength = workout recorded. Cardio = minutes / 30. These are execution summaries, not medical assessments. Saving metrics alone does not earn rewards.").font(.caption).foregroundStyle(.secondary) }
            Button("Save summary") { guard summary.sleepHours.isFinite, (0...24).contains(summary.sleepHours), summary.waterLiters.isFinite, (0...20).contains(summary.waterLiters) else { store.error = GameError.invalidInput.localizedDescription; return }; if store.perform({ $0.mergeHealth(summary) }) { dismiss() } }.forgePrimary()
            Button("Plan a rest day") { if store.perform({ try $0.planRest() }, success: "Planned rest. No health MMR loss today.") { dismiss() } }.buttonStyle(.bordered)
        }.formStyle(.grouped).navigationTitle("Health & activity").onAppear { if let s = store.session.health.first(where: { Calendar.current.isDateInToday($0.date) }) { summary = s } }
    }
}
