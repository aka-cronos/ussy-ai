import SwiftUI
import UzzyCore

struct SettingsView: View {
    @AppStorage("displayMagnitude") private var defaultMagnitude: QuotaMagnitude = .used

    var body: some View {
        Form {
            Picker("Mostrar cuotas", selection: $defaultMagnitude) {
                Text("Usadas").tag(QuotaMagnitude.used)
                Text("Restantes").tag(QuotaMagnitude.remaining)
            }
            .pickerStyle(.radioGroup)
            Text("Esta opción se aplica también al selector del panel.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: 400, height: 180)
    }
}
