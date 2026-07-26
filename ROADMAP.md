# hf.app roadmap — becoming THE native local-AI tool on Apple Silicon

The bet: hf.app is the honest macOS front-end, **Osaurus** owns inference, and the
**8b-is org already contains the engines** that make it a category-defining tool. This
maps those gems to concrete integrations. 🜂 *ahogy a dolgok vannak.*

## Shipped
- **v0.1.0–v0.3.0** — Spaces (playable on desktop), offline reader, Osaurus chat,
  MoE optimizer (intent classify → route → expert system prompt), macOS glass UI.
- **v0.4.0 — entheai Memory (preview).** Native Swift port of entheai's
  `crates/memory-pp` (`Sources/HFMac/Memory.swift`): *keep the past raw; search the raw
  space.* On-device raw span store + lexical recall mirroring entheai's `NativeMesh`
  scorer (distinct query-term overlap). Wired into chat (recall-inject + record-raw),
  Run-toolbar toggle, Settings. Verified end-to-end. No model, no network, no telemetry.

## The 8b-is gems → integration map
Mapped all ~80 org repos; these are the ones that directly level up hf.app / entheai.

| Priority | Gem (repo) | Integration | Shape |
|---|---|---|---|
| **1 — voice** | `liquid-rust` (STT, LFM2.5-Audio) · `kokoro-tiny` / `IndexTTS-Rust` (TTS) | Talk to hf.app: mic → transcript → chat → spoken reply. The killer Apple-Silicon feature. | Rust **sidecar** binaries (stdio/localhost), driven from Swift — same pattern as Osaurus. |
| **2 — real memory** | **MEM8** (`8b-Mem8`, `mem8v2`, `m8a/m8c`) | Replace the preview's lexical recall with wave-stored, lossless MEM8 recall. | Sidecar or FFI; keep `Memory.swift`'s interface, swap the scorer. |
| 3 — quant inference | `MLX-QUANT` | Native quantized model support alongside Osaurus. | Via Osaurus/MLX; expose in the Models tab. |
| 4 — compression | `marqant` + `kompress-core` | The "compress LAST" half of memory-pp; compress raw spans as they age. | Already what memory-pp's `KompressMarqant` calls — port or sidecar. |
| 5 — semantic files | `smart-tree` | A "Codebase" surface: semantic search + AST-aware context for the agent. | Already an applet in rustybox; reuse as a tool. |

## Design guardrails (so it stays THE tool, not vapor)
- **Every engine is honest**: a claimed capability ships as working code, or it's marked
  *preview*, or it's not on the page. (The MoE and Memory layers are real; verified.)
- **hf.app stays thin**: heavy engines are separate processes (Osaurus, and future
  Rust sidecars), never bundled weights. The app orchestrates; the engines compute.
- **On-device first**: voice, memory, and inference all run locally. Zero telemetry.
- **Reuse before rebuild**: prefer an existing 8b-is crate as a sidecar over a Swift
  rewrite, unless the port is small and self-contained (as Memory.swift's was).

## Next
Recommended order: **(1) voice sidecar** — it's the standout feature and the crates
exist — then **(2) MEM8** behind the Memory interface. Each is a self-contained,
verifiable slice.
