import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(Settings.self) private var settings
    @Environment(ChatViewModel.self) private var chat
    @Binding var hasKey: Bool
    @State private var showPaste = false

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
}
