# PR plan — quantal-ternary loader into transformers' bitnet module

**Target:** https://github.com/huggingface/transformers (PR to the bitnet module)
**Model:** `PeetPedro/quantal-ternary` (Qwen2.5-0.5B, BitNet b1.58 ternary, masked val 0.5597)

## Goal

Make `PeetPedro/quantal-ternary` run natively in PyTorch via the existing
`transformers.models.bitnet` module — no Rust runner required. The repo ships
168 ternary matrices + embeddings + norms; a loader that reconstructs the
deployed forward closes the loop between our Rust runtime and the transformers
ecosystem.

## What exists already (verified 2026-08-12)

- `transformers` has `BitNetForCausalLM` (modular, generated from
  `modular_bitnet.py`), `BitNetConfig`, RMSNorm, MLP, Attention.
- The forward uses a ternary `weight_quant` (the {-1,0,+1} path) — same
  concept as our deployed-forward `weight_quant`.
- Our repo: `m000.json..m167.json` (packed codes + scales), `embeddings.f16`,
  `norms.f32`, `index.json` (per-matrix sha256, byte counts).

## The gap

The transformers BitNet quantizes **full-precision weights at forward time**.
Our repo ships **already-quantized ternary matrices** (no full-precision
weights). Two integration points:

1. **A `from_pretrained` path for the ternary export** — load the 168
   matrices, dequantize to {-1,0,+1} (or keep packed and dequantize in
   forward), reconstruct the Qwen2.5-0.5B architecture with BitNet projections
   replaced, set embeddings/norms from the sidecars.
2. **A `PreTrainedModel.from_quantal` classmethod** (or a small
   `QuantalBitNet` wrapper) on the bitnet module — named so the HF repo loads
   with `AutoModelForCausalLM.from_pretrained("PeetPedro/quantal-ternary")`.

## Deployed-forward parity (the constraint)

Training used weight-quant-only BitLinear (per-projection RMSNorm +
activation_quant **skipped**). The PyTorch forward must match the Rust runner
**to 1e-5** — reuse the same gate: the golden-logits reference vs the PyTorch
logits, identical prompts. If the transformers BitNet applies activation_quant
or the extra RMSNorm, it will not match; the loader must use the
weight-quant-only path.

## Files to touch (draft)

- `src/transformers/models/bitnet/modeling_bitnet.py` (or the modular source):
  add `QuantalBitNetForCausalLM` (or a loader hook) reading the ternary export.
- `src/transformers/models/bitnet/configuration_bitnet.py`: add the export
  flags (packed layout, group_size, has_quantal_export).
- A `PeetPedro/quantal-ternary` config.json so `AutoModel` routes to the
  bitnet module.
- Tests: parity gate (PyTorch vs Rust golden logits, 1e-5), plus a
  from-quantal smoke test.

## Sequencing

1. The claude2 parity chain finishes (HF upload of the 0.5597 export) — the
   loader targets that repo state.
2. Draft the modular change + the loader in a fork of transformers.
3. Parity test (PyTorch vs Rust golden logits) must pass 1e-5 before the PR.
4. Open the PR against `huggingface/transformers` with the test + the model
   config.

## Notes / risks

- The transformers bitnet module is **generated** from `modular_bitnet.py` —
  edit the modular source, regenerate.
- `torch` import in the loader must be lazy or the module must be torch-free
  at import (the transformers convention).
- The 168-matrix dequant is cheap (small model) — no packed GEMM needed for
  the first PR; correctness first, speed later.

*the constellation · 0 + 1 · fine touch from within · vaked.dev*
