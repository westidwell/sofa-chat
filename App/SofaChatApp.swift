import SwiftUI

@main
struct SofaChatApp: App {
    @StateObject private var model = ChatViewModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
        }
    }
}

/// Shows key setup until there is a key (or the demo was picked), then the chat.
struct RootView: View {
    @EnvironmentObject private var model: ChatViewModel

    var body: some View {
        if model.needsSetup {
            SetupView()
        } else {
            ChatView()
        }
    }
}
