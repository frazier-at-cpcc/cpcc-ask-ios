import Foundation
import Observation

@MainActor
@Observable
final class CorpusStatus {

    enum State: Equatable {
        case loading
        case ready(version: String, totalChunks: Int)
        case unavailable(reason: String)

        var displayName: String {
            switch self {
            case .loading: return "Loading…"
            case .ready(let v, let n): return "Ready — \(v), \(n) chunks"
            case .unavailable(let r): return "Unavailable — \(r)"
            }
        }

        var isReady: Bool {
            if case .ready = self { return true }
            return false
        }
    }

    var state: State = .loading
    var lastCheck: Date?
    var isChecking: Bool = false
    var lastError: String?

    /// Loads the corpus from disk and (optionally) runs an update check.
    /// `force=true` skips the 24h guard — used by the manual "Check for update" button.
    func refresh(rag: RAGIndex,
                 updater: CorpusUpdater,
                 directory: URL,
                 force: Bool) async {
        guard !isChecking else { return }
        isChecking = true
        defer { isChecking = false }
        lastError = nil

        await rag.load(from: directory)
        let initialManifest = await rag.currentManifest()
        let initialState = await rag.state
        apply(state: initialState, manifest: initialManifest)

        let now = Date()
        if !force, let last = lastCheck, now.timeIntervalSince(last) < 24 * 3600 {
            return
        }

        do {
            let updated = try await updater.updateIfNewer(
                localManifest: initialManifest,
                installInto: directory)
            lastCheck = now
            UserDefaults.standard.set(now, forKey: "corpusStatus.lastCheck")
            if updated {
                await rag.load(from: directory)
                let newManifest = await rag.currentManifest()
                let newState = await rag.state
                apply(state: newState, manifest: newManifest)
            }
        } catch {
            lastError = "\(error)"
        }
    }

    private func apply(state ragState: RAGIndex.State, manifest: CorpusStore.Manifest?) {
        switch ragState {
        case .unloaded:
            state = .loading
        case .ready:
            if let m = manifest {
                state = .ready(version: m.version, totalChunks: m.totalChunks)
            } else {
                state = .unavailable(reason: "manifest missing")
            }
        case .unavailable(let reason):
            state = .unavailable(reason: reason)
        }
    }

    init() {
        self.lastCheck = UserDefaults.standard.object(forKey: "corpusStatus.lastCheck") as? Date
    }
}
