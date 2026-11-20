import Foundation
import SwiftData
import CoreData
import Observation
import ForgeCore

@Model final class StoredRecord {
    var id: UUID = UUID()
    var key: String = ""
    var payload: Data = Data()
    var version: Int = 1
    init(key: String, payload: Data) { self.key = key; self.payload = payload }
}

@Model final class StoredRevision {
    var revisionID: UUID = UUID()
    var payload: Data = Data()
    init(_ revision: SessionRevision) throws { revisionID = revision.id; payload = try JSONEncoder().encode(revision) }
}

struct SyncConflict: Error, LocalizedError {
    let versions: [SessionRevision]
    var errorDescription: String? { BackupError.conflict.localizedDescription }
}

/// The marker lives beside the owned directory, so it survives deletion of that
/// directory. Retry is explicit and every cleanup step can be repeated.
struct LocalPurge {
    let marker: URL

    func pendingCredentials() throws -> Bool? {
        do { return try JSONDecoder().decode(Bool.self, from: Data(contentsOf: marker)) }
        catch let error as CocoaError where error.code == .fileReadNoSuchFile || error.code == .fileNoSuchFile { return nil }
    }

    func begin(credentials: Bool) throws {
        try FileManager.default.createDirectory(at: marker.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(credentials).write(to: marker, options: .atomic)
    }

    func clear() throws { try Self.remove(marker) }

    func finish(
        files: [URL],
        remove: (URL) throws -> Void = Self.remove,
        cleanup: () throws -> Void
    ) throws {
        for file in files { try remove(file) }
        try cleanup()
        try clear()
    }

    static func remove(_ url: URL) throws {
        do { try FileManager.default.removeItem(at: url) }
        catch let error as CocoaError where error.code == .fileReadNoSuchFile || error.code == .fileNoSuchFile { }
    }
}

@MainActor @Observable final class SessionRepository {
    let container: ModelContainer
    let context: ModelContext
    private(set) var syncMessage: String
    private var observer: NSObjectProtocol?
    private var cloudActive = false
    var canPurgeLocally: Bool { !cloudActive }
    private(set) var quarantinedCount = 0
    let storageURL: URL?
    let beforeCommit: (() throws -> Void)?
    private var currentHeads: [UUID] = []
    private var lastPayload: Data?
    private var checkedRevisions: [UUID: (Data, SessionRevision)] = [:]
    let backupDirectory: URL?
    private(set) var backupError: String?
    init(memory: Bool = false, url: URL? = nil, cloud: Bool = false, beforeCommit: (() throws -> Void)? = nil) throws {
        self.beforeCommit = beforeCommit
        let schema = Schema([StoredRecord.self, StoredRevision.self])
        backupDirectory = memory ? nil : (url?.deletingLastPathComponent() ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("FORGE", isDirectory: true)).appendingPathComponent("Backups", isDirectory: true)
        let configuration: ModelConfiguration
        if let url { configuration = ModelConfiguration("FORGE", schema: schema, url: url, cloudKitDatabase: .none) }
        else { configuration = ModelConfiguration("FORGE", schema: schema, isStoredInMemoryOnly: memory, cloudKitDatabase: cloud && !memory ? .private(Bundle.main.object(forInfoDictionaryKey: "ForgeCloudContainer") as? String ?? "iCloud.com.personal.FORGE") : .none) }
        storageURL = memory ? nil : configuration.url
        do {
            container = try ModelContainer(for: schema, configurations: configuration)
            syncMessage = cloud && !memory ? "CloudKit configured. Server delivery is system-managed; concurrent edits require version review." : "Local storage · works offline"
        } catch {
            if cloud && !memory {
                let fallback = ModelConfiguration("FORGE", schema: schema, cloudKitDatabase: .none)
                container = try ModelContainer(for: schema, configurations: fallback)
                syncMessage = "iCloud unavailable. Local storage is active. \(error.localizedDescription)"
            } else { throw error }
        }
        context = ModelContext(container); context.autosaveEnabled = false
        cloudActive = cloud && !memory && !syncMessage.contains("unavailable")
        if cloudActive {
            observer = NotificationCenter.default.addObserver(forName: NSPersistentCloudKitContainer.eventChangedNotification, object: nil, queue: .main) { [weak self] notification in
                guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey] as? NSPersistentCloudKitContainer.Event else { return }
                let finished = event.endDate != nil, succeeded = event.succeeded, exported = event.type == .export
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if !finished { self.syncMessage = "Saved locally · Pending sync" }
                    else if !succeeded { self.syncMessage = "Saved locally · Sync failed. Check iCloud account, network and storage; local records remain usable." }
                    else if exported { self.syncMessage = "Synced · CloudKit export completed. Other-device receipt still requires verification." }
                }
            }
        }
    }
    func versions() throws -> [SessionRevision] {
        // A fresh context observes remote imports rather than cached envelope objects.
        let fresh = ModelContext(container)
        quarantinedCount = 0
        var valid: [UUID: SessionRevision] = [:]
        var rejected = Set<UUID>()
        let records = try fresh.fetch(FetchDescriptor<StoredRevision>())
        for record in records {
            do {
                let revision: SessionRevision
                if let cached = checkedRevisions[record.revisionID], cached.0 == record.payload { revision = cached.1 }
                else {
                    revision = try JSONDecoder().decode(SessionRevision.self, from: record.payload)
                    _ = try ForgeBackup.restore(revision.payload)
                }
                guard revision.id == record.revisionID, !revision.parents.contains(revision.id) else { throw BackupError.damaged }
                guard !rejected.contains(revision.id) else { throw BackupError.damaged }
                if let previous = valid[revision.id], try ForgeBackup.encoder.encode(previous) != ForgeBackup.encoder.encode(revision) { throw BackupError.damaged }
                valid[revision.id] = revision
                checkedRevisions[revision.id] = (record.payload, revision)
            } catch {
                // Keep the original row intact. A private quarantine copy permits inspection.
                quarantinedCount += 1
                rejected.insert(record.revisionID); valid.removeValue(forKey: record.revisionID); checkedRevisions.removeValue(forKey: record.revisionID)
                if let directory = backupDirectory {
                    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
                    let file = directory.appendingPathComponent("corrupt-\(record.revisionID).json")
                    try record.payload.write(to: file, options: .atomic)
                    try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
                }
            }
        }
        if !records.isEmpty && valid.isEmpty { throw BackupError.damaged }
        return Array(valid.values)

    }
    func load() throws -> GameSession {
        let all = try versions()
        // Never silently roll back to an older valid head after a newer row corrupts.
        guard quarantinedCount == 0 else { throw BackupError.damaged }
        let known = Set(all.map(\.id))
        guard all.allSatisfy({ Set($0.parents).isSubset(of: known) }) else { throw NSError(domain: "FORGE", code: 2, userInfo: [NSLocalizedDescriptionKey: "Revision delivery is incomplete. Retry after iCloud imports finish, or restore a validated backup. All versions were preserved."]) }
        let byID = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
        var visiting = Set<UUID>(), visited = Set<UUID>()
        func check(_ id: UUID) throws {
            guard !visiting.contains(id) else { throw BackupError.damaged }
            if visited.contains(id) { return }
            visiting.insert(id)
            for parent in byID[id]?.parents ?? [] { try check(parent) }
            visiting.remove(id); visited.insert(id)
        }
        for revision in all { try check(revision.id) }
        let heads = SessionRevision.heads(in: all)
        guard all.isEmpty || !heads.isEmpty else { throw BackupError.damaged }
        if heads.count > 1 { throw SyncConflict(versions: heads) }
        if let head = heads.first {
            let result = try ForgeBackup.restore(head.payload)
            currentHeads = [head.id]; lastPayload = try ForgeBackup.encoder.encode(result)
            return result
        }
        let result = try loadLegacy()
        try result.validateForStorage()
        lastPayload = try context.fetch(FetchDescriptor<StoredRecord>()).isEmpty ? ForgeBackup.encoder.encode(result) : nil
        return result
    }
    private func loadLegacy() throws -> GameSession {
        let records = try context.fetch(FetchDescriptor<StoredRecord>())
        if records.isEmpty { return GameSession() }
        guard records.allSatisfy({ $0.version == 1 }) else { throw GameError.invalidInput }
        // Arrays contain stable per-record identities; dictionaries/configuration are single records.
        var json: [String: Any] = [:]
        let arrays: Set<String> = ["goals", "quests", "evidence", "ledger", "snapshots", "revenue", "customers", "activities", "skills", "skillEdges", "skillProgress", "bosses", "rewards", "redemptions", "screenRules", "bypasses", "recoveries", "reviews", "integrations", "recommendations", "seasons", "health"]
        for name in arrays {
            json[name] = try records.filter { $0.key.hasPrefix(name + "/") }.sorted { $0.key < $1.key }.map { try JSONSerialization.jsonObject(with: $0.payload, options: .fragmentsAllowed) }
        }
        for record in records where !record.key.contains("/") { json[record.key] = try JSONSerialization.jsonObject(with: record.payload, options: .fragmentsAllowed) }
        let data = try JSONSerialization.data(withJSONObject: json)
        var result = try JSONDecoder().decode(GameSession.self, from: data)
        result.quests.sort { $0.createdAt < $1.createdAt }; result.ledger.sort { $0.timestamp < $1.timestamp }
        result.snapshots.sort { $0.date < $1.date }; result.health.sort { $0.date < $1.date }; result.reviews.sort { $0.date < $1.date }
        guard result.config.isValid, result.totalXP >= 0, result.coins >= 0 else { throw GameError.invalidConfiguration }
        return result
    }
    func save(_ session: GameSession) throws {
        let prepared = try SessionRevision.forSave(session: session, parents: currentHeads, device: deviceName, unlessMatching: lastPayload)
        let heads = SessionRevision.heads(in: try versions())
        guard quarantinedCount == 0 else { throw BackupError.damaged }
        guard Set(heads.map(\.id)) == Set(currentHeads) else { throw SyncConflict(versions: heads) }
        guard let (revision, payload) = prepared else { return }
        do { context.insert(try StoredRevision(revision)); try beforeCommit?(); try context.save() }
        catch { context.rollback(); throw error }
        currentHeads = [revision.id]; lastPayload = payload
        if cloudActive { syncMessage = "Saved locally · Pending sync" }
        writeBackup { revision.payload }
    }
    func resolve(_ selected: SessionRevision, merged: GameSession? = nil) throws -> GameSession {
        let heads = SessionRevision.heads(in: try versions())
        guard heads.contains(where: { $0.id == selected.id }) else { throw BackupError.conflict }
        let session = try merged ?? ForgeBackup.restore(selected.payload)
        // Preserve every branch in both the database and portable backup files before resolving.
        if let backupDirectory {
            try FileManager.default.createDirectory(at: backupDirectory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            for head in heads { let file = backupDirectory.appendingPathComponent("conflict-\(head.id).json"); try head.payload.write(to: file, options: .atomic); try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path) }
        }
        let revision = try SessionRevision(session: session, parents: heads.map(\.id), device: deviceName)
        do { context.insert(try StoredRevision(revision)); try beforeCommit?(); try context.save() }
        catch { context.rollback(); throw error }
        currentHeads = [revision.id]; lastPayload = try ForgeBackup.encoder.encode(session)
        writeBackup { revision.payload }
        return session
    }
    func backup(_ session: GameSession, preserving: Bool = false) {
        writeBackup(preserving: preserving) { try ForgeBackup(session: session).encoded() }
    }
    private func writeBackup(preserving: Bool = false, bytes: () throws -> Data) {
        guard let backupDirectory else { return }
        do {
            try FileManager.default.createDirectory(at: backupDirectory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            let file = backupDirectory.appendingPathComponent("\(preserving ? "pre-restore" : "automatic")-\(UUID()).json")
            try bytes().write(to: file, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
            let files = try FileManager.default.contentsOfDirectory(at: backupDirectory, includingPropertiesForKeys: [.contentModificationDateKey]).filter { $0.lastPathComponent.hasPrefix("automatic-") }.sorted { (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? .distantPast) ?? .distantPast > (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? .distantPast) ?? .distantPast }
            for old in files.dropFirst(7) { try FileManager.default.removeItem(at: old) }
            backupError = nil
        } catch { backupError = "Records saved, but automatic backup failed: \(error.localizedDescription)" }
    }
    func purgeLocal() throws {
        // Row deletion is one transaction. AppStore owns subsequent file and OS cleanup.
        guard canPurgeLocally else { throw GameError.invalidConfiguration }
        do {
            for row in try context.fetch(FetchDescriptor<StoredRevision>()) { context.delete(row) }
            for row in try context.fetch(FetchDescriptor<StoredRecord>()) { context.delete(row) }
            try beforeCommit?(); try context.save()
        } catch { context.rollback(); throw error }
        currentHeads = []; lastPayload = nil; checkedRevisions.removeAll()
    }
    func exportRecoveryArchive() throws -> Data {
        struct Row: Codable { let kind: String; let id: UUID; let data: Data }
        let rows = try context.fetch(FetchDescriptor<StoredRevision>()).map { Row(kind: "revision", id: $0.revisionID, data: $0.payload) } + context.fetch(FetchDescriptor<StoredRecord>()).map { Row(kind: "legacy", id: $0.id, data: $0.payload) }
        return try ForgeBackup.encoder.encode(rows)
    }
    func restoreAfterLaunchFailure(_ candidate: GameSession) throws {
        try candidate.validateForStorage()
        // Preserve every readable row even if its payload cannot decode.
        if let backupDirectory {
            try FileManager.default.createDirectory(at: backupDirectory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            let file = backupDirectory.appendingPathComponent("pre-recovery-\(UUID()).json")
            try exportRecoveryArchive().write(to: file, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
        }
        let parents = try context.fetch(FetchDescriptor<StoredRevision>()).map(\.revisionID)
        let revision = try SessionRevision(session: candidate, parents: parents, device: deviceName)
        do { context.insert(try StoredRevision(revision)); try beforeCommit?(); try context.save() }
        catch { context.rollback(); throw error }
        currentHeads = [revision.id]; lastPayload = try ForgeBackup.encoder.encode(candidate)
        writeBackup { revision.payload }
    }
    private var deviceName: String {
        #if os(macOS)
        "Mac"
        #else
        "iPhone / iPad"
        #endif
    }
}
