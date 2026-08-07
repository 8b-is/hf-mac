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
4. **[Osaurus](https://github.com/osaurus-ai/osaurus)** running locally on `localhost:1337`.

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
- Follow the design tokens in [`Theme.swift`](Sources/HFMac/Theme.swift).
- Use macOS native dark mode colors, subtle glassmorphic backgrounds, and clean padding.
- Avoid hardcoded magic UI offset numbers; compute layout bounds dynamically.

### 3. Error Handling
- Never silence errors silently (`try?` without logging or UI notification).
- Use typed Swift errors and present user-friendly error banners when network calls to Hugging Face or Osaurus fail.

---

##  Submitting Pull Requests

### Primary upstream contribution targets (kapu-nélküli, no-CLA)

The hf.app project is part of the wider constellation; the following
upstream projects are the designated first-class contribution lanes —
all no-CLA, external-PR-friendly:

| Project | Lane | First issue type |
|---|---|---|
| [`huggingface/transformers`](https://github.com/huggingface/transformers) | Good First Issue | docs / bisect-grade bugfix |
| [`safetensors/safetensors`](https://github.com/safetensors/safetensors) | good first issue | Rust+Python serialization |
| [`huggingface/optimum`](https://github.com/huggingface/optimum) | good first issue | quant/export tooling |
| [`ml-explore/mlx`](https://github.com/ml-explore/mlx) | good first issue | Metal kernel / dtype parity |
| [`ggml-org/llama.cpp`](https://github.com/ggml-org/llama.cpp) | good first issue | GGUF converters / quant |
| [`modelcontextprotocol/rust-sdk`](https://github.com/modelcontextprotocol/rust-sdk) | tracker | MCP transports / spec |
| [`ast-grep/ast-grep`](https://github.com/ast-grep/ast-grep) | help wanted | control-flow ops / LSIF |

Rule: disclose AI assistance in PR descriptions (several of these projects
hard-close undisclosed agent-authored PRs). Human review before opening.

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

Refer to [`PUBLISHING.md`](PUBLISHING.md) for full instructions on cutting tagged Developer-ID notarized DMG releases.

🜂 *ahogy a dolgok vannak* — thank you for contributing!
