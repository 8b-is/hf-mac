# Changelog

All notable changes to HF-MAC{-1,0,+1}.

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
- Notarized `.dmg` release pipeline (Developer-ID signed, Gatekeeper-clean).

## [0.10.0] — 2026-07-28

### Added
- Ecosystem tab: Osaurus · entheai · ayeOS · MEM8 · MLX-QUANT unified status.

*the constellation · 0 + 1 · fine touch from within · vaked.dev*
