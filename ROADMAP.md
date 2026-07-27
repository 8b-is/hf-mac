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
- **v0.9.0 — Mozart polish.** Hover-to-copy on any message; the active model'''s
  speed shows by the picker *and* in an elegant empty-chat welcome — the quant/
  speed awareness now harmonizes across Models · Run · welcome.
- **v0.8.0 — Chat polish.** Replies render markdown with fenced code blocks
  (streaming-safe — an unclosed fence renders as a growing code block); the view
  follows the streaming reply as it grows; a **Stop** button (⌘.) cancels a
  generation mid-stream, keeping whatever streamed so far.
- **v0.7.0 — Quant/speed awareness.** The Models tab classifies each model by
  on-device speed (`ModelSpeed`: ternary → MLX-4bit → quantized → full) with a
  badge + fast-model presets (MLX 4-bit · BitNet/ternary · GGUF), steering you
  onto models that run 2–4× faster in Osaurus. The ternary frontier — 8b's
  **MLX-QUANT** (BitNet b1.58 / rivaquant / quantal) — landed its Metal **GPU**
  kernel in **v1.0.0** (`ternary_qmv_fast`); the engine primitive now exists and
  the last mile is Osaurus serving it (its `vmlx` MLX-QUANT path). hf.app already
  badges and drives a ternary model the instant Osaurus lists one.
- **v0.6.0 — Streaming chat.** Replies fill token-by-token at the model's real
  tokens/sec (OpenAI-compatible SSE via `OsaurusClient.chatStream`) instead of
  blocking on the whole answer — the point of local inference, made visible.
- **v0.5.0 — Voice (preview).** On-device speech, Apple-native: TTS speaks replies
  (`AVSpeechSynthesizer`), STT dictates prompts forced on-device (`SFSpeechRecognizer`
  `requiresOnDeviceRecognition`). `Sources/HFMac/VoiceEngine.swift`; mic + speaker in the
  chat bar. The `liquid-rust`/`kokoro` sidecar swap slots behind this same interface.

## The 8b-is gems → integration map
Mapped all ~80 org repos; these are the ones that directly level up hf.app / entheai.

| Priority | Gem (repo) | Integration | Shape |
|---|---|---|---|
| **1 — voice ✅** | Apple-native now → `liquid-rust` / `kokoro-tiny` next | Talk to hf.app: mic → transcript → chat → spoken reply. **Shipped v0.5.0** on Apple engines; 8b-native sidecar swap pending. | Sidecar binaries behind `VoiceEngine.swift`. |
| **2 — real memory** | **MEM8** (`8b-Mem8`, `mem8v2`, `m8a/m8c`) | Replace the preview's lexical recall with wave-stored, lossless MEM8 recall. | Sidecar or FFI; keep `Memory.swift`'s interface, swap the scorer. |
| **3 — quant/speed ✅ front-end** | `MLX-QUANT` = MLX + BitNet b1.58 ternary kernels | Models tab steers you onto fast quantized models (v0.7.0). **MLX-QUANT v1.0.0 landed the Metal GPU ternary kernel** (`ternary_qmv_fast`) — the engine primitive now exists; the last mile is Osaurus serving it via its `vmlx` path. hf.app is aligned: `ModelSpeed` classifies the full rivaquant / quantal / mlx-quant lineage and drives it the instant Osaurus lists one. | Engine lands in Osaurus; the thin front-end is ready. |
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
Voice shipped (Apple-native, on-device). Next: **MEM8** behind the `Memory.swift`
interface (wave recall over the lexical scorer), then the **liquid-rust / kokoro
sidecars** to make voice fully 8b-native. Each is a self-contained, verifiable slice.
