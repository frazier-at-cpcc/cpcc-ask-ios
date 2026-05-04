import SwiftUI

struct ScheduleSectionRow: View {
    let section: Section

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("\(section.courseCode) §\(section.sectionNumber)")
                    .font(CPCCFonts.chip).foregroundStyle(CPCCColors.blue)
                Spacer()
                Text(section.seatsOpen >= 0 ? "\(section.seatsOpen) seats" : "FULL")
                    .font(CPCCFonts.chip)
                    .foregroundStyle(section.seatsOpen > 0 ? .green : .red)
            }
            Text("\(section.days) \(section.time) — \(section.location)")
                .font(.system(size: 13))
                .foregroundStyle(CPCCColors.gray)
            Text(section.instructor).font(.system(size: 12)).foregroundStyle(CPCCColors.gray.opacity(0.7))
        }
        .padding(.vertical, 4)
    }
}
