import Foundation
import Security

/// Reads, read-only, the session Claude Code keeps on this Mac: the access
/// token from the Keychain and the account identity from `~/.claude.json`.
/// It keeps only the access token, never the refresh token, and never
/// refreshes tokens or writes credentials.
///
/// Reading the Keychain can show the system access prompt, so this must only
/// run after a user action (opening the panel or pressing Actualizar).
public struct ClaudeCodeSessionReader: SessionReader {
    private let keychainService = "Claude Code-credentials"
    private let configFile: URL

    public init(home: URL = FileManager.default.homeDirectoryForCurrentUser) {
        configFile = home.appending(path: ".claude.json")
    }

    // Off the main actor: the Keychain call blocks while its prompt is shown.
    @concurrent
    public func read() async -> SessionReading {
        let credentials: Data
        switch keychainItem() {
        case .found(let data): credentials = data
        case .notFound: return .noSession
        case .denied: return .accessDenied
        case .failed: return .unknownFormat
        }
        // Decodes only the access token; the rest of the item is discarded.
        guard let stored = try? JSONDecoder().decode(StoredCredentials.self, from: credentials) else {
            return .unknownFormat
        }
        guard let token = stored.claudeAiOauth?.accessToken, !token.isEmpty else { return .noSession }
        return .session(Session(accessToken: token, accountID: accountID()))
    }

    private enum KeychainItem {
        case found(Data)
        case notFound
        case denied
        case failed
    }

    private func keychainItem() -> KeychainItem {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: keychainService,
            kSecMatchLimit: kSecMatchLimitOne,
            kSecReturnData: true,
        ]
        var result: CFTypeRef?
        switch SecItemCopyMatching(query as CFDictionary, &result) {
        case errSecSuccess:
            guard let data = result as? Data else { return .failed }
            return .found(data)
        case errSecItemNotFound:
            return .notFound
        // The user denied the prompt. `errSecInteractionNotAllowed` (the prompt
        // could not be shown) is not a denial and falls through to `.failed`.
        case errSecUserCanceled, errSecAuthFailed:
            return .denied
        default:
            return .failed
        }
    }

    /// `nil` when the identity cannot be verified: missing file, field or format.
    private func accountID() -> String? {
        guard let data = try? Data(contentsOf: configFile),
              let config = try? JSONDecoder().decode(ClaudeConfig.self, from: data),
              let id = config.oauthAccount?.accountUuid, !id.isEmpty
        else { return nil }
        return id
    }

    private struct StoredCredentials: Decodable {
        let claudeAiOauth: OAuth?

        struct OAuth: Decodable {
            let accessToken: String?
        }
    }

    private struct ClaudeConfig: Decodable {
        let oauthAccount: Account?

        struct Account: Decodable {
            let accountUuid: String?
        }
    }
}
