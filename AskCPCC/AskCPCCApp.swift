import SwiftUI

@main
struct AskCPCCApp: App {

    @State private var settings = Settings()
    @State private var chat = ChatViewModel()
    @State private var rag = RAGIndex()
    @State private var schedule = CourseScheduleClient()
    @State private var llm = OpenRouterClient()
    @State private var corpusUpdater = CorpusUpdater()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(settings)
                .environment(chat)
                .task {
                    await loadCorpus()
                }
                .preferredColorScheme(.light)
        }
    }

    private func loadCorpus() async {
        let dir = corpusDirectory()
        await rag.load(from: dir)

        let now = Date()
        if let last = settings.lastCorpusCheck, now.timeIntervalSince(last) < 24 * 3600 {
            return
        }
        settings.lastCorpusCheck = now
        let local = await rag.currentManifest()
        do {
            let updated = try await corpusUpdater.updateIfNewer(localManifest: local, installInto: dir)
            if updated { await rag.load(from: dir) }
        } catch {
            // silent — keep existing corpus
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
