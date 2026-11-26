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
        Group {
            if model.needsSetup {
                SetupView()
            } else {
                ChatView()
            }
        }
        #if DEBUG
        .task {
            // Screenshot helper (debug builds only), used by
            // .github/workflows/screenshots.yml: opens the demo and asks.
            if let question = ScreenshotScene.demoQuestion, model.needsSetup {
                model.useDemo()
                await model.ask(question)
            }
        }
        #endif
    }
}

#if DEBUG
/// Launch arguments that set up a screen for the README screenshots.
/// `-SofaChatDemoQuestion "..."` opens the demo and asks that question.
/// `-SofaChatShowPro YES` also opens the Pro list.
enum ScreenshotScene {
    static var demoQuestion: String? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-SofaChatDemoQuestion"), index + 1 < args.count else {
            return nil
        }
        return args[index + 1]
    }

    static var showPro: Bool {
        ProcessInfo.processInfo.arguments.contains("-SofaChatShowPro")
    }
}
#endif
