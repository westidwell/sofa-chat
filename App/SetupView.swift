import SwiftUI
import SofaChatCore

/// First launch: paste a key once, or try the demo.
struct SetupView: View {
    @EnvironmentObject private var model: ChatViewModel
    @State private var keyText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 36) {
            Text("Sofa Chat")
                .font(.system(size: 76, weight: .bold))

            Text("Talk with an AI assistant from your couch. It works with Anthropic's Claude API, using your own API key.")
                .font(.title3)

            VStack(alignment: .leading, spacing: 12) {
                Text("1. Get an API key from the Claude Console at platform.claude.com.")
                Text("2. Select the box below. When the keyboard opens, you can paste from your iPhone.")
                Text("3. Your key is kept in this Apple TV's Keychain and only sent to api.anthropic.com.")
            }
            .font(.body)
            .foregroundStyle(.secondary)

            SecureField("Paste your API key (starts with sk-ant-)", text: $keyText)
                .onSubmit(save)

            if let message = model.keyMessage {
                Text(message)
                    .foregroundStyle(.red)
            }

            HStack(spacing: 40) {
                Button("Save key", action: save)
                Button("Try the demo (no key)") { model.useDemo() }
            }
        }
        .padding(120)
    }

    private func save() {
        if model.saveKey(keyText) {
            keyText = ""
        }
    }
}
