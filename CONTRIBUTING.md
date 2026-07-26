# Contributing to hf.app

Thank you for your interest in contributing to **`hf.app`**! We welcome contributions from developers of all skill levels — whether fixing a bug, improving SwiftUI performance, adding documentation, or proposing new features.

---

## 📋 Table of Contents

- [Code of Conduct](#-code-of-conduct)
- [Development Environment Setup](#-development-environment-setup)
- [Project Architecture & Structure](#-project-architecture--structure)
- [Coding Guidelines & Patterns](#-coding-guidelines--patterns)
- [Submitting Pull Requests](#-submitting-pull-requests)
- [Release & Build Commands](#-release--build-commands)

---

## 🤝 Code of Conduct

We aim to build an inclusive, respectful, and welcoming open-source community. Please treat all contributors with kindness and respect.

---

## 🛠️ Development Environment Setup

### Prerequisites
1. **macOS 14.0+** (Sonoma or later) on Apple Silicon (recommended) or Intel.
2. **Xcode 15.0+** or Xcode Command Line Tools (`xcode-select --install`).
3. **Swift 5.9+** toolchain.
4. **[Osaurus](https://github.com/dinoki-ai/osaurus)** running locally on `localhost:1337`.

### Getting Started
```bash
# 1. Fork and clone the repository
git clone https://github.com/YOUR-USERNAME/hf-mac.git
cd hf-mac

# 2. Build the project using Swift Package Manager
swift build

# 3. Run the development target
swift run
```

Alternatively, open `Package.swift` in Xcode:
```bash
open Package.swift
```

---

## 🏗️ Project Architecture & Structure

`hf.app` relies on a clean, decoupled architecture:

```
Sources/HFMac/
├── HFMacApp.swift      # App entry point (@main), WindowGroup & MenuBarExtra setup
├── Services.swift      # HubClient (HF Hub REST) & OsaurusClient (OpenAI /v1 API)
├── Views.swift         # SwiftUI view hierarchy (Browse, Run, Your Models, MenuBar agent)
├── Keychain.swift      # Security.framework wrapper for HF tokens
├── OfflineStore.swift   # App state caching & persistence
├── WebView.swift       # WKWebView bridge for interactive model cards
└── Theme.swift         # Modern macOS dark mode tokens & styling constants
```

### Key Architectural Principles
- **Thin Front-End**: `hf.app` handles UI, model discovery, and interaction state. It **never** embeds MLX models directly.
- **Engine Delegation**: Model loading, weight management, and local inference execution are delegated entirely to **Osaurus** via standard HTTP REST (`/v1/chat/completions`, `/v1/models`).
- **MainActor State Management**: Global app state (`AppState`) is an `@Observable` object bound to `@MainActor`.

---

## 🎨 Coding Guidelines & Patterns

### 1. Swift & SwiftUI Conventions
- Adhere strictly to the official [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/).
- Use modern Swift concurrency (`async`/`await`, `Task`, `MainActor`). Avoid legacy completion handler callbacks.
- State management must use `@Observable` (iOS 17+ / macOS 14+) rather than `ObservableObject` / `@Published`.

### 2. Styling & Dark Mode Aesthetics
- Follow the design tokens in [`Theme.swift`](file:///Users/peter.lodri/workspace/peterlodri-sec/hf-mac/Sources/HFMac/Theme.swift).
- Use macOS native dark mode colors, subtle glassmorphic backgrounds, and clean padding.
- Avoid hardcoded magic UI offset numbers; compute layout bounds dynamically.

### 3. Error Handling
- Never silence errors silently (`try?` without logging or UI notification).
- Use typed Swift errors and present user-friendly error banners when network calls to Hugging Face or Osaurus fail.

---

## 🔀 Submitting Pull Requests

### Branch Naming
Create a descriptive branch for your work:
- Features: `feature/your-feature-name`
- Bug fixes: `fix/issue-description`
- Documentation: `docs/short-summary`

### Commit Message Format
We follow clear, imperative commit messages:
```
feat: add HF token sign-in keychain integration
fix: handle Osaurus localhost connection timeouts gracefully
docs: update architecture diagram and installation steps
```

### Pull Request Checklist
Before submitting a PR, ensure:
1. `swift build` compiles cleanly with zero warnings.
2. Code is formatted cleanly and follows repository conventions.
3. Relevant documentation (`README.md`, `docs/`) is updated if features changed.

---

## 📦 Release & Build Commands

To build a standalone macOS application bundle:
```bash
swift build -c release
```

Refer to [`PUBLISHING.md`](file:///Users/peter.lodri/workspace/peterlodri-sec/hf-mac/PUBLISHING.md) for full instructions on cutting tagged Developer-ID notarized DMG releases.

🜂 *ahogy a dolgok vannak* — thank you for contributing!
