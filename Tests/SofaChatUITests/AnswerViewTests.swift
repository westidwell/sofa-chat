#if canImport(SwiftUI) && canImport(Charts)
import SwiftUI
import XCTest
import SofaChatCore
@testable import SofaChatUI

final class AnswerViewTests: XCTestCase {
    func testViewsBuildForPlainAndChartAnswers() {
        let plain = DemoResponder.reply(to: "hello").answer
        let chart = DemoResponder.reply(to: "chart").answer
        XCTAssertFalse(plain.hasChart)
        XCTAssertTrue(chart.hasChart)
        _ = AnswerView(answer: plain).body
        _ = AnswerView(answer: chart, style: .tenFoot).body
        _ = AnswerChart(answer: chart).body
    }

    func testTenFootIsBiggerThanStandard() {
        XCTAssertGreaterThan(AnswerViewStyle.tenFoot.chartHeight, AnswerViewStyle.standard.chartHeight)
        XCTAssertGreaterThan(AnswerViewStyle.tenFoot.spacing, AnswerViewStyle.standard.spacing)
    }
}
#else
import XCTest

// SwiftUI isn't available on this platform (for example Linux), so there is
// nothing to draw; the engine's own tests still run.
final class AnswerViewTests: XCTestCase {
    func testNothingToDrawHere() {}
}
#endif
