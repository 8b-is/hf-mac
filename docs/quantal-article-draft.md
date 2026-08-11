# quantal-ternary: the baszataska night, masked-val 3.2862

*A BitNet b1.58 ternary model, re-trained on the deployed forward, now live
on the Hub. The "cogito" of the vaked constellation runs offline — in Rust.*

---

## TL;DR

- **Model**: `PeetPedro/quantal-ternary` — Qwen2.5-0.5B continued-trained,
  weight-quantized to **{-1, 0, +1}** (group size 64), exported as **168 ayeOS
  ternary matrices** + token embeddings + RMSNorm vectors.
- **Masked validation (n=90, honest protocol): 3.2862** — the old artifact
  measured identically was 11.34. The acceptance gate passed by a wide margin.
- **Principle**: *train the deployed forward.* The forward used in training is
  byte-identical to the one the Rust runner executes — so what you evaluate is
  what you ship.

---

## Why ternary, again

Ternary weights (`{-1, 0, +1}`) are the smallest useful parameter alphabet.
A 0.5B model quantized this way fits comfortably on a phone, an MCU, or a
Tailscale-only box that never touches the public internet. BitNet b1.58
replaces every linear projection with sign/threshold-quantized weights while
keeping per-group scales — the multiplications collapse to additions.

The vaked constellation runs its "cogito" **offline**: no API key, no cloud,
no telemetry. That is the whole point.

## The baszataska night

The winning checkpoint came out of a single long night on a rented
RTX 3090 (with an A100 40GB lane as backup — both stopped, credit saved).
The marathon was less about the math than about *honesty*:

| | old artifact | winner |
|---|---|---|
| masked val (n=90, same protocol) | 11.34 | **3.2862** |
| eval protocol | padding tokens counted | pad masked, honest mean |
| forward | full BitLinear (RMSNorm + act quant) | **deployed forward** (weight-quant-only) |

Three killers were found and removed:

1. **`mx.clip` over the grad tree** — flaky on mlx-cuda, crashes with silent
   heap corruption. Grad clip off; AdamW wd=0.1 regularizes.
2. **A concurrent agent lane** — another process on the same GPU benchmarked
   and trained simultaneously, splitting the 24 GB card and crashing every run.
3. **A pure-Python cosine LR schedule** — returns `float` past the warmup
   boundary, which mlx-cuda's `apply_single` chokes on. The schedule is now
   `mx`-aware (always an `mx.array`).

## The deployed-forward decision

Full BitLinear applies a per-projection RMSNorm and quantizes activations.
That forward does not exist in the Rust runtime. So training on it optimizes
a model that is *not* what ships.

The winning configuration:

```
forward       weight-quant-only BitLinear  (w + stop_gradient(quant(w) - w))
loss          masked CE (pad id 0 weighted out, mean over valid tokens)
padding       dynamic, bucketed to multiples of 64
optimizer     AdamW, wd 0.1, grad clip off, lr 3e-4 → cosine → 3e-5, 2% warmup
early stop    patience 5 / min-delta 0.05, 30-epoch cap
val           90 samples, stratified from the same file
```

Now `training ≡ deployed ≡ Rust`. No parity gap to paper over.

## Layout on the Hub

```
m000.json … m167.json  168 ternary matrices (packed codes + per-group scales)
index.json             capsule metadata + manifest (sha256, shapes)
embeddings.f16         token embeddings, [151936, 896] (272 MB)
norms.f32              49 RMSNorm gain vectors, [49, 896]
```

`norms.f32` rows: `2i` = layer `i` input_layernorm, `2i+1` = layer `i`
post_attention_layernorm, row 48 = final norm.

## Runtime

Consumed by the **entheai Rust ternary runner** (`crates/ternary`) and the
**`pocoo.vaked.dev/demos/quantal`** live viewer (same files, served from
Cloudflare Pages). The export tooling (`export_quantal_checkpoint.py` +
`export_quantal_assets.py`, fork of `MLX-QUANT` with native ternary quantize)
reproduces the repo from the checkpoint.

> *the constellation · 0 + 1 · fine touch from within · vaked.dev*
