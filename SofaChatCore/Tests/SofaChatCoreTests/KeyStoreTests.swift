import XCTest
@testable import SofaChatCore

/// A store that records calls and can be told to fail, standing in for the Keychain.
final class MockKeyStore: APIKeyStore {
    var saved: String?
    var saveCalls = 0
    var deleteCalls = 0
    var failWith: KeyStoreError?

    func loadKey() throws -> String? {
        if let failWith { throw failWith }
        return saved
    }

    func saveKey(_ key: String) throws {
        saveCalls += 1
        if let failWith { throw failWith }
        saved = key
    }

    func deleteKey() throws {
        deleteCalls += 1
        if let failWith { throw failWith }
        saved = nil
    }
}

final class KeyStoreTests: XCTestCase {
    let fakeKey = "sk-ant-test-0000000000000000"

    func testSavesCleanedKey() throws {
        let store = MockKeyStore()
        let manager = APIKeyManager(store: store)
        let saved = try manager.save("  sk-ant-test-0000\n000000000000 \n")
        XCTAssertEqual(saved, fakeKey)
        XCTAssertEqual(store.saved, fakeKey)
        XCTAssertEqual(manager.currentKey(), fakeKey)
        XCTAssertTrue(manager.hasKey)
    }

    func testRejectsTextThatIsNotAKey() {
        let store = MockKeyStore()
        let manager = APIKeyManager(store: store)
        for bad in ["", "hello", "sk-ant-", "pk-ant-test-0000000000000000", "sk-ant-short"] {
            XCTAssertThrowsError(try manager.save(bad)) { error in
                XCTAssertEqual(error as? KeyStoreError, .invalidFormat)
            }
        }
        XCTAssertEqual(store.saveCalls, 0, "nothing should reach the store")
        XCTAssertNil(manager.currentKey())
    }

    func testRemoveDeletesKey() throws {
        let store = MockKeyStore()
        let manager = APIKeyManager(store: store)
        try manager.save(fakeKey)
        try manager.remove()
        XCTAssertEqual(store.deleteCalls, 1)
        XCTAssertNil(manager.currentKey())
        XCTAssertFalse(manager.hasKey)
    }

    func testStoreFailuresSurface() {
        let store = MockKeyStore()
        store.failWith = .storageFailed(-25_299)
        let manager = APIKeyManager(store: store)
        XCTAssertThrowsError(try manager.save(fakeKey)) { error in
            XCTAssertEqual(error as? KeyStoreError, .storageFailed(-25_299))
        }
        XCTAssertNil(manager.currentKey(), "an unreadable store counts as no key")
        XCTAssertThrowsError(try manager.remove())
    }

    func testBlankStoredKeyCountsAsNoKey() {
        let manager = APIKeyManager(store: InMemoryKeyStore(key: "  \n "))
        XCTAssertNil(manager.currentKey())
    }

    func testInMemoryStoreRoundTrip() throws {
        let store = InMemoryKeyStore()
        XCTAssertNil(try store.loadKey())
        try store.saveKey(fakeKey)
        XCTAssertEqual(try store.loadKey(), fakeKey)
        try store.deleteKey()
        XCTAssertNil(try store.loadKey())
    }

    func testMaskedKeyShowsOnlyTheEnd() {
        XCTAssertEqual(APIKeyFormat.masked("sk-ant-test-0000000000001234"), "sk-ant-…1234")
        XCTAssertFalse(APIKeyFormat.masked(fakeKey).contains("test-0000"))
        XCTAssertEqual(APIKeyFormat.masked("abc"), "…")
    }

    func testKeyErrorsHaveMessages() {
        XCTAssertTrue(KeyStoreError.invalidFormat.userMessage.contains("sk-ant-"))
        XCTAssertTrue(KeyStoreError.storageFailed(-1).userMessage.contains("-1"))
    }
}
