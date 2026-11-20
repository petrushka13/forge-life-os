import SwiftUI
import Charts
import ForgeCore

struct ChartPoint: Identifiable { var id: Date { date }; var date: Date; var value: Double }
struct ProgressScreen: View {
    @Environment(AppStore.self) private var store
    @State private var range = 30
    @State private var historyLimit = 40
    @State private var metric = "Life MMR"
    private let metrics = ["Life MMR", "Business MMR", "Builder MMR", "Health MMR", "Revenue", "Main completion", "Deep work", "Screen Time", "Sleep", "Workouts"]
    private var since: Date { if range == 3650 { return .distantPast }; return Calendar.current.date(byAdding: .day, value: -(range - 1), to: Calendar.current.startOfDay(for: Date()))! }
    private var points: [ChartPoint] {
        let state = store.session
        if ["Sleep", "Screen Time", "Deep work", "Workouts"].contains(metric) {
            return state.health.filter { $0.date >= since && $0.metric(metric == "Sleep" ? "sleepHours" : metric == "Screen Time" ? "screenMinutes" : metric == "Deep work" ? "codingMinutes" : "workouts", now:$0.date).state != .missing }.sorted { $0.date < $1.date }.map { record in
                let value: Double = switch metric { case "Sleep": record.sleepHours; case "Screen Time": Double(record.screenMinutes) / 60; case "Deep work": Double(record.codingMinutes) / 60; default: Double(record.workouts) }
                return ChartPoint(date: record.date, value: value)
            }
        }
        return state.snapshots.filter { $0.date >= since }.sorted { $0.date < $1.date }.compactMap { snapshot in
            let value: Double
            switch metric {
            case "Revenue": value = state.monthlyRevenue(now: Calendar.current.date(byAdding: .day, value: 1, to: snapshot.date)!.addingTimeInterval(-1))
            case "Main completion": let main = state.quests.filter { Calendar.current.isDate($0.deadline, inSameDayAs: snapshot.date) && $0.priority == .main && $0.type != .recovery && $0.status != .archived }; if main.isEmpty { return nil }; value = Double(main.filter { $0.status == .completed }.count) / Double(main.count) * 100
            case "Business MMR": value = Double(snapshot.ratings[.business, default: 1000])
            case "Builder MMR": value = Double(snapshot.ratings[.builder, default: 1000])
            case "Health MMR": value = Double(snapshot.ratings[.health, default: 1000])
            default: value = Double(state.engine.lifeMMR(snapshot.ratings))
            }
            return ChartPoint(date: snapshot.date, value: value)
        }
    }
    private var yDomain: ClosedRange<Double> {
        let low = points.map(\.value).min() ?? 0, high = points.map(\.value).max() ?? 1
        let margin = max(1, (high - low) * 0.15)
        return max(0, low - margin)...(high + margin)
    }
    private var xDomain: ClosedRange<Date> {
        let start = Calendar.current.startOfDay(for: points.first?.date ?? Date())
        let end = Calendar.current.date(byAdding: .day, value: 1, to: points.last?.date ?? Date())!
        return start...max(end, start.addingTimeInterval(86400))
    }
    var body: some View {
        ScreenContent {
            PageHeader(eyebrow: "EVIDENCE OF CHANGE", title: "Progress you can prove.", subtitle: "Your rating is a signal. Real-world results are the point.")
            Picker("Time range", selection: $range) { Text("Today").tag(1); Text("7 days").tag(7); Text("30 days").tag(30); Text("90 days").tag(90); Text("All").tag(3650) }.pickerStyle(.segmented)
            Card { VStack(alignment: .leading, spacing: 20) { HStack { Eyebrow(title: "Execution trend"); Spacer(); Picker("Metric", selection: $metric) { ForEach(metrics, id: \.self) { Text($0) } }.labelsHidden() }
                if points.isEmpty { ContentUnavailableView("No measurements yet", systemImage: "chart.xyaxis.line", description: Text("Record health/activity summaries or complete quests to build an honest history.")) }
                else { HStack(alignment: .firstTextBaseline) { Text((points.last?.value ?? 0).formatted(.number.precision(.fractionLength(metric == "Sleep" || metric == "Screen Time" || metric == "Deep work" ? 1 : 0)))).font(.system(size: 42, weight: .semibold, design: .rounded)).monospacedDigit(); Text(unit).font(.caption).foregroundStyle(.secondary) }; if points.count > 1 { Chart(Array(points.suffix(365))) { point in AreaMark(x: .value("Date", point.date), yStart: .value("Chart baseline", yDomain.lowerBound), yEnd: .value(metric, point.value)).foregroundStyle(LinearGradient(colors: [ForgeStyle.accent.opacity(0.22), ForgeStyle.accent.opacity(0.01)], startPoint: .top, endPoint: .bottom)); LineMark(x: .value("Date", point.date), y: .value(metric, point.value)).foregroundStyle(ForgeStyle.accent).lineStyle(StrokeStyle(lineWidth: 2.5)); PointMark(x: .value("Date", point.date), y: .value(metric, point.value)).foregroundStyle(ForgeStyle.accent).symbolSize(points.count > 12 ? 8 : 35) }.chartYScale(domain: yDomain).chartXScale(domain: xDomain).chartYAxis { AxisMarks(position: .leading) }.frame(height: 240).clipped().accessibilityLabel("\(metric) history, \(points.count) recorded measurements") } else {
                    VStack(spacing: 18) {
                        Spacer()
                        Circle().fill(ForgeStyle.accent).frame(width: 10, height: 10)
                        Text("First measurement · \(points[0].date.formatted(date: .abbreviated, time: .omitted))").font(.caption).foregroundStyle(.secondary)
                        Text("Your trend starts with the next recorded day.").font(.caption2).foregroundStyle(.secondary)
                        Spacer()
                    }.frame(maxWidth: .infinity).frame(height: 200).accessibilityLabel("One recorded \(metric) measurement")
                } }
            } }
            if ["Sleep","Screen Time","Deep work","Workouts"].contains(metric), let last = store.session.health.last { Text("Latest summary: \(last.date.formatted(date: .abbreviated,time:.omitted)) · Values older than 48 hours are stale.").font(.caption).foregroundStyle(.secondary) }
            comparisons
            roi
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 190))], spacing: 12) { ForEach(store.session.streaks()) { streak in Metric(label: streak.title, value: "\(streak.current) days", footnote: "Best \(streak.best) days", symbol: "flame") } }
            let trophies = store.session.bosses.filter { boss in store.session.quests.contains { $0.id == boss.questID && $0.status == .completed } }
            if !trophies.isEmpty { Card { VStack(alignment: .leading, spacing: 12) { Eyebrow(title: "Boss trophies"); ForEach(trophies) { trophy in if let quest = store.session.quests.first(where: { $0.id == trophy.questID }) { Label(quest.title, systemImage: "trophy").font(.subheadline) } } } } }
            Card { VStack(alignment: .leading, spacing: 14) { HStack { Eyebrow(title: "Transaction history"); Spacer(); Text("Append-only").font(.caption2).foregroundStyle(.secondary) }; if store.session.ledger.isEmpty { Text("Your first completed quest creates the first entry.").foregroundStyle(.secondary) }; ForEach(store.session.ledger.sorted { $0.timestamp > $1.timestamp }.prefix(historyLimit)) { entry in HStack(alignment: .top) { VStack(alignment: .leading, spacing: 4) { Text(entry.reason).font(.subheadline).lineLimit(2); Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened)).font(.caption2).foregroundStyle(.secondary) }; Spacer(); Text("\(entry.amount >= 0 ? "+" : "")\(entry.amount) \(entry.kind == .mmr ? (entry.domain?.title ?? "") + " MMR" : entry.kind == .xp ? "XP" : "Coins")").font(.caption.weight(.semibold)).foregroundStyle(entry.amount >= 0 ? ForgeStyle.green : ForgeStyle.accent).monospacedDigit() } }; if store.session.ledger.count > historyLimit { Button("Show earlier transactions") { historyLimit += 40 }.buttonStyle(.bordered) } } }
        }
    }
    private var unit: String { switch metric { case "Revenue": "KZT / month"; case "Sleep", "Screen Time", "Deep work": "hours"; case "Main completion": "%"; case "Workouts": "workouts"; default: "MMR" } }
    private var comparisons: some View {
        let then = Date().addingTimeInterval(-30 * 86400)
        let old = store.session.snapshots.last { $0.date <= then }
        let oldHealth = store.session.health.last { $0.date <= then }
        let health = store.session.health.last
        return Card { VStack(alignment: .leading, spacing: 16) { Eyebrow(title: "30 days ago → today"); comparison("Monthly revenue", old: old == nil ? "—" : ForgeStyle.money(store.session.monthlyRevenue(now: then)), current: ForgeStyle.money(store.session.monthlyRevenue()) + " KZT"); comparison("Builder MMR", old: old.map { "\($0.ratings[.builder, default: 1000])" } ?? "—", current: "\(store.session.ratings[.builder, default: 1000])"); comparison("Screen Time", old: oldHealth.flatMap { $0.metric("screenMinutes",now:$0.date).state == .missing ? nil : "\($0.screenMinutes) min" } ?? "—", current: health.flatMap { $0.metric("screenMinutes").state == .missing ? nil : "\($0.screenMinutes) min · \($0.metric("screenMinutes").state.rawValue)" } ?? "—"); comparison("Sleep", old: oldHealth.flatMap { $0.metric("sleepHours",now:$0.date).state == .missing ? nil : $0 }.map { "\($0.sleepHours.formatted(.number.precision(.fractionLength(1)))) h" } ?? "—", current: health.flatMap { $0.metric("sleepHours").state == .missing ? nil : $0 }.map { "\($0.sleepHours.formatted(.number.precision(.fractionLength(1)))) h" } ?? "—"); if old == nil { Text("Thirty-day comparisons appear after real history exists.").font(.caption).foregroundStyle(.secondary) } } }
    }
    private func comparison(_ title: String, old: String, current: String) -> some View { HStack { Text(title).font(.subheadline); Spacer(); Text(old).foregroundStyle(.secondary); Image(systemName: "arrow.right").foregroundStyle(.tertiary); Text(current).fontWeight(.semibold) }.font(.subheadline).monospacedDigit() }
    private var roi: some View {
        let session = store.session
        let activities = session.activities.filter { $0.date >= since }
        let measuredCoding = session.health.filter { $0.date >= since && $0.metric("codingMinutes",now:$0.date).state == .available }
        let hours = Double(measuredCoding.reduce(0) { $0 + $1.codingMinutes }) / 60
        return Card { VStack(alignment: .leading, spacing: 18) { Eyebrow(title: "Real life ROI"); HStack(alignment: .top, spacing: 20) { VStack(alignment: .leading, spacing: 10) { Text("TIME INVESTED").font(.caption2).foregroundStyle(.secondary); Text(measuredCoding.isEmpty ? "— h" : "\(hours.formatted(.number.precision(.fractionLength(1)))) h").font(.title2.weight(.semibold)); Text("Logged deep work").font(.caption).foregroundStyle(.secondary) }; Spacer(); Image(systemName: "arrow.right").foregroundStyle(ForgeStyle.accent); VStack(alignment: .leading, spacing: 10) { Text("OUTPUT CREATED").font(.caption2).foregroundStyle(.secondary); Text("\(activities.filter { $0.kind == .shipped }.reduce(0) { $0 + $1.count }) shipped").font(.headline); Text("\(activities.filter { $0.kind == .outreach }.reduce(0) { $0 + $1.count }) outreach").font(.caption).foregroundStyle(.secondary) } }.frame(maxWidth: .infinity, alignment: .leading); Divider(); HStack { VStack(alignment: .leading, spacing: 6) { Text("REAL RESULTS").font(.caption2).foregroundStyle(.secondary); Text("\(activities.filter { $0.kind == .conversation }.reduce(0) { $0 + $1.count }) conversations · \(session.customers.filter { $0.stage == "Paying customer" }.count) customers").font(.subheadline) }; Spacer() }; Text("\(ForgeStyle.money(session.revenue.filter { $0.currency == "KZT" && $0.date >= since }.reduce(0) { $0 + $1.amount })) KZT received").font(.title2.weight(.semibold)).foregroundStyle(ForgeStyle.accent) } }
    }
}
