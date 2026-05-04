import SwiftUI

struct SourceChip: View {
    let url: URL

    private var label: String {
        let host = url.host ?? "source"
        let path = url.path
        return path.isEmpty ? host : host + path
    }

    var body: some View {
        Link(destination: url) {
            HStack(spacing: 4) {
                Image(systemName: "link")
                Text(label).lineLimit(1)
            }
            .font(CPCCFonts.chip)
            .foregroundStyle(CPCCColors.blue)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.white)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(CPCCColors.blue.opacity(0.4)))
        }
    }
}
