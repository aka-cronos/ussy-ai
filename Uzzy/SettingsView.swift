import SwiftUI
import UzzyCore

/// A native grouped settings pane: each row has a title, a short description
/// and a trailing control, as in System Settings.
struct SettingsView: View {
    static let width: CGFloat = 480

    let setProviderEnabled: @MainActor (Provider, Bool) -> Void
    @AppStorage("displayMagnitude") private var selectedMagnitude: QuotaMagnitude = .used
    @AppStorage(ProviderVisibilityPreferences.claudeKey) private var showClaude = true
    @AppStorage(ProviderVisibilityPreferences.codexKey) private var showCodex = true
    @AppStorage(ProviderVisibilityPreferences.cursorKey) private var showCursor = true

    var body: some View {
        Form {
            Section("Cuotas") {
                let title = "Porcentaje en las tarjetas"
                let description = "Muestra cuánto has usado de cada límite o cuánto te queda hasta el reinicio."
                LabeledContent {
                    // The hidden title still names the control for VoiceOver.
                    Picker(title, selection: $selectedMagnitude) {
                        // The same words as the suffix after each card's figure.
                        Text(QuotaMagnitude.used.name.localizedCapitalized).tag(QuotaMagnitude.used)
                        Text(QuotaMagnitude.remaining.name.localizedCapitalized).tag(QuotaMagnitude.remaining)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                    .accessibilityHint(description)
                } label: {
                    RowLabel(title: title, description: description)
                }
            }
            // The rows follow the panel's card order; #68 makes them reorderable.
            Section {
                ProviderRow(provider: .claude, isOn: $showClaude)
                ProviderRow(provider: .codex, isOn: $showCodex)
                ProviderRow(provider: .cursor, isOn: $showCursor)
            } header: {
                Text("Proveedores")
            } footer: {
                Text("Un proveedor desactivado no tiene tarjeta, y \(Format.appName) no lee su sesión ni consulta sus cuotas.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .frame(width: Self.width)
        .fixedSize(horizontal: false, vertical: true)
        .onChange(of: showClaude) { _, enabled in setProviderEnabled(.claude, enabled) }
        .onChange(of: showCodex) { _, enabled in setProviderEnabled(.codex, enabled) }
        .onChange(of: showCursor) { _, enabled in setProviderEnabled(.cursor, enabled) }
    }
}

/// One switch per provider, described by the session it reads.
private struct ProviderRow: View {
    let provider: Provider
    @Binding var isOn: Bool

    var body: some View {
        let description = "Usa la sesión de \(provider.officialApp) de este Mac."
        Toggle(isOn: $isOn) {
            RowLabel(title: provider.name, description: description)
        }
        .toggleStyle(.switch)
        .accessibilityLabel("Mostrar \(provider.name)")
        .accessibilityHint(description)
    }
}

/// A row's title over its secondary description, as System Settings lays
/// out a control's label in a grouped form.
private struct RowLabel: View {
    let title: String
    let description: String

    var body: some View {
        Text(title)
        Text(description)
    }
}
