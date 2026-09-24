import SwiftUI
import UzzyCore

struct SettingsView: View {
    @AppStorage("displayMagnitude") private var selectedMagnitude: QuotaMagnitude = .used

    var body: some View {
        Form {
            Picker("Mostrar cuotas", selection: $selectedMagnitude) {
                Text("Usadas").tag(QuotaMagnitude.used)
                Text("Restantes").tag(QuotaMagnitude.remaining)
            }
            .pickerStyle(.radioGroup)
            Text("La selección se conserva al volver a abrir Uzzy.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: 400, height: 180)
    }
}
