import SwiftUI

struct ScheduleBadge: View {
    let sections: [Section]
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button { expanded.toggle() } label: {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                    Text("\(sections.count) live section\(sections.count == 1 ? "" : "s")")
                    Image(systemName: expanded ? "chevron.up" : "chevron.down").font(.system(size: 11))
                }
                .font(CPCCFonts.chip)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(CPCCColors.gold.opacity(0.2))
                .foregroundStyle(CPCCColors.gray)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            if expanded {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(sections) { ScheduleSectionRow(section: $0) }
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Color.white)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(CPCCColors.gold.opacity(0.5)))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }
}
