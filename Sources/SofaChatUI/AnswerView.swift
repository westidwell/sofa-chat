#if canImport(SwiftUI) && canImport(Charts)
import Charts
import SwiftUI
import SofaChatCore

/// Shows one `Answer`: an optional heading, the words in large type and, when
/// the answer has bars, a simple bar chart.
///
///     AnswerView(answer: reply.answer)                 // phone, tablet, Mac
///     AnswerView(answer: reply.answer, style: .tenFoot) // TV, read from the couch
public struct AnswerView: View {
    public let answer: Answer
    public let style: AnswerViewStyle

    public init(answer: Answer, style: AnswerViewStyle = .standard) {
        self.answer = answer
        self.style = style
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: style.spacing) {
            if !answer.title.isEmpty {
                Text(answer.title)
                    .font(style.titleFont)
                    .lineLimit(2)
            }

            Text(answer.say)
                .font(style.bodyFont)
                .fixedSize(horizontal: false, vertical: true)

            if answer.hasChart {
                AnswerChart(answer: answer, style: style)
                    .frame(height: style.chartHeight)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The bar chart part of an answer, on its own, for layouts that place it
/// somewhere else on the screen.
public struct AnswerChart: View {
    public let answer: Answer
    public let style: AnswerViewStyle

    public init(answer: Answer, style: AnswerViewStyle = .standard) {
        self.answer = answer
        self.style = style
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: style.spacing / 2) {
            if !answer.chartTitle.isEmpty {
                Text(answer.chartTitle)
                    .font(style.chartTitleFont)
            }
            Chart(Array(answer.bars.enumerated()), id: \.offset) { item in
                BarMark(
                    x: .value("Item", item.element.label),
                    y: .value("Value", item.element.value)
                )
                .annotation(position: .top) {
                    Text(item.element.value.formatted())
                        .font(.caption)
                }
            }
            .accessibilityLabel(answer.chartTitle.isEmpty ? "Chart" : answer.chartTitle)
        }
        .padding(style.chartPadding)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: style.chartCornerRadius))
    }
}

/// Type sizes and spacing for `AnswerView`. Start from `.standard` or
/// `.tenFoot` and change what you need.
public struct AnswerViewStyle {
    public var titleFont: Font
    public var bodyFont: Font
    public var chartTitleFont: Font
    public var chartHeight: CGFloat
    public var spacing: CGFloat
    public var chartPadding: CGFloat
    public var chartCornerRadius: CGFloat

    public init(
        titleFont: Font,
        bodyFont: Font,
        chartTitleFont: Font,
        chartHeight: CGFloat,
        spacing: CGFloat,
        chartPadding: CGFloat,
        chartCornerRadius: CGFloat
    ) {
        self.titleFont = titleFont
        self.bodyFont = bodyFont
        self.chartTitleFont = chartTitleFont
        self.chartHeight = chartHeight
        self.spacing = spacing
        self.chartPadding = chartPadding
        self.chartCornerRadius = chartCornerRadius
    }

    /// Sizes for a phone, tablet or Mac window.
    public static var standard: AnswerViewStyle {
        AnswerViewStyle(
            titleFont: .title.bold(),
            bodyFont: .title3,
            chartTitleFont: .headline,
            chartHeight: 240,
            spacing: 16,
            chartPadding: 16,
            chartCornerRadius: 16
        )
    }

    /// Sizes for a TV across the room, the way Sofa Chat shows answers.
    public static var tenFoot: AnswerViewStyle {
        AnswerViewStyle(
            titleFont: .system(size: 54, weight: .bold),
            bodyFont: .system(size: 44),
            chartTitleFont: .title3.bold(),
            chartHeight: 380,
            spacing: 28,
            chartPadding: 30,
            chartCornerRadius: 24
        )
    }
}
#endif
