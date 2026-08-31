import Foundation
import Security

enum CredentialError: LocalizedError {
    case notPaired
    case malformed
    case keychain(OSStatus)

    var errorDescription: String? {
        switch self {
        case .notPaired: "No TV credential stored. Paste one in Settings."
        case .malformed: "That credential could not be read as a PKCS#12 bundle."
        case .keychain(let status): "Keychain error \(status)."
        }
    }
}

enum Credentials {
    private static let service = "app.lumind.tvremote"
    private static let account = "client-identity"
    static let passphrase = "tvremote"

    static func store(_ data: Data) throws {
        guard identity(from: data) != nil else { throw CredentialError.malformed }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else { throw CredentialError.keychain(status) }
    }

    static func remove() {
        SecItemDelete([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ] as CFDictionary)
    }

    static var isStored: Bool { (try? load()) != nil }

    static func load() throws -> SecIdentity {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            throw status == errSecItemNotFound ? CredentialError.notPaired : CredentialError.keychain(status)
        }
        guard let identity = identity(from: data) else { throw CredentialError.malformed }
        return identity
    }

    static func identity(from data: Data) -> SecIdentity? {
        let options = [kSecImportExportPassphrase as String: passphrase] as CFDictionary
        var items: CFArray?
        guard SecPKCS12Import(data as CFData, options, &items) == errSecSuccess,
              let entries = items as? [[String: Any]],
              let first = entries.first else { return nil }
        guard let raw = first[kSecImportItemIdentity as String] else { return nil }
        // Was a force cast. A surprise here should surface as "malformed
        // credential", not as a crash on the connect path.
        guard CFGetTypeID(raw as CFTypeRef) == SecIdentityGetTypeID() else { return nil }
        return (raw as! SecIdentity)
    }
}
