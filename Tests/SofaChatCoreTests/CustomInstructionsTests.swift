import XCTest
@testable import SofaChatCore

final class CustomInstructionsTests: XCTestCase {
    func testCustomInstructionsReplaceTheTVLines() {
        let text = SystemPrompt.text(richAnswers: true, custom: "You are the help desk on a museum kiosk.")
        XCTAssertTrue(text.hasPrefix("You are the help desk on a museum kiosk."))
        XCTAssertFalse(text.contains("living-room TV"))
        // The answer-format rules stay, so the reply still fits the screen.
        XCTAssertTrue(text.contains("chart_title"))
    }

    func testBlankCustomInstructionsFallBackToTheTVLines() {
        XCTAssertTrue(SystemPrompt.text(richAnswers: false, custom: "   \n").contains("living-room TV"))
        XCTAssertTrue(SystemPrompt.text(richAnswers: false, custom: nil).contains("living-room TV"))
    }

    func testRequestCarriesCustomInstructions() throws {
        var conversation = Conversation()
        conversation.addQuestion("Where is the dinosaur hall?")
        let settings = AssistantSettings(systemPrompt: "You are the help desk on a museum kiosk.")
        let body = RequestBuilder.body(conversation: conversation, settings: settings)
        XCTAssertEqual(body["system"]?.stringValue?.hasPrefix("You are the help desk on a museum kiosk."), true)
    }

    func testSettingsSavedBeforeCustomInstructionsStillLoad() throws {
        let saved = """
        {"model":"claude-sonnet-5-5","effort":"low","maxTokens":16000,"richAnswers":true,"speakAnswers":true,"useRefusalFallback":true}
        """
        let settings = try JSONDecoder().decode(AssistantSettings.self, from: Data(saved.utf8))
        XCTAssertNil(settings.systemPrompt)
        XCTAssertEqual(settings, AssistantSettings())
    }
}
