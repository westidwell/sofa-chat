import XCTest
@testable import SofaChatCore

final class DemoResponderTests: XCTestCase {
    func testChartQuestionGetsAChart() {
        let reply = DemoResponder.reply(to: "Show me a chart of something")
        XCTAssertTrue(reply.answer.hasChart)
        XCTAssertEqual(reply.answer.bars.first?.label, "Popcorn")
        XCTAssertTrue(reply.answer.chartTitle.contains("made-up"))
        XCTAssertEqual(reply.model, DemoResponder.modelName)
    }

    func testWholeWordsOnly() {
        // "monkey" contains "key" and "problem" contains "pro"; neither should match.
        XCTAssertEqual(DemoResponder.reply(to: "Is a monkey a problem?").answer.title, "Demo mode")
        XCTAssertEqual(DemoResponder.reply(to: "What does Pro add?").answer.title, "About Pro")
        XCTAssertEqual(DemoResponder.reply(to: "How do I add my key").answer.title, "Using your own key")
        XCTAssertEqual(DemoResponder.reply(to: "Hello!").answer.title, "Hello from the couch")
    }

    func testReplyCanBeKeptInHistory() {
        let reply = DemoResponder.reply(to: "anything")
        XCTAssertEqual(reply.replayContent.arrayValue?.first?["text"]?.stringValue, reply.answer.say)
    }

    func testDemoTalksAboutProHonestly() {
        let say = DemoResponder.reply(to: "pro").answer.say
        XCTAssertTrue(say.contains("isn't open yet"))
    }
}

final class SpokenTextTests: XCTestCase {
    func testPlainTextIsUnchanged() {
        XCTAssertEqual(SpokenText.clean("The game starts at eight."), "The game starts at eight.")
    }

    func testMarkdownIsRemoved() {
        let text = """
        ## Tonight's plan
        - **Pizza** at six
        - Movie at `eight`
        1. Bed by eleven
        """
        XCTAssertEqual(SpokenText.clean(text), "Tonight's plan Pizza at six Movie at eight Bed by eleven")
    }

    func testLinksKeepTheirWordsOnly() {
        XCTAssertEqual(
            SpokenText.clean("See [the recipe](https://example.com/recipe) for details."),
            "See the recipe for details."
        )
    }

    func testUnclosedBracketIsLeftAlone() {
        XCTAssertEqual(SpokenText.clean("Score [so far: 3 to 2"), "Score [so far: 3 to 2")
    }

    func testSystemPromptMatchesMode() {
        XCTAssertTrue(SystemPrompt.text(richAnswers: true).contains("chart_title"))
        XCTAssertFalse(SystemPrompt.text(richAnswers: false).contains("chart_title"))
        XCTAssertTrue(SystemPrompt.text(richAnswers: false).contains("no markdown"))
    }

    func testSettingsSurviveSaveAndLoad() throws {
        var settings = AssistantSettings.standard
        settings.effort = .high
        settings.speakAnswers = false
        let data = try JSONEncoder().encode(settings)
        XCTAssertEqual(try JSONDecoder().decode(AssistantSettings.self, from: data), settings)
    }
}
