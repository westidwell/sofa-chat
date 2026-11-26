import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Sends a request and hands back the body and HTTP status.
/// Tests swap in a fake so nothing touches the network.
public protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, Int)
}

/// The real transport, using `URLSession.shared`.
public struct URLSessionTransport: HTTPTransport {
    public init() {}

    public func send(_ request: URLRequest) async throws -> (Data, Int) {
        try await withCheckedThrowingContinuation { continuation in
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                continuation.resume(returning: (data ?? Data(), status))
            }
            task.resume()
        }
    }
}

/// Asks the assistant one question, with the whole conversation as context.
public struct AssistantClient: Sendable {
    private let transport: any HTTPTransport

    public init(transport: any HTTPTransport = URLSessionTransport()) {
        self.transport = transport
    }

    /// Sends the conversation (which should end with the new question) and
    /// returns the reply. Throws `AssistantError` with a TV-friendly message.
    public func send(
        conversation: Conversation,
        settings: AssistantSettings,
        apiKey: String?
    ) async throws -> AssistantReply {
        let key = APIKeyFormat.normalize(apiKey ?? "")
        guard !key.isEmpty else {
            throw AssistantError.missingKey
        }
        let request = try RequestBuilder.makeRequest(conversation: conversation, settings: settings, apiKey: key)

        let result: (Data, Int)
        do {
            result = try await transport.send(request)
        } catch {
            throw AssistantError.network(error.localizedDescription)
        }
        return try ResponseParser.parse(data: result.0, status: result.1)
    }
}
