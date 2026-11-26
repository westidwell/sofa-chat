import Foundation
import SofaChatCore

/// Text shown before the first question.
enum Greetings {
    static let welcome = Answer(
        say: "Select the box at the bottom, hold the mic button on your remote, and ask anything.",
        title: "Ask me anything"
    )
}

/// Holds the chat, the settings and the key, and talks to the assistant.
@MainActor
final class ChatViewModel: ObservableObject {
    enum Mode {
        case live
        case demo
    }

    /// nil until a key is saved or the demo is picked.
    @Published private(set) var mode: Mode? = nil
    @Published private(set) var lastQuestion = ""
    @Published private(set) var answer = Greetings.welcome
    @Published private(set) var isThinking = false
    @Published private(set) var settings: AssistantSettings
    @Published private(set) var maskedKey: String? = nil
    @Published var keyMessage: String? = nil

    private var conversation = Conversation()
    private let keys: APIKeyManager
    private let client: AssistantClient
    private let speaker: Speaker
    private let settingsStore: SettingsStore

    init(keyStore: APIKeyStore = KeychainKeyStore(), client: AssistantClient = AssistantClient()) {
        let settingsStore = SettingsStore()
        self.keys = APIKeyManager(store: keyStore)
        self.client = client
        self.speaker = Speaker()
        self.settingsStore = settingsStore
        self.settings = settingsStore.load()
        if let key = keys.currentKey() {
            mode = .live
            maskedKey = APIKeyFormat.masked(key)
        }
    }

    var needsSetup: Bool { mode == nil }
    var isDemo: Bool { mode == .demo }

    // MARK: Key

    /// Saves a pasted or typed key. Returns true when it was saved.
    @discardableResult
    func saveKey(_ raw: String) -> Bool {
        do {
            let key = try keys.save(raw)
            maskedKey = APIKeyFormat.masked(key)
            keyMessage = nil
            if mode != .live {
                mode = .live
                startNewChat(greeting: "Key saved. Ask me anything.")
            }
            return true
        } catch let error as KeyStoreError {
            keyMessage = error.userMessage
        } catch {
            keyMessage = error.localizedDescription
        }
        return false
    }

    func removeKey() {
        try? keys.remove()
        maskedKey = nil
        speaker.stop()
        conversation = Conversation()
        lastQuestion = ""
        answer = Greetings.welcome
        mode = nil
    }

    func useDemo() {
        mode = .demo
        startNewChat(greeting: "Demo mode: answers are canned. Ask for a chart to see one.")
    }

    // MARK: Chat

    func ask(_ raw: String) async {
        let question = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !isThinking else { return }

        speaker.stop()
        lastQuestion = question
        isThinking = true
        defer { isThinking = false }

        if mode == .demo {
            try? await Task.sleep(nanoseconds: 600_000_000)
            show(DemoResponder.reply(to: question).answer)
            return
        }

        conversation.addQuestion(question)
        do {
            let reply = try await client.send(
                conversation: conversation,
                settings: settings,
                apiKey: keys.currentKey()
            )
            conversation.addReply(reply)
            show(reply.answer)
        } catch {
            conversation.dropUnansweredQuestion()
            let message = (error as? AssistantError)?.userMessage ?? error.localizedDescription
            show(Answer(say: message, title: "Hmm"), speak: false)
        }
    }

    func newChat() {
        startNewChat(greeting: "New chat. Ask me anything.")
    }

    func stopTalking() {
        speaker.stop()
    }

    private func startNewChat(greeting: String) {
        speaker.stop()
        conversation = Conversation()
        lastQuestion = ""
        answer = Answer(say: greeting, title: Greetings.welcome.title)
    }

    private func show(_ newAnswer: Answer, speak: Bool = true) {
        answer = newAnswer
        if speak && settings.speakAnswers {
            speaker.say(SpokenText.clean(newAnswer.say))
        }
    }

    // MARK: Settings

    func update(_ change: (inout AssistantSettings) -> Void) {
        var copy = settings
        change(&copy)
        settings = copy.cleaned()
        settingsStore.save(settings)
        if !settings.speakAnswers {
            speaker.stop()
        }
    }
}

/// Saves settings as JSON in UserDefaults. Only settings; never the key.
struct SettingsStore {
    private let defaultsKey = "sofa-chat.settings"

    func load() -> AssistantSettings {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let settings = try? JSONDecoder().decode(AssistantSettings.self, from: data)
        else { return .standard }
        return settings.cleaned()
    }

    func save(_ settings: AssistantSettings) {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }
}
