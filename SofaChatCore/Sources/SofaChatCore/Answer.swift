import Foundation

/// One bar in an answer's chart.
public struct ChartBar: Codable, Equatable, Sendable {
    public var label: String
    public var value: Double

    public init(label: String, value: Double) {
        self.label = label
        self.value = value
    }
}

/// What the TV shows and says for one reply.
public struct Answer: Equatable, Sendable {
    /// The words read aloud and shown in large type.
    public var say: String
    /// A short heading for the screen. May be empty.
    public var title: String
    /// Heading for the chart. Empty when there is no chart.
    public var chartTitle: String
    /// Bars for a simple bar chart. Empty when there is no chart.
    public var bars: [ChartBar]

    public init(say: String, title: String = "", chartTitle: String = "", bars: [ChartBar] = []) {
        self.say = say
        self.title = title
        self.chartTitle = chartTitle
        self.bars = bars
    }

    public var hasChart: Bool { !bars.isEmpty }

    /// Most bars the TV will draw; extra bars are dropped so labels stay readable.
    public static let maxBars = 12
}

extension Answer: Codable {
    enum CodingKeys: String, CodingKey {
        case say
        case title
        case chartTitle = "chart_title"
        case bars
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        say = try container.decode(String.self, forKey: .say)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        chartTitle = try container.decodeIfPresent(String.self, forKey: .chartTitle) ?? ""
        let allBars = try container.decodeIfPresent([ChartBar].self, forKey: .bars) ?? []
        bars = Array(allBars.prefix(Answer.maxBars))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(say, forKey: .say)
        try container.encode(title, forKey: .title)
        try container.encode(chartTitle, forKey: .chartTitle)
        try container.encode(bars, forKey: .bars)
    }
}

/// The JSON shape the model is asked to answer in when rich answers are on.
public enum AnswerSchema {
    /// Goes in `output_config.format`.
    public static let format: JSONValue = .object([
        "type": .string("json_schema"),
        "schema": schema,
    ])

    static let stringType: JSONValue = .object(["type": .string("string")])
    static let numberType: JSONValue = .object(["type": .string("number")])

    static let bar: JSONValue = .object([
        "type": .string("object"),
        "properties": .object(["label": stringType, "value": numberType]),
        "required": .array([.string("label"), .string("value")]),
        "additionalProperties": .bool(false),
    ])

    static let schema: JSONValue = .object([
        "type": .string("object"),
        "properties": .object([
            "say": stringType,
            "title": stringType,
            "chart_title": stringType,
            "bars": .object(["type": .string("array"), "items": bar]),
        ]),
        "required": .array([.string("say"), .string("title"), .string("chart_title"), .string("bars")]),
        "additionalProperties": .bool(false),
    ])
}

/// The instructions sent as the system prompt.
public enum SystemPrompt {
    public static func text(richAnswers: Bool) -> String {
        var lines = [
            "You are a friendly voice assistant on a living-room TV.",
            "The person is on the couch and talks through the TV remote. Their words come from voice dictation, so expect misheard words and answer what they most likely meant.",
            "Your answer is read aloud and shown in large type, so write plain spoken sentences: no markdown, lists, headings, emoji or links.",
            "Keep it to one to four sentences unless they ask for more detail.",
            "You can't browse the web or see what is on the TV. If they ask about something recent or private that you can't know, say so plainly.",
        ]
        if richAnswers {
            lines += [
                "Answer in the JSON format you were given.",
                "\"say\": the spoken answer, following the rules above.",
                "\"title\": a heading of two to six words for the screen, or an empty string.",
                "\"chart_title\" and \"bars\": only when a small bar chart really helps (comparing amounts, a trend over time, shares of a whole), give a chart title and up to 8 bars, and mention the chart briefly in \"say\" instead of reading every number. Otherwise use an empty string and an empty list.",
            ]
        }
        return lines.joined(separator: "\n")
    }
}
