import SwiftUI
import SofaChatCore

/// Model, effort, voice and key settings, plus the locked Pro items.
struct SettingsView: View {
    @EnvironmentObject private var model: ChatViewModel
    @State private var modelName = ""
    @State private var newKey = ""
    @State private var lockedFeature: ProFeature? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section("Model") {
                    TextField("Model id", text: $modelName)
                        .onSubmit(applyModelName)
                    Button("Use this model") { applyModelName() }
                    Button("Reset to \(APIDefaults.defaultModel)") {
                        modelName = APIDefaults.defaultModel
                        applyModelName()
                    }
                    Text("Now using: \(model.settings.model)")
                        .foregroundStyle(.secondary)
                }

                Section("Thinking effort") {
                    ForEach(Effort.allCases, id: \.self) { effort in
                        Button {
                            model.update { $0.effort = effort }
                        } label: {
                            HStack {
                                Text(effort.label)
                                Spacer()
                                if model.settings.effort == effort {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }

                Section("Answers") {
                    Toggle("Read answers aloud", isOn: setting(\.speakAnswers))
                    Toggle("Headings and charts", isOn: setting(\.richAnswers))
                    Toggle("Retry declined questions on a backup model", isOn: setting(\.useRefusalFallback))
                }

                Section("API key") {
                    Text(model.maskedKey ?? "No key saved (demo mode)")
                    SecureField("Paste a new key", text: $newKey)
                        .onSubmit(saveNewKey)
                    Button("Save new key", action: saveNewKey)
                    if let message = model.keyMessage {
                        Text(message).foregroundStyle(.red)
                    }
                    if model.maskedKey != nil {
                        Button("Remove key from this Apple TV", role: .destructive) {
                            model.removeKey()
                        }
                    }
                }

                Section("Pro (\(PRO_PRICE), not open yet)") {
                    ForEach(ProFeature.allCases) { feature in
                        Button {
                            lockedFeature = feature
                        } label: {
                            Label(feature.name, systemImage: "lock.fill")
                        }
                    }
                }
            }
            .navigationTitle("Settings")
        }
        .onAppear { modelName = model.settings.model }
        .sheet(item: $lockedFeature) { feature in
            ProLockedView(feature: feature)
        }
    }

    private func applyModelName() {
        let name = modelName
        model.update { $0.model = name }
        modelName = model.settings.model
    }

    private func saveNewKey() {
        if model.saveKey(newKey) {
            newKey = ""
        }
    }

    private func setting(_ keyPath: WritableKeyPath<AssistantSettings, Bool>) -> Binding<Bool> {
        Binding(
            get: { model.settings[keyPath: keyPath] },
            set: { newValue in model.update { $0[keyPath: keyPath] = newValue } }
        )
    }
}
