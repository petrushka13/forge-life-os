import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import ForgeCore

struct StorageRecoveryView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    @State private var importing = false
    @State private var confirm = false
    @State private var exporting = false
    @State private var confirmPurgeRetry = false
    @State private var document = JSONDocument(data: Data())
    var body: some View {
        ContentUnavailableView {
            Label(store.purgePending ? "Local purge interrupted" : "Your data needs attention", systemImage: "externaldrive.badge.exclamationmark")
        } description: {
            Text(store.purgePending
                 ? (store.launchError ?? "Local purge did not finish.")
                 : "Storage could not be opened. Existing data is preserved.\n\(store.launchError ?? "Unknown storage error")")
        } actions: {
            if store.purgePending {
                Button("Retry local purge…", role: .destructive) { confirmPurgeRetry = true }
            } else {
                Button("Retry") { store.retryStorage() }
            }
            Button("Export recovery copy…") {
                do { document = JSONDocument(data: try store.recoveryCopy()); exporting = true }
                catch { store.error = error.localizedDescription }
            }
            if !store.purgePending {
                Button("Restore validated backup…") { importing = true }
                Text("Restore uses a fresh local store and preserves the damaged original. Credentials are excluded from recovery copies. Keep exports private.").font(.caption)
            }
        }
        .confirmationDialog("Finish purging the remaining local data?", isPresented: $confirmPurgeRetry) {
            Button("Finish local purge", role: .destructive) {
                do { try store.retryLocalPurge(); router.sheet = .onboarding }
                catch { store.error = error.localizedDescription }
            }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            do {
                let url = try result.get(), scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                guard (try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) <= ForgeBackup.maximumBytes else { throw BackupError.tooLarge }
                try store.prepareRestore(Data(contentsOf: url)); confirm = true
            } catch { store.error = error.localizedDescription }
        }
        .confirmationDialog("Restore into a fresh local store? The damaged original is retained for recovery.", isPresented: $confirm) {
            Button("Restore") { do { if let candidate = store.restoreCandidate { try store.recoverStorage(candidate) }; store.restoreCandidate = nil } catch { store.error = error.localizedDescription } }
            Button("Cancel", role: .cancel) { store.restoreCandidate = nil }
        }
        .fileExporter(isPresented: $exporting, document: document, contentType: .json, defaultFilename: "FORGE-private-recovery") { result in if case .failure(let error) = result { store.error = error.localizedDescription } }
    }
}
