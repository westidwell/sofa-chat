import XCTest
@testable import SofaChatCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Hands back a canned response and remembers the request. No network.
final class FakeTransport: HTTPTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var requests: [URLRequest] = []
    let body: Data
    let status: Int
    let failure: Error?

    init(body: String, status: Int = 200, failure: Error? = nil) {
        self.body = Data(body.utf8)
        self.status = status
        self.failure = failure
    }

    var sentRequests: [URLRequest] {
        lock.lock()
        defer { lock.unlock() }
        return requests
    }

    private func record(_ request: URLRequest) {
        lock.lock()
        defer { lock.unlock() }
        requests.append(request)
    }

    func send(_ request: URLRequest) async throws -> (Data, Int) {
        record(request)
        if let failure { throw failure }
        return (body, status)
    }
}

struct Offline: Error, LocalizedError {
    var errorDescription: String? { "The network is offline." }
}

final class ConversationTests: XCTestCase {
    func testQuestionsAndRepliesAlternate() {
        var conversation = Conversation()
        XCTAssertTrue(conversation.isEmpty)
        conversation.addQuestion("Hi")
        conversation.addReply(AssistantReply(answer: Answer(say: "Hello"), replayContent: [["type": "text", "text": "Hello"]]))
        conversation.addQuestion("What's new?")
        XCTAssertEqual(conversation.turns.map(\.role), [.user, .assistant, .user])
        XCTAssertEqual(conversation.lastQuestion, "What's new?")
    }

    func testDropUnansweredQuestionOnlyRemovesAQuestion() {
        var conversation = Conversation()
        conversation.addQuestion("Hi")
        conversation.addReply(AssistantReply(answer: Answer(say: "Hello"), replayContent: [["type": "text", "text": "Hello"]]))
        conversation.dropUnansweredQuestion()
        XCTAssertEqual(conversation.turns.count, 2, "a reply is never removed")
        conversation.addQuestion("Again?")
        conversation.dropUnansweredQuestion()
        XCTAssertEqual(conversation.turns.count, 2)
    }

    func testReplayKeepsContentWithoutFallback() {
        let blocks: [JSONValue] = [
            ["type": "thinking", "thinking": "", "signature": "sig"],
            ["type": "text", "text": "Answer"],
        ]
        XCTAssertEqual(ReplaySanitizer.contentForReplay(blocks), blocks)
    }

    func testReplayDropsModelBlocksBeforeFallbackOnly() {
        let blocks: [JSONValue] = [
            ["type": "thinking", "thinking": "", "signature": "old"],
            ["type": "text", "text": "Partial "],
            ["type": "fallback", "from": ["model": "a"], "to": ["model": "b"]],
            ["type": "thinking", "thinking": "", "signature": "new"],
            ["type": "text", "text": "rest of the answer"],
        ]
        let kept = ReplaySanitizer.contentForReplay(blocks)
        XCTAssertEqual(kept.compactMap { $0["type"]?.stringValue }, ["text", "fallback", "thinking", "text"])
        XCTAssertEqual(kept[2]["signature"]?.stringValue, "new")
    }

    func testConversationSurvivesSaveAndLoad() throws {
        var conversation = Conversation()
        conversation.addQuestion("Hi")
        conversation.addReply(AssistantReply(answer: Answer(say: "Hello"), replayContent: [["type": "text", "text": "Hello"]]))
        let data = try JSONEncoder().encode(conversation)
        XCTAssertEqual(try JSONDecoder().decode(Conversation.self, from: data), conversation)
    }

    func testJSONValueRoundTrip() throws {
        let value: JSONValue = ["a": [1, 2.5, "three", true, nil], "b": ["nested": "yes"]]
        XCTAssertEqual(try JSONValue.decode(value.encoded()), value)
        XCTAssertEqual(try String(decoding: JSONValue.number(3).encoded(), as: UTF8.self), "3")
    }
}

final class AssistantClientTests: XCTestCase {
    let fakeKey = "sk-ant-test-0000000000000000"
    let okBody = """
    {"model": "claude-sonnet-5-5", "stop_reason": "end_turn",
     "content": [{"type": "text", "text": "{\\"say\\":\\"Sure thing.\\",\\"title\\":\\"\\",\\"chart_title\\":\\"\\",\\"bars\\":[]}"}]}
    """

    func testSendsConversationAndReturnsReply() async throws {
        let transport = FakeTransport(body: okBody)
        let client = AssistantClient(transport: transport)
        var conversation = Conversation()
        conversation.addQuestion("Can you help?")

        let reply = try await client.send(conversation: conversation, settings: .standard, apiKey: fakeKey)
        XCTAssertEqual(reply.answer.say, "Sure thing.")

        let request = try XCTUnwrap(transport.sentRequests.first)
        XCTAssertEqual(transport.sentRequests.count, 1)
        XCTAssertEqual(request.value(forHTTPHeaderField: "x-api-key"), fakeKey)
    }

    func testMissingKeyNeverTouchesTheNetwork() async {
        let transport = FakeTransport(body: okBody)
        let client = AssistantClient(transport: transport)
        var conversation = Conversation()
        conversation.addQuestion("Hello?")
        for key in [nil, "", "   "] as [String?] {
            do {
                _ = try await client.send(conversation: conversation, settings: .standard, apiKey: key)
                XCTFail("expected missingKey")
            } catch {
                XCTAssertEqual(error as? AssistantError, .missingKey)
            }
        }
        XCTAssertTrue(transport.sentRequests.isEmpty)
    }

    func testNetworkFailureBecomesFriendlyError() async {
        let client = AssistantClient(transport: FakeTransport(body: "", failure: Offline()))
        var conversation = Conversation()
        conversation.addQuestion("Hello?")
        do {
            _ = try await client.send(conversation: conversation, settings: .standard, apiKey: fakeKey)
            XCTFail("expected a network error")
        } catch {
            XCTAssertEqual(error as? AssistantError, .network("The network is offline."))
        }
    }

    func testBadKeyStatusBecomesInvalidKey() async {
        let client = AssistantClient(transport: FakeTransport(body: "{\"type\":\"error\",\"error\":{\"type\":\"authentication_error\",\"message\":\"invalid x-api-key\"}}", status: 401))
        var conversation = Conversation()
        conversation.addQuestion("Hello?")
        do {
            _ = try await client.send(conversation: conversation, settings: .standard, apiKey: fakeKey)
            XCTFail("expected invalidKey")
        } catch {
            XCTAssertEqual(error as? AssistantError, .invalidKey)
        }
    }
}
