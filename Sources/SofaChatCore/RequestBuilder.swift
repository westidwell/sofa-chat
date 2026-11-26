import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Builds the HTTP request for one question.
public enum RequestBuilder {
    /// The JSON body: model, limits, system prompt, the whole conversation,
    /// and the optional effort, answer format and fallback fields.
    public static func body(conversation: Conversation, settings rawSettings: AssistantSettings) -> JSONValue {
        let settings = rawSettings.cleaned()
        var body: [String: JSONValue] = [
            "model": .string(settings.model),
            "max_tokens": .number(Double(settings.maxTokens)),
            "system": .string(SystemPrompt.text(richAnswers: settings.richAnswers, custom: settings.systemPrompt)),
            "messages": .array(conversation.turns.map { $0.json }),
        ]

        var outputConfig: [String: JSONValue] = [:]
        if let effort = settings.effort.apiValue {
            outputConfig["effort"] = .string(effort)
        }
        if settings.richAnswers {
            outputConfig["format"] = AnswerSchema.format
        }
        if !outputConfig.isEmpty {
            body["output_config"] = .object(outputConfig)
        }

        if settings.sendsRefusalFallback {
            body["fallbacks"] = .string("default")
        }
        return .object(body)
    }

    /// Request headers. The key goes in `x-api-key` and nowhere else.
    public static func headers(apiKey: String, settings: AssistantSettings) -> [String: String] {
        var headers = [
            "content-type": "application/json",
            "x-api-key": apiKey,
            "anthropic-version": APIDefaults.apiVersion,
        ]
        if settings.sendsRefusalFallback {
            headers["anthropic-beta"] = APIDefaults.fallbackBeta
        }
        return headers
    }

    public static func makeRequest(
        conversation: Conversation,
        settings: AssistantSettings,
        apiKey: String
    ) throws -> URLRequest {
        var request = URLRequest(url: APIDefaults.endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = APIDefaults.timeoutSeconds
        for (name, value) in headers(apiKey: apiKey, settings: settings) {
            request.setValue(value, forHTTPHeaderField: name)
        }
        request.httpBody = try body(conversation: conversation, settings: settings).encoded()
        return request
    }
}
