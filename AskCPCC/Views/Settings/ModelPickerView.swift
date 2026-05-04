import SwiftUI

struct ModelPickerView: View {
    @Environment(Settings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        Picker("Model", selection: $settings.modelId) {
            ForEach(OpenRouterModel.all) { m in
                VStack(alignment: .leading) {
                    Text(m.displayName)
                    Text(String(format: "$%.2f / $%.2f per M tokens", m.promptCostPerMTok, m.completionCostPerMTok))
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .tag(m.id)
            }
        }
        .pickerStyle(.inline)
    }
}
