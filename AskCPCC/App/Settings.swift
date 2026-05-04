import Foundation
import Observation

@MainActor
@Observable
final class Settings {
    var modelId: String {
        didSet { UserDefaults.standard.set(modelId, forKey: "modelId") }
    }

    var searchLiveSchedule: Bool {
        didSet { UserDefaults.standard.set(searchLiveSchedule, forKey: "searchLiveSchedule") }
    }

    var demoMode: Bool {
        didSet { UserDefaults.standard.set(demoMode, forKey: "demoMode") }
    }

    var lastCorpusCheck: Date? {
        didSet {
            if let d = lastCorpusCheck {
                UserDefaults.standard.set(d, forKey: "lastCorpusCheck")
            } else {
                UserDefaults.standard.removeObject(forKey: "lastCorpusCheck")
            }
        }
    }

    init() {
        let d = UserDefaults.standard
        self.modelId = d.string(forKey: "modelId") ?? "anthropic/claude-haiku-4-5"
        self.searchLiveSchedule = d.object(forKey: "searchLiveSchedule") as? Bool ?? true
        self.demoMode = d.bool(forKey: "demoMode")
        self.lastCorpusCheck = d.object(forKey: "lastCorpusCheck") as? Date
    }
}
