import SwiftUI

struct MessageBubble: View {
    let turn: ChatTurn

    var body: some View {
        switch turn.role {
        case .user: userBubble
        case .assistant: assistantBubble
        case .system: systemBubble
        }
    }

    private var userBubble: some View {
        HStack {
            Spacer(minLength: 40)
            Text(turn.text)
                .font(CPCCFonts.body)
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(CPCCColors.blue)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private var assistantBubble: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                if turn.text.isEmpty && turn.isStreaming {
                    StreamingDots()
                } else {
                    Text(LocalizedStringKey(turn.text))
                        .font(CPCCFonts.body)
                        .foregroundStyle(CPCCColors.gray)
                        .textSelection(.enabled)
                }
                if !turn.sources.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(turn.sources, id: \.self) { url in SourceChip(url: url) }
                        }
                    }
                }
                if !turn.scheduleHits.isEmpty {
                    ScheduleBadge(sections: turn.scheduleHits)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.white)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(CPCCColors.gold.opacity(0.5)))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            Spacer(minLength: 40)
        }
    }

    private var systemBubble: some View {
        HStack {
            Text(turn.text)
                .font(CPCCFonts.body)
                .foregroundStyle(CPCCColors.gray.opacity(0.8))
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Color.white.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            Spacer(minLength: 40)
        }
    }
}
