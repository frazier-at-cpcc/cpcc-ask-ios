import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(Settings.self) private var settings
    @Environment(ChatViewModel.self) private var chat
    @Environment(CorpusStatus.self) private var corpusStatus
    @Environment(\.ragIndex) private var rag
    @Environment(\.corpusUpdater) private var corpusUpdater
    @Binding var hasKey: Bool
    @State private var showPaste = false

    private static let lastCheckFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f
    }()

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            Form {
                SwiftUI.Section("OpenRouter API key") {
                    if hasKey {
                        Button("Replace key") { showPaste = true }
                        Button("Remove key", role: .destructive) {
                            try? KeychainStore.deleteOpenRouterKey()
                            hasKey = false
                        }
                    } else {
                        Button("Add key") { showPaste = true }
                    }
                }
                SwiftUI.Section("Model") {
                    ModelPickerView()
                }
                SwiftUI.Section("Corpus") {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(corpusStatus.state.displayName)
                            .foregroundStyle(corpusStatus.state.isReady ? Color.secondary : Color.red)
                            .font(.footnote)
                            .multilineTextAlignment(.trailing)
                    }
                    if let last = corpusStatus.lastCheck {
                        HStack {
                            Text("Last checked")
                            Spacer()
                            Text(Self.lastCheckFormatter.localizedString(for: last, relativeTo: Date()))
                                .foregroundStyle(.secondary).font(.footnote)
                        }
                    }
                    if let err = corpusStatus.lastError {
                        Text(err).font(.footnote).foregroundStyle(.red)
                    }
                    Button {
                        let dir = corpusDirectory()
                        Task {
                            await corpusStatus.refresh(rag: rag, updater: corpusUpdater,
                                                       directory: dir, force: true)
                        }
                    } label: {
                        if corpusStatus.isChecking {
                            HStack { ProgressView(); Text("Checking…") }
                        } else {
                            Text("Check for update")
                        }
                    }
                    .disabled(corpusStatus.isChecking)
                }
                SwiftUI.Section("Search live course schedule") {
                    Toggle("Enabled", isOn: $settings.searchLiveSchedule)
                }
                SwiftUI.Section("Chat") {
                    Button("Reset chat memory") {
                        chat.newChat()
                    }
                }
                SwiftUI.Section("About") {
                    NavigationLink("About Ask CPCC") { AboutView() }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showPaste) {
                ApiKeyPasteView(hasKey: $hasKey)
            }
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
