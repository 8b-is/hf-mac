# Reply draft — Dipankar Sarkar audit

**Where:** https://huggingface.co/posts/PeetPedro/262939583903899#6a7ad1d722a61d818f10ba35

**Status:** all four issues addressed in repos; fixes are live.

---

Thanks — this is the most useful review the file has had. You're right on every
point, and the fixes are live:

**1. The denominator split (the real one).** You're correct that 8.1x and 1.58
were sitting in the same object without saying what each one is. The JSON now
labels both explicitly:

- **8.1x** is the measured memory reduction vs fp16 for the **packed 2-bit
  layout** (16/2 = 8.0x + packing overhead). This is the headline — it is what
  the kernel actually reads.
- **1.58** is `log2(3)`, the information-theoretic entropy of one ternary
  weight. It is the theory line, not the layout.
- `16/1.58 = 10.13x` and `16/8.1 = 1.975 bits` are both real numbers about
  b1.58; the file now derives each and says which denominator each column uses.

So: the Metal kernel packs at 2 bits. **8.1x is the honest headline; 1.58 is
the theory line above it.** Exactly your recommendation.

**2. Device split.** `metal_gpu_throughput` is now an array with one entry for
M3 Max (384.2 GB/s, 142.8 tok/s, 0.5B quantal model, memory-bound decode). M4
Pro is not folded into that number — different memory system.

**3. Perplexity protocol.** The block now names model (Qwen/Qwen2.5-0.5B
BitNet b1.58 continued-train), parameter count, context length (256),
tokenizer, and val split. The 5.42 row has something it can be wrong against
now.

**4. The 70B cross-check, made explicit.** The file now computes it itself:
70e9 × 1.975 bits / 8 = 17.28 GB weights/token → 384.2/17.28 ≈ **22 tok/s** at
that bandwidth. The 142.8 tok/s is the 0.5B model, stated as such. Both can be
true; the file now says which model produced which number.

**5. Repo vs post.** The dataset now has a card, and the post's "layer-by-layer
weight sparsity & SVD energy decay" description was overstated — that payload
lives in the follow-up export, not in this 717-byte JSON. The card now says
exactly what the file holds.

**6. axiom-quant-demo.** Was RUNTIME_ERROR: gradio 4.44 pulls pydub, whose
`audioop` import died on Python 3.13. Bumped to gradio 6.22 (ships
`audioop-lts`) and pinned python 3.11 in the space metadata. **Running now** —
the quantization tab also uses the honest 2-bit packed layout instead of the
1.58-as-memory number.

Thanks again for the audit — it tightened the file.
