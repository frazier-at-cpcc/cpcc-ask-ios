import SwiftUI

@main
struct AskCPCCApp: App {

    @State private var settings = Settings()
    @State private var chat = ChatViewModel()
    @State private var corpusStatus = CorpusStatus()
    @State private var rag = RAGIndex()
    @State private var schedule = CourseScheduleClient()
    @State private var llm = OpenRouterClient()
    @State private var corpusUpdater = CorpusUpdater()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(settings)
                .environment(chat)
                .environment(corpusStatus)
                .environment(\.ragIndex, rag)
                .environment(\.courseScheduleClient, schedule)
                .environment(\.openRouterClient, llm)
                .environment(\.corpusUpdater, corpusUpdater)
                .task {
                    await corpusStatus.refresh(
                        rag: rag,
                        updater: corpusUpdater,
                        directory: corpusDirectory(),
                        force: false)
                }
                .preferredColorScheme(.light)
        }
    }

    private func corpusDirectory() -> URL {
        let fm = FileManager.default
        let support = (try? fm.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            ?? fm.temporaryDirectory
        let dir = support.appendingPathComponent("Corpus", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
