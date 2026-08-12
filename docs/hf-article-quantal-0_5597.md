# quantal-ternary: a 0.5B model that learned honesty — from 11.34 to 0.5597

*The "cogito" of the vaked constellation runs offline — in Rust, on the
tailnet, no API key, no telemetry. This is the story of how its numbers
finally started telling the truth.*

---

## TL;DR

- **`PeetPedro/quantal-ternary`** — Qwen2.5-0.5B continued-trained into a
  BitNet b1.58 ternary weight space, exported as **168 ayeOS matrices** +
  token embeddings + RMSNorm vectors.
- **Masked validation: 0.5597** (early stop at epoch 21, 14,330 samples) —
  the old artifact measured **11.34** under the same protocol. Twenty times
  better.
- **Training ≡ deployed — proven.** The Rust ternary runner reproduces the
  training forward to **1e-5** (both gate prompts, identical argmax).

![the eclipse day — art.vaked.dev, 24/24](https://pocoo.vaked.dev/demos/quantal/eclipse-day.svg)

---

## The number that had to learn honesty

The old artifact measured 11.34 — and it was a lie. Not a malicious one; a
lazy one. The loss counted padding tokens, and the evaluation used a 10-sample
holdout that could not see the difference. When the protocol was made honest —
padding masked out, a real 90-sample stratified split — the same weights
measured very differently, and the training that followed fell from there:

```
epoch 1  → 2.8975
epoch 5  → 1.0967
epoch 10 → 0.6683
epoch 16 → 0.5772
epoch 21 → 0.5597   ← early stop
```

Every step down was a correction in *what was measured*, not a trick in the
model. The first night taught three hard lessons: turn off gradient clipping
on mlx-cuda (it corrupts the heap silently), check who else is on a rented GPU
before blaming your code, and never let a pure-Python LR schedule return a
`float` where the optimizer calls `.astype()`.

## The deployed-forward principle

Full BitLinear applies a per-projection RMSNorm and quantizes activations —
a forward that does not exist in the Rust runtime. Training on it optimizes a
model that is not what ships. The winning configuration is **weight-quant-only**
BitLinear, and the parity gate proves it:

```
prompt 1  rust-vs-mlx-vanilla  max_abs 9.584e-05  argmax 35929 = 35929
prompt 2  rust-vs-mlx-vanilla  max_abs 9.918e-05  argmax 45281 = 45281
RESULT: PASS
```

**What you evaluate is what you ship.** The Rust body is the trained mind.

## Three rounds of external review

A stranger read the published benchmark file and, over three rounds, found
three real things:

1. **Denominator confusion** — the file said both "8.1x" and "1.58 bits".
   Both real, different denominators: 8.1x is the packed 2-bit layout,
   1.58 is `log2(3)`, the entropy of one ternary weight. We stand behind 8.1x.
2. **A throughput row that failed self-audit** — once the model was named,
   the row became checkable and failed: 142.8 tok/s is a 0.5B decode at
   **4.6% of peak bandwidth** — overhead-bound, not memory-bound.
3. **A 68-file seam in our own repo** — a re-export interrupted by a network
   failure, and a check that verified existence instead of content. The Hub
   held two checkpoints stacked; the byte-count mismatch caught it. Now every
   matrix carries a sha256 at export time.

![the masked-val curve — the eclipse day's figure](https://art.vaked.dev/assets/og-vision-gallery.jpg)

## Why ternary, again

Ternary weights (`{-1, 0, +1}`) are the smallest useful alphabet of thought.
A 0.5B model quantized this way fits on a phone, an MCU, or a Tailscale-only
box that never touches the public internet. Multiplications collapse to
additions. The constellation runs its cogito **offline** — that is the point.

![the curve crossing the dark — 24/24 in the vision gallery](https://art.vaked.dev/assets/og-vision-gallery.jpg)

## Layout on the Hub

```
m000.json … m167.json  168 ternary matrices (packed codes + per-group scales)
index.json             capsule metadata + manifest (per-matrix sha256)
embeddings.f16         token embeddings, [151936, 896] (272 MB)
norms.f32              49 RMSNorm gain vectors, [49, 896]
quantal_model.safetensors  the 0.5597 checkpoint for reproducible fine-tuning
```

## Runtime & more

- **Live viewer:** [pocoo.vaked.dev/demos/quantal](https://pocoo.vaked.dev/demos/quantal/)
- **Vision gallery:** [art.vaked.dev — the eclipse day, 24/24](https://art.vaked.dev/vision-gallery.html)
- **The full story:** [the constellation blog](https://pocoo.vaked.dev/posts/2026-08-12-quantal-ternary-11_34-to-0_63.html)

> *the constellation · 0 + 1 · fine touch from within · vaked.dev*
