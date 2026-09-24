import Foundation
import UzzyCore

enum ProviderVisibilityPreferences {
    static let claudeKey = "showClaude"
    static let codexKey = "showCodex"
    static let cursorKey = "showCursor"

    static func enabledProviders(in defaults: UserDefaults) -> Set<Provider> {
        Set(Provider.allCases.filter { provider in
            let key = switch provider {
            case .claude: claudeKey
            case .codex: codexKey
            case .cursor: cursorKey
            }
            return defaults.object(forKey: key) == nil || defaults.bool(forKey: key)
        })
    }
}
