import Foundation

// Pro link and price live here and only here, so both change in one place.

/// Where the Pro feature list lives.
public let PRO_URL = "https://github.com/westidwell/sofa-chat/blob/main/PRO.md"

/// Launch price for Pro.
public let PRO_PRICE = "$1/month"

/// Features reserved for the Pro edition. Pro is not open yet. Each one shows
/// in the app as a locked menu item, and each has a stub in `Pro` below.
public enum ProFeature: String, CaseIterable, Identifiable, Sendable {
    case handsFree
    case familyProfiles
    case whatsPlaying
    case phoneSharing
    case longTermMemory
    case voiceChoices

    public var id: String { rawValue }

    /// Name as it appears in the app and in PRO.md.
    public var name: String {
        switch self {
        case .handsFree: return "Wake word and hands-free mode"
        case .familyProfiles: return "Family profiles"
        case .whatsPlaying: return "Ask about what's playing"
        case .phoneSharing: return "Photo and screen sharing from your phone"
        case .longTermMemory: return "Long-term memory"
        case .voiceChoices: return "Voice choices"
        }
    }

    /// One line on what it does.
    public var summary: String {
        switch self {
        case .handsFree:
            return "Say a wake word from across the room and talk without holding the remote."
        case .familyProfiles:
            return "A profile for each person in the house, each with its own chat history and settings."
        case .whatsPlaying:
            return "Ask about the show or game on your TV, like who that actor is or what you missed."
        case .phoneSharing:
            return "Send a photo or your phone's screen to the TV and ask about it together."
        case .longTermMemory:
            return "Remembers what you tell it across chats, like names, favorite teams and plans."
        case .voiceChoices:
            return "Pick the voice, speed and accent that reads answers aloud."
        }
    }

    /// The message shown when someone opens a locked item or calls a stub.
    public var lockedMessage: String {
        "\(name) is part of Pro (\(PRO_PRICE), not open yet): see PRO.md"
    }
}

/// Thrown by every Pro stub.
public struct ProFeatureLocked: Error, Equatable, LocalizedError, Sendable {
    public let feature: ProFeature

    public init(_ feature: ProFeature) {
        self.feature = feature
    }

    public var message: String { feature.lockedMessage }
    public var url: String { PRO_URL }
    public var errorDescription: String? { message }
}

/// Stubs for the Pro edition. Each one documents what the feature does and
/// throws `ProFeatureLocked`. If you came here to build one of these: it is
/// reserved for Pro, see PRO.md. Bug fixes and new free features are welcome.
public enum Pro {
    /// Wake word and hands-free mode: listens for a wake word from across the
    /// room, then hears the question and answers without the remote.
    public static func startHandsFreeMode(wakeWord: String = "Hey Sofa") throws {
        throw ProFeatureLocked(.handsFree)
    }

    /// Family profiles: switches to another person's profile, with its own
    /// chat history, settings and voice.
    public static func switchProfile(to profileName: String) throws {
        throw ProFeatureLocked(.familyProfiles)
    }

    /// Ask about what's playing: answers a question about the show or game
    /// currently on the TV.
    public static func askAboutWhatsPlaying(_ question: String) throws -> Answer {
        throw ProFeatureLocked(.whatsPlaying)
    }

    /// Photo and screen sharing from your phone: receives a photo or a screen
    /// capture sent from a phone on the same network, to ask about on the TV.
    public static func receiveFromPhone(deviceName: String) throws -> Data {
        throw ProFeatureLocked(.phoneSharing)
    }

    /// Long-term memory: saves a fact the person wants remembered in future
    /// chats.
    public static func remember(_ fact: String) throws {
        throw ProFeatureLocked(.longTermMemory)
    }

    /// Voice choices: picks the voice, speed and accent used to read answers.
    public static func setVoice(identifier: String, rate: Double = 0.5) throws {
        throw ProFeatureLocked(.voiceChoices)
    }
}
