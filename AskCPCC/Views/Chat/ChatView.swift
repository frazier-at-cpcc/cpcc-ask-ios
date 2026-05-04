import SwiftUI

struct ChatView: View {
    @Environment(Settings.self) private var settings
    @Environment(ChatViewModel.self) private var chat

    var body: some View {
        VStack(spacing: 0) {
            if settings.demoMode && (try? KeychainStore.readOpenRouterKey()) == nil {
                Text("Demo mode — add an OpenRouter key in Settings to use real questions.")
                    .font(CPCCFonts.chip).foregroundStyle(.white)
                    .padding(8).frame(maxWidth: .infinity)
                    .background(CPCCColors.gold)
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(chat.turns) { turn in
                            MessageBubble(turn: turn).id(turn.id)
                        }
                    }
                    .padding(16)
                }
                .onChange(of: chat.turns.count) { _, _ in
                    if let last = chat.turns.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            if let err = chat.lastError {
                ErrorBanner(message: err)
            }

            InputBar()
        }
        .navigationTitle("Ask CPCC")
        .navigationBarTitleDisplayMode(.inline)
    }
}
