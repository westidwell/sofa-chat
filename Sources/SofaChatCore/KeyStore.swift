import Foundation

/// Somewhere to keep the person's API key. The app uses `KeychainKeyStore`;
/// tests use `InMemoryKeyStore`.
public protocol APIKeyStore: AnyObject {
    func loadKey() throws -> String?
    func saveKey(_ key: String) throws
    func deleteKey() throws
}

public enum KeyStoreError: Error, Equatable, Sendable {
    /// The text doesn't look like an Anthropic API key.
    case invalidFormat
    /// The underlying store (Keychain) returned this status code.
    case storageFailed(Int32)

    public var userMessage: String {
        switch self {
        case .invalidFormat:
            return "That doesn't look like an Anthropic API key. Keys start with \"sk-ant-\"."
        case .storageFailed(let code):
            return "Couldn't save the key on this Apple TV (error \(code)). Try again."
        }
    }
}

/// Small helpers for the key text itself.
public enum APIKeyFormat {
    public static let prefix = "sk-ant-"

    /// Removes spaces and line breaks that sneak in when a key is pasted or
    /// dictated.
    public static func normalize(_ raw: String) -> String {
        var kept = String.UnicodeScalarView()
        for scalar in raw.unicodeScalars where !CharacterSet.whitespacesAndNewlines.contains(scalar) {
            kept.append(scalar)
        }
        return String(kept)
    }

    /// A quick shape check before saving. It does not prove the key works;
    /// the first question does that.
    public static func looksValid(_ key: String) -> Bool {
        let key = normalize(key)
        return key.hasPrefix(prefix) && key.count >= 20
    }

    /// Safe to show on screen: "sk-ant-…WXYZ".
    public static func masked(_ key: String) -> String {
        let key = normalize(key)
        guard key.count > 4 else { return "…" }
        return prefix + "…" + String(key.suffix(4))
    }
}

/// Reads, checks, saves and removes the key through any `APIKeyStore`.
public final class APIKeyManager {
    private let store: APIKeyStore

    public init(store: APIKeyStore) {
        self.store = store
    }

    /// The saved key, or nil when there isn't one or it can't be read.
    public func currentKey() -> String? {
        guard let key = try? store.loadKey() else { return nil }
        let cleaned = APIKeyFormat.normalize(key)
        return cleaned.isEmpty ? nil : cleaned
    }

    public var hasKey: Bool { currentKey() != nil }

    /// Checks the shape, then saves. Returns the cleaned key.
    @discardableResult
    public func save(_ raw: String) throws -> String {
        let key = APIKeyFormat.normalize(raw)
        guard APIKeyFormat.looksValid(key) else {
            throw KeyStoreError.invalidFormat
        }
        try store.saveKey(key)
        return key
    }

    public func remove() throws {
        try store.deleteKey()
    }
}

/// Keeps the key in memory only. For tests and previews.
public final class InMemoryKeyStore: APIKeyStore, @unchecked Sendable {
    private let lock = NSLock()
    private var key: String?

    public init(key: String? = nil) {
        self.key = key
    }

    public func loadKey() throws -> String? {
        lock.lock()
        defer { lock.unlock() }
        return key
    }

    public func saveKey(_ key: String) throws {
        lock.lock()
        defer { lock.unlock() }
        self.key = key
    }

    public func deleteKey() throws {
        lock.lock()
        defer { lock.unlock() }
        key = nil
    }
}
