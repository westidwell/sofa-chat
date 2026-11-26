import XCTest
@testable import SofaChatCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class RequestBuilderTests: XCTestCase {
    let fakeKey = "sk-ant-test-0000000000000000"

    func conversationWithOneQuestion() -> Conversation {
        var conversation = Conversation()
        conversation.addQuestion("How far away is the moon?")
        return conversation
    }

    func decodedBody(_ request: URLRequest) throws -> JSONValue {
        let data = try XCTUnwrap(request.httpBody)
        return try JSONValue.decode(data)
    }

    func testRequestGoesToMessagesEndpointWithHeaders() throws {
        let request = try RequestBuilder.makeRequest(
            conversation: conversationWithOneQuestion(),
            settings: .standard,
            apiKey: fakeKey
        )
        XCTAssertEqual(request.url?.absoluteString, "https://api.anthropic.com/v1/messages")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "x-api-key"), fakeKey)
        XCTAssertEqual(request.value(forHTTPHeaderField: "anthropic-version"), "2026-10-21")
        XCTAssertEqual(request.value(forHTTPHeaderField: "content-type"), "application/json")
    }

    func testBodyCarriesModelLimitsSystemAndMessages() throws {
        let request = try RequestBuilder.makeRequest(
            conversation: conversationWithOneQuestion(),
            settings: .standard,
            apiKey: fakeKey
        )
        let body = try decodedBody(request)
        XCTAssertEqual(body["model"]?.stringValue, APIDefaults.defaultModel)
        XCTAssertEqual(body["max_tokens"]?.doubleValue, 16_000)
        XCTAssertEqual(body["system"]?.stringValue?.contains("living-room TV"), true)

        let messages = try XCTUnwrap(body["messages"]?.arrayValue)
        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages[0]["role"]?.stringValue, "user")
        XCTAssertEqual(messages[0]["content"]?.stringValue, "How far away is the moon?")
    }

    func testKeyNeverAppearsInBody() throws {
        let request = try RequestBuilder.makeRequest(
            conversation: conversationWithOneQuestion(),
            settings: .standard,
            apiKey: fakeKey
        )
        let bodyText = try String(decoding: XCTUnwrap(request.httpBody), as: UTF8.self)
        XCTAssertFalse(bodyText.contains(fakeKey))
    }

    func testRichAnswersAskForJSONFormatAndLowEffort() {
        let body = RequestBuilder.body(conversation: conversationWithOneQuestion(), settings: .standard)
        let outputConfig = body["output_config"]
        XCTAssertEqual(outputConfig?["effort"]?.stringValue, "low")
        XCTAssertEqual(outputConfig?["format"]?["type"]?.stringValue, "json_schema")
        let required = outputConfig?["format"]?["schema"]?["required"]?.arrayValue?.compactMap { $0.stringValue }
        XCTAssertEqual(required, ["say", "title", "chart_title", "bars"])
        XCTAssertEqual(outputConfig?["format"]?["schema"]?["additionalProperties"]?.boolValue, false)
    }

    func testPlainAnswersWithModelDefaultEffortLeaveOutputConfigOut() {
        var settings = AssistantSettings.standard
        settings.richAnswers = false
        settings.effort = .modelDefault
        let body = RequestBuilder.body(conversation: conversationWithOneQuestion(), settings: settings)
        XCTAssertNil(body["output_config"])
        XCTAssertEqual(body["system"]?.stringValue?.contains("JSON"), false)
    }

    func testFallbackSentOnlyForModelsThatSupportIt() throws {
        let supported = try RequestBuilder.makeRequest(
            conversation: conversationWithOneQuestion(),
            settings: .standard,
            apiKey: fakeKey
        )
        XCTAssertEqual(try decodedBody(supported)["fallbacks"]?.stringValue, "default")
        XCTAssertEqual(supported.value(forHTTPHeaderField: "anthropic-beta"), "server-side-fallback-2026-07-01")

        var otherModel = AssistantSettings.standard
        otherModel.model = "claude-haiku-5-5"
        let unsupported = try RequestBuilder.makeRequest(
            conversation: conversationWithOneQuestion(),
            settings: otherModel,
            apiKey: fakeKey
        )
        XCTAssertNil(try decodedBody(unsupported)["fallbacks"])
        XCTAssertNil(unsupported.value(forHTTPHeaderField: "anthropic-beta"))

        var switchedOff = AssistantSettings.standard
        switchedOff.useRefusalFallback = false
        XCTAssertNil(RequestBuilder.body(conversation: conversationWithOneQuestion(), settings: switchedOff)["fallbacks"])
        XCTAssertNil(RequestBuilder.headers(apiKey: fakeKey, settings: switchedOff)["anthropic-beta"])
    }

    func testSettingsAreCleanedBeforeSending() {
        var settings = AssistantSettings.standard
        settings.model = "   "
        settings.maxTokens = 5
        let body = RequestBuilder.body(conversation: conversationWithOneQuestion(), settings: settings)
        XCTAssertEqual(body["model"]?.stringValue, APIDefaults.defaultModel)
        XCTAssertEqual(body["max_tokens"]?.doubleValue, 256)

        settings.maxTokens = 10_000_000
        XCTAssertEqual(
            RequestBuilder.body(conversation: conversationWithOneQuestion(), settings: settings)["max_tokens"]?.doubleValue,
            64_000
        )
    }

    func testAssistantContentIsSentBackUnchanged() {
        var conversation = conversationWithOneQuestion()
        let content: JSONValue = [
            ["type": "thinking", "thinking": "", "signature": "fake-signature-abc"],
            ["type": "text", "text": "{\"say\":\"About 384,000 kilometers.\",\"title\":\"\",\"chart_title\":\"\",\"bars\":[]}"],
        ]
        conversation.addReply(AssistantReply(answer: Answer(say: "About 384,000 kilometers."), replayContent: content))
        conversation.addQuestion("And the sun?")

        let messages = RequestBuilder.body(conversation: conversation, settings: .standard)["messages"]?.arrayValue
        XCTAssertEqual(messages?.count, 3)
        XCTAssertEqual(messages?[1]["role"]?.stringValue, "assistant")
        XCTAssertEqual(messages?[1]["content"], content)
        XCTAssertEqual(messages?[2]["content"]?.stringValue, "And the sun?")
    }

    func testBodyBytesAreStable() throws {
        let first = try RequestBuilder.body(conversation: conversationWithOneQuestion(), settings: .standard).encoded()
        let second = try RequestBuilder.body(conversation: conversationWithOneQuestion(), settings: .standard).encoded()
        XCTAssertEqual(first, second)
        let text = String(decoding: first, as: UTF8.self)
        XCTAssertTrue(text.contains("\"max_tokens\":16000"), "whole numbers should encode without a decimal point")
    }
}
