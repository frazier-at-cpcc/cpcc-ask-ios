import SwiftUI

// MARK: - EnvironmentKeys for actor singletons
//
// SwiftUI's @Environment(Type.self) only works with @Observable classes.
// Actors aren't @Observable, so we route them through custom EnvironmentKeys
// to give every view the same shared instance.

private struct RAGIndexKey: EnvironmentKey {
    static let defaultValue = RAGIndex()
}

private struct CourseScheduleClientKey: EnvironmentKey {
    static let defaultValue = CourseScheduleClient()
}

private struct OpenRouterClientKey: EnvironmentKey {
    static let defaultValue = OpenRouterClient()
}

private struct CorpusUpdaterKey: EnvironmentKey {
    static let defaultValue = CorpusUpdater()
}

extension EnvironmentValues {
    var ragIndex: RAGIndex {
        get { self[RAGIndexKey.self] }
        set { self[RAGIndexKey.self] = newValue }
    }
    var courseScheduleClient: CourseScheduleClient {
        get { self[CourseScheduleClientKey.self] }
        set { self[CourseScheduleClientKey.self] = newValue }
    }
    var openRouterClient: OpenRouterClient {
        get { self[OpenRouterClientKey.self] }
        set { self[OpenRouterClientKey.self] = newValue }
    }
    var corpusUpdater: CorpusUpdater {
        get { self[CorpusUpdaterKey.self] }
        set { self[CorpusUpdaterKey.self] = newValue }
    }
}
