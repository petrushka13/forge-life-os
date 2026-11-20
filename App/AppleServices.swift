import Foundation
import EventKit
import UserNotifications
import ForgeCore

struct AppleCalendarService: CalendarService {
    func today() async throws -> [CalendarCommitment] {
        guard Bundle.main.object(forInfoDictionaryKey: "NSCalendarsFullAccessUsageDescription") != nil else { throw NSError(domain: "FORGE", code: 1, userInfo: [NSLocalizedDescriptionKey: "Calendar permission requires the Xcode app build. Open FORGE.xcodeproj."]) }
        let store = EKEventStore()
        let allowed = try await store.requestFullAccessToEvents()
        guard allowed else { throw NSError(domain: "FORGE", code: 2, userInfo: [NSLocalizedDescriptionKey: "Calendar permission was not granted. Manual planning remains available."]) }
        let start = Calendar.current.startOfDay(for: Date()), end = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date()))!
        return store.events(matching: store.predicateForEvents(withStart: start, end: end, calendars: nil)).filter { $0.availability != .free && $0.status != .canceled }.sorted { $0.startDate < $1.startDate }.map { CalendarCommitment(id: $0.eventIdentifier ?? UUID().uuidString, title: $0.title ?? "Commitment", start: $0.startDate, end: $0.endDate) }
    }
}

enum ForgeNotifications {
    static func enableMorning(hour: Int) async throws {
        guard Bundle.main.bundleIdentifier != nil else { throw GameError.invalidInput }
        let center = UNUserNotificationCenter.current()
        guard try await center.requestAuthorization(options: [.alert, .sound]) else { throw NSError(domain: "FORGE", code: 3, userInfo: [NSLocalizedDescriptionKey: "Notifications not authorized. Your quests remain available in the app."]) }
        guard UserDefaults.standard.bool(forKey: "forge.notifications") else { return }
        let content = UNMutableNotificationContent(); content.title = "FORGE"; content.body = "Today's Main Quest is ready."
        let trigger = UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: hour, minute: 0), repeats: true)
        try await center.add(UNNotificationRequest(identifier: "forge.morning", content: content, trigger: trigger))
        if !UserDefaults.standard.bool(forKey: "forge.notifications") {
            center.removePendingNotificationRequests(withIdentifiers: ["forge.morning"])
            center.removeDeliveredNotifications(withIdentifiers: ["forge.morning"])
        }
    }
    static func refresh(session: GameSession) async throws {
        guard UserDefaults.standard.bool(forKey:"forge.notifications") else { return }
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard UserDefaults.standard.bool(forKey: "forge.notifications") else { return }
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
        let notices = NotificationPlan.notices(session:session)
        let desired = Set(notices.map(\.id))
        let pending = await center.pendingNotificationRequests()
        guard UserDefaults.standard.bool(forKey: "forge.notifications") else { return }
        center.removePendingNotificationRequests(withIdentifiers:pending.map(\.identifier).filter { $0.hasPrefix("forge.") && $0 != "forge.morning" && !desired.contains($0) })
        var seen = UserDefaults.standard.stringArray(forKey:"forge.noticeIDs") ?? []
        let existing = Set(pending.map(\.identifier))
        for notice in notices where !existing.contains(notice.id) && !seen.contains(notice.id) {
            let content=UNMutableNotificationContent();content.title="FORGE";content.body=notice.body
            try await center.add(UNNotificationRequest(identifier:notice.id,content:content,trigger:UNTimeIntervalNotificationTrigger(timeInterval:max(1,notice.date.timeIntervalSinceNow),repeats:false)))
            guard UserDefaults.standard.bool(forKey: "forge.notifications") else {
                center.removePendingNotificationRequests(withIdentifiers: [notice.id])
                center.removeDeliveredNotifications(withIdentifiers: [notice.id])
                return
            }
            seen.append(notice.id)
        }
        UserDefaults.standard.set(Array(seen.suffix(100)),forKey:"forge.noticeIDs")
    }
    static func disable() {
        let center=UNUserNotificationCenter.current()
        Task { let pending = await center.pendingNotificationRequests(); center.removePendingNotificationRequests(withIdentifiers:pending.map(\.identifier).filter { $0.hasPrefix("forge.") }) }
    }
    static func purge() {
        guard Bundle.main.bundleIdentifier != nil else { return }
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }
}

