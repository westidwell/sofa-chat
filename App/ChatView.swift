import Charts
import SwiftUI
import SofaChatCore

/// The main screen: the question, a big answer, an optional chart, and the
/// controls along the bottom.
struct ChatView: View {
    @EnvironmentObject private var model: ChatViewModel
    @State private var draft = ""
    @State private var showSettings = false
    @State private var showPro = false

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            header

            if !model.lastQuestion.isEmpty {
                Text("You asked: \(model.lastQuestion)")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if !model.answer.title.isEmpty {
                Text(model.answer.title)
                    .font(.system(size: 54, weight: .bold))
                    .lineLimit(2)
            }

            Text(model.answer.say)
                .font(.system(size: 44))
                .minimumScaleFactor(0.4)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            if model.answer.hasChart {
                AnswerChart(answer: model.answer)
                    .frame(height: 380)
            }

            controls
        }
        .padding(.horizontal, 80)
        .padding(.vertical, 60)
        // Play/Pause on the Siri Remote stops the voice.
        .onPlayPauseCommand { model.stopTalking() }
        .sheet(isPresented: $showSettings) {
            SettingsView().environmentObject(model)
        }
        .sheet(isPresented: $showPro) {
            ProOverviewView()
        }
    }

    private var header: some View {
        HStack(spacing: 24) {
            Text("Sofa Chat")
                .font(.system(size: 60, weight: .bold))
            if model.isDemo {
                Text("Demo")
                    .font(.headline)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.3), in: Capsule())
            }
            Spacer()
            if model.isThinking {
                ProgressView()
                Text("Thinking…")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 24) {
            TextField("Select me, then hold the mic button and talk", text: $draft)
                .onSubmit(send)
            Button("Ask", action: send)
            Button("Stop voice") { model.stopTalking() }
            Button("New chat") { model.newChat() }
            Button {
                showSettings = true
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
            Button {
                showPro = true
            } label: {
                Label("Pro", systemImage: "lock.fill")
            }
        }
    }

    private func send() {
        let question = draft
        draft = ""
        Task { await model.ask(question) }
    }
}

/// A simple bar chart, sized for reading from across the room.
struct AnswerChart: View {
    let answer: Answer

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !answer.chartTitle.isEmpty {
                Text(answer.chartTitle)
                    .font(.title3)
                    .bold()
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
        }
        .padding(30)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 24))
    }
}
