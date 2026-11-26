# Security

Please don't report security problems in a public issue.

Report them privately through GitHub: open the **Security** tab of this repo and choose **Report a vulnerability**, or go straight to [the private report form](https://github.com/westidwell/sofa-chat/security/advisories/new).

Things worth reporting:

- Anything that could send the API key somewhere other than `api.anthropic.com`, or write it anywhere other than the Apple TV's Keychain.
- Anything that sends a question, an answer or other data to a server other than the one the person set up.

Fixes go into the latest version on `main`.
