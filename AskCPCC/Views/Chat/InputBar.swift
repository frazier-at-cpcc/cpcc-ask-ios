import SwiftUI

struct InputBar: View {
    @Environment(Settings.self) private var settings
    @Environment(ChatViewModel.self) private var chat
    @Environment(\.ragIndex) private var rag
    @Environment(\.courseScheduleClient) private var schedule
    @Environment(\.openRouterClient) private var llm

    @State private var orchestrator: QueryOrchestrator?

    var body: some View {
        @Bindable var chat = chat
        HStack(spacing: 8) {
            TextField("Ask about a program…", text: $chat.inputText, axis: .vertical)
                .lineLimit(1...4)
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .submitLabel(.send)
                .onSubmit { sendIfReady() }

            Button(action: sendIfReady) {
                Image(systemName: "paperplane.fill")
                    .frame(width: 44, height: 44)
                    .foregroundStyle(.white)
                    .background(canSend ? CPCCColors.blue : CPCCColors.gray.opacity(0.5))
                    .clipShape(Circle())
            }
            .disabled(!canSend)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(.thinMaterial)
    }

    private var canSend: Bool {
        !chat.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !chat.isStreaming
    }

    private func sendIfReady() {
        guard canSend else { return }
        Task {
            let key = (try? KeychainStore.readOpenRouterKey()) ?? ""
            if orchestrator == nil {
                orchestrator = QueryOrchestrator(rag: rag, schedule: schedule, llm: llm)
            }
            guard let orchestrator else { return }
            await chat.send(orchestrator: orchestrator,
                            modelId: settings.modelId,
                            apiKey: key,
                            allowSchedule: settings.searchLiveSchedule)
        }
    }
}
