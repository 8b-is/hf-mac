# Changelog

All notable changes to HF-MAC{-1,0,+1}.

## [Unreleased]

### Fixed
- **ModelSpeed duplicate** — `gptq` appeared twice in the quant classifier.
- **Chat message duplicate** — `send()` appended the user message twice to the
  API call (once via the chat array, once explicitly), causing the model to see
  every user prompt repeated.
- **CHANGELOG structure** — consolidated `0.13.0` release notes under the proper
  heading; removed stray cross-heading markup under `Unreleased`.

## [0.13.0] — 2026-11-01

### Added
- **deepsiper-enthea wiring.** The sovereign agent harness
  ([`8b-is/deepsiper-enthea`](https://github.com/8b-is/deepsiper-enthea))
  reaches hf.app's Osaurus server through its `llm-osarous` provider seam on
  `localhost:1337`. hf.app keeps ownership of weights and MLX serving; the
  harness owns the agent loop, tools, and session log. Landing page, README,
  and the stack marquee now name the seam.
- **Project Zero — local CPU ternary backend.** A third Run source:
  [`shifulegend/project-zero`](https://github.com/shifulegend/project-zero),
  a dependency-free C99 engine serving `{-1,0,+1}` inference on `:8090`.
  `ProjectZeroClient` + `scripts/setup-project-zero.sh` + `docs/project-zero.md`.
- **`HFMac --check-tools`** — a headless companion health check: resolves the
  binaries, probes the ayeOS daemon over its socket, and prints the entheai argv.
- **MiroFish connection** — connect to a local
  [`666ghj/MiroFish`](https://github.com/666ghj/MiroFish) swarm-intelligence
  prediction engine over HTTP (Flask `:5001`, Vue `:3000`). `MiroFishClient` +
  an Ecosystem card; AGPL stays a separate process. `docs/mirofish.md`.
- **MOE-ptimizer connection** — a fourth Run source: the transparent
  OpenAI-compatible context-optimizing proxy
  ([`peterlodri-sec/moeptimizer`](https://github.com/peterlodri-sec/moeptimizer),
  default `:8080`). `docs/moeptimizer.md`.
- **Landing Web Audio** — the hero's two wave systems (cyan mind · amber
  anchor) are now audible: a gentle oscillator pair over a filtered creek
  bed, pointer-shaped, opt-in via the nav **sound** toggle. Plus SOTA UX
  polish (safe-area insets, focus rings, coarse-pointer targets).
- **Landing reskin** — `docs/` is now an interactive surface (animated ternary
  field, live MoE router demo, animated data-flow pipeline, reveals).
- **`scripts/e2e-project-zero.sh`** — an end-to-end check of the Project Zero
  lane (build → serve → probe the OpenAI surface). Verified against the live
  engine: `models()` / `chat()` / `chatStream()` all match.

### Changed
- **Landing page domain.** Canonical, Open Graph, Twitter, JSON-LD, and README
  links now use `https://hf.8b.is/`; `docs/CNAME` pins the GitHub Pages custom
  domain. Version bumped to `0.13.0` (`project.yml` + `Packaging/Info.plist`),
  and downloads follow `releases/latest`.

### Fixed
- **Companion detection** — the Ecosystem tab reported entheai / ayeOS /
  hf-mount / HF Accelerate as missing. Paths were hardcoded to `/usr/local/bin`
  (they live in `~/.cargo/bin`, `/opt/homebrew/bin`, the Python framework), and
  the Developer-ID build was signed with `app-sandbox`, which cannot read those
  paths or exec the children. A `Toolchain` resolver (PATH + known dirs + env
  overrides) now backs every client, and the OSS build is sandbox-free.
- **entheai launch** — the prompt must be **positional** (`--prompt` does not
  exist), with `--fanout` / `--no-companion`; and a first-wins continuation
  gate stops the timeout path and the completion path double-resuming (the
  v.12.0 background crash).
- **ayeOS daemon** — the client dialed TCP:9876, but`ayeosd` binds a local
  **UNIX socket** (`/tmp/ayeosd.sock`) under the AyeFire covenant (no IP).

## [0.12.0] — 2026-08-12

### Added
- **HF Storage Buckets support** — native bucket management via the `hf`
  CLI integration: `hf buckets create/sync/info`, with Xet dedup and the
  built-in CDN for streaming training corpora to GPUs.
- **quantal-ternary ready** — first-class support for the constellation's
  0.5B BitNet b1.58 ternary model (masked val 0.5597): 168 ayeOS ternary
  matrices run through the MLX-QUANT + ayeOS stack, offline in Rust.

### Changed
- Version bumped to 0.12.0; landing page download URLs aligned to v0.12.0.
- Landing page now lists the quantal-ternary + HF Storage Bucket features.

## [0.11.0] — 2026-07-28

### Added
- Notarized `.dmg` release pipeline (eveloper-ID signed, Gatekeeper-clean).

## [0.10.0] — 2026-07-28

### Added
- Ecosystem tab: Osaurus · entheai · ayeOS · MEM8 · MLX-QUANT unifiedstatus.

*the constellation · 0 + 1 · fine touch from withn · ake.dev*