import Foundation
import ForgeCore
import SwiftData

@MainActor enum PersistenceSmoke {
    /// Optional single-host benchmark. Timings are synchronous main-actor work,
    /// including automatic backup where the production save path performs it.
    static func benchmark() throws {
        let files = FileManager.default
        let directory = files.temporaryDirectory.appendingPathComponent("forge-storage-benchmark-\(UUID())")
        try files.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? files.removeItem(at: directory) }
        let url = directory.appendingPathComponent("benchmark.store")
        let repo = try SessionRepository(url: url)
        var state = try repo.load()
        let now = Date()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? calendar.timeZone
        state.onboard(profile: UserProfile(), now: now.addingTimeInterval(-90 * 86_400), calendar: calendar)
        for daysAgo in (0..<90).reversed() {
            state.advanceDay(now: now.addingTimeInterval(Double(-daysAgo) * 86_400), calendar: calendar)
        }
        let formatter = ISO8601DateFormatter()
        let evidence = (0..<500).map { index in
            let start = now.addingTimeInterval(Double(index - 501) * 60)
            let end = start.addingTimeInterval(60)
            return ExternalProof(id: "benchmark-\(index)", kind: "coding_session", project: "workspace-fixture",
                                 timestamp: formatter.string(from: end), start: formatter.string(from: start),
                                 end: formatter.string(from: end), minutes: 1)
        }
        try state.importEvidence(evidence, now: now, calendar: calendar)
        try repo.save(state)
        let store = try AppStore(repository: repo)
        var saveTimes: [TimeInterval] = []
        for index in 1...120 {
            let elapsed = try measure {
                try store.mutate {
                    $0.activities.append(.init(kind: .conversation, note: "Qualified buyer fixture \(index)"))
                }
            }
            saveTimes.append(elapsed)
            if [1, 30, 60, 120].contains(index) {
                let sqliteBytes = try ["", "-wal", "-shm"].reduce(0) { size, suffix in
                    let file = URL(fileURLWithPath: url.path + suffix)
                    guard files.fileExists(atPath: file.path) else { return size }
                    return try size + (file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0)
                }
                print("Storage benchmark: revisions=\(index + 1) databaseAndSidecarsBytes=\(sqliteBytes)")
            }
        }
        var reopened: SessionRepository?
        let cold = try measure { reopened = try SessionRepository(url: url); _ = try reopened?.load() }
        guard let reopened else { throw GameError.missingRecord }
        var reopenedState = state
        let warm = try measure { reopenedState = try reopened.load() }
        guard reopenedState.activities.count == 120, reopenedState.evidenceInbox.count == 500,
              try reopened.versions().count == 121, repo.backupError == nil else { throw GameError.invalidInput }
        let backup = try ForgeBackup(session: state).encoded()
        let recovery = try measure {
            try store.prepareRestore(backup)
            try store.confirmRestore()
        }
        guard try SessionRepository(url: url).load().activities.isEmpty else { throw GameError.invalidInput }
        let ordered = saveTimes.sorted()
        print("Storage benchmark: edits=120 snapshots=\(state.snapshots.count) evidence=500 backupBytes=\(backup.count) mainActorSaveP50=\(ordered[59])s mainActorSaveP95=\(ordered[113])s mainActorSaveMax=\(ordered[119])s coldLoad=\(cold)s warmLoad=\(warm)s validatedRestore=\(recovery)s")
    }

    private static func measure(_ work: () throws -> Void) rethrows -> TimeInterval {
        let start = ProcessInfo.processInfo.systemUptime
        try work()
        return ProcessInfo.processInfo.systemUptime - start
    }

    static func run() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("forge-smoke-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("test.store")
        let repo = try SessionRepository(url: url)
        var state = try repo.load(); state.onboard(profile: UserProfile())
        let quest = state.todayQuests().first!
        _ = try state.completeQuest(quest.id, proof: QuestEvidence(questID: quest.id, note: "Ten qualified outreach attempts recorded"))
        try state.addRevenue(RevenueEntry(amount: 150_000, client: "Smoke customer"))
        try state.updateSkill(state.skills[0].id, state: .verified, proof: "Tested independently implemented script")
        state.reviews.append(DailyReview(moved: "Customer contact", blocked: "", mainQuestCorrect: true, energy: 4, rating: 4))
        state.startRecovery()
        try repo.save(state)
        let revisions = try repo.versions()
        guard let revision = revisions.first,
              let automaticBackup = try FileManager.default.contentsOfDirectory(at: requireBackupDirectory(repo), includingPropertiesForKeys: nil).first,
              try Data(contentsOf: automaticBackup) == revision.payload else {
            throw NSError(domain: "FORGE storage fixture", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Automatic backup must match the committed revision envelope byte for byte"
            ])
        }
        let second = try SessionRepository(url: url)
        let restored = try second.load()
        guard restored.lifeMMR == state.lifeMMR, restored.coins == state.coins, restored.totalXP == state.totalXP, restored.todayQuests().count == 4, restored.ledger.count == state.ledger.count, restored.revenue.count == 1, restored.reviews.count == 1, restored.skillProgress.count == 1, restored.recoveries.count == 1 else { throw GameError.invalidInput }
        try second.save(restored)
        let final = try second.load()
        guard final.ledger.count == state.ledger.count else { throw GameError.invalidInput }
        // Two repository instances: stale edits fail, all branch data remains available.
        var changed = restored; changed.reviews.append(DailyReview(moved: "Independent note", blocked: "", mainQuestCorrect: true, energy: 3, rating: 3))
        try repo.save(changed)
        do { var stale = restored; stale.activities.append(BusinessActivity(kind: .conversation)); try second.save(stale); throw GameError.invalidInput }
        catch is SyncConflict { }
        // Inject a failed durable write; AppStore must retain its published balances/state.
        let failing = try SessionRepository(url: url, beforeCommit: { throw CocoaError(.fileWriteOutOfSpace) })
        let failedStore = try AppStore(repository: failing)
        let coins = failedStore.session.coins, count = failedStore.session.reviews.count
        do { try failedStore.mutate { $0.reviews.append(DailyReview(moved: "Must not persist", blocked: "", mainQuestCorrect: true, energy: 1, rating: 1)) }; throw GameError.invalidInput }
        catch let error as CocoaError { guard error.code == .fileWriteOutOfSpace else { throw error } }
        guard failedStore.session.coins == coins, failedStore.session.reviews.count == count, try failing.load().reviews.count == count else { throw GameError.invalidInput }
        // Backup -> mutate -> restore preserves original IDs and ledger, no partial apply.
        let bytes = try ForgeBackup(session: changed).encoded()
        let candidate = try ForgeBackup.restore(bytes)
        guard candidate.quests.map(\.id) == changed.quests.map(\.id), candidate.totalXP == changed.totalXP else { throw GameError.invalidInput }
        try verifyRestore(in: directory, original: state, replacement: changed)
        // True legacy schema file migration, not merely JSON round trip.
        let legacyURL = directory.appendingPathComponent("legacy.store")
        try seedLegacy(state, at: legacyURL)
        let migrated = try SessionRepository(url: legacyURL)
        let legacy = try migrated.load()
        guard legacy.profile.id == state.profile.id, Set(legacy.quests.map(\.id)) == Set(state.quests.map(\.id)), legacy.ledger.count == state.ledger.count, legacy.revenue.first?.id == state.revenue.first?.id, legacy.reviews.first?.id == state.reviews.first?.id, legacy.skillProgress.first?.id == state.skillProgress.first?.id else { throw GameError.invalidInput }
        try migrated.save(legacy)
        guard try migrated.versions().count == 1 else { throw GameError.invalidInput }
        // A failed row transaction must leave the original profile and backups intact.
        let blockedPurge = try SessionRepository(url: legacyURL, beforeCommit: { throw CocoaError(.fileWriteOutOfSpace) })
        let backupDirectory = try requireBackupDirectory(blockedPurge)
        let oldBackups = try Set(FileManager.default.contentsOfDirectory(atPath: backupDirectory.path))
        do { try blockedPurge.purgeLocal(); throw GameError.invalidInput }
        catch let error as CocoaError { guard error.code == .fileWriteOutOfSpace else { throw error } }
        guard try blockedPurge.load().profile.id == state.profile.id,
              try Set(FileManager.default.contentsOfDirectory(atPath: backupDirectory.path)) == oldBackups else { throw GameError.invalidInput }
        // Purge only this synthetic fixture; no real application data is touched.
        try migrated.purgeLocal()
        guard try migrated.context.fetch(FetchDescriptor<StoredRecord>()).isEmpty,
              try migrated.context.fetch(FetchDescriptor<StoredRevision>()).isEmpty,
              !(try migrated.load()).profile.onboarded,
              FileManager.default.fileExists(atPath: backupDirectory.path) else {
            throw NSError(domain: "FORGE storage fixture", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Committed row deletion must be observable before separate backup cleanup"
            ])
        }
        try verifyInterruptedPurge(in: directory, backupDirectory: backupDirectory)
        // An incomplete CloudKit delivery must preserve all rows and block mutation.
        let incomplete = try SessionRepository(memory: true)
        let missing = try SessionRevision(session: state, parents: [UUID()], device: "fixture")
        incomplete.context.insert(try StoredRevision(missing)); try incomplete.context.save()
        do { _ = try incomplete.load(); throw GameError.invalidInput }
        catch let error as NSError { guard error.domain == "FORGE" && error.code == 2 else { throw error } }
        // Corruption in a newer revision cannot silently expose an older state as current.
        let corrupt = try SessionRepository(url: directory.appendingPathComponent("corrupt.store"))
        _ = try corrupt.load(); try corrupt.save(state)
        let row = try StoredRevision(SessionRevision(session: state, parents: [], device: "fixture"))
        row.payload = Data("damaged fixture".utf8); corrupt.context.insert(row); try corrupt.context.save()
        do { _ = try corrupt.load(); throw GameError.invalidInput }
        catch BackupError.damaged { }
        guard corrupt.quarantinedCount == 1, try corrupt.context.fetch(FetchDescriptor<StoredRevision>()).count == 2 else { throw GameError.invalidInput }
        // Many immutable revisions: record cold load and warm read costs, no live data.
        let volumeURL = directory.appendingPathComponent("volume.store")
        let volume = try SessionRepository(url: volumeURL); var history = try volume.load()
        history.onboard(profile: UserProfile())
        for i in 0..<60 { history.reviews.append(.init(moved: "Revision fixture \(i)", blocked: "", mainQuestCorrect: true, energy: 3, rating: 3)); try volume.save(history) }
        let started = Date(), cold = try SessionRepository(url: volumeURL)
        let loaded = try cold.load(), coldTime = Date().timeIntervalSince(started)
        let warm = Date(); _ = try cold.load(); let warmTime = Date().timeIntervalSince(warm)
        guard loaded.reviews.count == 60, coldTime < 10, warmTime < 5 else { throw GameError.invalidInput }
        print("FORGE revision volume: 60 durable revisions cold=\(coldTime)s warm=\(warmTime)s")
        print("Verified disk relaunch, legacy migration, concurrent-save rejection, write rollback, backup restore and fixture purge")
    }
    private static func requireBackupDirectory(_ repository: SessionRepository) throws -> URL {
        guard let directory = repository.backupDirectory else { throw GameError.missingRecord }
        return directory
    }
    private static func verifyRestore(in directory: URL, original: GameSession, replacement: GameSession) throws {
        let restoreFolder = directory.appendingPathComponent("restore", isDirectory: true)
        try FileManager.default.createDirectory(at: restoreFolder, withIntermediateDirectories: true)
        let url = restoreFolder.appendingPathComponent("fixture.store")
        var denyCommit = false
        let repo = try SessionRepository(url: url, beforeCommit: {
            if denyCommit { throw CocoaError(.fileWriteOutOfSpace) }
        })
        _ = try repo.load()
        try repo.save(original)
        let store = try AppStore(repository: repo)
        let bytes = try ForgeBackup(session: replacement).encoded()
        try store.prepareRestore(bytes)
        denyCommit = true
        do { try store.confirmRestore(); throw GameError.invalidInput }
        catch let error as CocoaError { guard error.code == .fileWriteOutOfSpace else { throw error } }
        guard store.session.reviews.count == original.reviews.count, store.restoreCandidate != nil,
              try SessionRepository(url: url).load().reviews.count == original.reviews.count else { throw GameError.invalidInput }
        denyCommit = false
        try store.confirmRestore()
        let reopened = try SessionRepository(url: url).load()
        let copies = try FileManager.default.contentsOfDirectory(at: requireBackupDirectory(repo), includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("pre-restore-") }
        guard copies.count == 2,
              try copies.allSatisfy({ try ForgeBackup.restore(Data(contentsOf: $0)).reviews.count == original.reviews.count }),
              reopened.reviews.count == replacement.reviews.count,
              store.restoreCandidate == nil else { throw GameError.invalidInput }
        print("Verified AppStore restore rollback, preserved recovery copies and durable retry")
    }
    private static func verifyInterruptedPurge(in directory: URL, backupDirectory: URL) throws {
        let journal = LocalPurge(marker: directory.appendingPathComponent("purge-fixture.json"))
        try journal.begin(credentials: true)
        var cleanups = 0
        do {
            try journal.finish(files: [backupDirectory], remove: { _ in throw CocoaError(.fileWriteNoPermission) }) {
                cleanups += 1
            }
            throw GameError.invalidInput
        } catch let error as CocoaError { guard error.code == .fileWriteNoPermission else { throw error } }
        let reopened = LocalPurge(marker: journal.marker)
        guard try reopened.pendingCredentials() == true, cleanups == 0,
              FileManager.default.fileExists(atPath: backupDirectory.path) else { throw GameError.invalidInput }
        do {
            try reopened.finish(files: [backupDirectory]) { throw CocoaError(.fileWriteNoPermission) }
            throw GameError.invalidInput
        } catch let error as CocoaError { guard error.code == .fileWriteNoPermission else { throw error } }
        guard try reopened.pendingCredentials() == true,
              !FileManager.default.fileExists(atPath: backupDirectory.path) else { throw GameError.invalidInput }
        try reopened.finish(files: [backupDirectory]) { cleanups += 1 }
        guard try reopened.pendingCredentials() == nil, cleanups == 1 else { throw GameError.invalidInput }
        print("Verified local purge transaction rollback and journaled retry after file or secondary cleanup failure")
    }
    private static func seedLegacy(_ state: GameSession, at url: URL) throws {
        let schema = Schema([StoredRecord.self])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration("FORGE", schema: schema, url: url, cloudKitDatabase: .none))
        let context = ModelContext(container)
        let object = try JSONSerialization.jsonObject(with: ForgeBackup.encoder.encode(state)) as! [String: Any]
        let arrayNames: Set<String> = ["goals", "quests", "evidence", "ledger", "snapshots", "revenue", "customers", "activities", "skills", "skillEdges", "skillProgress", "bosses", "rewards", "redemptions", "screenRules", "bypasses", "recoveries", "reviews", "integrations", "recommendations", "seasons", "health"]
        for (name, value) in object where !["evidenceInbox", "evidenceCursor", "evidenceServerID"].contains(name) {
            if arrayNames.contains(name), let records = value as? [[String: Any]] {
                for record in records { context.insert(StoredRecord(key: "\(name)/\(record["id"] ?? UUID().uuidString)", payload: try JSONSerialization.data(withJSONObject: record))) }
            } else { context.insert(StoredRecord(key: name, payload: try JSONSerialization.data(withJSONObject: value, options: .fragmentsAllowed))) }
        }
        try context.save()
    }
}
