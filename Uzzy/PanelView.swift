import SwiftUI
import UzzyCore

struct PanelView: View {
    let core: UsageCore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(Format.appName).font(.headline)
                    Text("Cuotas de suscripción").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Picker("Mostrar", selection: Binding(get: { core.state.magnitude }, set: core.show)) {
                    Text("Usado").tag(QuotaMagnitude.used)
                    Text("Restante").tag(QuotaMagnitude.remaining)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
                .accessibilityLabel("Mostrar cuota usada o restante")
            }
            .padding([.horizontal, .top], 16)
            .padding(.bottom, 10)

            ScrollView {
                // Recomputes the time left until each reset every minute.
                TimelineView(.everyMinute) { _ in
                    VStack(spacing: 8) {
                        ForEach(core.state.cards, id: \.provider) { card in
                            CardView(card: card, magnitude: core.state.magnitude, now: core.now())
                        }
                    }
                    .padding([.horizontal, .bottom], 12)
                }
            }
            .frame(maxHeight: 520)
            .fixedSize(horizontal: false, vertical: true)

            Divider()
            HStack {
                Button("Actualizar", action: core.refresh)
                    .accessibilityValue(core.state.isQuerying ? "Consulta en curso" : "")
                    .help("Consultar las cuotas ahora")
                // Keeps its space so the footer does not shift while querying.
                ProgressView()
                    .controlSize(.small)
                    .opacity(core.state.isQuerying ? 1 : 0)
                    .accessibilityHidden(true)
                Spacer()
                // Quotas live only in memory, so quitting has nothing to save.
                Button("Salir") { NSApp.terminate(nil) }
                    .accessibilityLabel(Format.quitApp)
                    .accessibilityInputLabels(["Salir", Format.quitApp])
                    .help("\(Format.quitApp) (⌘Q)")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(width: 360)
    }
}

private struct CardView: View {
    let card: Card
    let magnitude: QuotaMagnitude
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(card.provider.name).fontWeight(.semibold)

            switch card.content {
            case .loading:
                Message(title: "Consultando cuotas…", detail: "Todavía no hay un dato válido.")
            case .failed(let failure):
                FailureMessage(failure: failure, provider: card.provider)
            case .quotas(let quotas):
                ForEach(quotas, id: \.period) { quota in
                    QuotaView(quota: quota, magnitude: magnitude, now: now)
                }
            case .stale(let quotas, let failure):
                // Why the figures below could not be refreshed.
                FailureMessage(failure: failure, provider: card.provider)
                ForEach(quotas, id: \.period) { quota in
                    QuotaView(quota: quota, magnitude: magnitude, now: now)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.separator))
    }
}

private struct QuotaView: View {
    let quota: Quota
    let magnitude: QuotaMagnitude
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            switch quota.value {
            case .percent(let percent, let calculated):
                // The label and the bar come from the same value, so they
                // always show the same magnitude.
                HStack(alignment: .firstTextBaseline) {
                    Text(quota.period.name)
                    if quota.isStale {
                        Text("Desactualizado").font(.caption.weight(.semibold)).foregroundStyle(.orange)
                    }
                    Spacer()
                    Text(Format.percent(percent))
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(quota.isStale ? .secondary : .primary)
                    Text(magnitude.name).font(.caption).foregroundStyle(.secondary)
                }
                Bar(fraction: percent / 100)
                    .opacity(quota.isStale ? 0.5 : 1)
                Group {
                    if calculated {
                        Text("Calculado: 100 − usado")
                    }
                    Text(Format.reset(quota.reset, now: now))
                    Text("Última lectura: \(Format.time(quota.readAt))")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            // No valid reading of this quota, so no reset or reading time to vouch for.
            case .uninterpretable:
                QuotaNotice(period: quota.period, notice: "Dato no interpretable")
            case .unavailable:
                QuotaNotice(period: quota.period, notice: "Cuota no disponible")
            }
        }
        .padding(.top, 14)
        .accessibilityElement(children: .combine)
    }
}

/// A quota without a percentage to show: no figure and no bar.
private struct QuotaNotice: View {
    let period: QuotaPeriod
    let notice: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(period.name)
            Spacer()
            Text(notice).fontWeight(.semibold).foregroundStyle(.orange)
        }
    }
}

private struct Bar: View {
    let fraction: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule().fill(.tint).frame(width: geometry.size.width * fraction)
            }
        }
        .frame(height: 5)
        .accessibilityHidden(true)
    }
}

private struct Message: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).fontWeight(.semibold)
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }
        .padding(.top, 12)
    }
}

/// Why the card has no quotas, and what to do about it.
private struct FailureMessage: View {
    let failure: Failure
    let provider: Provider

    var body: some View {
        switch failure {
        case .noSession:
            Message(title: "Sin sesión", detail: "Inicia sesión en \(provider.officialApp) y pulsa Actualizar.")
        case .sessionAccessDenied:
            Message(
                title: "Sin acceso a la sesión",
                detail: "Se denegó el acceso a la sesión de \(provider.officialApp) en el llavero. Pulsa Actualizar para volver a pedirlo."
            )
        case .incompatibleSession:
            Message(
                title: "Sesión incompatible",
                detail: "La sesión de \(provider.officialApp) tiene un formato que \(Format.appName) no reconoce."
            )
        case .sessionExpired:
            Message(title: "Sesión vencida", detail: "Renueva la sesión en \(provider.officialApp) y pulsa Actualizar.")
        case .accessRefused:
            Message(
                title: "Acceso rechazado",
                detail: "\(provider.name) rechazó la consulta. Puede ser una restricción de la cuenta; revísala en \(provider.officialApp) y pulsa Actualizar."
            )
        case .offline:
            Message(title: "Sin conexión", detail: "No se pudo conectar con \(provider.name). Pulsa Actualizar para reintentar.")
        case .timedOut:
            Message(title: "Tiempo agotado", detail: "\(provider.name) no respondió a tiempo. Pulsa Actualizar para reintentar.")
        case .serverError(let status):
            Message(title: "Error del servidor", detail: "\(provider.name) respondió con un error (\(status)). Pulsa Actualizar para reintentar.")
        case .incompatibleResponse:
            Message(
                title: "Respuesta incompatible",
                detail: "\(provider.name) respondió en un formato que \(Format.appName) no reconoce. Puede que haya cambiado su servicio."
            )
        }
    }
}

private extension QuotaPeriod {
    var name: String {
        switch self {
        case .fiveHours: "5 horas"
        case .weekly: "Semanal"
        case .weeklyForModel(let model): "Semanal · \(model)"
        }
    }
}

private extension QuotaMagnitude {
    var name: String {
        switch self {
        case .used: "usado"
        case .remaining: "restante"
        }
    }
}

private extension Provider {
    var name: String {
        switch self {
        case .claude: "Claude"
        }
    }

    /// The app whose session the card reuses.
    var officialApp: String {
        switch self {
        case .claude: "Claude Code"
        }
    }
}
