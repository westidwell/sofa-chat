# Contributing

Bug fixes and new free features are welcome.

Features listed in PRO.md are reserved for the Pro edition, so pull requests that add them will be closed with a pointer to PRO.md.

## Before you open a pull request

- Run the tests: `swift test --package-path SofaChatCore`. They run offline and need no key.
- If you change the app, check that it still builds: `xcodegen generate`, then build the `SofaChat` scheme for an Apple TV simulator.
- Keep `SofaChatCore` free of Apple-only frameworks (wrap anything Apple-only in `#if canImport(...)`), so the tests keep running on Linux.
- Never put an API key, token or other secret in code, tests or fixtures. Tests use obviously fake keys such as `sk-ant-test-0000000000000000`.
- No analytics, tracking or calls to any service other than the API the person configured.

## Reporting a bug

Open an issue with your tvOS version, the model id from Settings, what you asked, and what the screen showed. Don't paste your API key.
