import Foundation

/// One message in the chat, in the shape the Messages API expects.
public struct Turn: Codable, Equatable, Sendable {
    public enum Role: String, Codable, Sendable {
        case user
        case assistant
    }

    public let role: Role
    /// A plain string for questions; the raw content blocks for replies.
    public let content: JSONValue

    public init(role: Role, content: JSONValue) {
        self.role = role
        self.content = content
    }

    var json: JSONValue {
        .object(["role": .string(role.rawValue), "content": content])
    }
}

/// The whole chat so far. Every question is sent with the full history so the
/// assistant remembers what was said earlier in the chat.
///
/// History is only ever added to, never rewritten: replies go back exactly as
/// they arrived (thinking blocks included), which the API requires.
public struct Conversation: Codable, Equatable, Sendable {
    public private(set) var turns: [Turn] = []

    public init() {}

    public var isEmpty: Bool { turns.isEmpty }

    /// Adds a question from the person.
    public mutating func addQuestion(_ text: String) {
        turns.append(Turn(role: .user, content: .string(text)))
    }

    /// Adds the assistant's reply, keeping its content blocks as received.
    public mutating func addReply(_ reply: AssistantReply) {
        turns.append(Turn(role: .assistant, content: reply.replayContent))
    }

    /// Removes the last question when it never got an answer (network error,
    /// declined, cut off), so the next question doesn't pile up behind it.
    public mutating func dropUnansweredQuestion() {
        if turns.last?.role == .user {
            turns.removeLast()
        }
    }

    /// The most recent question, if any.
    public var lastQuestion: String? {
        turns.last(where: { $0.role == .user })?.content.stringValue
    }
}

/// Prepares reply content to be sent back on the next turn.
public enum ReplaySanitizer {
    /// Block types that must not be echoed when they come before a `fallback`
    /// block (the point where a backup model took over mid-answer).
    static let droppedBeforeFallback: Set<String> = [
        "thinking",
        "redacted_thinking",
        "tool_use",
        "server_tool_use",
    ]

    /// Returns the blocks to keep in history. With no `fallback` block the
    /// content comes back untouched. With one, model-internal blocks before
    /// the last `fallback` block are left out and everything else, including
    /// the `fallback` block itself, stays where it was.
    public static func contentForReplay(_ blocks: [JSONValue]) -> [JSONValue] {
        guard let boundary = blocks.lastIndex(where: { $0["type"]?.stringValue == "fallback" }) else {
            return blocks
        }
        var kept: [JSONValue] = []
        for (index, block) in blocks.enumerated() {
            let type = block["type"]?.stringValue ?? ""
            if index < boundary && droppedBeforeFallback.contains(type) {
                continue
            }
            kept.append(block)
        }
        return kept
    }
}
