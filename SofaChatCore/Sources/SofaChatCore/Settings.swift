import Foundation

/// Fixed facts about the API this app talks to.
public enum APIDefaults {
    /// The Messages endpoint. Your key is only ever sent here.
    public static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    /// The API version header the request bodies are written for.
    public static let apiVersion = "2026-10-21"

    /// Default model: quick and lower cost, which suits short spoken answers
    /// paid for with your own key. You can type any other model id in Settings.
    public static let defaultModel = "claude-sonnet-5-5"

    /// Beta header that lets the API retry a declined question on a backup
    /// model inside the same call (the `fallbacks: "default"` request field).
    public static let fallbackBeta = "server-side-fallback-2026-07-01"

    /// Models documented to accept `fallbacks: "default"`. For any other model
    /// the field and its header are left out, so the request stays valid.
    public static let modelsWithServerFallback: Set<String> = [
        "claude-fable-5-2",
        "claude-sonnet-5-5",
    ]

    /// How long to wait for an answer before giving up.
    public static let timeoutSeconds: TimeInterval = 120
}

/// How hard the model thinks before answering.
public enum Effort: String, Codable, CaseIterable, Sendable {
    /// Fastest. Good for chatting from the couch.
    case low
    case medium
    case high
    /// Don't send an effort value; the model uses its own default.
    /// Pick this for older models that don't accept the setting.
    case modelDefault

    /// The value sent as `output_config.effort`, or nil to leave it out.
    public var apiValue: String? {
        switch self {
        case .low: return "low"
        case .medium: return "medium"
        case .high: return "high"
        case .modelDefault: return nil
        }
    }

    public var label: String {
        switch self {
        case .low: return "Low (fastest)"
        case .medium: return "Medium"
        case .high: return "High (slower, more careful)"
        case .modelDefault: return "Model default"
        }
    }
}

/// Everything the person can change in Settings. Saved as JSON on the device.
public struct AssistantSettings: Codable, Equatable, Sendable {
    public var model: String
    public var effort: Effort
    /// Upper limit on tokens per answer, thinking included.
    public var maxTokens: Int
    /// Ask for a heading and an optional bar chart along with the spoken answer.
    public var richAnswers: Bool
    /// Read answers aloud with the Apple TV's built-in voice.
    public var speakAnswers: Bool
    /// When a question is declined, let the API retry it on a backup model.
    public var useRefusalFallback: Bool

    public init(
        model: String = APIDefaults.defaultModel,
        effort: Effort = .low,
        maxTokens: Int = 16_000,
        richAnswers: Bool = true,
        speakAnswers: Bool = true,
        useRefusalFallback: Bool = true
    ) {
        self.model = model
        self.effort = effort
        self.maxTokens = maxTokens
        self.richAnswers = richAnswers
        self.speakAnswers = speakAnswers
        self.useRefusalFallback = useRefusalFallback
    }

    public static let standard = AssistantSettings()

    public static let maxTokensRange = 256...64_000

    /// A copy with an empty model replaced by the default and the token limit
    /// kept in a safe range.
    public func cleaned() -> AssistantSettings {
        var copy = self
        let trimmed = model.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.model = trimmed.isEmpty ? APIDefaults.defaultModel : trimmed
        copy.maxTokens = min(max(maxTokens, Self.maxTokensRange.lowerBound), Self.maxTokensRange.upperBound)
        return copy
    }

    /// True when the request should carry `fallbacks: "default"`.
    public var sendsRefusalFallback: Bool {
        useRefusalFallback && APIDefaults.modelsWithServerFallback.contains(cleaned().model)
    }
}
