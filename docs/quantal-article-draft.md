# quantal-ternary: 3.29 → 1.64 — the baszataska nights, and an honest audit

*A BitNet b1.58 ternary model, re-trained on the deployed forward, now live
on the Hub. The "cogito" of the vaked constellation runs offline — in Rust.*

---

## TL;DR

- **Model**: `PeetPedro/quantal-ternary` — Qwen2.5-0.5B continued-trained,
  weight-quantized to **{-1, 0, +1}** (group size 64), exported as **168 ayeOS
  ternary matrices** + token embeddings + RMSNorm vectors.
- **Masked validation (n=90, honest protocol): 1.6998** (fine-tune touched
  **1.6404**) — the old artifact measured identically was **11.34**. The gate
  passed by a wide margin.
- **Training ≡ deployed — proven.** The Rust ternary runner reproduces the
  training forward to **1e-5** (both gate prompts, identical argmax).
- **Principle**: *train the deployed forward.* What you evaluate is what you
  ship.

---

## Why ternary, again

Ternary weights (`{-1, 0, +1}`) are the smallest useful parameter alphabet.
A 0.5B model quantized this way fits comfortably on a phone, an MCU, or a
Tailscale-only box that never touches the public internet. BitNet b1.58
replaces every linear projection with sign/threshold-quantized weights while
keeping per-group scales — the multiplications collapse to additions.

The vaked constellation runs its "cogito" **offline**: no API key, no cloud,
no telemetry. That is the whole point.

## The training story

Two nights on rented GPUs (RTX 3090 → L40), 7,000 samples from the
constellation corpus, and three killers found and removed:

1. **`mx.clip` over the gradient tree** — flaky on mlx-cuda, silent heap
   corruption. Grad clip off; AdamW wd=0.1 regularizes.
2. **A concurrent ghost** — another process on the same rented GPU, splitting
   the 24 GB card and crashing every run. Killed it; the training ran.
3. **A pure-Python cosine LR schedule** — returned `float` past the warmup
   boundary; mlx-cuda's `apply_single` crashed. The schedule is now
   `mx`-aware (always an `mx.array`).

The masked-val trajectory: **11.34 (old artifact) → 3.2862 → 1.6998 →
1.6404** — every step under the same honest protocol (pad masked out of the
loss, real 90-sample stratified hold-out).

## The deployed-forward decision

Full BitLinear applies a per-projection RMSNorm and quantizes activations.
That forward does not exist in the Rust runtime. So training on it optimizes
a model that is *not* what ships. The winning configuration is
weight-quant-only BitLinear — and the **Rust runner now reproduces the
training forward to 1e-5** (golden-logits gate, both prompts, identical
argmax). No parity gap to paper over.

## The audit that tightened the file

An external reviewer (Dipankar Sarkar) read the benchmark JSON and caught the
real gaps:

- **8.1x vs 1.58 bits** — different denominators. 8.1x is the packed 2-bit
  layout (the honest headline); 1.58 is log2(3), the theory line. Both now
  labelled with derivations.
- **142.8 tok/s is a 0.5B decode at 4.6% of peak bandwidth** — overhead-bound,
  NOT memory-bound. The 70B row is a ceiling, not a scale-check.
- **Perplexity rows are topic slices of one file**, not three external corpora.

Every point was fixed in the JSON and the card, and the replies concede each
— because they were right.

## Layout on the Hub

```
m000.json … m167.json  168 ternary matrices (packed codes + per-group scales)
index.json             capsule metadata + manifest (sha256, shapes)
embeddings.f16         token embeddings, [151936, 896] (272 MB)
norms.f32              49 RMSNorm gain vectors, [49, 896]
quantal_model.safetensors  the full 1.6998 checkpoint (989 MB) for fine-tuning
```

## Runtime

Consumed by the **entheai Rust ternary runner** (`crates/ternary`) and the
**`pocoo.vaked.dev/demos/quantal`** live viewer. The full story — the
training nights, the audit, the numbers that now check themselves — is on the
[constellation blog](https://pocoo.vaked.dev/posts/2026-08-11-quantal-ternary-3_29-to-1_64.html).

> *the constellation · 0 + 1 · fine touch from within · vaked.dev*
