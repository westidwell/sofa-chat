# SofaChatCore

Ask Claude a question and get back an answer made for a screen: what to say out loud, a short heading and, when numbers help, a small bar chart. One Swift package, no dependencies. It's the engine inside [Sofa Chat](https://github.com/westidwell/sofa-chat), a free Apple TV app.

![Sofa Chat on Apple TV, answering with a heading, spoken words and a bar chart](docs/sofa-chat-chart.jpg)

*Sofa Chat on the Apple TV simulator in demo mode, with made-up numbers.*

> SofaChatCore is an independent open-source project. It is not made by, affiliated with or endorsed by Anthropic.

## What's in it

- **SofaChatCore** builds the request to Anthropic's Messages API, asks for a small structured answer (`say`, `title`, `chart_title`, `bars`) and reads it back. It also keeps the conversation, stores the person's API key in the Keychain, cleans text so it reads well aloud, and has a demo mode with canned answers that needs no key and no network. Builds on iOS, tvOS, macOS and Linux.
- **SofaChatUI** has `AnswerView`, a SwiftUI view that shows an answer with its heading and chart. Use `.standard` sizes for a phone, tablet or Mac, or `.tenFoot` for a TV across the room.

## Add it

In Xcode, choose File > Add Package Dependencies and paste the repository address. Or in `Package.swift`:

```swift
.package(url: "https://github.com/westidwell/sofa-chat-core", from: "0.1.0")
```

Then add `SofaChatCore`, and `SofaChatUI` if you want the view, to your target.

## Use it

```swift
import SofaChatCore
import SofaChatUI

var conversation = Conversation()
conversation.addQuestion("Which planets are the biggest?")

let settings = AssistantSettings(
    systemPrompt: "You answer visitors' questions on a science museum kiosk."
)
let reply = try await AssistantClient().send(
    conversation: conversation,
    settings: settings,
    apiKey: personsKey
)
conversation.addReply(reply)   // keeps the chat going for the next question

// In SwiftUI:
AnswerView(answer: reply.answer)
```

No key yet? `DemoResponder.reply(to: "Show me a chart")` returns a made-up answer with a chart, so you can build the screen first.

Leave `systemPrompt` out and you get Sofa Chat's own instructions, written for a living-room TV. Either way the rules for the answer format are added for you.

## About the API key

Don't put your own API key inside an app you ship, because anyone can pull it out. Let each person paste their own key (`KeychainKeyStore` keeps it on that device only), or send requests through a server you run.

## The answer format

The answer shape is small on purpose so any screen can show it. It's written up in [SPEC.md](SPEC.md) if you want to use the same shape elsewhere.

## Works on

iOS 17, tvOS 17 and macOS 13 or later. `SofaChatCore` also builds on Linux with Swift 5.9 or later. Every push runs the tests on Linux and macOS and builds for iOS and tvOS.

## Built with it

- [Sofa Chat](https://github.com/westidwell/sofa-chat): talk to Claude from the couch on Apple TV.

Built something with it? Open a pull request that adds it to this list.

## Contributing

Bug reports, ideas and pull requests are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT. See [LICENSE](LICENSE).
