import Foundation

public struct WorkoutSample: Sendable {
    public var start: Date; public var end: Date; public var seconds: Double; public var kind: UInt
    public init(start: Date, end: Date, seconds: Double, kind: UInt) { self.start = start; self.end = end; self.seconds = seconds; self.kind = kind }
    public static func deduplicated(_ samples: [Self]) -> [Self] {
        var result: [Self] = []
        for sample in samples.sorted(by: { $0.start < $1.start }) where sample.end > sample.start && sample.seconds.isFinite && sample.seconds >= 0 {
            if let index = result.lastIndex(where: { old in
                guard old.kind == sample.kind else { return false }
                let overlap = min(old.end, sample.end).timeIntervalSince(max(old.start, sample.start))
                return overlap > 0.8 * min(old.end.timeIntervalSince(old.start), sample.end.timeIntervalSince(sample.start))
            }) { if sample.seconds > result[index].seconds { result[index] = sample } }
            else { result.append(sample) }
        }
        return result
    }
}

extension HealthSummary {
    public func metric(_ name: String, now: Date = Date()) -> HealthMetric {
        if var metric = metrics?[name] {
            if metric.state == .available && now.timeIntervalSince(metric.observedAt) > 48 * 3600 { metric.state = .stale }
            return metric
        }
        // Legacy zero defaults are unknown, rather than fabricated measurements.
        let positive: Bool
        switch name {
        case "sleepHours": positive = sleepHours > 0
        case "steps": positive = steps > 0
        case "workouts": positive = workouts > 0
        case "cardioMinutes": positive = cardioMinutes > 0
        case "weight": positive = weight != nil
        case "waterLiters": positive = waterLiters > 0
        case "screenMinutes": positive = screenMinutes > 0
        case "codingMinutes": positive = codingMinutes > 0
        case "wakeTime": positive = wakeTime != nil
        default: positive = false
        }
        return HealthMetric(source: source, observedAt: date, state: positive ? (now.timeIntervalSince(date) > 48 * 3600 ? .stale : .available) : .missing)
    }
}
extension GameSession {
    public mutating func mergeHealth(_ incoming: HealthSummary, calendar: Calendar = .current) {
        guard let index = health.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: incoming.date) }) else { health.append(incoming); return }
        var current = health[index]
        for name in ["sleepHours", "steps", "workouts", "cardioMinutes", "weight", "waterLiters", "screenMinutes", "codingMinutes", "wakeTime"] {
            let next = incoming.metric(name, now: incoming.date)
            guard next.state == .available else { continue }
            let old = current.metric(name, now: incoming.date)
            // Automatic refresh never overwrites a deliberately entered manual metric.
            guard old.state != .available || old.source != "Manual" || next.source == "Manual" else { continue }
            switch name {
            case "sleepHours": current.sleepHours = incoming.sleepHours
            case "steps": current.steps = incoming.steps
            case "workouts": current.workouts = incoming.workouts
            case "cardioMinutes": current.cardioMinutes = incoming.cardioMinutes
            case "weight": current.weight = incoming.weight
            case "waterLiters": current.waterLiters = incoming.waterLiters
            case "screenMinutes": current.screenMinutes = incoming.screenMinutes
            case "codingMinutes": current.codingMinutes = incoming.codingMinutes
            case "wakeTime": current.wakeTime = incoming.wakeTime
            default: break
            }
            if current.metrics == nil { current.metrics = [:] }
            current.metrics![name] = next
        }
        health[index] = current // Preserve stable daily identity and unrelated metrics.
    }
}
