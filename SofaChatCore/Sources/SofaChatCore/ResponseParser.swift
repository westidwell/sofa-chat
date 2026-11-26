import Foundation

/// A successful reply, ready to show and to keep in the chat history.
public struct AssistantReply: Equatable, Sendable {
    public var answer: Answer
    /// Content blocks to send back on the next turn (see `ReplaySanitizer`).
    public var replayContent: JSONValue
    /// The model that actually answered.
    public var model: String?
    public var stopReason: String?
    /// True when a backup model answered because the first one declined.
    public var answeredByFallback: Bool

    public init(
        answer: Answer,
        replayContent: JSONValue,
        model: String? = nil,
        stopReason: String? = nil,
        answeredByFallback: Bool = false
    ) {
        self.answer = answer
        self.replayContent = replayContent
        self.model = model
        self.stopReason = stopReason
        self.answeredByFallback = answeredByFallback
    }
}

/// Everything that can go wrong, each with a sentence that reads well on a TV.
public enum AssistantError: Error, Equatable, Sendable {
    case missingKey
    case invalidKey
    case notAllowed(String)
    case modelNotFound(String)
    case badRequest(String)
    case chatTooLong
    case rateLimited
    case overloaded
    case serverError(Int, String)
    case declined
    case cutOff
    case unreadable
    case network(String)

    public var userMessage: String {
        switch self {
        case .missingKey:
            return "Add your API key in Settings to start chatting, or try the demo."
        case .invalidKey:
            return "That API key didn't work. Open Settings and check it."
        case .notAllowed(let detail):
            return "This key isn't allowed to do that. \(detail)"
        case .modelNotFound:
            return "The model name in Settings wasn't found. Check it, or reset it to the default."
        case .badRequest(let detail):
            return "The request was turned down: \(detail)"
        case .chatTooLong:
            return "This chat has grown too long. Start a new chat and ask again."
        case .rateLimited:
            return "Too many questions at once for this key. Wait a moment and ask again."
        case .overloaded:
            return "The service is busy right now. Try again in a minute."
        case .serverError(let status, _):
            return "The service had a problem (error \(status)). Try again in a minute."
        case .declined:
            return "The assistant declined that one. Try asking another way."
        case .cutOff:
            return "That answer ran too long and got cut off. Try asking for a shorter answer."
        case .unreadable:
            return "I got an answer I couldn't read. Please ask again."
        case .network(let detail):
            return "I couldn't reach the service. Check the Apple TV's internet connection. (\(detail))"
        }
    }
}

extension AssistantError: LocalizedError {
    public var errorDescription: String? { userMessage }
}

/// Turns the raw HTTP response into an `AssistantReply` or an `AssistantError`.
public enum ResponseParser {
    public static func parse(data: Data, status: Int) throws -> AssistantReply {
        let json = try? JSONValue.decode(data)

        guard status == 200 else {
            throw error(status: status, body: json)
        }
        guard let json, let blocks = json["content"]?.arrayValue else {
            throw AssistantError.unreadable
        }

        let stopReason = json["stop_reason"]?.stringValue
        // A decline still comes back as HTTP 200. Check before reading content.
        if stopReason == "refusal" {
            throw AssistantError.declined
        }

        let text = blocks
            .filter { $0["type"]?.stringValue == "text" }
            .compactMap { $0["text"]?.stringValue }
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let answer = readAnswer(from: text) else {
            throw stopReason == "max_tokens" ? AssistantError.cutOff : AssistantError.unreadable
        }

        return AssistantReply(
            answer: answer,
            replayContent: .array(ReplaySanitizer.contentForReplay(blocks)),
            model: json["model"]?.stringValue,
            stopReason: stopReason,
            answeredByFallback: usedFallback(json: json, blocks: blocks)
        )
    }

    /// Reads the answer text. JSON answers (rich mode) are decoded; plain text
    /// is used as-is. Returns nil when there is nothing usable, including JSON
    /// that was cut off halfway, so raw braces never reach the screen.
    public static func readAnswer(from text: String) -> Answer? {
        let trimmed = stripCodeFence(text)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.hasPrefix("{") {
            guard let answer = try? JSONDecoder().decode(Answer.self, from: Data(trimmed.utf8)),
                  !answer.say.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else { return nil }
            return answer
        }
        return Answer(say: trimmed)
    }

    /// Removes a ```json ... ``` wrapper if a model added one anyway.
    static func stripCodeFence(_ text: String) -> String {
        var body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard body.hasPrefix("```") else { return body }
        if let firstNewline = body.firstIndex(of: "\n") {
            body = String(body[body.index(after: firstNewline)...])
        } else {
            body = String(body.dropFirst(3))
        }
        if body.hasSuffix("```") {
            body = String(body.dropLast(3))
        }
        return body.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func usedFallback(json: JSONValue, blocks: [JSONValue]) -> Bool {
        if blocks.contains(where: { $0["type"]?.stringValue == "fallback" }) {
            return true
        }
        let iterations = json["usage"]?["iterations"]?.arrayValue ?? []
        return iterations.contains(where: { $0["type"]?.stringValue == "fallback_message" })
    }

    static func error(status: Int, body: JSONValue?) -> AssistantError {
        let message = body?["error"]?["message"]?.stringValue ?? "no details"
        switch status {
        case 400:
            return .badRequest(message)
        case 401:
            return .invalidKey
        case 403:
            return .notAllowed(message)
        case 404:
            return .modelNotFound(message)
        case 413:
            return .chatTooLong
        case 429:
            return .rateLimited
        case 529:
            return .overloaded
        default:
            return .serverError(status, message)
        }
    }
}
