# Security Policy — hf.app

At **`hf.app`**, security, data privacy, and user sovereignty are fundamental architectural design choices, not afterthoughts. This document outlines our security architecture, data handling practices, sandbox policies, and vulnerability reporting procedures.

---

## 🔒 Security Architecture & Data Privacy

`hf.app` is designed as a **thin, honest native macOS client**. It does not collect user analytics, run hidden background daemons, or transmit telemetry to third-party tracking servers.

### 1. Zero External Telemetry & Local Execution
- **Zero Tracking**: `hf.app` contains no telemetry, product analytics, crash reporting trackers, or diagnostic telemetry.
- **Local Engine Binding**: All local LLM inference occurs strictly via `localhost:1337` communicating with [Osaurus](https://github.com/dinoki-ai/osaurus). No prompts or chat histories leave your local machine.

### 2. macOS App Sandbox & Entitlements
`hf.app` strictly adheres to Apple's macOS App Sandbox security controls defined in [`Packaging/hf-mac.entitlements`](file:///Users/peter.lodri/workspace/peterlodri-sec/hf-mac/Packaging/hf-mac.entitlements):

```xml
<key>com.apple.security.app-sandbox</key>
<true/>
<key>com.apple.security.network.client</key>
<true/>
```

- **Outbound Network Client Only**: Network permissions are restricted exclusively to outgoing client requests (HTTPS REST requests to `api-inference.huggingface.co` for model search and metadata, and HTTP requests to `localhost:1337` for local inference).
- **No Direct File System Access**: The app operates inside its sandboxed container, preventing unauthorized access to your local file system or private user directories.

### 3. Keychain Token Storage
Hugging Face Access Tokens are securely stored using Apple's system-level `Security.framework` (`SecItemAdd`, `SecItemCopyMatching`):
- **Account Service**: `dev.peterl.hfmac.token`
- **Access Level**: Accessible strictly by `hf.app` within your macOS user login keychain.
- **No Hardcoded Credentials**: API tokens are never written to disk unencrypted, logged in standard output, or cached in plaintext store.

---

## 🛡️ Supported Versions

We maintain security updates and patches for the following versions:

| Version | Supported | Security Maintenance |
|---|---|---|
| `v0.1.x` (Main / Latest) | ✅ Yes | Active development and rapid security patching |
| `< v0.1.0` (Development Builds) | ❌ No | Please upgrade to the latest tagged release |

---

## 📩 Reporting a Vulnerability

We take all security reports seriously and appreciate responsible disclosure efforts.

### How to Submit a Report
If you discover a security vulnerability or credential leak risk:

1. **Do NOT open a public GitHub issue.**
2. Send an email directly to **`security@peterl.dev`** or submit a private security advisory via [GitHub Security Advisories](https://github.com/8b-is/hf-mac/security/advisories/new).
3. Include detailed steps to reproduce the issue (proof-of-concept code, environment details, macOS version).

### Response Expectations
- **Initial Acknowledgment**: Within 24-48 hours.
- **Assessment & Triage**: Within 3 business days.
- **Patch Release & Disclosure**: Fixes will be pushed to `main` and released in a patch build with a CVE/advisory credit.

---

## 🔏 Code Signing & Notarization

Every release DMG published on our [GitHub Releases](https://github.com/8b-is/hf-mac/releases) page undergoes automated Apple Developer ID signing and notarization:

1. **Developer-ID Certificate**: Signed with an official Apple Developer ID Application certificate.
2. **Hardened Runtime**: Built with macOS Hardened Runtime (`-o runtime`) enabled.
3. **Apple Notary Service**: Notarized and stapled (`xcrun notarytool`) by Apple servers prior to release distribution.

You can verify the notarization of your installed DMG locally via Terminal:
```bash
spctl -a -vv --type install /path/to/HFMac.dmg
```

🜂 *ahogy a dolgok vannak* — on-device, private, real tokens/sec, no fake states.
