import XCTest
@testable import SofaChatCore

final class ResponseParserTests: XCTestCase {
    func data(_ text: String) -> Data { Data(text.utf8) }

    let richReply = """
    {
      "id": "msg_fake_001",
      "type": "message",
      "role": "assistant",
      "model": "claude-sonnet-5-5",
      "stop_reason": "end_turn",
      "content": [
        {"type": "thinking", "thinking": "", "signature": "fake-signature-1"},
        {"type": "text", "text": "{\\"say\\":\\"Popcorn is the clear winner.\\",\\"title\\":\\"Snack poll\\",\\"chart_title\\":\\"Votes\\",\\"bars\\":[{\\"label\\":\\"Popcorn\\",\\"value\\":12},{\\"label\\":\\"Grapes\\",\\"value\\":4}]}"}
      ],
      "usage": {"input_tokens": 120, "output_tokens": 40}
    }
    """

    func testReadsRichAnswerWithChart() throws {
        let reply = try ResponseParser.parse(data: data(richReply), status: 200)
        XCTAssertEqual(reply.answer.say, "Popcorn is the clear winner.")
        XCTAssertEqual(reply.answer.title, "Snack poll")
        XCTAssertEqual(reply.answer.chartTitle, "Votes")
        XCTAssertEqual(reply.answer.bars, [ChartBar(label: "Popcorn", value: 12), ChartBar(label: "Grapes", value: 4)])
        XCTAssertTrue(reply.answer.hasChart)
        XCTAssertEqual(reply.model, "claude-sonnet-5-5")
        XCTAssertEqual(reply.stopReason, "end_turn")
        XCTAssertFalse(reply.answeredByFallback)
    }

    func testKeepsAllContentBlocksForReplay() throws {
        let reply = try ResponseParser.parse(data: data(richReply), status: 200)
        let blocks = try XCTUnwrap(reply.replayContent.arrayValue)
        XCTAssertEqual(blocks.count, 2)
        XCTAssertEqual(blocks[0]["type"]?.stringValue, "thinking")
        XCTAssertEqual(blocks[0]["signature"]?.stringValue, "fake-signature-1")
    }

    func testReadsPlainTextAnswer() throws {
        let body = """
        {"model": "claude-sonnet-5-5", "stop_reason": "end_turn",
         "content": [{"type": "text", "text": "  The moon is about 384,000 kilometers away.  "}]}
        """
        let reply = try ResponseParser.parse(data: data(body), status: 200)
        XCTAssertEqual(reply.answer.say, "The moon is about 384,000 kilometers away.")
        XCTAssertEqual(reply.answer.title, "")
        XCTAssertFalse(reply.answer.hasChart)
    }

    func testJoinsSeveralTextBlocks() throws {
        let body = """
        {"stop_reason": "end_turn", "content": [
          {"type": "text", "text": "First part. "},
          {"type": "text", "text": "Second part."}
        ]}
        """
        let reply = try ResponseParser.parse(data: data(body), status: 200)
        XCTAssertEqual(reply.answer.say, "First part. Second part.")
    }

    func testRefusalIsReportedBeforeReadingContent() {
        let body = """
        {"stop_reason": "refusal", "stop_details": {"type": "refusal", "category": null}, "content": []}
        """
        XCTAssertThrowsError(try ResponseParser.parse(data: data(body), status: 200)) { error in
            XCTAssertEqual(error as? AssistantError, .declined)
        }
    }

    func testCutOffJSONIsNotShownRaw() {
        let body = """
        {"stop_reason": "max_tokens", "content": [{"type": "text", "text": "{\\"say\\":\\"The long story begins"}]}
        """
        XCTAssertThrowsError(try ResponseParser.parse(data: data(body), status: 200)) { error in
            XCTAssertEqual(error as? AssistantError, .cutOff)
        }
    }

    func testEmptyContentIsUnreadable() {
        XCTAssertThrowsError(try ResponseParser.parse(data: data("{\"stop_reason\":\"end_turn\",\"content\":[]}"), status: 200)) { error in
            XCTAssertEqual(error as? AssistantError, .unreadable)
        }
        XCTAssertThrowsError(try ResponseParser.parse(data: data("not json"), status: 200)) { error in
            XCTAssertEqual(error as? AssistantError, .unreadable)
        }
    }

    func testFallbackIsDetected() throws {
        let body = """
        {"model": "claude-haiku-5-5", "stop_reason": "end_turn", "content": [
          {"type": "fallback", "from": {"model": "claude-sonnet-5-5"}, "to": {"model": "claude-haiku-5-5"}},
          {"type": "text", "text": "Here is an answer from the backup model."}
        ]}
        """
        let reply = try ResponseParser.parse(data: data(body), status: 200)
        XCTAssertTrue(reply.answeredByFallback)
        XCTAssertEqual(reply.model, "claude-haiku-5-5")

        let sticky = """
        {"stop_reason": "end_turn", "content": [{"type": "text", "text": "Hi."}],
         "usage": {"iterations": [{"type": "fallback_message"}]}}
        """
        XCTAssertTrue(try ResponseParser.parse(data: data(sticky), status: 200).answeredByFallback)
    }

    func testCodeFenceAroundJSONIsRemoved() {
        let text = "```json\n{\"say\":\"Fenced.\",\"title\":\"\",\"chart_title\":\"\",\"bars\":[]}\n```"
        XCTAssertEqual(ResponseParser.readAnswer(from: text)?.say, "Fenced.")
    }

    func testTooManyBarsAreTrimmed() {
        let bars = (1...20).map { "{\"label\":\"B\($0)\",\"value\":\($0)}" }.joined(separator: ",")
        let text = "{\"say\":\"Lots.\",\"title\":\"\",\"chart_title\":\"Many\",\"bars\":[\(bars)]}"
        XCTAssertEqual(ResponseParser.readAnswer(from: text)?.bars.count, Answer.maxBars)
    }

    func testHTTPErrorsMapToFriendlyErrors() {
        let errorBody = data("{\"type\":\"error\",\"error\":{\"type\":\"invalid_request_error\",\"message\":\"max_tokens is too large\"}}")
        let cases: [(Int, AssistantError)] = [
            (400, .badRequest("max_tokens is too large")),
            (401, .invalidKey),
            (403, .notAllowed("max_tokens is too large")),
            (404, .modelNotFound("max_tokens is too large")),
            (413, .chatTooLong),
            (429, .rateLimited),
            (500, .serverError(500, "max_tokens is too large")),
            (529, .overloaded),
        ]
        for (status, expected) in cases {
            XCTAssertThrowsError(try ResponseParser.parse(data: errorBody, status: status)) { error in
                XCTAssertEqual(error as? AssistantError, expected, "status \(status)")
            }
        }
    }

    func testErrorWithoutBodyStillHasAMessage() {
        XCTAssertThrowsError(try ResponseParser.parse(data: Data(), status: 502)) { error in
            XCTAssertEqual(error as? AssistantError, .serverError(502, "no details"))
            XCTAssertFalse((error as? AssistantError)?.userMessage.isEmpty ?? true)
        }
    }

    func testEveryErrorHasATVFriendlyMessage() {
        let all: [AssistantError] = [
            .missingKey, .invalidKey, .notAllowed("x"), .modelNotFound("x"), .badRequest("x"),
            .chatTooLong, .rateLimited, .overloaded, .serverError(500, "x"), .declined,
            .cutOff, .unreadable, .network("offline"),
        ]
        for error in all {
            XCTAssertFalse(error.userMessage.isEmpty)
            XCTAssertFalse(error.userMessage.contains("{"), "messages are read aloud; no raw JSON")
        }
    }
}
