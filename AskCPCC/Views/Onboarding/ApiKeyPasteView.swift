import SwiftUI

struct ApiKeyPasteView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var hasKey: Bool
    @State private var pasted: String = ""
    @State private var error: String?

    var body: some View {
        VStack(spacing: 20) {
            Text("Paste your OpenRouter key")
                .font(CPCCFonts.title)
            TextField("sk-or-…", text: $pasted)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            if let err = error {
                Text(err).font(.footnote).foregroundStyle(.red)
            }
            Button("Save") {
                let trimmed = pasted.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { error = "Empty key"; return }
                do {
                    try KeychainStore.writeOpenRouterKey(trimmed)
                    hasKey = true
                    dismiss()
                } catch {
                    self.error = "Couldn't save: \(error)"
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(CPCCColors.blue)
            .controlSize(.large)
            Spacer()
        }
        .padding(24)
    }
}
