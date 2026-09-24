import Foundation
import UssyCore

/// Panel text, in local time. The UI copy is Spanish.
enum Format {
    private static let locale = Locale(identifier: "es_ES")

    static func percent(_ value: Double) -> String {
        "\(value.formatted(.number.precision(.fractionLength(0...1)).locale(locale))) %"
    }

    static func time(_ date: Date) -> String {
        date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).locale(locale))
    }

    static func reset(_ reset: Reset, now: Date) -> String {
        switch reset {
        case .unknown:
            return "Reinicio desconocido"
        case .at(let date):
            let remaining = date.timeIntervalSince(now)
            let when = "Reinicio: \(day(date, now: now)), \(time(date))"
            return remaining > 0 ? "\(when) · en \(countdown(remaining))" : when
        }
    }

    private static func day(_ date: Date, now: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDate(date, inSameDayAs: now) { return "Hoy" }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
           calendar.isDate(date, inSameDayAs: tomorrow) { return "Mañana" }
        return date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).locale(locale))
    }

    private static func countdown(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        let (days, hours, restMinutes) = (minutes / 1440, minutes / 60 % 24, minutes % 60)
        if days > 0 { return "\(days) d \(hours) h" }
        if hours > 0 { return "\(hours) h \(restMinutes) min" }
        return "\(restMinutes) min"
    }
}
