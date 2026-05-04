import SwiftUI

struct AboutView: View {
    @Environment(CorpusStatus.self) private var corpusStatus

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Image("CPCCMark").resizable().aspectRatio(contentMode: .fit).frame(height: 64)
                Text("Ask CPCC").font(CPCCFonts.title)
                Text("Every answer about CPCC, sourced and cited. Built with on-device RAG (BAAI/bge-small-en-v1.5), Apple Vision/CoreML, and OpenRouter.")
                    .font(CPCCFonts.body).foregroundStyle(CPCCColors.gray)

                Divider()

                Text("Diagnostics").font(.headline).foregroundStyle(CPCCColors.gray)
                Group {
                    diagRow("Corpus state", corpusStatus.state.displayName)
                    if case .ready(let v, let n) = corpusStatus.state {
                        diagRow("Corpus version", v)
                        diagRow("Total chunks", "\(n)")
                    }
                    if let last = corpusStatus.lastCheck {
                        diagRow("Last update check", last.formatted(date: .abbreviated, time: .shortened))
                    }
                    if let err = corpusStatus.lastError {
                        diagRow("Last error", err)
                    }
                }
                .font(.footnote)

                Divider()

                Text("Version 1.0").font(.footnote).foregroundStyle(.secondary)
                Text("github.com/Frazier-at-CPCC/cpcc-ask-ios").font(.footnote).foregroundStyle(.secondary)
                Text("© 2026 Central Piedmont Community College").font(.footnote).foregroundStyle(.secondary)
            }
            .padding(24)
        }
        .navigationTitle("About")
    }

    @ViewBuilder
    private func diagRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).multilineTextAlignment(.trailing).textSelection(.enabled)
        }
    }
}
