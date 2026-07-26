# hf.app — native macOS Hugging Face client

Browse the Hub, run models **locally on Apple Silicon via [Osaurus](https://github.com/dinoki-ai/osaurus)**, and chat from a real window *or* a menu-bar agent. The app is the thin, honest front-end — Osaurus owns the weights, MLX, and serving.

## The loop
```
Browse HF  →  pull into Osaurus  →  run + chat locally (private)  →  manage your models
```

## Run (dev)
```
swift run
```
Requires **Osaurus** running (localhost:1337, OpenAI-compatible). Pull a model in Osaurus, then hit **Refresh** in the Run tab.

## Architecture
- **`Services.swift`** — `HubClient` (HF Hub REST: search + your models) · `OsaurusClient` (Osaurus `/v1` OpenAI API: models + chat).
- **`HFMacApp.swift`** — `@main App` (`WindowGroup` + `MenuBarExtra`) + a MainActor `@Observable AppState`.
- **`Views.swift`** — Browse / Run / Your models, plus the menu-bar quick-prompt agent.

The app never embeds MLX itself — it drives Osaurus. Everything heavy stays in the engine.

## Status
**MVP:** Browse (live HF search) + Run (live local chat via Osaurus) + menu-bar quick prompt. **Next:** HF-token sign-in (Keychain) → your models/Spaces (creator tab), one-click *pull-to-Osaurus*, and ternary/1-bit models (rivaquant) as the hero on-device run.

🜂 *ahogy a dolgok vannak* — on-device, private, real tokens/sec, no fake states.
