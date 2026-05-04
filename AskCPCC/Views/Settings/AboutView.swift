import SwiftUI

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Image("CPCCMark").resizable().aspectRatio(contentMode: .fit).frame(height: 64)
                Text("Ask CPCC").font(CPCCFonts.title)
                Text("Every answer about CPCC, sourced and cited. Built with on-device RAG (BAAI/bge-small-en-v1.5), Apple Vision/CoreML, and OpenRouter.")
                    .font(CPCCFonts.body).foregroundStyle(CPCCColors.gray)
                Divider()
                Text("Version 1.0").font(.footnote).foregroundStyle(.secondary)
                Text("github.com/Frazier-at-CPCC/cpcc-ask-ios").font(.footnote).foregroundStyle(.secondary)
                Text("© 2026 Central Piedmont Community College").font(.footnote).foregroundStyle(.secondary)
            }
            .padding(24)
        }
        .navigationTitle("About")
    }
}
