import Foundation

/// Canned answers so the app can be tried with no key and no network.
/// Everything here is made up.
public enum DemoResponder {
    public static let modelName = "demo"

    public static func reply(to question: String) -> AssistantReply {
        let canned = cannedAnswer(for: question)
        let content: JSONValue = .array([
            .object(["type": .string("text"), "text": .string(canned.say)]),
        ])
        return AssistantReply(answer: canned, replayContent: content, model: modelName, stopReason: "end_turn")
    }

    static func cannedAnswer(for question: String) -> Answer {
        let words = Set(
            question.lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { !$0.isEmpty }
        )
        func has(_ options: String...) -> Bool {
            options.contains(where: words.contains)
        }

        if has("chart", "charts", "graph", "compare", "snack", "snacks") {
            return Answer(
                say: "Here's a made-up chart of snack votes from movie night. Popcorn won by a mile, and the grapes had a rough night.",
                title: "Movie night snack votes",
                chartTitle: "Votes (made-up data)",
                bars: [
                    ChartBar(label: "Popcorn", value: 12),
                    ChartBar(label: "Nachos", value: 9),
                    ChartBar(label: "Pretzels", value: 7),
                    ChartBar(label: "Grapes", value: 4),
                ]
            )
        }
        if has("pro", "upgrade") {
            return Answer(
                say: "Pro will add a wake word, family profiles, long-term memory and more. It isn't open yet. Open the Pro menu to see the list.",
                title: "About Pro"
            )
        }
        if has("key", "api", "setup", "real") {
            return Answer(
                say: "To talk with the real assistant, open Settings and paste your Anthropic API key. It stays in this Apple TV's Keychain.",
                title: "Using your own key"
            )
        }
        if has("hi", "hello", "hey") {
            return Answer(
                say: "Hi there. This is demo mode, so my answers are canned. Ask me for a chart to see how charts look on the TV.",
                title: "Hello from the couch"
            )
        }
        return Answer(
            say: "This is demo mode, so I can't really answer that. Add your own API key in Settings for real answers, or ask me for a chart to see one.",
            title: "Demo mode"
        )
    }
}
