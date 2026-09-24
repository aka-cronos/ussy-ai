import SwiftUI
import UssyCore

struct PanelView: View {
    let core: UsageCore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text("UssyAi").font(.headline)
                Text("Cuotas de suscripción").font(.caption).foregroundStyle(.secondary)
            }
            .padding([.horizontal, .top], 16)
            .padding(.bottom, 10)

            ScrollView {
                // Recomputes the time left until each reset every minute.
                TimelineView(.everyMinute) { _ in
                    VStack(spacing: 8) {
                        ForEach(core.state.cards, id: \.provider) { card in
                            CardView(card: card, now: core.now())
                        }
                    }
                    .padding([.horizontal, .bottom], 12)
                }
            }
            .frame(maxHeight: 520)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: 360)
    }
}

private struct CardView: View {
    let card: Card
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(card.provider.name).fontWeight(.semibold)

            switch card.content {
            case .loading:
                Message(title: "Consultando cuotas…", detail: "Todavía no hay un dato válido.")
            case .queryFailed:
                Message(title: "No se pudo consultar", detail: "No hay un dato válido que mostrar.")
            case .quotas(let quotas):
                ForEach(quotas, id: \.period) { quota in
                    QuotaView(quota: quota, now: now)
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
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(quota.period)
                Spacer()
                Text(Format.percent(quota.usedPercent))
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                Text("usado").font(.caption).foregroundStyle(.secondary)
            }
            Bar(fraction: quota.usedPercent / 100)
            Group {
                Text(Format.reset(quota.reset, now: now))
                Text("Última lectura: \(Format.time(quota.readAt))")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.top, 14)
        .accessibilityElement(children: .combine)
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

private extension Provider {
    var name: String {
        switch self {
        case .claude: "Claude"
        }
    }
}
