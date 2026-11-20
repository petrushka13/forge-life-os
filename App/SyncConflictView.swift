import SwiftUI
import ForgeCore
import UniformTypeIdentifiers

struct SyncConflictView: View {
    @Environment(AppStore.self) private var store
    @State private var export = false
    @State private var document = JSONDocument(data: Data())
    @State private var selected: SessionRevision?
    private var merged: GameSession? { try? SafeSessionMerge.merge(store.syncConflicts.map { try ForgeBackup.restore($0.payload) }) }
    var body: some View {
        ScreenContent {
            PageHeader(eyebrow: "YOUR DATA IS PRESERVED", title: "Review device versions", subtitle: "Several devices changed FORGE independently. Choose the version to continue with. Every version remains in history and is backed up before selection.")
            Text("Balances are not added together: the same completed quest must not earn rewards twice. Export the other version's records from the automatic conflict backup if you need to reconcile distinct work.").font(.subheadline).foregroundStyle(.secondary)
            if let merged, let first = store.syncConflicts.first { Button("Merge independent notes and references") { store.resolveSync(first, merged: merged) }.forgePrimary() }
            ForEach(store.syncConflicts) { revision in
                Card {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("\(revision.device) · \(revision.createdAt.formatted())").font(.headline)
                        if let state = try? ForgeBackup.restore(revision.payload) {
                            Text("\(state.profile.name) · \(state.totalXP) XP · \(state.coins) Coins · \(state.quests.filter { $0.status == .completed }.count) completed quests")
                            Button("Continue with this version") { selected = revision }.buttonStyle(.borderedProminent)
                            Button("Export this preserved version…") { document = JSONDocument(data: revision.payload); export = true }
                        } else { Text("This version cannot be decoded. It remains preserved for recovery.") }
                    }
                }
            }
        }
        .fileExporter(isPresented: $export, document: document, contentType: .json, defaultFilename: "FORGE-conflict-version") { result in if case .failure(let error) = result { store.error = error.localizedDescription } }
        .confirmationDialog("Continue with the selected scoring state? Other versions remain in the database and private conflict backups; their distinct work is not automatically combined.", isPresented: Binding(get: { selected != nil }, set: { if !$0 { selected = nil } })) {
            Button("Continue with selected version") { if let selected { store.resolveSync(selected) }; selected = nil }
        }
    }
}
