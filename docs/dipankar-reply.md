# Reply draft — Dipankar Sarkar audit, round 2

**Where:** https://huggingface.co/posts/PeetPedro/262939583903899#6a7b42a9b9514eaa75dd33aa

**Status:** round-2 fixes live in the JSON + card (commits 0ed7497e / d5354664).

---

Round 1's fixes are yours — the denominator split (8.1x = packed 2-bit layout,
1.58 = log2(3) theory line), the device split, the ppl protocol, the 70B
cross-check. You checked them live and they held. Round 2 is the harder one,
and it is right too:

**1. The throughput row — you caught the real problem.** Once the model is
named, the row becomes checkable, and it fails:

```
0.5e9 x 1.975 / 8 = 0.1234 GB weights/token
384.2 / 0.1234 = 3,113 tok/s        (what the row implies)
the row says      142.8 tok/s       (21.8x apart)
```

The honest reading: **142.8 tok/s is a 0.5B decode rate, and it is NOT
memory-bound.** 0.1234 × 142.8 = 17.6 GB/s = **4.6% of the 384.2 peak**. At
this size per-token overhead dominates, which is the normal situation for a
half-billion-parameter model. The JSON and card now say exactly that:
384.2 GB/s is a device ceiling, 142.8 tok/s is a 0.5B single-stream decode,
and the 21.8x gap is headroom a larger model could spend — not a claim that
this run is memory-bound.

**2. The 70B row is a ceiling, not a scale-check.** You are right that putting
"memory-bound decode" and "the 142.8 tok/s here is the 0.5B model" in the same
bullet list cancelled each other. The card now separates them: the 70B row
(17.28 GB/token → 22 tok/s at peak) is a hardware bound the 0.5B run is
nowhere near, and it is labelled as such.

**3. The corpora/val_split problem.** One held-out split from one file cannot
be WikiText-2, C4 and LAMBADA. Correct — the three rows are **topic slices of
the same training file** (the konstellation corpus used for the continued-
train), not three external corpora. The protocol now says so explicitly, and
each row label carries "(topic slice)". If read as external corpora the
numbers would be invalid; read as slices of one file they are consistent.

**4. The question you put on the front of the card.** What does 142.8 measure?
It is the ternary Metal kernel decoding a 0.5B model at 4.6% of bandwidth —
bound by per-token overhead, not by the weights. The interesting number in
the file is therefore the **21.8x of headroom**, not the 8.1x. You are right
about that too.

Thanks again — the second pass was the one that found the actual claim.
