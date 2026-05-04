import SafariServices
import SwiftUI

struct OnboardingView: View {
    @Binding var hasKey: Bool
    @Environment(Settings.self) private var settings
    @State private var showSafari = false
    @State private var showPaste = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            Image("CPCCMark").resizable().aspectRatio(contentMode: .fit).frame(height: 96)
            Text("Ask CPCC")
                .font(CPCCFonts.title)
            Text("Every answer about CPCC, sourced and cited. Bring your own OpenRouter key.")
                .font(CPCCFonts.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .foregroundStyle(CPCCColors.gray)
            VStack(spacing: 12) {
                Button("Connect OpenRouter") { showSafari = true }
                    .buttonStyle(.borderedProminent)
                    .tint(CPCCColors.blue)
                    .controlSize(.large)
                Button("I have a key — paste it") { showPaste = true }
                    .buttonStyle(.bordered)
                Button("Skip for now (demo)") {
                    settings.demoMode = true
                }
                .font(.footnote)
            }
            Spacer()
        }
        .padding(24)
        .sheet(isPresented: $showSafari) {
            SafariView(url: URL(string: "https://openrouter.ai/keys")!)
                .ignoresSafeArea()
        }
        .sheet(isPresented: $showPaste) {
            ApiKeyPasteView(hasKey: $hasKey)
        }
    }
}

private struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController { SFSafariViewController(url: url) }
    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}
}