#if os(iOS)
import HealthKit
struct AppleHealthService: HealthService {
    func summary() async throws -> HealthSummary {
        guard HKHealthStore.isHealthDataAvailable(), Capabilities.health else { throw NSError(domain: "FORGE", code: 4, userInfo: [NSLocalizedDescriptionKey: "Enable the HealthKit capability in Config/Local.xcconfig in the signed iOS build. Manual summaries are available now."]) }
        let store = HKHealthStore()
        let steps = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let sleep = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!
        let water = HKQuantityType.quantityType(forIdentifier: .dietaryWater)!
        let weight = HKQuantityType.quantityType(forIdentifier: .bodyMass)!
        let workout = HKObjectType.workoutType()
        try await store.requestAuthorization(toShare: [], read: [steps, sleep, water, weight, workout])
        let start = Calendar.current.startOfDay(for: Date()), now = Date()
        let predicate = HKQuery.predicateForSamples(withStart: start, end: now, options: .strictStartDate)
        func sum(_ type: HKQuantityType, unit: HKUnit) async throws -> Double? {
            try await withCheckedThrowingContinuation { continuation in
                let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, stats, error in if let error { continuation.resume(throwing: error) } else { continuation.resume(returning: stats?.sumQuantity()?.doubleValue(for: unit)) } }
                store.execute(query)
            }
        }
        func samples(_ type: HKSampleType, predicate: NSPredicate) async throws -> [HKSample] {
            try await withCheckedThrowingContinuation { continuation in
                let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 10000, sortDescriptors: nil) { _, result, error in if let error { continuation.resume(throwing: error) } else { continuation.resume(returning: result ?? []) } }
                store.execute(query)
            }
        }
        let stepCount = try await sum(steps, unit: .count())
        let liters = try await sum(water, unit: .liter())
        let sleepStart = start.addingTimeInterval(-12 * 3600)
        let sleepPredicate = HKQuery.predicateForSamples(withStart: sleepStart, end: now)
        let sleepSamples = try await samples(sleep, predicate: sleepPredicate)
        // Merge intervals to avoid counting duplicate watch/app sleep records twice.
        let intervals = sleepSamples.compactMap { sample -> (Date, Date)? in
            guard let category = sample as? HKCategorySample, [HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue, HKCategoryValueSleepAnalysis.asleepCore.rawValue, HKCategoryValueSleepAnalysis.asleepDeep.rawValue, HKCategoryValueSleepAnalysis.asleepREM.rawValue].contains(category.value) else { return nil }
            return (max(sleepStart, sample.startDate), min(now, sample.endDate))
        }.sorted { $0.0 < $1.0 }
        var sleepSeconds = 0.0, lastEnd = Date.distantPast
        for (a, b) in intervals where b > a { sleepSeconds += max(0, b.timeIntervalSince(max(a, lastEnd))); lastEnd = max(lastEnd, b) }
        let allWorkouts = try await samples(workout, predicate: predicate).compactMap { $0 as? HKWorkout }
        let workouts = WorkoutSample.deduplicated(allWorkouts.map { .init(start: $0.startDate, end: $0.endDate, seconds: $0.duration, kind: $0.workoutActivityType.rawValue) })
        let weights = try await samples(weight, predicate: HKQuery.predicateForSamples(withStart: start.addingTimeInterval(-30 * 86400), end: now)).compactMap { $0 as? HKQuantitySample }.sorted { $0.endDate > $1.endDate }
        let cardio = Set([HKWorkoutActivityType.running, .cycling, .swimming, .walking].map(\.rawValue))
        var summary = HealthSummary(sleepHours: sleepSeconds / 3600, steps: Int(min(1_000_000, max(0, stepCount ?? 0))), workouts: min(100, workouts.count), cardioMinutes: min(1440, Int(workouts.filter { cardio.contains($0.kind) }.reduce(0) { $0 + $1.seconds } / 60)), weight: weights.first?.quantity.doubleValue(for: .gramUnit(with: .kilo)), waterLiters: min(100,max(0,liters ?? 0)), source: "Apple Health")
        summary.wakeTime = intervals.map(\.1).max()
        summary.metrics = [:]
        for (name, available) in [("sleepHours",!intervals.isEmpty),("wakeTime",!intervals.isEmpty),("steps",stepCount != nil),("workouts",!workouts.isEmpty),("cardioMinutes",!workouts.isEmpty),("weight",!weights.isEmpty),("waterLiters",liters != nil)] {
            summary.metrics![name] = HealthMetric(source:"Apple Health",observedAt:name == "weight" ? weights.first?.endDate ?? now : now,state:available ? .available : .missing)
        }
        return summary

    }
}
#endif
