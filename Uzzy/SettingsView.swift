import SwiftUI
import UzzyCore

struct SettingsView: View {
    let setProviderEnabled: @MainActor (Provider, Bool) -> Void
    @AppStorage("displayMagnitude") private var selectedMagnitude: QuotaMagnitude = .used
    @AppStorage(ProviderVisibilityPreferences.claudeKey) private var showClaude = true
    @AppStorage(ProviderVisibilityPreferences.codexKey) private var showCodex = true
    @AppStorage(ProviderVisibilityPreferences.cursorKey) private var showCursor = true

    var body: some View {
        Form {
            Section("Cuotas") {
                Picker("Mostrar cuotas", selection: $selectedMagnitude) {
                    Text("Usadas").tag(QuotaMagnitude.used)
                    Text("Restantes").tag(QuotaMagnitude.remaining)
                }
                .pickerStyle(.radioGroup)
            }
            Section("Proveedores") {
                Toggle("Mostrar Claude", isOn: $showClaude)
                Toggle("Mostrar Codex", isOn: $showCodex)
                Toggle("Mostrar Cursor", isOn: $showCursor)
            }
            Text("Los cambios se conservan al volver a abrir Uzzy.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: 400, height: 310)
        .onChange(of: showClaude) { _, enabled in setProviderEnabled(.claude, enabled) }
        .onChange(of: showCodex) { _, enabled in setProviderEnabled(.codex, enabled) }
        .onChange(of: showCursor) { _, enabled in setProviderEnabled(.cursor, enabled) }
    }
}
