import SwiftUI

struct RootView: View {
    @Environment(Settings.self) private var settings
    @Environment(ChatViewModel.self) private var chat

    @State private var hasKey: Bool = (try? KeychainStore.readOpenRouterKey()) != nil
    @State private var showSettings = false

    var body: some View {
        Group {
            if hasKey || settings.demoMode {
                NavigationStack {
                    ChatView()
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button { showSettings = true } label: {
                                    Image(systemName: "gearshape.fill")
                                }
                            }
                        }
                        .sheet(isPresented: $showSettings) {
                            SettingsView(hasKey: $hasKey)
                        }
                }
            } else {
                OnboardingView(hasKey: $hasKey)
            }
        }
    }
}
